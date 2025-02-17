import os
import re
import json
import csv


def find_sp_vars(content, file_path, sp_list):
    jdbc_call_regex = re.compile(
        r"(?P<variable>\w+)\s*=\s*new\s*SimpleJdbcCall\s*\([^)]*\)\s*"
        r"(\.\s*withProcedureName\s*\(\s*\"(?P<sp_name>\w+)\"\s*\))",
        re.DOTALL,
    )

    sp_vars_for_sp = {}

    for match in jdbc_call_regex.finditer(content):
        sp_name = match.group("sp_name")
        variable = match.group("variable")
        # print("sp_name: ", sp_name, "variable: ", variable, "line: ", file_path+":"+str(content[:match.start()].count('\n') + 1))
        # line_number = content[:match.start()].count('\n') + 1
        if sp_name.lower() in (sp.lower() for sp in sp_list):
            sp_vars_for_sp.setdefault(sp_name.lower(), []).append(variable)
    return sp_vars_for_sp


def find_methods_for_sp(content, sp_methods_for_sp, file_path):
    """
    Finds all the function names and line numbers where the specified objects are used.

    Args:
        content (str): The content of the file as a string.
        sp_methods_for_sp (dict): Dictionary mapping SP names to their associated objects.

    Returns:
        dict: A dictionary where keys are object names, and values are lists of tuples with function names and their starting line numbers where they are used.
    """
    # Regex patterns to match Java function definitions and object usage
    function_pattern = re.compile(
        r"\b(public|protected|private|static|final|\s)+\s+\S+\s+(\w+)\s*\(.*?\)\s*\{",
        re.DOTALL,
    )

    # To track results
    function_to_objects = {}

    # Find all function definitions and their spans
    functions = [
        (m.group(2), m.start(), m.end()) for m in function_pattern.finditer(content)
    ]

    # Iterate through each function and analyze its body
    for i, (func_name, start, end) in enumerate(functions):
        # Determine the end of the current function's body
        body_start = end
        body_end = functions[i + 1][1] if i + 1 < len(functions) else len(content)

        # Extract function body
        function_body = content[body_start:body_end]

        # Track line numbers for the current function
        current_line_number = content[:start].count("\n") + 1

        # Search for object usage within the function body
        for sp_name, objects in sp_methods_for_sp.items():
            for obj in objects:
                # Ensure object is used only when fully matched in the line
                if any(
                    re.search(r"\b" + re.escape(obj) + r"\b", line)
                    for line in function_body.splitlines()
                ):
                    if sp_name not in function_to_objects:
                        function_to_objects[sp_name] = {}
                    if obj not in function_to_objects[sp_name]:
                        function_to_objects[sp_name][obj] = []
                    if (func_name, current_line_number) not in function_to_objects[
                        sp_name
                    ][obj]:
                        function_to_objects[sp_name][obj].append(
                            (func_name, file_path + ":" + str(current_line_number))
                        )

    return function_to_objects


def find_sp_usage(sp_list, root_dir):
    sp_usage = {}
    for dirpath, _, filenames in os.walk(root_dir):
        for file in filenames:
            if file.endswith(".java"):
                file_path = os.path.join(dirpath, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()  # Read the entire file as a single string

                # Get List Of SP Methods
                sp_methods_for_sp = find_sp_vars(content, file_path, sp_list)
                if sp_methods_for_sp:
                    res = find_methods_for_sp(content, sp_methods_for_sp, file_path)
                    if res:
                        for sp_name, obj_dict in res.items():
                            if sp_name not in sp_usage:
                                sp_usage[sp_name] = {}
                            for obj, func_list in obj_dict.items():
                                if obj not in sp_usage[sp_name]:
                                    sp_usage[sp_name][obj] = []
                                sp_usage[sp_name][obj].extend(func_list)

    return sp_usage


def convert_json_to_csv(json_data, csv_file_path):
    with open(csv_file_path, mode="w", newline="") as csv_file:
        csv_writer = csv.writer(csv_file)
        # Write header
        csv_writer.writerow(["sp_name", "var_name", "method_name", "method_location"])

        for sp_name, vars_data in json_data.items():
            for var_name, methods in vars_data.items():
                for method in methods:
                    method_name, method_location = method
                    csv_writer.writerow(
                        [sp_name, var_name, method_name, method_location]
                    )


sp_list = [
    "getsmslist",
    "sp_casa_interest_accrual",
    "sp_account_info_balances",
    "sp_browse_transaction",
    "neft_rtgs_register",
    "sp_calculate_charges_casa_daily",
    "sp_get_accounts_for_folio_charges",
    "sp_get_accounts_for_debitcard_charges",
    "sp_account_statement",
    "sp_get_account_info",
    "sp_change_account_status",
    "sp_get_accounts_for_maintenance_charges",
    "sp_get_loan_cc_accounts",
    "sp_td_interest_application",
    "sp_product_info_balances",
    "getactiveaccountsbymobileno",
    "sp_loan_penal_interest_accrual",
    "loan_auto_recovery_sp",
    "sp_duplicate_master_entries",
    "sp_td_interest_exception",
    "sp_product_statement",
    "sp_account_for_status_change",
    "sp_getaccountdetails_upi",
    "sp_loan_interest_accrual",
    "sp_npa_borrower",
    "loan_cc_asset_classification_list",
    "loan_npa_identifcation_task_list",
    "sp_interest_accrual_pnr_pl_posting_pre_processing",
    "sp_account_mini_statement",
    "statement_search",
    "sp_casa_minimum_bal_charges",
    "sp_loan_interest_exception",
    "sp_backup_bod",
    "getavgmonthlybalance",
    "sp_last_transaction",
    "sp_co_demand_generation",
    "get_casa_int_application_accs",
    "sp_update_policy_renew_details",
    "npa_provision_preprocessing",
    "sp_verify_pl_account",
    "sp_reset_accrual",
    "sp_getdetailsbytxnrefno",
    "sp_rectify_consistency",
    "zerobalance_productcheck",
    "sp_rectify_balance",
    "checkdailytrialbalancediff",
    "sp_insert_td_customer_interest_tds",
    "sp_get_overdue_details",
    "sp_interest_application_loan",
    "sp_interest_application_cc",
    "calculate_overdue_loan",
    "sp_insert_casa_balances",
    "sp_insert_loan_balances",
    "sp_casa_inoperative_bal_charges",
    "sp_insert_td_balances",
    "sp_td_interest_application_bucketing",
    "update_loan_repayment_chart_post_interest_application",
    "sp_casa_balance_check",
    "sp_dds_closure_calculation",
    "update_product_and_internal_account_balance",
    "sp_casa_interest_exception",
    "sp_get_bsbda_rule_config",
    "sp_get_bsbda_product_id",
    "sp_get_old_account_list",
    "sp_get_reschedule_product_list",
    "sp_get_active_account_list_from_product",
]

# sp_list = [
#     "getsmslist",
# ]


root_dir = "/Users/mrityunjoydey/Documents/github/ne-bank-cbs/turing-slice-cbs/cbs-transactions/app"
output_csv_file = "/Users/mrityunjoydey/Documents/util/scripts/tmp/code_analysis/repo_func_for_sp/output.csv"
result = find_sp_usage(sp_list, root_dir)
convert_json_to_csv(result, output_csv_file)
