import os
import re
import csv

def extract_databases_from_sql(file_path):
    """Extract database names from a SQL file."""
    databases = set()
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()
            # Regex pattern to match database names explicitly (e.g., BSGLOAN..TableName or BSGLOAN.Schema.TableName)
            pattern = r'\b([A-Za-z0-9_]+)\.\.\b'
            matches = re.findall(pattern, content)
            print(f"Matches found in {file_path}: {matches}")
            databases.update(match.upper() for match in matches)
            pattern = r'\b([A-Za-z0-9_]+)\.dbo\.\b'
            matches = re.findall(pattern, content)
            print(f"Matches found in {file_path}: {matches}")
            databases.update(match.upper() for match in matches)
            if not databases:
                databases.add('BSGACCOUNTING')
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
    return databases

def process_directory(input_dir, output_csv_path):
    """Process all SQL files in the directory and output a CSV with SP name, dependent database names, and count."""
    result_data = []

    # Iterate through all files in the directory
    for file_name in os.listdir(input_dir):
        if file_name.endswith('.sql'):
            file_path = os.path.join(input_dir, file_name)
            databases = extract_databases_from_sql(file_path)
            result_data.append({
                'SP Name': file_name,
                'Dependent Databases': ', '.join(databases),
                'Database Count': len(databases)
            })

    # Sort results by Database Count in descending order
    result_data.sort(key=lambda x: x['Database Count'], reverse=True)

    # Write results to a CSV file
    try:
        with open(output_csv_path, 'w', newline='', encoding='utf-8') as csv_file:
            fieldnames = ['SP Name', 'Dependent Databases', 'Database Count']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(result_data)
        print(f"Results saved to {output_csv_path}")
    except Exception as e:
        print(f"Error writing CSV file: {e}")

if __name__ == "__main__":
    input_dir = "/Users/mrityunjoydey/Documents/util/scripts/tmp/sp-analysis/SP"
    output_csv_path = "/Users/mrityunjoydey/Documents/util/scripts/tmp/sp-analysis/output.csv"

    if os.path.isdir(input_dir):
        process_directory(input_dir, output_csv_path)
    else:
        print("Invalid directory path. Please try again.")
