## 1. Dependent Functions or Other Stored Procedures

### Dependent Stored Procedures
- **`BSGACCOUNTING.dbo.npa_provision_details`**  
  **Usage:** Executed at the end of the procedure with `@cbsAppDate` as the parameter.  
  **Purpose:** Likely calculates Non-Performing Assets (NPA) provisions based on the SMA classification and other parameters.

### Dependent Tables and Views
While not functions or stored procedures, several tables and views from different databases are accessed, which might have underlying dependencies:

- **`BSGADMIN..cbs_config`**
- **`BSGACCOUNTING..interest_details`**
- **`BSGLOAN..loan_account_master`**
- **`BSGLOAN..loan_product_master`**
- **`BSGLOAN..loan_account_basic`**
- **`BSGACCOUNTING..account_balance_loan`**

*Note: If these tables have associated triggers, views, or underlying stored procedures, those would also constitute dependencies.*

---

## 2. Fields Where Data is Being Written or Modified

### a. Temporary Tables

- **`#temp_product_details`**  
  - **Fields:**
    - `product_code` (VARCHAR(500))
  - **Data Written:** Populated by splitting the `config_value` from `BSGADMIN..cbs_config`.

- **`#temp_sm0_details`, `#temp_sm1_details`, `#temp_sm2_details`**  
  - **Fields:**
    - `account_id`
    - `txn_date`
    - `Interest`
  - **Data Written:** Calculated SMA interest details for different SMA periods (0, 1, 2).

- **`#temp_sma_calculation_details`**  
  - **Fields:**
    - Various fields including `overdue_days_count_for_sma_calulation` and `smaclassificationforInterest`.
  - **Data Written:** Initial data populated via `SELECT INTO` and later updated.

### b. Permanent Tables

- **`loan_sma_classification_details`**  
  - **Fields Inserted:**
    - `loan_account_id`
    - `txn_date`
    - `sma_classification`
    - `asset_classification`
    - `rate_of_interest`
    - `offset`
    - `overdue_days_count_for_sma_calulation`
    - `smaclassificationforOverdue`
    - `smaclassificationforInterest`
    - `overdueDaysForInterestSMA`
    - Two additional fields set to `0` (presumably placeholders or default values).

### c. Updates

- **`#temp_sma_calculation_details`**  
  - **Fields Updated:**
    - `overdue_days_count_for_sma_calulation`
    - `smaclassificationforInterest`
  - **Modification Logic:** Adjusts overdue days based on conditions and resets SMA classification for interest calculations.

---

## 3. Tables Being Read From, Including Fields and Conditions

### a. Configuration Data

- **Table:** `BSGADMIN..cbs_config`  
  - **Fields Read:**
    - `config_value`
  - **Conditions:**
    - `config_key = 'LOAN_ORDER_REVERSAL_PRODUCTS'`
    - `is_active = 1`
  - **Purpose:** Retrieves a comma-separated list of product codes to populate `#temp_product_details`.

### b. Interest Details for SMA Classification

- **Table:** `BSGACCOUNTING..interest_details` (Alias: `id`)  
  - **Fields Read:**
    - `account_id`
    - `interest_amount`
    - `activity_id`
    - `txn_date`
  - **Conditions:**
    - `txn_date` within respective SMA periods (`@fromDateSM0` to `@cbsAppDate`, etc.)
    - `activity_id` in specified lists for debit and reversal activities.

- **Table:** `BSGLOAN..loan_account_master` (Alias: `lam`)  
  - **Fields Read:**
    - `loan_account_id`
    - `is_active`
    - `loan_account_status`
  - **Conditions:**
    - `is_active = 1`
    - `loan_account_status <> 2` (presumably excluding closed or defaulted accounts)

### c. Loan Account and Product Details

- **Tables:**
  - `BSGLOAN..loan_product_master` (Alias: `LPM`)
  - `BSGLOAN..loan_account_basic` (Alias: `LAB`)

- **Fields Read:**
  - Various fields related to loan products, repayment modes, frequencies, interest rates, etc.

- **Conditions:**
  - `is_active = 1` for relevant joins.

### d. Account Balance Loan

- **Table:** `BSGACCOUNTING..account_balance_loan` (Alias: `ABL`)  
  - **Fields Read:**
    - `loan_account_id`
    - `txn_date`
    - `interest_applied`
    - `interest_paid`
    - `penal_interest_applied`
    - `penal_interest_paid`
    - `overdue_amount`
    - `overdue_days_count`
    - `interest_overdue_days`
  - **Conditions:**
    - `txn_date <= @cbsAppDate`
    - Joins based on `loan_account_id` and latest `txn_date`.

### e. Product Codes for Staff Housing

- **Temporary Table:** `#temp_product_details` (Alias: `staffHousing`)  
  - **Fields Read:**
    - `product_code`
  - **Conditions:**
    - Joins on `loan_product_code` cast to `VARCHAR(50)`.

---

## 4. Joins Used in the Procedure

### a. `#temp_product_details` Population
- **Type:** None (Data is inserted via a WHILE loop)

### b. SMA Details (`#temp_sm0_details`, `#temp_sm1_details`, `#temp_sm2_details`)
- **Join Type:** `LEFT OUTER JOIN`
- **Tables Involved:**
  - `BSGACCOUNTING..interest_details` (`id`)
  - `BSGLOAN..loan_account_master` (`lam`)
- **Join Conditions:**
  - `id.account_id = lam.loan_account_id`
  - `lam.is_active = 1`

### c. Main SMA Calculation (`#temp_sma_calculation_details`)
- **Join Types:** Multiple `LEFT JOIN` and `LEFT OUTER JOIN`
- **Tables Involved:**
  - `BSGLOAN..loan_account_master` (`LAM`)
  - `BSGLOAN..loan_product_master` (`LPM`)
  - `BSGLOAN..loan_account_basic` (`LAB`)
  - Subqueries on `BSGACCOUNTING..account_balance_loan` (`AB`, `ABL`)
  - Temporary SMA details tables (`#temp_sm0_details`, `#temp_sm1_details`, `#temp_sm2_details`)
  - `#temp_product_details` (`staffHousing`)
- **Join Conditions:**
  - Various conditions based on `loan_account_id`, `txn_date`, and `product_code`.

### d. Update Statement on `#temp_sma_calculation_details`
- **Join Types:** `LEFT OUTER JOIN`
- **Tables Involved:**
  - `BSGLOAN..loan_account_master` (`l`)
  - `BSGLOAN..loan_product_master` (`LPM`)
  - Subqueries on `BSGACCOUNTING..account_balance_loan` (`AB`, `ABL`)
- **Join Conditions:**
  - `l.loan_account_id = s.loan_account_id`
  - `l.loan_product_id = LPM.loan_product_id`
  - `ABL.loan_account_id = AB.loan_account_id` and `ABL.txn_date = AB.txn_date`

### e. Insertion into `loan_sma_classification_details`
- **Type:** `SELECT` with no explicit join (data is selected from a temporary table)

---

## 5. Temporary Tables Details

### a. `#temp_product_details`
- **Purpose:** Stores product codes relevant for identifying staff housing loans.  
- **Fields:**
  - `product_code` (VARCHAR(500))
- **Data Source:**  
  - Populated by splitting the `config_value` from `BSGADMIN..cbs_config` based on a comma delimiter.

### b. `#temp_sm0_details`, `#temp_sm1_details`, `#temp_sm2_details`
- **Purpose:** Store SMA interest details for different SMA periods (0, 1, 2).
- **Fields:**
  - `account_id`
  - `txn_date`
  - `Interest`
- **Data Source:**  
  - Calculated from `BSGACCOUNTING..interest_details` joined with `BSGLOAN..loan_account_master` based on specific `activity_id` and `txn_date` ranges.

### c. `#temp_sma_calculation_details`
- **Purpose:** Intermediate table for calculating SMA classifications.
- **Fields:** Various fields including:
  - `overdue_days_count_for_sma_calulation`
  - `smaclassificationforInterest`
  - Other loan and interest-related fields.
- **Data Source:**  
  - Derived from joining multiple tables including `loan_account_master`, `loan_product_master`, `loan_account_basic`, `account_balance_loan`, and temporary SMA details tables.
- **Additional Logic:**  
  - Contains complex calculations for overdue days, SMA classification based on interest and dates, handling of moratorium periods, and identification of staff housing loans.

---

## Additional Insights

### Data Flow Overview

1. **Configuration Retrieval:**  
   The procedure starts by fetching configuration data (`LOAN_ORDER_REVERSAL_PRODUCTS`) to identify relevant loan products.

2. **SMA Details Calculation:**  
   Calculates SMA interest details for three periods (0, 1, 2) and stores them in respective temporary tables.

3. **SMA Classification Calculation:**  
   Combines loan details with SMA interest data to determine the SMA classification for each loan account.  
   Adjusts overdue days based on specific conditions and repayment modes.

4. **Final Classification Insertion:**  
   Inserts the calculated SMA classifications into the `loan_sma_classification_details` table.

5. **NPA Provision Calculation:**  
   Executes another stored procedure to calculate NPA provisions based on the updated SMA classifications.

### Performance Considerations

- **Use of `WITH (NOLOCK)`:**  
  The procedure extensively uses `WITH (NOLOCK)` hints to read uncommitted data, which can lead to dirty reads but may improve performance by reducing locking.

- **Temporary Tables:**  
  Utilizing temporary tables (`#temp_*`) helps in breaking down complex calculations and can improve readability and maintainability. However, excessive use of temporary tables can impact performance, especially with large datasets.

- **Indexing:**  
  Ensure that the joined fields, especially `loan_account_id` and `txn_date`, are properly indexed to optimize join and filter operations.

- **Loop for Splitting Strings:**  
  The procedure uses a WHILE loop to split a comma-separated string into `#temp_product_details`. Consider using more efficient string-splitting methods (e.g., `STRING_SPLIT` in SQL Server 2016+) to enhance performance.

---
