import os
import re
import csv

def find_datasource_names(repo_root_dir, providers):
    """
    Finds the datasource names by provider in Java source files within the repository.
    """
    datasource_map = {}
    constructor_pattern = re.compile(
        r'\b(?:' + '|'.join(re.escape(provider) for provider in providers) + r')\b'
    )
    datasource_pattern = re.compile(
        r'\bthis\.(\w+)\s*=\s*\w+\.get\(\)\.(\w+)\(\);'
    )
    for root, _, files in os.walk(repo_root_dir):
        for file in files:
            if file.endswith(".java"):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                if constructor_pattern.search(content):
                    matches = datasource_pattern.findall(content)
                    for provider in providers:
                        if provider in content:
                            if provider not in datasource_map:
                                datasource_map[provider] = []
                            datasource_map[provider].extend(
                                [match[0] for match in matches]
                            )
    return datasource_map

def map_datasource_to_methods(repo_root_dir, datasource_map):
    """
    Maps providers and their datasources to JdbcTemplate or SimpleJdbcCall instances
    and finds the methods in which these instances are used, including SQL analysis.
    """
    result_map = {}
    jdbc_pattern = re.compile(r'\b(\w+)\s*=\s*new\s+(JdbcTemplate|SimpleJdbcCall)\((\w+)\);')
    method_pattern = re.compile(r'(public|protected|private)\s+[\w<>]+\s+\w+\(.*?\)\s*{')
    sql_pattern = re.compile(r'(?i)\b(select|update|delete|insert)\b\s+(.*?)\bfrom\b\s+([\w.]+)', re.DOTALL)

    for root, _, files in os.walk(repo_root_dir):
        for file in files:
            if file.endswith(".java"):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    matches = jdbc_pattern.findall(content)
                    if matches:
                        for var_name, jdbc_class, datasource in matches:
                            for provider, datasources in datasource_map.items():
                                if datasource in datasources:
                                    if provider not in result_map:
                                        result_map[provider] = {}
                                    if datasource not in result_map[provider]:
                                        result_map[provider][datasource] = {}
                                    if var_name not in result_map[provider][datasource]:
                                        result_map[provider][datasource][var_name] = {
                                            "jdbc_class": jdbc_class,
                                            "file_path": file_path,
                                            "methods": []
                                        }
                                    method_matches = list(method_pattern.finditer(content))
                                    for method_match in method_matches:
                                        method_start = method_match.start()
                                        method_end = content.find('}', method_start)
                                        if method_end == -1:
                                            continue
                                        method_body = content[method_start:method_end]
                                        sql_matches = sql_pattern.findall(method_body)
                                        if var_name in method_body or any(var_name in sql for sql in method_body):
                                            method_name = method_match.group(0)
                                            result_map[provider][datasource][var_name]["methods"].append({
                                                "method_name": method_name.strip(),
                                                "line_number": content[:method_start].count('\n') + 1,
                                                "file_path": file_path,
                                                "sql_statements": [{
                                                    "query": match[0],
                                                    "fields": match[1].strip(),
                                                    "table_name": match[2].strip()
                                                } for match in sql_matches]
                                            })
                except Exception as e:
                    print(f"Error processing file {file_path}: {e}")
    return result_map

def write_methods_to_csv(output_map, csv_file_path):
    """
    Writes the mapping of methods to a CSV file, including SQL analysis.
    """
    rows = []
    for provider, datasources in output_map.items():
        for datasource, variables in datasources.items():
            method_to_vars = {}
            for var_name, details in variables.items():
                for method in details["methods"]:
                    method_key = f"{method['method_name']}, {method['file_path']}:{method['line_number']}"
                    if method_key not in method_to_vars:
                        method_to_vars[method_key] = {"var_names": set(), "sql_analysis": []}
                    method_to_vars[method_key]["var_names"].add(var_name)
                    method_to_vars[method_key]["sql_analysis"].extend(method.get("sql_statements", []))
            
            for method_key, details in method_to_vars.items():
                method_name, location = method_key.rsplit(", ", 1)
                sql_analysis = details["sql_analysis"]
                if sql_analysis:
                    for sql in sql_analysis:
                        rows.append({
                            "method_name": method_name.strip(),
                            "file_path:line_number": location.strip(),
                            "involved_var_names": ", ".join(sorted(details["var_names"])),
                            "query_type": sql["query"].upper(),
                            "table_name": sql["table_name"],
                            "fields": sql["fields"]
                        })
                else:
                    rows.append({
                        "method_name": method_name.strip(),
                        "file_path:line_number": location.strip(),
                        "involved_var_names": ", ".join(sorted(details["var_names"])),
                        "query_type": "",
                        "table_name": "",
                        "fields": ""
                    })

    with open(csv_file_path, mode='w', newline='', encoding='utf-8') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=["method_name", "file_path:line_number", "involved_var_names", "query_type", "table_name", "fields"])
        writer.writeheader()
        writer.writerows(rows)

if __name__ == "__main__":
    repo_root_dir = '/Users/mrityunjoydey/Documents/github/ne-bank-cbs/turing-slice-cbs/cbs-transactions'
    output_path = '/Users/mrityunjoydey/Documents/util/scripts/tmp/code_analysis/repofunc_by_provider/output.csv'
    providers = ['BsgDeepFreezeDataSourceProvider']
    datasource = find_datasource_names(repo_root_dir, providers)
    method_usage = map_datasource_to_methods(repo_root_dir, datasource)
    write_methods_to_csv(method_usage, output_path)
