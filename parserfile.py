import pandas as pd
import glob
import os
import re
import sys

# 1. Get paths from Snakemake arguments
if len(sys.argv) < 3:
    print("Usage: python parserfile.py <input_dir> <output_csv>")
    sys.exit(1)

base_path = sys.argv[1]   # This is {params.result_dir}
final_output = sys.argv[2] # This is {output.csv}

folders = glob.glob(os.path.join(base_path, "*/"))
master_list = []

print(f"Searching for results in: {base_path}")

for folder in folders:
    file_path = os.path.join(folder, "index.html")
    folder_name = os.path.basename(os.path.normpath(folder))
    
    if os.path.exists(file_path):
        try:
            # Logic remains the same...
            gbk_files = glob.glob(os.path.join(folder, "*.region*.gbk"))
            contig_count = len(set([os.path.basename(f).split(".region")[0] for f in gbk_files]))
            
            dfs = pd.read_html(file_path)
            
            with open(file_path, 'r', encoding='utf-8') as f:
                html_content = f.read()
            record_names = re.findall(r'<div class="record-overview-header">\s*<strong>(.*?)</strong>', html_content)
            
            for i in range(min(len(dfs), contig_count)):
                record = record_names[i] if i < len(record_names) else f"Unknown_Record_{i}"
                df = dfs[i].copy()
                
                df['Region'] = df['Region'].astype(str).str.replace('&nbsp', ' ').str.replace(r'\s+', ' ', regex=True)
                df["Genome"] = record
                df["Sample_ID"] = folder_name
                
                column_order = ["Region", "Type", "From", "To", "Most similar known cluster", 
                                "Most similar known cluster.1", "Similarity", "Genome", "Sample_ID"]
                df = df.reindex(columns=column_order)
                master_list.append(df)
        except Exception as e:
            print(f"Error processing {folder_name}: {e}")

# 3. Save the result using the path Snakemake provided
if master_list:
    master_table = pd.concat(master_list, ignore_index=True)
    master_table.to_csv(final_output, index=False)
    print(f"Success! Consolidated data saved to: {final_output}")
else:
    print("No data found to save.")
