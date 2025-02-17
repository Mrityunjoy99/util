
CREATE   PROCEDURE [dbo].[sp_account_last_txn]
AS BEGIN

DECLARE @CBSDATE DATE = (SELECT DATEADD(DAY,-1,app_date) from BSGACCOUNTING..cbs_application_date where is_active = 1)
DECLARE @MAXLASTDATE DATE = (SELECT ISNULL(DATEADD(DAY,1,MAX(txn_date)),'2018-12-27') FROM BSGACCOUNTING..account_last_txn)

PRINT 'CBSDATE ' + CONVERT(varchar(10),@CBSDATE,121)
PRINT 'MAXLASTDATE ' + CONVERT(varchar(10),@MAXLASTDATE,121) 

IF(@MAXLASTDATE<=@CBSDATE)
BEGIN

SELECT 
	DISTINCT txn_posting_date, account_id, txn_nature, BM.channel
		INTO #TEMPTM
FROM  
	transaction_master TM WITH (NOLOCK)
	LEFT OUTER JOIN batch_master BM WITH (NOLOCK)
		ON TM.batch_code = BM.batch_code AND BM.is_active = 1
WHERE 
	TM.is_active = 1 AND TM.txn_posting_date BETWEEN @MAXLASTDATE and @CBSDATE


INSERT INTO account_last_txn (account_id, active, created_by)
SELECT 
	DISTINCT T.account_id, 1, 0
FROM 
	#TEMPTM T
	LEFT OUTER JOIN account_last_txn L
		ON T.account_id = L.account_id and L.active = 1
WHERE
	L.account_id IS NULL
	
WHILE(@MAXLASTDATE <= @CBSDATE)
BEGIN

PRINT CONVERT(VARCHAR(10),@MAXLASTDATE,121)


UPDATE L
SET 
	txn_date = @MAXLASTDATE,
	last_credit_date = @MAXLASTDATE,
	last_modified_by = -1,
	last_modified_date = GETDATE()
-- SELECT *
FROM 
	account_last_txn L 
	INNER JOIN #TEMPTM T
		ON L.account_id = T.account_id and T.txn_nature = 'C'
		AND T.txn_posting_date = @MAXLASTDATE
WHERE 
	active = 1

UPDATE L
SET 
	txn_date = @MAXLASTDATE,
	last_debit_date = @MAXLASTDATE,
	last_modified_by = -1,
	last_modified_date = GETDATE()
-- SELECT *
FROM 
	account_last_txn L 
	INNER JOIN #TEMPTM T
		ON L.account_id = T.account_id and T.txn_nature = 'D'
		AND T.txn_posting_date = @MAXLASTDATE
WHERE 
	active = 1

UPDATE L
SET 
	txn_date = @MAXLASTDATE,
	last_user_init_date = @MAXLASTDATE,
	last_modified_by = -1,
	last_modified_date = GETDATE()
-- SELECT *
FROM 
	account_last_txn L 
	INNER JOIN #TEMPTM T
		ON L.account_id = T.account_id AND T.channel <> 'S'
		AND T.txn_posting_date = @MAXLASTDATE
WHERE 
	active = 1

UPDATE L
SET 
	txn_date = @MAXLASTDATE,
	last_system_date = @MAXLASTDATE,
	last_modified_by = -1,
	last_modified_date = GETDATE()
-- SELECT *
FROM 
	account_last_txn L 
	INNER JOIN #TEMPTM T
		ON L.account_id = T.account_id AND T.channel = 'S'
		AND T.txn_posting_date = @MAXLASTDATE
WHERE 
	active = 1
SET @MAXLASTDATE = DATEADD(DAY,1,@MAXLASTDATE)

END
END

END

