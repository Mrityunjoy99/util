

CREATE   PROCEDURE [dbo].[sp_insert_td_balances] -- sp_insert_td_balances '2018-10-31'
@p_rundate date
as
BEGIN

INSERT INTO [dbo].[account_balance_td]
           ([td_account_id]
           ,[maker_unclear_balance]
           ,[maker_clear_balance]
           ,[checker_unclear_balance]
           ,[checker_clear_balance]
           ,[principal_sweep_out]
           ,[interest_accrual]
           ,[interest_provided]
           ,[interest_paid]
           ,[tds_from_interest]
           ,[tds_receivable]
           ,[tds_on_accrued_interest]
           ,[interest_payable]
           ,[previous_td_interest_payable]
           ,[premature_closure_interest]
           ,[available_balance]
           ,[tds_receivable_date]
           ,[created_by]
           ,[created_date]
           ,[last_modified_by]
           ,[last_modified_date]
           ,[txn_date]
           ,[is_active]
		   ,branch_code)    

SELECT 
	   ab.[td_account_id]
      ,ab.[maker_unclear_balance]
      ,ab.[maker_clear_balance]
      ,ab.[checker_unclear_balance]
      ,ab.[checker_clear_balance]
      ,ab.[principal_sweep_out]
      ,ab.[interest_accrual]
      ,ab.[interest_provided]
      ,ab.[interest_paid]
      ,ab.[tds_from_interest]
      ,ab.[tds_receivable]
      ,ab.[tds_on_accrued_interest]
      ,ab.[interest_payable]
      ,ab.[previous_td_interest_payable]
      ,ab.[premature_closure_interest]
      ,ab.[available_balance]
      ,ab.[tds_receivable_date]
      ,ab.[created_by]
      ,GETDATE() as created_date
      ,ab.[last_modified_by]
      ,GETDATE() as last_modified_date
      ,@p_rundate as txn_date
      ,ab.[is_active]
	  ,ab.branch_code
FROM
    BSGACCOUNTING..td_interest_application tia
        INNER JOIN
    bsgaccounting..account_balance_td ab ON 
	tia.td_account_id = ab.td_account_id
        INNER JOIN
    (SELECT 
        td_account_id, MAX(id) max_id
    FROM
        bsgaccounting..account_balance_td
    WHERE
        txn_date <= @p_rundate
    GROUP BY td_account_id) a ON ab.td_account_id = a.td_account_id
        AND ab.id = a.max_id
		   LEFT OUTER JOIN
    bsgaccounting..account_balance_td abcurrent ON ab.td_account_id = abcurrent.td_account_id
        AND abcurrent.txn_date = @p_rundate
	WHERE
       tia.current_interest > 0
	     AND abcurrent.td_account_id IS NULL;


insert into bsgaccounting..account_balance 
(	account_id,
    day_open_balance,
    maker_clear_balance,
    maker_unclear_balance,
    checker_unclear_balance,
    checker_clear_balance,
    day_close_balance,
    available_balance,
    interest_accrual,
    sprinkle,
    is_active,
    created_by,
    created_date,
    last_modified_by,
    last_modified_date,
	  txn_date,
    last_accrual_date,
    encrypted_balance,
    lien_amount,
	branch_code)
	
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
    ab.encrypted_balance,
    ab.lien_amount,
	ab.branch_code
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
        am.account_status_id NOT IN (2,4,5)
        AND abcurrent.account_id IS NULL
        -- and ab.interest_accrual > 0
		AND am.is_Active = 1
		AND EXISTS (
		SELECT * FROM BSGACCOUNTING..td_interest_application WHERE current_interest>0 AND transfer_account_id=am.account_id AND transfer_activity_type=1002
		AND (current_interest-current_tds-interest_on_tds_receivable-tds_receivable)>0);

END


