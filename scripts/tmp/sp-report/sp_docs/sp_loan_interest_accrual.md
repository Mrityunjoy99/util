## Overview
The stored procedure `sp_loan_interest_accrual` performs the following operations:
1. Calculates interest accruals for loan accounts.
2. Updates interest accrual and other related fields in specific tables.
3. Generates a summary report of success and failure counts.
4. Utilizes temporary tables for intermediate calculations.

---

## Analysis

### 1. **Dependent Functions and Stored Procedures**
   - **Functions**:
     - `dbo.fn_calcInterestForLoanAgainstDeposit`: Calculates interest for loans against deposits.
     - `dbo.IsLeapYear`: Checks if a year is a leap year (commented out in the procedure).
   - **Dependent Stored Procedures**:
     - `BSGACCOUNTING..SMA_IDENTIFICATION`: Executes at the end with `@cbsApplicationDate`.

---

### 2. **Fields Where Data is Modified**
   - **Table**: `BSGACCOUNTING.dbo.account_balance_loan`
     - `interest_accrual`
     - `last_modified_by`
     - `last_modified_date`
   - **Table**: `BSGACCOUNTING.dbo.account_loan_last_accrual`
     - `accrual_date`
     - `last_modified_by`
     - `last_modified_date`
   - **Table**: `bsgturing.dbo.turing_task_result`
     - `task_id`
     - `task_ref_id`
     - `task_ref_table`
     - `response_code`
     - `message`
     - `created_date`
     - `created_by`

---

### 3. **Tables Read**
   - **`bsgaccounting.dbo.account_balance_loan`**:
     - Fields: `loan_account_id`, `txn_date`, `checker_clear_balance`, `npa_interest_amount`, `npa_penal_interest_amount`, `npa_charges_amount`, `principal_outstanding`
     - Conditions:
       - `is_active = 1`
       - `txn_date <= ab.intDate`
   - **`BSGLOAN..loan_account_master`**:
     - Fields: `loan_account_id`, `loan_account_status`, `loan_type`
     - Conditions:
       - `is_active = 1`
       - `loan_account_status = 1`
       - `loan_type = 1`
   - **`BSGLOAN..loan_account_basic`**:
     - Fields: `rate_of_interest`, `offset`, `loan_amount`, `loan_tenure_year`, `loan_tenure_month`, `loan_tunure_days`
     - Conditions:
       - `is_active = 1`
   - **`BSGLOAN..loan_product_master`**:
     - Fields: `rate_of_interest`
     - Conditions:
       - `is_active = 1`
   - **`BSGLOAN..loan_interest_slab_master`**:
     - Fields: `rate_of_interest`, `from_amount`, `to_amount`, `from_months`, `to_months`, `effective_date`
     - Conditions:
       - `is_active = 1`
       - Based on loan tenure and effective date.

---

### 4. **Joins Used**
   - **Left Outer Joins**:
     - Between `loan_account_master` and:
       - `account_loan_last_accrual`
       - `loan_account_basic`
       - `loan_product_master`
   - **Inner Joins**:
     - Between `#temp1` and `account_balance_loan` for updates.
   - **Merge Join**:
     - Between `account_loan_last_accrual` and a source dataset for insert/update operations.

---

### 5. **Temporary Tables**
   - **`#temp`**:
     - Created with fields:
       - `loan_account_id`, `intDate`, `principal_amount`, `rate_of_interest`, `offset`, `intAcc`
     - Populated using data from:
       - `account_balance_loan`
       - `loan_account_master`
       - `loan_account_basic`
       - `loan_interest_slab_master`
   - **`#temp1`**:
     - Created with fields:
       - `loan_account_id`, `inteAmount`, `txn_date`
     - Populated using:
       - Summarized interest (`intAcc`) from `#temp`.

---

### 6. **Summary**
   - This procedure reads data from multiple loan-related tables, computes interest accruals using both predefined functions and inline calculations, and updates or inserts data into critical accounting tables. Temporary tables are utilized extensively for intermediate data handling.

---

