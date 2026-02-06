# Functional Characterization Pipeline
Overview

This pipeline performs comprehensive functional characterization of assembled microbial genomes. It integrates structural and functional annotation with targeted scans for biosynthetic and resistance/virulence features, and inspects mobile genetic element associations:

Core steps
- Genome assembly → Prokka annotation → COG functional profiling  
- ABRicate (AMR, virulence, metal/biocide resistance)  
- antiSMASH (biosynthetic gene clusters)  
- geNomad (phage & plasmid / mobile genetic element context)

Purpose
-------
This workflow helps answer two complementary questions about novel genomes:
- What useful or novel secondary metabolites could this organism produce? (antiSMASH)
- What resistance/virulence/environmental-adaptation genes does it carry, and are they associated with mobile elements? (ABRicate + geNomad)
  
COG profiling provides genome-wide functional context and helps prioritize gene families for follow-up.

Prerequisites
-------------
- Conda (for environments used by Snakemake)
- Snakemake
- Sufficient compute resources for antiSMASH and other analysis steps.

Inputs
------
- Genome assemblies (FASTA): one file per sample or a folder of assemblies as defined in the config.
- Configuration file (e.g., config.yaml) specifying:
  - sample list and input assemblies
  - output directory
  - database paths or download destination
    
Configuration
-------------
- Provide database paths and sample inputs in `config.yaml` (or the pipeline's config file).  
- If you already have local copies of databases, point the config to those paths.  
- If no paths are provided, set a download destination in the config; the pipeline can download required databases automatically to that location.  
- Modify input/output directories only when necessary and update the config accordingly.

Step-by-step instruction for running Module 5
--------------------------
Module 5 runs ABRicate, antiSMASH and geNomad and links results with Prokka/COG annotations.

1.Clone or download this Module 5 directory:

    git clone https://github.com/Novel-sp/Functional-Characterization.git
    cd Functional-Characterization/module5  # the directory where the module 5 is located

2.  Activate the snakemake environment:
```bash
   - conda activate snakemake
```
3. Run Module 5 (example using 20 cores):
```bash
   - snakemake --use-conda --cores 20
```

## Pipeline Flow 

<div align="center">

<pre>
Genome Assembly
      ↓
Prokka annotation
(Gene models + protein translations)
      ↓
COG functional profiling
(Functional category counts & summary statistics)
      ↓
ABRicate
(AMR – CARD | Default – NCBI | Virulence – VFDB | Metal/Biocide – BacMet)
      ↓
antiSMASH
(Biosynthetic Gene Clusters: NRPS, PKS, hybrid, others)
      ↓
geNomad
(Phage detection & Mobile Genetic Elements association)
</pre>

</div>

Databases used
--------------
ABRicate databases:
- CARD (antimicrobial resistance)
- VFDB (virulence factors)
- BacMet (metal/biocide resistance)
- NCBI (optional curated or metadata-based screens)

antiSMASH: uses its own curated cluster detection models and domain databases.

Outputs
-----------------
Each sample will produce a directory containing:
All tools in this module generate standardized CSV outputs for each analyzed factor.
- Prokka outputs: `.gff`, `.gbk`, `.faa`, `.ffn` (annotations and protein sequences)
- COG/functional profile summary: per-genome and aggregated tables (gene counts per COG category)
- ABRicate reports: tabular summaries per database (CARD, VFDB, BacMet, NCBI)
- antiSMASH results: HTML summaries and cluster folders with annotated region files
- geNomad outputs: predictions of phage/plasmid origin, coordinates, and summary tables


Highlights
----------
- antiSMASH: identifies biosynthetic gene clusters (BGCs) — NRPS, PKS, hybrid clusters, and other secondary metabolite loci.
- ABRicate: screens genomes against curated AMR/virulence/metal resistance databases (NCBI, CARD, VFDB, BacMet).
- geNomad: predicts whether genes of interest are associated with phage or plasmid/mobile elements.
- Prokka + COGs: standardized gene calling and functional classification across genomes.
  
Notes:
- Database paths should be configured in the pipeline config (see Configuration).  
- Only modify input/output directories ; the pipeline will use the configured database paths.  
- If database paths are not provided, the pipeline can be configured to download required databases automatically to a user-specified location.


Troubleshooting
---------------
- antiSMASH failures: reduce concurrency or run antiSMASH rules on nodes with more memory.
- Missing databases: verify config paths or enable the automatic download destination.
- Permission issues: ensure the pipeline user has read/write access to input/output and database locations.

Outputs for downstream analysis
------------------------------
- Combined annotation tables for statistical analysis and visualization (Python)
- Multi-sample ABRicate summary for resistome comparisons
- BGC presence/absence matrix for biosynthetic potential comparisons
- Reports linking ABRicate hits to geNomad-predicted MGEs for mobility assessments

Citations & resources
---------------------
- Prokka: rapid prokaryotic genome annotation
- antiSMASH: secondary metabolite gene cluster identification
- ABRicate: mass-screening for AMR/virulence genes
- geNomad: detection of plasmid and phage origins for genomic features
