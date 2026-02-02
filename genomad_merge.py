#!/usr/bin/env python3
"""
GeNomad Results Consolidation Script
Version: 1.1.0
Description: Aggregates geNomad TSV outputs into consolidated CSV files.
Retains source file identification while excluding secondary metadata columns.
"""

import os
import sys
import glob
import logging
import pandas as pd
from typing import Dict, List

# Configure formal logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def merge_genomad_results(base_directory: str) -> None:
    """
    Finds geNomad TSV files recursively and merges them into CSV format.
    
    Args:
        base_directory (str): Path to the geNomad results root directory.
    """
    # GeNomad internal outputs are tab-separated values
    target_files: Dict[str, str] = {
        "virus_summary": "virus_summary.tsv",
        "virus_genes": "virus_genes.tsv",
        "plasmid_summary": "plasmid_summary.tsv",
        "plasmid_genes": "plasmid_genes.tsv"
    }

    if not os.path.isdir(base_directory):
        logger.error(f"Directory not found: {base_directory}")
        sys.exit(1)

    for label, pattern in target_files.items():
        logger.info(f"Processing category: {label}")
        
        # Recursive search for TSV files in sample subdirectories
        search_path = os.path.join(base_directory, "**", f"*{pattern}")
        discovered_files = glob.glob(search_path, recursive=True)
        
        data_collection: List[pd.DataFrame] = []
        
        for file_path in discovered_files:
            try:
                # Extract Sample ID from the directory structure for the first column
                path_parts = file_path.split(os.sep)
                if "genomad_results" in path_parts:
                    idx = path_parts.index("genomad_results")
                    # Capture the directory name immediately following 'genomad_results'
                    sample_id = path_parts[idx + 1]
                else:
                    sample_id = "unknown"

                # Load the raw TSV data
                df = pd.read_csv(file_path, sep='\t')
                
                if not df.empty:
                    # Insert the File Name/Genome ID as the first column
                    df.insert(0, 'fasta_file', sample_id)
                    
                    # NOTE: The second column (fasta_name) is intentionally omitted
                    data_collection.append(df)
            
            except Exception as e:
                logger.warning(f"Could not process file {file_path}: {str(e)}")

        if data_collection:
            # Concatenate all discovered dataframes
            final_dataframe = pd.concat(data_collection, ignore_index=True)
            
            # Define output path using CSV extension
            output_filename = f"combined_{label}.csv"
            output_path = os.path.join(base_directory, output_filename)
            
            # Export to standard CSV format
            final_dataframe.to_csv(output_path, index=False)
            logger.info(f"Successfully generated {output_filename} with {len(final_dataframe)} records")
        else:
            logger.info(f"No data available for category: {label}")

if __name__ == "__main__":
    # Expects target directory as the first command-line argument from Snakemake
    if len(sys.argv) > 1:
        merge_genomad_results(sys.argv[1])
    else:
        logger.error("No input directory path provided.")
        sys.exit(1)
