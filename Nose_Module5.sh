#!/bin/bash

# ==============================================================================
# NOSE Module 5: Functional Characterization Workflow
# Developed by: Raman Lab, IIT Madras
# Tools: ABRicate, antiSMASH, geNomad, Prokka, COGclassifier
# ==============================================================================

# 1. Initialize Conda
source $(conda info --base)/etc/profile.d/conda.sh
conda activate snakemake

# 2. Workspace Analytics
GENOME_COUNT=$(ls inputs/*.fasta 2>/dev/null | wc -l)
DATABASE_SIZE=$(du -sh databases 2>/dev/null | cut -f1 || echo "N/A")
TOTAL_WORKSPACE=$(du -sh . 2>/dev/null | cut -f1)

echo "------------------------------------------------------------------------"
echo " # NOSE Module 5: Functional Characterization Workflow"
echo " # Developed by: Raman Lab, IIT Madras"
echo " # Tools: ABRicate, antiSMASH, geNomad, Prokka, COGclassifier"
echo "------------------------------------------------------------------------"
echo "WORKSPACE SUMMARY:"
echo "  - Genomes Detected:  $GENOME_COUNT"
echo "  - Database Size:     $DATABASE_SIZE"
echo "  - Total Workspace:   $TOTAL_WORKSPACE"
echo "------------------------------------------------------------------------"

# 3. User Input for Cores
MAX_CORES=$(nproc)
echo "System Capacity: $MAX_CORES cores available."
echo "Enter cores to use or press ENTER for default 20:"
read -p "> " USER_INPUT

# Handle default value
if [ -z "$USER_INPUT" ]; then
    FINAL_CORES=20
else
    FINAL_CORES=$USER_INPUT
fi

# 4. Estimation Logic
# Benchmark: 1 genome approx 18 mins on 20 cores
BASELINE_MINS=18
if [ $GENOME_COUNT -gt 0 ]; then
    EST_TIME=$(( (GENOME_COUNT * BASELINE_MINS * 20) / FINAL_CORES ))
else
    EST_TIME=0
fi

echo "------------------------------------------------------------------------"
echo "PREDICTION LOG:"
echo "  - Selected Resources: $FINAL_CORES cores"
echo "  - Estimated Runtime:  ~ $EST_TIME minutes"
echo "  - Storage Note:       Outputs expand ~18x relative to input size."
echo "------------------------------------------------------------------------"

# 5. Execution
echo ">>> Launching Snakemake Pipeline..."
snakemake --use-conda --cores $FINAL_CORES
