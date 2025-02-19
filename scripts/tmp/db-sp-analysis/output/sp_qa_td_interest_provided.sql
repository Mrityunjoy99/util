
-- =============================================
-- Author:		Satdhruti
-- Create date: 10th Sep 2024
-- Description:	Temporary QA Utility SP for TD Payout
-- =============================================

CREATE PROCEDURE [dbo].[sp_qa_td_interest_provided]
    @tdAccountId INT
AS
BEGIN
    -- Retrieve data from customer_accounts table based on tdAccountId
    SELECT 
        ca.customer_id,
        ca.account_no,
        
        -- Interest Payable Product ID
        (SELECT internal_product_id 
         FROM BSGCORE..product_master_internal 
         WHERE product_code = (
             SELECT config_value 
             FROM BSGADMIN..cbs_config 
             WHERE config_key = 'INTEREST_PAYABLE' 
             AND is_active = 1
         ) 
         AND branch_code = tam.branch_code 
         AND is_active = 1) AS interest_payable_product_id,
         
        -- TDS Product ID
        (SELECT internal_product_id 
         FROM BSGCORE..product_master_internal 
         WHERE product_code = (
             SELECT config_value 
             FROM BSGADMIN..cbs_config 
             WHERE config_key = 'TDS_PRODUCT' 
             AND is_active = 1
         ) 
         AND branch_code = tam.branch_code
         AND is_active = 1) AS tds_product_id,
         
        -- TDS Receivable Product ID
        (SELECT internal_product_id 
         FROM BSGCORE..product_master_internal 
         WHERE product_code = (
             SELECT config_value 
             FROM BSGADMIN..cbs_config 
             WHERE config_key = 'TDS_RECEIVABLE_PRODUCT' 
             AND is_active = 1
         ) 
         AND branch_code = tam.branch_code 
         AND is_active = 1) AS tds_receivable_product_id,
         
        -- PL Product ID
        (SELECT internal_product_id 
         FROM BSGCORE..account_master_internal 
         WHERE internal_account_id = tpm.pl_account_id 
         AND is_active = 1) AS pl_product_id,

        -- Interest Type ID from td_product_master
        tpm.interest_type_id,
        tpm.interest_frequency,
        tpm.pl_account_id,

        -- TDS Receivable, TDS Receivable Date, Interest Payable from account_balance_td
        abt.tds_receivable,
        abt.tds_receivable_date,
        abt.interest_payable,

        -- Next Interest Date and Next Paid Date from td_account_deposit_details
        tadd.next_interest_date,
        tadd.next_paid_date,

        -- Interest on TDS Receivable Calculation
        ROUND(((abt.tds_receivable * tadd.base_rate * DATEDIFF(D, abt.tds_receivable_date, tadd.next_interest_date)) / 36500), 0) AS interest_on_tds_receivable,

        -- Current Interest Calculation
        tdi.interest AS current_interest
         
    FROM BSGCORE..customer_accounts ca
    JOIN BSGTD..td_account_master tam
        ON ca.account_id = tam.td_account_id  
        AND tam.is_active = 1 -- Ensuring active td_account_master records
    JOIN BSGTD..td_product_master tpm
        ON tpm.product_id = tam.product_id
        AND tpm.is_active = 1
    JOIN (
        -- Select the most recent record from account_balance_td
        SELECT TOP 1 abt.td_account_id, abt.tds_receivable, abt.tds_receivable_date, abt.interest_payable, abt.checker_clear_balance, abt.interest_paid
        FROM BSGACCOUNTING..account_balance_td abt
        WHERE abt.td_account_id = @tdAccountId 
        AND abt.is_active = 1 
        ORDER BY abt.txn_date DESC  -- Selecting the most recent record
    ) abt
        ON abt.td_account_id = tam.td_account_id  -- Fetching from account_balance_td
    JOIN BSGTD..td_account_deposit_details tadd
        ON tadd.td_account_id = @tdAccountId  
        AND tadd.is_active = 1  -- Ensuring active td_account_deposit_details records
    JOIN BSGACCOUNTING..td_datewise_interest tdi
         ON tdi.td_account_id = tam.td_account_id 
         AND tdi.interest_date = tadd.next_interest_date 
         AND tdi.is_active = 1
    WHERE ca.account_id = @tdAccountId;
END;