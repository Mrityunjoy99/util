
-- ==========================================================================================
-- Author:		ASHISH L.
-- Create date: 2022-09-15
-- Description:	<Get Details By TxnRefNo For Duplicate>
-- exec sp_getDetailsByTxnRefNo 0
-- ==========================================================================================

create    PROCEDURE [dbo].[sp_getDetailsByTxnRefNo]

@txnRefNo varchar(20) = 0

AS
BEGIN

DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WITH(NOLOCK) WHERE is_active=1)

;WITH CTE as(
	SELECT 
		COUNT(1) duplicate_count, txn_ref_no, txn_date, narration, activity_id, account_no, txn_amount, txn_nature
	FROM BSGACCOUNTING..transaction_pending tp WITH(NOLOCK)
	INNER JOIN BSGCORE..customer_accounts ca WITH(NOLOCK)
	ON tp.account_id=ca.account_id
	AND tp.is_active=1
	WHERE ca.is_active=1
	GROUP BY txn_ref_no, txn_date, narration, activity_id, account_no, txn_amount, txn_nature
	HAVING COUNT(1)>1
)

SELECT 
	account_no, txn_nature, txn_amount amount, narration narration, activity_id, duplicate_count
FROM CTE

END;

 




