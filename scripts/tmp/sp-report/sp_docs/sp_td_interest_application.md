## Overview
The stored procedure `sp_td_interest_application` calculates and applies interest and tax deducted at source (TDS) for term deposits. It processes customer data, applies different rates based on customer type and deposit type, and updates the `td_interest_application` table accordingly. It uses temporary tables for intermediate calculations and handles various edge cases for interest and TDS application.

---

## 1. Dependent Functions and Stored Procedures
- **Dependent Functions**:
  - None explicitly mentioned, but inline calculations and subqueries are extensively used.
- **Stored Procedures**:
  - None invoked explicitly within this procedure.

---

## 2. Fields Where Data is Modified
- **Table**: `BSGACCOUNTING..td_interest_application`
  - Fields:
    - `current_interest`
    - `projected_interest`
    - `current_tds`
    - `is_applied`
    - `tds_rate`
    - Other customer and account details.

---

## 3. Tables Read
1. **`BSGADMIN..cbs_config`**
   - Used to retrieve configuration values like TDS rates and thresholds.
   - Fields:
     - `config_key`
     - `config_value`
   - Conditions:
     - `is_active = 1`

2. **`BSGACCOUNTING..account_balance_td`**
   - Used to fetch account balances for term deposits.
   - Fields:
     - `td_account_id`
     - `interest_accrual`
     - `checker_clear_balance`
   - Conditions:
     - Fetches data for active accounts based on maximum ID or transaction date.

3. **`BSGACCOUNTING..td_customer_interest_tds`**
   - Fields:
     - `td_account_id`
     - `interest`
     - `tds`
   - Conditions:
     - Date range filtering using financial year start and end dates.

4. **`BSGCRM..customer_master`**
   - Used to determine customer types and groups.
   - Fields:
     - `customer_group_id`
     - `custome_type_code`
     - `age_group`
   - Conditions:
     - Active customers only.

5. **`BSGTD..td_account_master`**
   - Used to fetch term deposit account details.
   - Fields:
     - `td_account_id`
     - `account_status_id`
     - `maturity_amount`

---

## 4. Joins Used
- **Inner Joins**:
  - Between account master, customer details, and product configurations for interest and TDS calculations.
- **Left Joins**:
  - For optional fields like projected interest and TDS data.

---

## 5. Temporary Tables
1. **`#temp_interest_application`**:
   - Used to store intermediate interest application data.
   - Populated using customer and account data with interest and TDS calculations.
   - Key Fields:
     - `td_account_id`
     - `current_interest`
     - `projected_interest`
     - `interest_start_date`
     - `maturity_date`

2. **`#temp_form15AA_details`**:
   - Captures data for customers with Form 15AA.
   - Key Fields:
     - `customer_group_id`
     - `tds_rate`
     - `current_interest`
     - `previous_interest`

3. **`#temp_15AACustomerWiseDetails`**:
   - Stores consolidated interest and TDS data for customers.
   - Key Fields:
     - `customer_group_id`
     - `total_int`
     - `current_total_tds`

---

## 6. Summary
The procedure processes term deposit data to calculate:
1. Interest for each term deposit based on account status, maturity, and interest rates.
2. TDS application with varying rates for different customer types and deposit types.
3. Consolidation of TDS and interest data for reporting and updates.

It uses multiple temporary tables and nested queries to manage complex calculations and ensure data integrity.

---

