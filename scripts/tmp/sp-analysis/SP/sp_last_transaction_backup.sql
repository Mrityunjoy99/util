-- =============================================
-- Author:        <Author,,Shubham Bhalerao>
-- Create date: <Create Date,, 04/10/2022>
-- Description:    <Description,, Save Max Transaction Posting Date in account_last_transaction_date>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_last_transaction_backup] --[sp_last_transaction]
    -- Add the parameters for the stored procedure here
AS
BEGIN
    declare @totalCount int = 0;
    IF OBJECT_ID('tempdb..#temp') IS NOT NULL
    drop table #temp;
    
    declare @cbsAppDate date;
    SELECT  @cbsAppDate = app_date  FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1;
	SET @cbsAppDate = DATEADD(DAY,-1,@cbsAppDate)


   CREATE TABLE #temp(
        account_id bigint,
        txn_posting_date date
    )
    
    CREATE UNIQUE INDEX temp_index
    ON #temp (account_id);



    insert into #temp
    SELECT account_id, MAX(txn_posting_date) as txn_posting_date
    FROM transaction_master tm with(nolock)
    WHERE activity_id in (1001,1002,3001,3003,6001,6002,1005,1006)
    AND txn_posting_date = @cbsAppDate
	and is_active=1
    GROUP BY account_id
    



   MERGE BSGACCOUNTING.dbo.account_last_transaction_date  AS target  
    USING (SELECT account_id, txn_posting_date FROM #temp)
    AS source (account_id, txn_posting_date)  
    ON (target.account_id = source.account_id and target.is_active=1)  
    WHEN MATCHED THEN
        UPDATE SET target.last_transaction_date = source.txn_posting_date ,target.last_modified_date = getDate()
    WHEN NOT MATCHED THEN  
    INSERT (account_id, account_no,branch_code,last_transaction_date,created_date,last_modified_date,is_active)  
    VALUES (source.account_id,
    (isnull((SELECT DISTINCT account_no from BSGCORE..customer_accounts WITH(NOLOCK) WHERE account_id = source.account_id and is_active=1),'-1')),
    (isnull((SELECT branch_code FROM BSGCORE..customer_accounts WITH(NOLOCK)  WHERE account_id = source.account_id  and is_active=1), -1)),
    source.txn_posting_date,
    getdate(),
    getdate(),
    1);



   set @totalCount = @@ROWCOUNT;
    Select @totalCount
END
