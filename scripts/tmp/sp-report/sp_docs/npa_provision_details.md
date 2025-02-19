## Overview
This report provides an analysis of the SQL stored procedure `npa_provision_details`. It includes details on:

1. Dependent functions or stored procedures (SPs).
2. Fields where data is being written or modified.
3. Tables being read from, including fields and conditions.
4. Joins used.
5. Temporary tables created and their associated fields.

---

## 1. Dependent Functions or Other SPs

- The stored procedure does not call any other functions or stored procedures directly.
- The procedure depends on input parameter `@cbsAppDate` for data filtration and processing.

---

## 2. Fields Where Data is Being Written or Modified

### Temporary Tables
- `#loanBasicDetails`:
  - Fields: `loan_account_id`, `loan_account_no`, `loan_account_status`, `asset_classification`, `loan_product_code`, `loan_product_id`, `branch_code`, `customer_no`, `date_of_account_opening`, `loan_amount`, `checker_clear_balance`, `is_secured`.

- `#LoanAccountDefaulter`:
  - Fields: All fields from `#loanBasicDetails` + `defaulter_type`.

- `#DefaulterDetails`:
  - Fields: `loan_account_id`, `is_secured`, `defaulter_match`.

- `#DefaulterCompleteDetails`:
  - Fields: All fields from `#DefaulterDetails` + `df_matrix_id`, `df_mapping_description`.

- `#npaProvisionDetails`:
  - Fields: `provision_percentage`, `provision_amount`, `loan_account_no`, `loan_account_id`, `is_secured`, `df_matrix_id`, `defaulter_match`, `df_mapping_description`, `checker_clear_balance`, `asset_classification`.

### Permanent Tables
- `BSGACCOUNTING..loan_sma_classification_details`:
  - Updated fields: `provision_amount`, `provision_percentage`.

---

## 3. Tables Being Read From

### BSGLOAN Schema
- **`loan_account_master`**
  - Fields: `loan_account_id`, `loan_account_no`, `loan_account_status`, `asset_classification`, `loan_product_code`, `loan_product_id`, `branch_code`, `customer_no`, `date_of_account_opening`, `is_active`.
  - Conditions: `lam.is_active = 1` and `(lam.loan_account_status != 2 OR abb.checker_clear_balance <> 0)`.

- **`loan_account_basic`**
  - Fields: `loan_account_id`, `loan_amount`, `is_active`.
  - Conditions: `lab.is_active = 1`.

- **`loan_product_master`**
  - Fields: `loan_product_id`, `is_secured`, `is_active`.
  - Conditions: `lpm.is_active = 1`.

- **`defaulter_master_marking_unmarking`**
  - Fields: `loan_account_id`, `defaulter_type`, `is_active`.
  - Conditions: `dmmu.is_active = 1`.

### BSGACCOUNTING Schema
- **`account_balance_loan`**
  - Fields: `checker_clear_balance`, `loan_account_id`, `txn_date`.
  - Conditions: `txn_date <= @cbsAppDate`.

- **`npa_defaulter_matrix`**
  - Fields: `df_matrix_id`, `df_mapping`, `df_mapping_description`, `is_active`.
  - Conditions: `ndm.is_active = 1`.

- **`npa_provision_matrix`**
  - Fields: `df_matrix_id`, `asset_classification`, `secured_percentage`, `unsecured_percentage`, `effective_date`, `is_active`.
  - Conditions: `npm.is_active = 1` and `npm.effective_date = MAX(effective_date)`.

- **`loan_sma_classification_details`**
  - Fields: `loan_account_id`, `txn_date`, `provision_amount`, `provision_percentage`.
  - Conditions: `txn_date <= @cbsAppDate`.

---

## 4. Joins Used

### Inner Joins
- `loan_account_master` with `loan_account_basic`:
  - `lam.loan_account_id = lab.loan_account_id`.

- `loan_account_master` with `loan_product_master`:
  - `lam.loan_product_id = lpm.loan_product_id`.

- `account_balance_loan` with a subquery on `account_balance_loan`:
  - `abl.loan_account_id = abbl.loanAccountId` and `abl.txn_date = abbl.maxTxnDate`.

- `loan_product_master` with `loan_account_master`:
  - `LM.loan_product_id = PM.loan_product_id`.

- `npa_provision_matrix` with subquery:
  - `npm.df_matrix_id = npmm.df_matrix_id` and `npm.asset_classification = npmm.asset_classification`.

### Left Joins
- `loan_account_master` with `loan_product_master`.
- `loanBasicDetails` with `defaulter_master_marking_unmarking`.
- `DefaulterDetails` with `npa_defaulter_matrix`.

---

## 5. Temporary Table Analysis

**`#loanBasicDetails`**
Fields:
- `loan_account_id`, `loan_account_no`, `loan_account_status`, `asset_classification`, `loan_product_code`, `loan_product_id`, `branch_code`, `customer_no`, `date_of_account_opening`, `loan_amount`, `checker_clear_balance`, `is_secured`.

**`#LoanAccountDefaulter`**
Fields:
- All from `#loanBasicDetails` + `defaulter_type`.

**`#DefaulterDetails`**
Fields:
- `loan_account_id`, `is_secured`, `defaulter_match`.

**`#DefaulterCompleteDetails`**
Fields:
- All from `#DefaulterDetails` + `df_matrix_id`, `df_mapping_description`.

**`#npaProvisionDetails`**
Fields:
- `provision_percentage`, `provision_amount`, `loan_account_no`, `loan_account_id`, `is_secured`, `df_matrix_id`, `defaulter_match`, `df_mapping_description`, `checker_clear_balance`, `asset_classification`.

---

## Conclusion
The procedure processes loan account details, calculates provision amounts, and updates classification details in the permanent table `loan_sma_classification_details`. It uses temporary tables extensively to organize intermediate results. The joins and filters ensure accuracy in data extraction and transformations.

