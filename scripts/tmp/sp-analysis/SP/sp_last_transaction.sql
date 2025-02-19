-- =============================================
-- Author:        <Author,,Shubham Bhalerao>
-- Create date: <Create Date,, 04/10/2022>
-- Description:    <Description,, Save Max Transaction Posting Date in account_last_transaction_date>
-- =============================================
CREATE PROCEDURE [dbo].[sp_last_transaction] --[sp_last_transaction]
    -- Add the parameters for the stored procedure here
AS
BEGIN
    declare @totalCount int = 0;
    IF OBJECT_ID('tempdb..#temp') IS NOT NULL
        drop table #temp;
    
    declare @cbsAppDate date;
    SELECT  @cbsAppDate = app_date  FROM BSGACCOUNTING..cbs_application_date WITH(NOLOCK) WHERE is_active = 1;
	SET @cbsAppDate = DATEADD(DAY,-1,@cbsAppDate)



SELECT DISTINCT activity_id,txn_nature,'U' user_type
INTO #activity_master
FROM BSGACCOUNTING..activity_type WITH(NOLOCK) WHERE classification_id IN(1,2,3,4,6)

SELECT  id, account_id, txn_nature, activity_id, txn_amount, txn_posting_date, narration
INTO #transaction_master
FROM BSGACCOUNTING..transaction_master WITH(NOLOCK)

--FROM (SELECT  id, account_id, txn_nature, activity_id, txn_amount, txn_posting_date, narration 
--		FROM BSGACCOUNTING..transaction_master WITH(NOLOCK)
--	UNION ALL
--		SELECT  id, account_id, txn_nature, activity_id, txn_amount, txn_posting_date, narration 
--		FROM BSGDEEPFREEZE..transaction_master_df WITH(NOLOCK)
--		) a
--WHERE
--	txn_posting_date>='2023-06-02'

	
--UPDATE temp_df
--SET activity_id = 11141
--FROM #transaction_master temp_df
--WHERE LEN(activity_id) = 4 
--AND (narration like '%Charges%' OR narration like '%Interest%')



SELECT 
	id,
	account_id,
	CASE WHEN txn_nature='C' AND activity_id IN(SELECT activity_id FROM #activity_master WITH(NOLOCK) WHERE txn_nature='C' and user_type='U')
	AND (narration NOT LIKE 'INT%') THEN txn_amount ELSE 0 END user_init_credit,
	CASE WHEN txn_nature='D' AND activity_id IN(SELECT activity_id FROM #activity_master WITH(NOLOCK) WHERE txn_nature='D' and user_type='U')
	AND (narration NOT LIKE 'INT%') THEN txn_amount ELSE 0 END user_init_debit,
	CASE WHEN txn_nature='C' AND activity_id NOT IN(SELECT activity_id FROM #activity_master WITH(NOLOCK) WHERE txn_nature='C' and user_type='U') THEN txn_amount ELSE 0 END sys_init_credit,
	CASE WHEN txn_nature='D' AND activity_id NOT IN(SELECT activity_id FROM #activity_master WITH(NOLOCK) WHERE txn_nature='D' and user_type='U') THEN txn_amount ELSE 0 END sys_init_debit,
	txn_posting_date 
INTO #transaction_master_temp_df
FROM #transaction_master

;WITH 
all_Accounts AS
(
	SELECT DISTINCT t.account_id,ca.account_no,ca.branch_code from  
	#transaction_master_temp_df t WITH(NOLOCK)
	INNER JOIN BSGCORE..customer_accounts ca WITH(NOLOCK)
	ON t.account_id=ca.account_id
	and ca.is_active=1

)
,user_credit as (
	SELECT * FROM (
	SELECT 
		ROW_NUMBER() OVER(partition by account_id ORDER BY a.id desc) srNo,
		user_init_credit,account_id,txn_posting_date
	FROM 
		#transaction_master_temp_df a WITH(NOLOCK)
	WHERE
		a.user_init_credit<>0
		) a WHERE a.srNo=1
),
user_debit as (
	SELECT * FROM (
	SELECT 
		ROW_NUMBER() OVER(partition by account_id ORDER BY a.id desc) srNo,
		user_init_debit,account_id,txn_posting_date
	FROM 
		#transaction_master_temp_df a WITH(NOLOCK)
	WHERE
		a.user_init_debit<>0
		) a WHERE a.srNo=1
),
sys_credit as (
	SELECT * FROM (
	SELECT 
		ROW_NUMBER() OVER(partition by account_id ORDER BY a.id desc) srNo,
		sys_init_credit,account_id,txn_posting_date
	FROM 
		#transaction_master_temp_df a WITH(NOLOCK)
	WHERE
		a.sys_init_credit<>0
		) a WHERE a.srNo=1
),
sys_debit as (
	SELECT * FROM (
	SELECT 
		ROW_NUMBER() OVER(partition by account_id ORDER BY a.id desc) srNo,
		sys_init_debit,account_id,txn_posting_date
	FROM 
		#transaction_master_temp_df a WITH(NOLOCK)
	WHERE
		a.sys_init_debit<>0
		) a WHERE a.srNo=1
)
SELECT 
	a.account_id
	,uc.user_init_credit,uc.txn_posting_date  user_init_credit_dt
	,ud.user_init_debit,ud.txn_posting_date  user_init_debit_dt
	,sc.sys_init_credit,sc.txn_posting_date sys_init_credit_dt
	,sd.sys_init_debit,sd.txn_posting_date sys_init_debit_dt,
	account_no,branch_code
INTO #last_transactions_df
FROM 
all_Accounts a WITH(NOLOCK)
LEFT OUTER JOIN user_credit uc WITH(NOLOCK)
	ON a.account_id=uc.account_id
LEFT OUTER JOIN user_debit ud WITH(NOLOCK)
	ON a.account_id=ud.account_id
LEFT OUTER JOIN sys_credit sc WITH(NOLOCK)
	ON a.account_id=sc.account_id
LEFT OUTER JOIN sys_debit sd WITH(NOLOCK)
	ON a.account_id=sd.account_id


 
MERGE BSGACCOUNTING.dbo.account_last_transaction_date  AS target  
USING (
	SELECT account_id, user_init_debit_dt, user_init_credit_dt, 
     	sys_init_debit_dt,sys_init_credit_dt,user_init_debit,user_init_credit,account_no,branch_code FROM #last_transactions_df
	)
         AS source (account_id, user_init_debit_dt, user_init_credit_dt,sys_init_debit_dt,sys_init_credit_dt,user_init_debit,user_init_credit,account_no,branch_code)  
         ON (target.account_id = source.account_id and target.is_active=1)  
         WHEN MATCHED THEN
             UPDATE SET 
				target.user_debit_txn_date = ISNULL(source.user_init_debit_dt,target.user_debit_txn_date) ,
     			target.user_credit_txn_date = ISNULL(source.user_init_credit_dt,target.user_credit_txn_date),
     			target.system_debit_txn_date = ISNULL(source.sys_init_debit_dt,target.system_debit_txn_date),
     			target.system_credit_txn_date = ISNULL(source.sys_init_credit_dt,target.system_credit_txn_date),
     			target.user_debit_txn_amount = ISNULL(source.user_init_debit,target.user_debit_txn_amount),
     			target.user_credit_txn_amount = ISNULL(source.user_init_credit,target.user_credit_txn_amount),
     			target.last_modified_date = GETDATE()
         WHEN NOT MATCHED THEN  
         INSERT (account_id, account_no,branch_code,user_debit_txn_date,user_credit_txn_date,system_debit_txn_date,system_credit_txn_date,
     	  user_debit_txn_amount,user_credit_txn_amount,created_by,created_date,last_modified_by,last_modified_date,is_active)  
         VALUES (source.account_id,
         account_no,
		 branch_code,
         source.user_init_debit_dt,source.user_init_credit_dt,source.sys_init_debit_dt, source.sys_init_credit_dt,
     	source.user_init_debit, source.user_init_credit, -11,
         getdate(),
     	-11,
         getdate(),
         1);


   set @totalCount = @@ROWCOUNT;
    Select @totalCount
END
