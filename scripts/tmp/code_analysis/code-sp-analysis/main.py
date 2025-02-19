import os
import re
from collections import defaultdict
import csv

def find_stored_procedures(root_directory, output_file="./output-details.txt", unique_csv_file="./unique-sp.csv"):
    # Regular expression to match the stored procedure pattern
    procedure_pattern = re.compile(r'withProcedureName\("(.*?)"\)')

    # Dictionary to store procedure names and their occurrences
    procedure_dict = defaultdict(lambda: defaultdict(list))

    # Walk through the directory recursively
    for dirpath, _, filenames in os.walk(root_directory):
        for file in filenames:
            # Only process text files (e.g., .py, .txt, .java, etc.)
            file_path = os.path.join(dirpath, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    for line_number, line_content in enumerate(f, start=1):
                        matches = procedure_pattern.findall(line_content)
                        for match in matches:
                            procedure_dict[match][file_path].append(line_number)
            except Exception as e:
                print(f"Error reading file {file_path}: {e}")

    # Sort procedures by total occurrences in descending order
    sorted_procedures = sorted(procedure_dict.items(), key=lambda x: sum(len(lines) for lines in x[1].values()), reverse=True)

    # Write detailed output to file
    total_count = sum(sum(len(lines) for lines in files.values()) for files in procedure_dict.values())
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"Total Unique Procedures: {len(procedure_dict)}\n")
        f.write(f"Total Procedure Occurrences: {total_count}\n\n")
        for proc, files in sorted_procedures:
            f.write(f"Procedure Name: {proc}\n")
            count = sum(len(lines) for lines in files.values())
            f.write(f"Count: {count}\n")
            f.write("Occurrences:\n")
            for file_path, lines in files.items():
                line_numbers = ", ".join(map(str, lines))
                f.write(f"  - {file_path}: Lines {line_numbers}\n")
            f.write("\n")

    # Write unique procedures with count to CSV file
    with open(unique_csv_file, 'w', encoding='utf-8', newline='') as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["Procedure Name", "Count"])
        for proc, files in sorted_procedures:
            count = sum(len(lines) for lines in files.values())
            writer.writerow([proc, count])

    return total_count, len(procedure_dict)

if __name__ == "__main__":
    root_dir = input("Enter the project root directory path: ")
    if os.path.isdir(root_dir):
        total_occurrences, unique_procedures = find_stored_procedures(root_dir)
        print(f"Analysis complete.\nTotal Unique Procedures: {unique_procedures}\nTotal Procedure Occurrences: {total_occurrences}\nOutput written to: ./output-details.txt\nUnique procedures written to: ./unique-sp.csv")
    else:
        print("Invalid directory path provided.")
