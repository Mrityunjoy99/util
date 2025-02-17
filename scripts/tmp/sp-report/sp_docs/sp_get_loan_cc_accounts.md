## Overview
The stored procedure `sp_get_loan_cc_accounts` processes loan and cash credit accounts based on two different processing types:
1. Calendar Quarter Processing (`@processing_type = 1`).
2. Anniversary Quarter Processing (`@processing_type = 2`).

It identifies loan accounts based on their type and creates or updates records in the `loan_interest_details` table. The procedure also processes accounts nearing their due dates, calculates interest, and updates associated balances.

---

## Report Details

### 1. **Dependent Functions and Stored Procedures**
- **Dependent Functions**:
  - None directly mentioned.
- **Stored Procedures**:
  - None explicitly invoked within this procedure.

---

### 2. **Fields Where Data is Modified**
- **Table**: `bsgaccounting..loan_interest_details`
  - Fields:
    - `customer_id`
    - `loan_account_id`
    - `account_no`
    - `loan_type`
    - `npa_flag`
    - `branch_code`
    - `loan_product_code`
    - `loan_product_id`
    - `account_balance`
    - `interest_amount`
    - `penal_interest_amount`
    - `internal_product_id`
    - `internal_account_id`
    - `penal_pl_account_id`
    - `penal_pl_product_id`
    - `is_processed`

- **Table**: `bsgaccounting..account_balance_loan`
  - Fields:
    - Updated indirectly via joins for:
      - `interest_amount`
      - `penal_interest_amount`
      - `available_balance`

- **Temporary Tables**:
  - Updates are performed in:
    - `#temp_anniversary_date`
    - `#temp_limit_expired_accounts`
    - `#templimitexpiredacrualdate`

---

### 3. **Tables Read**
- **`bsgloan..loan_account_master`**
  - Fields:
    - `loan_account_id`
    - `loan_type`
    - `branch_code`
    - `loan_product_code`
    - `loan_product_id`
    - `is_active`
    - `loan_account_status`
    - `is_bddr`
  - Conditions:
    - Active accounts, loan type, and status checks.

- **`bsgloan..loan_product_master`**
  - Fields:
    - `penal_interest_pl_account_id`
    - `interest_income_pl_code`
    - `regular_interest_quarter_type`
  - Conditions:
    - Active loan products.

- **`bsgcore..customer_accounts`**
  - Fields:
    - `customer_id`
    - `account_no`
    - `is_active`
  - Conditions:
    - Active customer accounts.

- **`bsgaccounting..account_balance_loan`**
  - Fields:
    - `loan_account_id`
    - `available_balance`
    - `interest_accrual`
    - `penal_interest_accrual`
    - `txn_date`
  - Conditions:
    - Based on transaction date and account activity.

- **`bsgaccounting..loan_repayment_chart`**
  - Fields:
    - `loan_account_id`
    - `due_date`
    - `installment_no`
  - Conditions:
    - Based on due dates and installment numbers.

- **`bsgadmin..cbs_config`**
  - Fields:
    - `config_key`
    - `config_value`
  - Conditions:
    - Configuration for branch ID and microfinance products.

---

### 4. **Joins Used**
- **Inner Joins**:
  - Used extensively to link loan master, product master, and account details.
- **Left Joins**:
  - For optional matching between temporary tables and master tables.

---

### 5. **Temporary Tables**
- **`#temp_anniversary_date`**:
  - Created for accounts identified based on anniversary date criteria.
  - Fields include:
    - `customer_id`, `loan_account_id`, `loan_type`, `interest_amount`, `penal_interest_amount`.

- **`#temp_limit_expired_accounts`**:
  - Created for accounts with expired limits.
  - Fields include:
    - `loan_account_id`, `loan_type`, `account_balance`.

- **`#templimitexpiredacrualdate`**:
  - Tracks accrual dates for expired accounts.
  - Fields include:
    - `loan_account_id`, `accrualdate`, `startdatepart`.

---

## Summary
This stored procedure is focused on preparing loan account data for interest processing. It efficiently separates accounts into different categories, calculates relevant balances, and updates or inserts data into the main interest table. Temporary tables are utilized heavily to manage intermediate data for both calendar and anniversary quarter processing.

---
