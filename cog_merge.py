import pandas as pd
import glob
import os
import sys

# Get paths from Snakemake arguments
input_dir = sys.argv[1]   # The COG output directory
output_file = sys.argv[2] # Where to save the merged file

# Find all classifier_count.tsv files within the sample subfolders
all_files = glob.glob(os.path.join(input_dir, "*", "classifier_count.tsv"))

if not all_files:
    print("No COG count files found.")
    sys.exit(0)

merged_list = []

for file in all_files:
    # folder name = genome ID
    genome = os.path.basename(os.path.dirname(file))  
    df = pd.read_csv(file, sep="\t")
    
    # Ensure columns exist before filtering
    if 'LETTER' in df.columns and 'COUNT' in df.columns:
        df = df[['LETTER', 'COUNT']]
        df = df.set_index('LETTER').T
        df.insert(0, "Genome", genome)
        merged_list.append(df)

if merged_list:
    merged_df = pd.concat(merged_list, axis=0, ignore_index=True)
    # Fill NaN with 0 for genomes missing specific COG categories
    merged_df = merged_df.fillna(0) 
    merged_df.to_csv(output_file, sep="\t", index=False)
    print(f"Merged COG results saved to {output_file}")
