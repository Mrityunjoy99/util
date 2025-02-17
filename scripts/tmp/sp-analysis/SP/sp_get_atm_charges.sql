-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_get_atm_charges]
	@txnDate date
AS
BEGIN
	
INSERT INTO bsgaccounting..debitcard_charges_on_accounts
(account_id,
branch_code,
product_code,
product_id,
classification_id,
account_balance,
charge_amount,
cgst_amount,
sgst_amount,
cgst_internal_product_id,
sgst_internal_product_id,
charges_pl_product_id,
charges_pl_account_id,
narration)
SELECT 
    am.account_id,
    am.branch_code,
    am.product_code,
    am.product_id,
    ca.classification_id,
    ab.checker_clear_balance,
    120,
	120*0.09,
    120*0.09,
     (select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'CGST_PRODUCT' AND is_active = 1) and branch_code=ca.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'SGST_PRODUCT' AND is_active = 1) and branch_code=ca.branch_code
	and is_active=1),
    (SELECT 
            internal_product_id
        FROM
            BSGCORE..product_master_internal
        WHERE
            product_code = 9000
                AND branch_code = ca.branch_code
                AND is_active = 1),
    (SELECT 
           top 1  account_id
        FROM
            bsgcore..customer_accounts
        WHERE
            account_no = (SELECT top 1 
                    REPLACE(account_no,
                            LEFT(account_no, 4),
                            ca.branch_code)
                FROM
                    BSGCORE..customer_accounts
                WHERE
                    account_id = 9872 AND is_Active = 1
               )
                AND is_Active = 1
       ),
    CONCAT('Debit Card Charges - ',@txnDate)
FROM
    bsgcore..customer_accounts ca
        INNER JOIN
    bsgcore..account_master am ON ca.account_id = am.account_id
        INNER JOIN
    (SELECT 
        ab.account_id, MAX(txn_date) txn_date
    FROM
        bsgaccounting..account_balance ab
    WHERE
        ab.account_id IN (SELECT 
                account_id
            FROM
                bsgcore..customer_accounts
            WHERE
                account_no IN (SELECT 
                        account_no
                    FROM
                        bsgdeepfreeze..atm_charges_accounts
                    WHERE
                        classification_id IN (1 , 2)
                            AND is_active = 1))
    GROUP BY ab.account_id) a ON am.account_id = a.account_id
        INNER JOIN
    bsgaccounting..account_balance ab ON am.account_id = ab.account_id
        AND a.txn_date = ab.txn_date
WHERE
    ca.is_active = 1 AND am.is_active = 1
    and am.account_status_id not in (4,8)
union all
   
SELECT 
    am.loan_account_id,
    am.branch_code,
    am.loan_product_code,
    am.loan_product_id,
    ca.classification_id,
    ab.available_balance,
    120,
	120*0.09,
   120*0.09,
     (select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'CGST_PRODUCT' AND is_active = 1) and branch_code=ca.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'SGST_PRODUCT' AND is_active = 1) and branch_code=ca.branch_code
	and is_active=1),
    (SELECT 
            internal_product_id
        FROM
            BSGCORE..product_master_internal
        WHERE
            product_code = 9000
                AND branch_code = ca.branch_code
                AND is_active = 1),
    (SELECT top 1  
            account_id
        FROM
            bsgcore..customer_accounts
        WHERE
            account_no = (SELECT top 1 
                    REPLACE(account_no,
                            LEFT(account_no, 4),
                            ca.branch_code)
                FROM
                    BSGCORE..customer_accounts
                WHERE
                    account_id = 9872 AND is_Active = 1
                )
                AND is_Active = 1
        ),
    CONCAT('Debit Card Charges - ',@txnDate)
FROM
    bsgcore..customer_accounts ca
        INNER JOIN
    bsgloan..loan_account_master am ON ca.account_id = am.loan_account_id
        INNER JOIN
    (SELECT 
        ab.loan_account_id, MAX(txn_date) txn_date
    FROM
        bsgaccounting..account_balance_loan ab
    WHERE
        ab.loan_account_id IN (SELECT 
                account_id
            FROM
                bsgcore..customer_accounts
            WHERE
                account_no IN (SELECT 
                        account_no
                    FROM
                        bsgdeepfreeze..atm_charges_accounts
                    WHERE
                        classification_id IN (6)
                            AND is_active = 1))
    GROUP BY ab.loan_account_id) a ON am.loan_account_id = a.loan_account_id
        INNER JOIN
    bsgaccounting..account_balance_loan ab ON am.loan_account_id = ab.loan_account_id
        AND a.txn_date = ab.txn_date
WHERE
    ca.is_active = 1 AND am.is_active = 1 and am.loan_account_status <> 2
;

   
END

