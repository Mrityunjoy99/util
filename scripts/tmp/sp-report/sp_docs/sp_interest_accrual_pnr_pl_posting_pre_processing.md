## Overview
The stored procedure `sp_interest_accrual_pnr_pl_posting_pre_processing` processes interest accruals for CASA, term deposits (TD), and loans. It ensures accurate mappings between payable and PNR accounts, updates relevant balances, and inserts data into the `interest_accrual_pnr_pl_posting` table. Additionally, it updates the internal product IDs for source and destination accounts.

---

## 1. Dependent Functions and Stored Procedures
- **Functions**:
  - None explicitly mentioned.
- **Stored Procedures**:
  - None explicitly invoked within this procedure.

---

## 2. Fields Where Data is Modified
- **Table**: `BSGACCOUNTING..interest_accrual_pnr_pl_posting`
  - Fields:
    - `branch_code`
    - `classification_id`
    - `product_id`
    - `source_principal_type`
    - `source_txn_nature`
    - `source_balance`
    - `destination_principal_type`
    - `destination_txn_nature`
    - `destination_balance`
    - `txn_amount`
    - `narration`
    - `source_principal_product_id`
    - `destination_principal_product_id`

- **Tables Updated with Balances**:
  - **`BSGACCOUNTING..account_balance`**
  - **`BSGACCOUNTING..account_balance_td`**
  - **`BSGACCOUNTING..account_balance_loan`**

---

## 3. Tables Read
1. **`BSGACCOUNTING..account_balance`**
   - Used to retrieve and update CASA balances.
   - Fields:
     - `branch_code`
     - `product_id`
     - `interest_accrual`
   - Conditions:
     - Based on transaction date and account activity.

2. **`BSGACCOUNTING..account_balance_td`**
   - Used for term deposit (TD) accounts.
   - Fields:
     - `branch_code`
     - `product_id`
     - `interest_accrual`
   - Conditions:
     - Based on transaction date.

3. **`BSGACCOUNTING..account_balance_loan`**
   - Used for loan and credit card (CC) accounts.
   - Fields:
     - `branch_code`
     - `product_id`
     - `interest_accrual`
     - `penal_interest_accrual`
   - Conditions:
     - Non-NPA accounts with active loans.

4. **`BSGCORE..product_master`**
   - Maps product IDs with additional account details.
   - Fields:
     - `product_id`
     - `classification_id`

5. **`BSGACCOUNTING..interest_pnr_pl_mapping`**
   - Used for mapping between payable and PNR accounts.
   - Fields:
     - `pl_account_id`
     - `pnr_account_id`
   - Conditions:
     - Active mappings only.

---

## 4. Joins Used
- **Inner Joins**:
  - Used to connect account balances with product mappings and PNR accounts.
- **Left Joins**:
  - Used for optional mappings where payable balances may not exist.

---

## 5. Temporary Tables
1. **`#tempCasa`**:
   - Stores CASA account balances and mapping details.
   - Key Fields:
     - `branch_code`
     - `interest_accrual`
     - `payable_account_id`

2. **`#tempTd`**:
   - Stores term deposit balances for processing.
   - Key Fields:
     - `branch_code`
     - `interest_accrual`
     - `payable_account_id`

3. **`#temploanCcRegularInt`**:
   - Captures regular interest details for loans and credit cards.
   - Key Fields:
     - `branch_code`
     - `interest_accrual`
     - `payable_account_id`

4. **`#temploanCcPenalInt`**:
   - Stores penal interest details for loans and credit cards.
   - Key Fields:
     - `branch_code`
     - `interest_accrual`
     - `payable_account_id`

---

## 6. Key Business Logic
1. **CASA Processing**:
   - Reads CASA balances and maps them to their payable accounts.
   - Inserts processed data into `interest_accrual_pnr_pl_posting`.

2. **Term Deposit (TD) Processing**:
   - Reads TD balances and updates mappings to payable accounts.
   - Handles active TD accounts only.

3. **Loan and Credit Card Processing**:
   - Separates regular and penal interest accruals.
   - Ensures non-NPA accounts are processed.

4. **Internal Product ID Updates**:
   - Updates `source_principal_product_id` and `destination_principal_product_id` in the `interest_accrual_pnr_pl_posting` table.

---

## 7. Summary
This procedure performs pre-processing for interest accrual posting across CASA, term deposit, and loan accounts. It ensures:
1. Accurate updates to account balances and mappings.
2. Proper segregation of interest types (regular and penal).
3. Maintenance of internal product IDs for reporting and further processing.

---
