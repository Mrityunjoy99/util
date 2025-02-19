import os
import re
import csv

def scan_providers(repo_root_dir, output_csv_path):
    provider_pattern = re.compile(
        r"public class (?P<provider_name>\w+) implements Provider<.*?>\s*\{.*?dbApi\.database\(\"(?P<database_name>\w+)\"\).*?", re.DOTALL
    )

    results = []

    for root, _, files in os.walk(repo_root_dir):
        for file in files:
            if file.endswith(".java"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    matches = provider_pattern.finditer(content)
                    for match in matches:
                        provider_name = match.group("provider_name")
                        database_name = match.group("database_name")
                        results.append((file_path, provider_name, database_name))

    with open(output_csv_path, mode="w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["File Path", "Provider Name", "Database Name"])
        writer.writerows(results)

    print(f"Scan complete. Results saved to {output_csv_path}")

# Example usage
if __name__ == "__main__":
    repo_root_dir = '/Users/mrityunjoydey/Documents/github/ne-bank-cbs/turing-slice-cbs/cbs-transactions'
    output_csv_path = '/Users/mrityunjoydey/Documents/util/scripts/tmp/code_analysis/code_provider_analysis/output.csv'
    scan_providers(repo_root_dir, output_csv_path)
