## Overview
The stored procedure `update_loan_repayment_chart_post_interest_application` processes loan repayment charts by:
1. Calculating and updating interest details for loans.
2. Managing moratorium accounts and their balances.
3. Ensuring ideal balances are updated, and adjustments are made for differences in actual vs. expected interests.
4. Handles both calendar-based and due-date-based processing types.

---

## 1. Dependent Functions and Stored Procedures
- **Functions**:
  - None explicitly mentioned; the procedure relies on SQL joins and inline calculations.
- **Stored Procedures**:
  - None explicitly invoked within this procedure.

---

## 2. Fields Where Data is Modified
- **Table**: `BSGACCOUNTING..loan_repayment_chart`
  - Fields:
    - `principal_amount`
    - `ideal_balance`
    - `interest_amount`
    - `od_int_accrual`
    - `penal_int_accrual`
    - `is_active`
    - `excess_id`
    - `last_modified_by`
    - `last_modified_date`
- **Table**: `BSGACCOUNTING..account_balance_loan`
  - Fields:
    - `principal_outstanding`
    - `interest_applied`
    - `penal_interest_applied`
    - `last_modified_by`
    - `last_modified_date`
- **Table**: `loan_actual_interest_ideal_interest_diff`
  - Fields:
    - `actual_interest_amount`
    - `ideal_interest_amount`
    - `diff_amount`
    - `is_active`
- **Table**: `[BSGDEEPFREEZE]..account_balance_loan_moratorium_updation_bucket` (backup table)
  - Inserts rows for backup during moratorium updates.

---

## 3. Tables Read
1. **`BSGACCOUNTING..loan_interest_details`**
   - Fields:
     - `interest_amount`
     - `penal_interest_amount`
   - Conditions:
     - Based on account ID.

2. **`BSGACCOUNTING..loan_repayment_chart`**
   - Fields:
     - `loan_account_id`
     - `due_date`
     - `principal_amount`
   - Conditions:
     - Active accounts and filtering by `@processing_type`.

3. **`BSGLOAN..loan_product_master`**
   - Fields:
     - `repayment_mode`
   - Conditions:
     - Active loan products with EMI mode.

4. **`BSGLOAN..loan_account_master`**
   - Fields:
     - `loan_account_id`
     - `loan_account_status`
   - Conditions:
     - Active loan accounts with a valid start date.

5. **`BSGACCOUNTING..account_balance_loan`**
   - Fields:
     - `principal_outstanding`
     - `interest_applied`
   - Conditions:
     - Accounts matching moratorium criteria.

---

## 4. Joins Used
- **Inner Joins**:
  - To connect repayment charts, loan interest details, and account balances.
- **Left Joins**:
  - Used for optional connections between repayment charts and product details.

---

## 5. Temporary Tables
1. **`#temp_loan_interest_details`**:
   - Stores interest details for loans from `loan_interest_details` and repayment charts.
   - Key Fields:
     - `interest_amount`
     - `penal_interest_amount`
     - `loan_account_id`

2. **`#temp_moratorium_account_list`**:
   - Identifies accounts with moratoriums.
   - Key Fields:
     - `loan_account_id`
     - `moratorium_period`

3. **`#temp_moratorium_list_with_moratorium_end_date`**:
   - Extends moratorium accounts with calculated end dates.
   - Key Fields:
     - `moratorium_end_date`

4. **`#temp_ideal_balance`**:
   - Captures ideal balances for loans during moratorium processing.
   - Key Fields:
     - `loan_account_id`
     - `ideal_balance`

5. **`#temp_moratorium_exclude_list`**:
   - Lists moratorium accounts excluded from updates.
   - Key Fields:
     - `loan_account_id`

---

## 6. Summary
This stored procedure manages the update of loan repayment charts by:
1. Calculating interest and updating repayment details.
2. Backing up moratorium account balances and making updates to principal and interest.
3. Handling both calendar-based and due-date-based processing.
4. Using temporary tables for intermediate calculations and ensuring data integrity.

---
