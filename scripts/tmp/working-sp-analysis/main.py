import pandas as pd

root_dir = '/Users/mrityunjoydey/Documents/util/scripts/tmp/working-sp-analysis/'
# Read the CSV files
file1 = pd.read_csv(root_dir+'code-sp-count.csv')
file2 = pd.read_csv(root_dir+'db-sp-analysis.csv')

# Normalize the 'SP Name' columns for comparison
file1['SP Name'] = file1['SP Name'].str.strip().str.lower()
file2['SP Name'] = file2['SP Name'].str.strip().str.lower().str.replace('.sql', '')

# Merge the dataframes on 'SP Name'
merged = file1.merge(file2, on='SP Name', how='left')

# Add remarks column
merged['Remarks'] = merged.apply(
    lambda row: 'error: sp not present' if pd.isna(row['Dependent Databases']) and pd.isna(row['Database Count']) else '',
    axis=1
)

# Order by Count and Remarks (errors at the end)
merged = merged.sort_values(by=['Count', 'Remarks'], ascending=[False, True])

# Save merged file
merged.to_csv(root_dir+'merged_output.csv', index=False)

# Identify rows in file2 not present in file1
not_in_file1 = file2[~file2['SP Name'].isin(file1['SP Name'])]
not_in_file1.to_csv(root_dir+'not_in_file1.csv', index=False)

print("Merged output saved as 'merged_output.csv'")
print("SP Names in file2 but not in file1 saved as 'not_in_file1.csv'")
