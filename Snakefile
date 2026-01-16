import os
import glob

configfile: "config.yaml"

# --- Path Assignments ---
INPUT_BASE    = config["paths"]["input_base"]
OUTPUT_BASE   = config["paths"]["output_base"]
DB_DIR        = config["paths"]["database_dir"]

ANTISMASH_OUT = os.path.join(OUTPUT_BASE, "antismash_results")
ABRICATE_OUT  = os.path.join(OUTPUT_BASE, "abricate_results")

GENOMES   = [os.path.splitext(os.path.basename(f))[0] for f in glob.glob(os.path.join(INPUT_BASE, "*.fasta"))]
DATABASES = config["params"]["abricate_databases"]

rule all:
    input:
        os.path.join(ANTISMASH_OUT, "AntiSMASH_Master_Table.csv"),
        expand(os.path.join(ABRICATE_OUT, "Abricate_{db}.csv"), db=DATABASES)

# --- RULE 1: ANTISMASH ---
rule run_antismash:
    input:
        genome = os.path.join(INPUT_BASE, "{genome}.fasta")
    output:
        index = os.path.join(ANTISMASH_OUT, "{genome}", "index.html")
    threads: config["params"]["antismash_threads"]
    conda: config["paths"]["antismash"]
    shell:
        """
        if [ ! -d "{DB_DIR}/pfam" ]; then
            download-antismash-databases --database-dir {DB_DIR}
        fi
        rm -rf {ANTISMASH_OUT}/{wildcards.genome}
        antismash {input.genome} \
            --output-dir {ANTISMASH_OUT}/{wildcards.genome} \
            --databases {DB_DIR} \
            --genefinding-tool prodigal \
            --taxon bacteria \
            --cpus {threads} \
            --cb-general --cb-subclusters --cb-knownclusters \
            --asf --pfam2go --smcog-trees --fullhmmer \
            --hmmdetection-strictness strict --allow-long-headers
        """

# --- RULE 2: PARSE ANTISMASH ---
rule parse_antismash:
    input:
        html_files = expand(os.path.join(ANTISMASH_OUT, "{genome}", "index.html"), genome=GENOMES)
    output:
        csv = os.path.join(ANTISMASH_OUT, "AntiSMASH_Master_Table.csv")
    conda: config["paths"]["antismash"]
    shell:
        "python parserfile.py"

# --- RULE 3: ABRICATE ---
rule run_abricate:
    input:
        fastas = expand(os.path.join(INPUT_BASE, "{genome}.fasta"), genome=GENOMES),
        trigger = os.path.join(ANTISMASH_OUT, "AntiSMASH_Master_Table.csv")
    output:
        csv = os.path.join(ABRICATE_OUT, "Abricate_{db}.csv")
    threads: config["params"]["abricate_threads"]
    conda: config["paths"]["abricate"]
    shell:
        """
        # Run abricate on all files
        # awk handles the transformation:
        # 1. NR==1: Print the header as is.
        # 2. NR>1: Split the first column by '/' to remove path, 
        #    then remove '.fasta' from that filename.
        abricate --db {wildcards.db} --threads {threads} --csv {input.fastas} | \
        awk -F',' 'BEGIN {{OFS=","}} 
            NR==1 {{print $0}} 
            NR>1 {{
                split($1, path, "/"); 
                fname = path[length(path)]; 
                sub(/\.fasta$/, "", fname); 
                $1 = fname; 
                print $0
            }}' > {output.csv}
        """
