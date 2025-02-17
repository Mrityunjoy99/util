CREATE   PROCEDURE [dbo].[statement_search]   -- statement_search '00011001005488','2016-08-01','2019-11-09',0,99999999999,'C',2,69
@accountNumber varchar(20), 
@fromDate datetime,
@toDate datetime,
@minAmount decimal(18,2),
@maxAmount decimal(18,2),
@txnNature varchar(2),
@page int ,
@p_size int 

AS
BEGIN

DECLARE @accountId BIGINT;

SET @accountId  = (SELECT account_id FROM bsgcore..customer_accounts WITH(NOLOCK) where account_no = @accountNumber and is_Active = 1);


IF(@page <> 0 AND @p_size <> 0)

BEGIN

	IF(@page = 1)

	BEGIN

		SELECT
			Main.*
		FROM
		(
		SELECT	
			ROW_NUMBER() OVER(ORDER BY A.txn_posting_date DESC) SRNO,
			A.*
		FROM
			(
			SELECT 
				tm.sprinkle,
				tm.id,
				tm.txn_ref_no,
				tm.txn_sub_ref_no,
				tm.txn_branch,
				tm.home_branch,
				tm.txn_date,
				ISNULL(tm.txn_time,CURRENT_TIMESTAMP) txn_time,
				tm.txn_value_date,
				tm.txn_posting_date,
				tm.account_id,
				tm.batch_code,
				tm.scroll_no,
				tm.set_no,
				tm.txn_amount,
				tm.txn_nature,
				ISNULL(tm.instr_no,'000000') instr_no,
				ISNULL(tm.instr_date,CURRENT_TIMESTAMP) instr_date,
				tm.narration,
				tm.is_active,
				tm.created_date,
				tm.activity_id,
				tm.activity_sub_type_id,
				tm.txn_type        
			FROM 
				bsgaccounting..transaction_master tm WITH(NOLOCK)
			WHERE 
				tm.account_id = @accountId
				and tm.txn_posting_date >= cast(@fromDate as date)
				and tm.txn_posting_date <= cast(@toDate as date)
				and tm.txn_amount >= @minAmount
				and tm.txn_amount <= @maxAmount
				and tm.txn_nature = @txnNature
				and tm.is_active = 1

			UNION ALL

			SELECT 
				tm_df.sprinkle,
				tm_df.id,
				tm_df.txn_ref_no,
				tm_df.txn_sub_ref_no,
				tm_df.txn_branch,
				tm_df.home_branch,
				tm_df.txn_date,
				ISNULL(tm_df.txn_time,CURRENT_TIMESTAMP) txn_time,
				tm_df.txn_value_date,
				tm_df.txn_posting_date,
				tm_df.account_id,
				tm_df.batch_code,
				tm_df.scroll_no,
				tm_df.set_no,
				tm_df.txn_amount,
				tm_df.txn_nature,
				ISNULL(tm_df.instr_no,'000000') instr_no,
				ISNULL(tm_df.instr_date,CURRENT_TIMESTAMP) instr_date,
				tm_df.narration,
				tm_df.is_active,
				tm_df.created_date,
				tm_df.activity_id,
				tm_df.activity_sub_type_id,
				tm_df.txn_type 
			FROM 
				bsgdeepfreeze..transaction_master_df tm_df WITH(NOLOCK)
			WHERE 
				tm_df.account_id = @accountId
				and tm_df.txn_posting_date >= cast(@fromDate as date)
				and tm_df.txn_posting_date <= cast(@toDate as date)
				and tm_df.txn_amount >= @minAmount
				and tm_df.txn_amount <= @maxAmount
				and tm_df.txn_nature = @txnNature
				and tm_df.is_active = 1		
			)A	
		)Main
		WHERE
			Main.SRNO >= 1 
			and Main.SRNO <= @p_size;
	END
	ELSE
	BEGIN	
		SELECT
			Main.*
		FROM
		(
		SELECT	
			ROW_NUMBER() OVER(ORDER BY A.txn_posting_date DESC) SRNO,
			A.*
		FROM
		(
		SELECT 
			tm.sprinkle,
			tm.id,
			tm.txn_ref_no,
			tm.txn_sub_ref_no,
			tm.txn_branch,
			tm.home_branch,
			tm.txn_date,
			ISNULL(tm.txn_time,CURRENT_TIMESTAMP) txn_time,
			tm.txn_value_date,
			tm.txn_posting_date,
			tm.account_id,
			tm.batch_code,
			tm.scroll_no,
			tm.set_no,
			tm.txn_amount,
			tm.txn_nature,
			ISNULL(tm.instr_no,'000000') instr_no,
			ISNULL(tm.instr_date,CURRENT_TIMESTAMP) instr_date,
			tm.narration,
			tm.is_active,
			tm.created_date,
			tm.activity_id,
			tm.activity_sub_type_id,
			tm.txn_type        
		FROM 
			bsgaccounting..transaction_master tm WITH(NOLOCK)
		WHERE 
			tm.account_id = @accountId
			and tm.txn_posting_date >= cast(@fromDate as date)
			and tm.txn_posting_date <= cast(@toDate as date)
			and tm.txn_amount >= @minAmount
			and tm.txn_amount <= @maxAmount
			and tm.txn_nature = @txnNature
			and tm.is_active = 1	

		UNION ALL

		SELECT 
			tm_df.sprinkle,
			tm_df.id,
			tm_df.txn_ref_no,
			tm_df.txn_sub_ref_no,
			tm_df.txn_branch,
			tm_df.home_branch,
			tm_df.txn_date,
			ISNULL(tm_df.txn_time,CURRENT_TIMESTAMP) txn_time,
			tm_df.txn_value_date,
			tm_df.txn_posting_date,
			tm_df.account_id,
			tm_df.batch_code,
			tm_df.scroll_no,
			tm_df.set_no,
			tm_df.txn_amount,
			tm_df.txn_nature,
			ISNULL(tm_df.instr_no,'000000') instr_no,
			ISNULL(tm_df.instr_date,CURRENT_TIMESTAMP) instr_date,
			tm_df.narration,
			tm_df.is_active,
			tm_df.created_date,
			tm_df.activity_id,
			tm_df.activity_sub_type_id,
			tm_df.txn_type 
		FROM 
			bsgdeepfreeze..transaction_master_df tm_df WITH(NOLOCK)
		WHERE 
			tm_df.account_id = @accountId
			and tm_df.txn_posting_date >= cast(@fromDate as date)
			and tm_df.txn_posting_date <= cast(@toDate as date)
			and tm_df.txn_amount >= @minAmount
			and tm_df.txn_amount <= @maxAmount
			and tm_df.txn_nature = @txnNature
			and tm_df.is_active = 1	
		)A
		
		)Main
		WHERE
			Main.SRNO > ((@page - 1) * @p_size) 
			and Main.SRNO <= (@p_size * @page);
		
	END
END
ELSE
BEGIN    
	SELECT	
		SUM(A.txn_count) txn_count
	FROM
	(
	SELECT 
		COUNT(1) txn_count       
	FROM 
		bsgaccounting..transaction_master tm WITH(NOLOCK)
	WHERE 
		tm.account_id = @accountId
		and tm.txn_posting_date >= cast(@fromDate as date)
		and tm.txn_posting_date <= cast(@toDate as date)
		and tm.txn_amount >= @minAmount
		and tm.txn_amount <= @maxAmount
		and tm.txn_nature = @txnNature
		and tm.is_active = 1

	UNION ALL

	SELECT 
		COUNT(1) txn_count       
	FROM 
		bsgdeepfreeze..transaction_master_df tm_df WITH(NOLOCK)
	WHERE 
		tm_df.account_id = @accountId
		and tm_df.txn_posting_date >= cast(@fromDate as date)
		and tm_df.txn_posting_date <= cast(@toDate as date)
		and tm_df.txn_amount >= @minAmount
		and tm_df.txn_amount <= @maxAmount
		and tm_df.txn_nature = @txnNature
		and tm_df.is_active = 1		
	)A;
        
END 

END
