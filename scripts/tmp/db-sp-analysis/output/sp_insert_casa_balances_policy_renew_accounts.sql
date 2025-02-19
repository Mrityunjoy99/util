




----------------------------------- Balance Insert Procedure ---------------------------------------------

create   PROCEDURE [dbo].[sp_insert_casa_balances_policy_renew_accounts] -- sp_insert_casa_balances_policy_renew_accounts '2021-03-18',764
@p_rundate date,
@fileId Int
as
BEGIN


 INSERT INTO account_balance 
	(	account_id, day_open_balance, maker_clear_balance, maker_unclear_balance, checker_unclear_balance, checker_clear_balance, day_close_balance, available_balance, 
		interest_accrual, sprinkle, is_active, created_by, created_date, last_modified_by, last_modified_date, txn_date, last_accrual_date, lien_amount, 
		encrypted_balance, branch_code, product_id, tds_amount, lcy_amount
	)
SELECT 
    ab.account_id,
    ab.day_open_balance,
    ab.maker_clear_balance,
    ab.maker_unclear_balance,
    ab.checker_unclear_balance,
    ab.checker_clear_balance,
    ab.day_close_balance,
    ab.available_balance,
    ISNULL(ab.interest_accrual,0),
    ab.sprinkle,
    ab.is_active,
    ab.created_by,
    GETDATE(),
    ab.last_modified_by,
    GETDATE(),
    @p_rundate txn_date,
    ab.last_accrual_date,
    ab.lien_amount,ab.encrypted_balance,ab.branch_code, ab.product_id, ab.tds_amount, ab.lcy_amount
FROM
    bsgcore..account_master am 
        INNER JOIN
    bsgaccounting..account_balance ab ON am.account_id = ab.account_id 
	 INNER JOIN
    (SELECT 
        account_id, MAX(txn_date) txn_date
    FROM
        bsgaccounting..account_balance
    WHERE
        txn_date <= @p_rundate
    GROUP BY account_id) a ON ab.account_id = a.account_id
        AND ab.txn_date = a.txn_date
        LEFT OUTER JOIN
    bsgaccounting..account_balance abcurrent ON ab.account_id = abcurrent.account_id
        AND abcurrent.txn_date = @p_rundate
WHERE
        am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1
		AND 
		am.account_id IN( SELECT account_id from bsgaccounting..policy_renewal_details prd WHERE prd.file_id = @fileId) 
END



