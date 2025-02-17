## Overview

This report provides an analysis of the SQL stored procedure `UPDATES_IN_DAY_END`. It includes details on:

1. Dependent functions or stored procedures (SPs).
2. Fields where data is being written or modified.
3. Tables being read from, including fields and conditions.
4. Joins used.
5. Additional observations.

---

## 1. Dependent Functions or Other SPs

- No explicit dependent stored procedures or functions are called within this procedure.
- Multiple configuration values are fetched from `BSGADMIN..cbs_config` for offset rates and loan overdue settings.

---

## 2. Fields Where Data is Being Written or Modified

### Permanent Tables

1. **`BSGLOAN..loan_account_basic`**:
   - **Fields Updated**:
     - `rate_of_interest`
   - **Conditions**:
     - Updates are based on the interest slab applicable to the loan's tenure, amount, and product.

2. **`BSGACCOUNTING..account_balance`**:
   - **Fields Updated**:
     - `maker_clear_balance`, `maker_unclear_balance`
   - **Conditions**:
     - Updates balances to match checker balances for the most recent transaction date.

3. **`BSGACCOUNTING..loan_repayment_chart`**:
   - **Fields Updated**:
     - `overdue_amount`, `overdue_days_count`
   - **Conditions**:
     - Updates overdue details for loans that meet specified criteria.

### Temporary Tables

1. **`#temp_security_details`**:
   - Stores security details for loans with primary security as fixed deposits.

2. **`#temp_details`**:
   - Stores updated interest rates for loans based on offset and third-party rates.

3. **`#temp_overdue_details`**:
   - Stores calculated overdue amounts, including NPA-related charges for loans.

---

## 3. Tables Being Read From

### `BSGLOAN..loan_account_master`
- **Fields Selected**:
  - `loan_account_id`, `loan_account_status`, `is_active`, `loan_type`, `loan_account_no`.
- **Conditions Applied**:
  - Active loans (`is_active = 1` and `loan_account_status <> 2`).

### `BSGLOAN..loan_account_basic`
- **Fields Selected**:
  - Includes `loan_tenure_year`, `loan_tenure_month`, `loan_amount`, `rate_of_interest`.
- **Conditions Applied**:
  - Active loans (`is_active = 1`).

### `BSGACCOUNTING..account_balance`
- **Fields Selected**:
  - Includes `account_id`, `txn_date`, `checker_clear_balance`, `checker_unclear_balance`, `maker_clear_balance`, `maker_unclear_balance`.
- **Conditions Applied**:
  - Retrieves the latest transaction date for each account (`MAX(txn_date)`).

### `BSGADMIN..cbs_config`
- **Fields Selected**:
  - Includes `config_key`, `config_value`.
- **Conditions Applied**:
  - Fetches configuration values for offset rates and overdue settings (`is_active = 1`).

---

## 4. Joins Used

### Inner Joins

1. **`loan_account_master` with `loan_account_basic`**:
   - Join Condition: `lam.loan_account_id = lab.loan_account_id`.

2. **`loan_account_master` with `loan_interest_slab_master`**:
   - Join Condition: `lism.loan_product_id = lam.loan_product_id` and `lism.effective_date` matches the latest applicable date.

3. **`account_balance` with Subquery**:
   - Subquery: Retrieves the latest transaction date for each account.
   - Join Condition: `ab.account_id = a.account_id` and `ab.txn_date = a.txn_date`.

4. **`loan_repayment_chart` with Subquery**:
   - Subquery: Retrieves the latest installment for each loan account.
   - Join Condition: `lrc.loan_account_id = a.loan_account_id` and `lrc.installment_no = a.installment_no`.

### Left Joins

1. **`loan_bank_deposit_view` with `#temp_security_details`**:
   - Join Condition: `lbdv.security_id = t.security_id`.

2. **`account_balance_loan` with Subquery**:
   - Subquery: Retrieves the latest transaction date for each loan account.
   - Join Condition: `abl.loan_account_id = a.loan_account_id` and `abl.txn_date = a.txn_date`.

---

## 5. Additional Observations

1. **Error Handling**:
   - The procedure does not include error handling. Adding `TRY...CATCH` blocks would improve robustness.

2. **Dynamic Date Handling**:
   - If `@p_rundate` is not provided, the procedure dynamically retrieves the application date, ensuring flexibility.

3. **Temporary Table Usage**:
   - Temporary tables are used effectively to store intermediate results and reduce redundant computations.

4. **Optimization**:
   - Indexing on fields like `txn_date`, `loan_account_id`, `account_id`, and `is_active` would improve performance.

---

## Conclusion

The `UPDATES_IN_DAY_END` procedure updates loan interest rates, account balances, and overdue amounts efficiently. It ensures accurate data updates by using well-structured joins and dynamic configurations. Adding error handling and optimizing indexes can further enhance its reliability and performance.

