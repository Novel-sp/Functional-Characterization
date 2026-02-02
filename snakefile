import os
import glob
import pandas as pd

configfile: "config.yaml"

# --- Variables ---
INPUT_DIR  = config["paths"]["input_dir"]
OUTPUT_DIR = config["paths"]["output_dir"]

# Reverted to your original sample identification format
SAMPLES = [os.path.splitext(os.path.basename(f))[0] for f in glob.glob(os.path.join(INPUT_DIR, "*.fasta"))]

# Tool-specific Sub-dirs
PROKKA_OUT    = os.path.join(OUTPUT_DIR, "prokka")
COG_OUT       = os.path.join(OUTPUT_DIR, "cog")
ANTISMASH_OUT = os.path.join(OUTPUT_DIR, "antismash_results")
ABRICATE_OUT  = os.path.join(OUTPUT_DIR, "abricate_results")
GENOMAD_OUT   = os.path.join(OUTPUT_DIR, "genomad_results")

ABRICATE_DBS  = config["params"]["abricate_databases"]

rule all:
    input:
        os.path.join(COG_OUT, "merged_classifier_count.csv"),
        os.path.join(ANTISMASH_OUT, "AntiSMASH_results.csv"), 
        expand(os.path.join(ABRICATE_OUT, "Abricate_{db}.csv"), db=ABRICATE_DBS),
        os.path.join(GENOMAD_OUT, "combined_virus_summary.csv"),
        os.path.join(GENOMAD_OUT, "combined_virus_genes.csv"),
        os.path.join(GENOMAD_OUT, "combined_plasmid_summary.csv"),
        os.path.join(GENOMAD_OUT, "combined_plasmid_genes.csv")

# --- STEP 1: PROKKA ---
rule run_prokka:
    input: fasta = os.path.join(INPUT_DIR, "{sample}.fasta")
    output: faa = os.path.join(PROKKA_OUT, "{sample}", "{sample}.faa")
    conda: config["envs"]["prokka"]
    shell: "prokka --outdir {PROKKA_OUT}/{wildcards.sample} --prefix {wildcards.sample} --force {input.fasta}"

# --- STEP 2: COG SETUP & RUN ---
rule setup_cog_database:
    output: db_marker = os.path.join(config["paths"]["cog_db_dir"], "Cdd.pal")
    params: db_dir = config["paths"]["cog_db_dir"], url = config["params"]["cog_db_url"]
    shell: "mkdir -p {params.db_dir} && cd {params.db_dir} && wget -c {params.url} && tar -xvzf Cdd_LE.tar.gz"

rule run_cogclassifier:
    input: 
        faa = os.path.join(PROKKA_OUT, "{sample}", "{sample}.faa"),
        db = os.path.join(config["paths"]["cog_db_dir"], "Cdd.pal")
    output: summary = os.path.join(COG_OUT, "{sample}", "classifier_stats.txt")
    conda: config["envs"]["cogclassifier"]
    shell: "COGclassifier -i {input.faa} -o {COG_OUT}/{wildcards.sample}"

rule merge_cog_results:
    input:
        # This forces the rule to wait until ALL samples have run through COGclassifier
        stats = expand(os.path.join(COG_OUT, "{sample}", "classifier_stats.txt"), sample=SAMPLES)
    output:
        merged = os.path.join(COG_OUT, "merged_classifier_count.csv")
    params:
        cog_dir = COG_OUT
    conda:
        config["envs"]["cogclassifier"] # Uses the same env as COGclassifier for pandas
    shell:
        "python {workflow.basedir}/cog_merge.py {params.cog_dir} {output.merged}"

# --- STEP 3: ANTISMASH ---
rule download_antismash_db:
    output: directory(os.path.join(config["paths"]["antismash_db"], "pfam"))
    conda: config["envs"]["antismash"]
    shell: "download-antismash-databases --database-dir {config[paths][antismash_db]}"

rule run_antismash:
    input:
        genome = os.path.join(INPUT_DIR, "{sample}.fasta"),
        db_ready = os.path.join(config["paths"]["antismash_db"], "pfam"),
        trigger = os.path.join(COG_OUT, "{sample}", "classifier_stats.txt")
    output: index = os.path.join(ANTISMASH_OUT, "{sample}", "index.html")
    threads: config["params"]["threads_med"]
    conda: config["envs"]["antismash"]
    shell:
        """
        rm -rf {ANTISMASH_OUT}/{wildcards.sample}
        antismash {input.genome} --output-dir {ANTISMASH_OUT}/{wildcards.sample} \
            --databases {config[paths][antismash_db]} --genefinding-tool prodigal \
            --cpus {threads} --taxon bacteria --cb-general --cb-knownclusters \
            --allow-long-headers
        """

rule parse_antismash:
    input: 
        html_files = expand(os.path.join(ANTISMASH_OUT, "{sample}", "index.html"), sample=SAMPLES)
    output: 
        csv = os.path.join(ANTISMASH_OUT, "AntiSMASH_results.csv")
    params:
        result_dir = ANTISMASH_OUT
    conda: 
        config["envs"]["antismash"]
    shell: 
        "python {workflow.basedir}/parserfile.py {params.result_dir} {output.csv}"

# --- STEP 4: ABRICATE ---
rule run_abricate:
    input:
        fastas = expand(os.path.join(INPUT_DIR, "{sample}.fasta"), sample=SAMPLES),
        trigger = os.path.join(ANTISMASH_OUT, "AntiSMASH_results.csv")
    output:
        csv = os.path.join(ABRICATE_OUT, "Abricate_{db}.csv")
    threads: config["params"]["threads_high"]
    conda: config["envs"]["abricate"]
    shell:
        r"""
        abricate --db {wildcards.db} --threads {threads} --csv {input.fastas} | \
        awk -F',' 'BEGIN {{OFS=","}} 
            NR==1 {{print $0}} 
            NR>1 {{
                split($1, p, "/"); 
                fn=p[length(p)]; 
                sub(/\.fasta$/, "", fn); 
                $1=fn; 
                print $0
            }}' > {output.csv}
        """

# --- STEP 5: GENOMAD DATABASE ---
rule download_genomad_db:
    output: db_marker = os.path.join(config["paths"]["genomad_db"], "genomad_db", "version.txt")
    conda: config["envs"]["genomad"]
    params: db_dir = config["paths"]["genomad_db"]
    shell:
        """
        if [ ! -f "{output.db_marker}" ]; then
            mkdir -p {params.db_dir}
            genomad download-database {params.db_dir}
        fi
        """

# --- STEP 6: RUN GENOMAD ---
rule run_genomad:
    input:
        fasta = os.path.join(INPUT_DIR, "{sample}.fasta"),
        db_ready = rules.download_genomad_db.output.db_marker,
        trigger = expand(os.path.join(ABRICATE_OUT, "Abricate_{db}.csv"), db=ABRICATE_DBS)
    output: 
        # Simplified output folder to genomad_results/{sample}
        out_dir = directory(os.path.join(GENOMAD_OUT, "{sample}"))
    threads: config["params"]["threads_high"]
    conda: config["envs"]["genomad"]
    params: 
        actual_db_path = os.path.join(config["paths"]["genomad_db"], "genomad_db")
    shell:
        """
        rm -rf {output.out_dir}
        genomad end-to-end {input.fasta} {output.out_dir} {params.actual_db_path} \
            --threads {threads} --cleanup
        """
        
# --- STEP 7: MERGE GENOMAD RESULTS ---
rule merge_genomad_results:
    input:
        genomad_runs = expand(os.path.join(GENOMAD_OUT, "{sample}"), sample=SAMPLES)
    output:
        os.path.join(GENOMAD_OUT, "combined_virus_summary.csv"),
        os.path.join(GENOMAD_OUT, "combined_virus_genes.csv"),
        os.path.join(GENOMAD_OUT, "combined_plasmid_summary.csv"),
        os.path.join(GENOMAD_OUT, "combined_plasmid_genes.csv")
    params:
        genomad_dir = GENOMAD_OUT
    conda:
        config["envs"]["genomad"] 
    shell:
        "python {workflow.basedir}/genomad_merge.py {params.genomad_dir}"
