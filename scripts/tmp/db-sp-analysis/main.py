import csv
import os

def generate_sql_files(csv_file_path, output_dir):
    """
    Reads a CSV file containing stored procedure names and definitions,
    and generates individual SQL files for each stored procedure.

    :param csv_file_path: Path to the CSV file
    :param output_dir: Directory where the SQL files will be saved
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    with open(csv_file_path, 'r', encoding='utf-8') as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            procedure_name = row.get("ProcedureName")
            procedure_definition = row.get("ProcedureDefinition")

            if not procedure_name or not procedure_definition:
                print(f"Skipping row due to missing data: {row}")
                continue

            # Generate file path for the procedure
            sql_file_path = os.path.join(output_dir, f"{procedure_name}.sql")

            # Write the procedure definition to the SQL file
            with open(sql_file_path, 'w', encoding='utf-8') as sql_file:
                sql_file.write(procedure_definition)

            print(f"Generated SQL file for: {procedure_name}")

if __name__ == "__main__":
    # Input root directory for input CSV file
    input_root_dir = input("Enter the root directory for the input CSV file: ")
    csv_file_path = os.path.join(input_root_dir, "input.csv")  # Replace "input.csv" with the actual file name if different

    # Output root directory for SQL files
    output_root_dir = input("Enter the root directory for the output SQL files: ")

    generate_sql_files(csv_file_path, output_root_dir)
