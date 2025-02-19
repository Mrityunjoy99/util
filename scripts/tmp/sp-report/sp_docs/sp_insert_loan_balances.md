## Overview
This report provides an analysis of the SQL stored procedure `sp_insert_loan_balances`. It includes details on:

1. Dependent functions or stored procedures (SPs).
2. Fields where data is being written or modified.
3. Tables being read from, including fields and conditions.
4. Joins used.
5. Additional observations.

---

## 1. Dependent Functions or Other SPs

- **Dependent Stored Procedure**:
  - `UPDATES_IN_DAY_END`: Called with the parameter `@p_rundate` after inserting data.

---

## 2. Fields Where Data is Being Written or Modified

### Permanent Tables

1. **`bsgaccounting..account_balance_loan`**:
   - **Fields Inserted**:
     - `loan_account_id`, `statement_opening_balance`, `day_opening_balance`, `maker_unclear_balance`, `maker_clear_balance`, `checker_unclear_balance`, `checker_clear_balance`, `day_end_balance`, `interest_accrual`, `interest_applied`, `interest_paid`, `charges_applied`, `charges_paid`, `penal_interest_accrual`, `penal_interest_applied`, `penal_interest_paid`, `principal_outstanding`, `legal_fee`, `lawyer_fee`, `npa_interest`, `overdue_amount`, `debit_summation`, `credit_summation`, `disbursement_count`, `disbursement_amount`, `sanction_limit`, `available_dp`, `available_balance`, `overdue_days_count`, `npa_amount`, `npa_marked_date`, `earmarked_amount`, `created_by`, `created_date`, `last_modified_by`, `last_modified_date`, `txn_date`, `is_active`, `adhoc_amount`, `installment_amount`, `is_final_installment_amount`, `received_amount`, `security_amount_overdue_days`, `npa_interest_amount`, `npa_penal_interest_amount`, `npa_charges_amount`, `bddr_interest_outstanding`, `principal_waived_off`, `interest_waived_off`, `penal_interest_waived_off`, `margin_amount`, `subsidy_realised`, `subsidy_received`, `excess_interest`, `margin_realised_amount`, `backdated_checker_clear_balance`, `backdated_principal_outstanding`, `backdated_npa_interest_amount`, `backdated_npa_penal_interest_amount`, `backdated_npa_charges_amount`, `principal_overdue`, `interest_overdue`, `principal_overdue_days`, `interest_overdue_days`, `branch_code`.
   - **Conditions**:
     - Ensures `abcurrent.loan_account_id IS NULL` to avoid duplicate data for the same transaction date.

2. **Update Operation on `bsgaccounting..account_balance_loan`**:
   - **Field Updated**: `npa_marked_date`
   - **Conditions**:
     - `lam.asset_classification = 1`
     - `CAST(abl.npa_marked_date AS date) <> '1900-01-01'`

---

## 3. Tables Being Read From

### `bsgloan..loan_account_master`
- **Fields Selected**:
  - `loan_account_id`, `loan_account_status`, `is_active`, `asset_classification`.
- **Conditions Applied**:
  - `loan_account_status != 2`
  - `is_active = 1`

### `bsgaccounting..account_balance_loan`
- **Fields Selected**:
  - All fields inserted into `account_balance_loan`.
- **Conditions Applied**:
  - `txn_date <= @p_rundate`
  - Only considers the latest transaction (`MAX(txn_date)`).
  - Ensures `abcurrent.loan_account_id IS NULL` to avoid duplication.

---

## 4. Joins Used

### Inner Joins

1. **`loan_account_master` with `account_balance_loan`**:
   - Join Condition: `lam.loan_account_id = ab.loan_account_id`.

2. **`account_balance_loan` with Subquery (`a`)**:
   - Subquery: Retrieves the latest transaction date for each loan account.
   - Join Condition: `ab.loan_account_id = a.loan_account_id` and `ab.txn_date = a.txn_date`.

### Left Joins

1. **`account_balance_loan` with `account_balance_loan` (alias `abcurrent`)**:
   - Join Condition: `ab.loan_account_id = abcurrent.loan_account_id` and `abcurrent.txn_date = @p_rundate`.

---

## 5. Additional Observations

1. **Error Handling**:
   - The procedure does not include error handling. Adding `TRY...CATCH` blocks would improve robustness.

2. **Duplicate Prevention**:
   - The `LEFT JOIN` with `abcurrent` ensures no duplicate data is inserted for the same transaction date.

3. **Optimization**:
   - Ensure proper indexing on frequently used fields like `txn_date`, `loan_account_id`, and `is_active` to improve performance.

4. **External Dependencies**:
   - The procedure relies on the external stored procedure `UPDATES_IN_DAY_END`.
   - It modifies `npa_marked_date` for specific loan accounts after the main insertion process.

5. **Data Integrity**:
   - Ensures `npa_marked_date` is reset for specific accounts with `asset_classification = 1`, maintaining data consistency.

---

## Conclusion
The `sp_insert_loan_balances` procedure inserts loan balance data for active accounts without duplicates for the specified run date. It uses efficient filtering and joins to ensure data accuracy and integrity. Adding error handling and validating dependencies like `UPDATES_IN_DAY_END` would enhance its reliability and maintainability.

