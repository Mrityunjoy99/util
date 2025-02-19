## Overview

This report provides an analysis of the SQL stored procedure `sp_insert_td_balances`. It includes details on:

1. Dependent functions or stored procedures (SPs).
2. Fields where data is being written or modified.
3. Tables being read from, including fields and conditions.
4. Joins used.
5. Additional observations.

---

## 1. Dependent Functions or Other SPs

- No dependent functions or stored procedures are called explicitly within this procedure.

---

## 2. Fields Where Data is Being Written or Modified

### Permanent Tables

1. **`dbo.account_balance_td`**:
   - **Fields Inserted**:
     - Includes `td_account_id`, `maker_unclear_balance`, `checker_clear_balance`, `principal_sweep_out`, `interest_accrual`, `interest_provided`, `interest_paid`, `tds_from_interest`, and other TD-related balance fields.
   - **Conditions**:
     - Ensures `abcurrent.td_account_id IS NULL` to prevent duplicate entries for the run date.

2. **`bsgaccounting..account_balance`**:
   - **Fields Inserted**:
     - Includes `account_id`, `day_open_balance`, `maker_clear_balance`, `checker_unclear_balance`, `interest_accrual`, `available_balance`, and other balance-related fields.
   - **Conditions**:
     - Ensures `abcurrent.account_id IS NULL` and validates active accounts with specific interest conditions.

---

## 3. Tables Being Read From

### `bsgaccounting..td_interest_application`
- **Fields Selected**:
  - `td_account_id`, `current_interest`.
- **Conditions Applied**:
  - `current_interest > 0`.

### `bsgaccounting..account_balance_td`
- **Fields Selected**:
  - Includes `td_account_id`, `maker_unclear_balance`, `checker_clear_balance`, and related fields.
- **Conditions Applied**:
  - Retrieves the latest transaction date for each `td_account_id` (`MAX(id)`).

### `bsgcore..account_master`
- **Fields Selected**:
  - Includes `account_id`, `account_status_id`, and `is_active`.
- **Conditions Applied**:
  - `account_status_id NOT IN (2,4,5)`
  - `is_active = 1`.

---

## 4. Joins Used

### Inner Joins

1. **`td_interest_application` with `account_balance_td`**:
   - Join Condition: `tia.td_account_id = ab.td_account_id`.

2. **`account_balance_td` with Subquery (`a`)**:
   - Subquery: Retrieves the latest transaction (`MAX(id)`) for each `td_account_id`.
   - Join Condition: `ab.td_account_id = a.td_account_id` and `ab.id = a.max_id`.

3. **`account_master` with `account_balance`**:
   - Join Condition: `am.account_id = ab.account_id`.

### Left Joins

1. **`account_balance_td` with `account_balance_td` (alias `abcurrent`)**:
   - Join Condition: `ab.td_account_id = abcurrent.td_account_id` and `abcurrent.txn_date = @p_rundate`.

2. **`account_balance` with `account_balance` (alias `abcurrent`)**:
   - Join Condition: `ab.account_id = abcurrent.account_id` and `abcurrent.txn_date = @p_rundate`.

---

## 5. Additional Observations

1. **Error Handling**:
   - The procedure lacks error handling mechanisms. Adding `TRY...CATCH` blocks would enhance robustness.

2. **Duplicate Prevention**:
   - The procedure uses `LEFT JOIN` to ensure no duplicate data is inserted for the same transaction date.

3. **Optimization**:
   - Ensure proper indexing on frequently used fields like `txn_date`, `td_account_id`, `account_id`, and `is_active` to improve performance.

4. **Data Integrity**:
   - The procedure validates input parameters and active statuses, maintaining data consistency.

---

## Conclusion

The `sp_insert_td_balances` procedure inserts TD and account balance data efficiently, ensuring no duplicates for the specified run date. It relies on well-structured joins and conditions for accurate data insertion. Adding error handling and optimizing dependencies could enhance its maintainability and reliability.

