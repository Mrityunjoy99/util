## Overview
The stored procedure `sp_loan_penal_interest_accrual` calculates the penal interest accrual for loan accounts based on overdue amounts. It updates the corresponding fields in several tables and generates a success/failure count report.

---

## Analysis

### 1. **Dependent Functions and Stored Procedures**
   - **Functions**:
     - `dbo.IsLeapYear`: Used in the commented-out section for determining leap years when calculating penal interest.
   - **Dependent Stored Procedures**:
     - None specified directly.

---

### 2. **Fields Where Data is Modified**
   - **Table**: `BSGACCOUNTING.dbo.account_balance_loan`
     - `penal_interest_accrual`
     - `last_modified_by`
     - `last_modified_date`
   - **Table**: `BSGACCOUNTING.dbo.account_loan_last_accrual`
     - `penal_accrual_date`
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
   - **`BSGACCOUNTING.dbo.account_balance_loan`**:
     - Fields: `loan_account_id`, `txn_date`, `overdue_amount`
     - Conditions:
       - `is_active = 1`
       - `txn_date <= Dateadd(day,sv.number+1,accrual_date)`
   - **`BSGLOAN.dbo.loan_account_master`**:
     - Fields: `loan_account_id`, `loan_account_status`, `loan_type`
     - Conditions:
       - `is_active = 1`
       - `loan_account_status = 1`
       - `loan_type = 1`
   - **`BSGLOAN.dbo.loan_account_basic`**:
     - Fields: `penal_int_mode_for_overdue`, `penal_interest_for_overdue`
     - Conditions:
       - `is_active = 1`
   - **`BSGLOAN.dbo.loan_product_master`**:
     - Fields: `penal_int_mode_for_overdue`, `penal_interest_for_overdue`
     - Conditions:
       - `is_active = 1`
   - **`master..spt_values`**:
     - Used for generating dates based on `accrual_date`.
     - Fields: `number`
   - **`bsgturing.dbo.turing_task_result`**:
     - Inserted into this table based on the results of the interest accrual.

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
       - `loan_account_id`, `overdue_amount`, `penal_int_mode_for_overdue`, `penal_interest_for_overdue`, `pnlAmount`, `intrdate`
     - Populated using data from:
       - `account_balance_loan`
       - `loan_account_master`
       - `loan_account_basic`
       - `loan_product_master`
   - **`#temp1`**:
     - Created with fields:
       - `loan_account_id`, `pnlAmount`, `txn_date`
     - Populated using:
       - Summarized penal interest (`pnlAmount`) from `#temp`.

---

### 6. **Summary**
   - This procedure calculates penal interest accruals for overdue loan accounts, updates several key tables with the results, and generates a summary report of the number of successful and failed operations. Temporary tables are used extensively to store intermediate results and facilitate the calculation and updates.

---

