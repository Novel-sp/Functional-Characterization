import pandas as pd
import glob
import os
import re
import yaml

# 1. Load the config file to maintain path consistency
with open("config.yaml", 'r') as f:
    config = yaml.safe_load(f)

# 2. Setup Paths
output_base = config["paths"]["output_base"]
# base_path is now set to the results subfolder directly
base_path = os.path.join(output_base, "antismash_results")

folders = glob.glob(os.path.join(base_path, "*/"))
master_list = []

print(f"Searching for results in: {base_path}")

for folder in folders:
    file_path = os.path.join(folder, "index.html")
    folder_name = os.path.basename(os.path.normpath(folder))
    
    if os.path.exists(file_path):
        try:
            # Match number of tables to the number of region files found
            gbk_files = glob.glob(os.path.join(folder, "*region*.gbk"))
            contig_count = len(set([os.path.basename(f).split(".region")[0] for f in gbk_files]))
            
            # Read HTML tables and the raw text for record names
            dfs = pd.read_html(file_path)
            with open(file_path, 'r', encoding='utf-8') as f:
                html_content = f.read()
            
            # Extract record names from HTML headers
            record_names = re.findall(r'<div class="record-overview-header">\s*<strong>(.*?)</strong>', html_content)
            
            for i in range(contig_count):
                record = record_names[i] if i < len(record_names) else f"Unknown_Record_{i}"
                df = dfs[i].copy()
                
                # Data Cleaning
                df['Region'] = df['Region'].astype(str).str.replace(r'&nbsp', ' ', regex=True).str.replace(r'\s+', ' ', regex=True)
                df["Genome"] = record
                df["File_Name"] = folder_name
                
                # Reindex to ensure consistent column ordering across all samples
                column_order = ["Region", "Type", "From", "To", "Most similar known cluster", 
                                "Most similar known cluster.1", "Similarity", "Genome", "File_Name"]
                df = df.reindex(columns=column_order)
                master_list.append(df)
        except Exception as e:
            print(f"Error processing {folder_name}: {e}")

# 3. Save the result INSIDE the antismash_results sub-directory
if master_list:
    master_table = pd.concat(master_list, ignore_index=True)
    
    # Save directly to base_path (antismash_results/)
    final_output = os.path.join(base_path, "AntiSMASH_Master_Table.csv")
    
    master_table.to_csv(final_output, index=False)
    print(f"Success! Consolidated data saved to: {final_output}")
else:
    print("No data found to save. Ensure AntiSMASH has completed running.")
