create    PROCEDURE [dbo].[sp_account_mini_statement_13122022] -- sp_account_mini_statement 679429,1,50
@accountId BIGINT,
@page INT,
@p_size INT
AS
BEGIN

IF(@page = 1)

BEGIN
	
	SELECT
		Main.*
	FROM
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY A.txn_posting_date DESC) AS SRNO,
			A.*
		FROM
		(
		SELECT 
			tm.sprinkle,tm.id,tm.txn_ref_no,tm.txn_sub_ref_no,tm.txn_branch,
			tm.home_branch,tm.txn_date,ISNULL(tm.txn_time,CURRENT_TIMESTAMP) txn_time,tm.txn_value_date,
			tm.txn_posting_date,tm.account_id,tm.batch_code,tm.scroll_no,
			tm.set_no,tm.txn_amount,tm.txn_nature,ISNULL(tm.instr_no,'000000') instr_no,ISNULL(tm.instr_date,CURRENT_TIMESTAMP) instr_date,
			tm.narration,tm.is_active,tm.created_date,tm.activity_id,
			tm.activity_sub_type_id,tm.txn_type        
		FROM 
			bsgaccounting..transaction_master tm WITH(NOLOCK)
		WHERE 
			tm.account_id = @accountId
			and tm.is_active = 1

		UNION ALL

		SELECT 
			tm_df.sprinkle,tm_df.id,tm_df.txn_ref_no,tm_df.txn_sub_ref_no,tm_df.txn_branch,
			tm_df.home_branch,tm_df.txn_date,ISNULL(tm_df.txn_time,CURRENT_TIMESTAMP) txn_time,tm_df.txn_value_date,
			tm_df.txn_posting_date,tm_df.account_id,tm_df.batch_code,tm_df.scroll_no,
			tm_df.set_no,tm_df.txn_amount,tm_df.txn_nature,ISNULL(tm_df.instr_no,'000000') instr_no,ISNULL(tm_df.instr_date,CURRENT_TIMESTAMP) instr_date,
			tm_df.narration,tm_df.is_active,tm_df.created_date,tm_df.activity_id,
			tm_df.activity_sub_type_id,tm_df.txn_type   
		FROM 
			bsgdeepfreeze..transaction_master_df tm_df WITH(NOLOCK)
		WHERE 
			tm_df.account_id = @accountId
			and tm_df.is_active = 1
		)A		
	)Main
	WHERE
		Main.SRNO >= 1 
		AND Main.SRNO <= @p_size
END

ELSE

BEGIN
	
	SELECT
		Main.*
	FROM
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY A.txn_posting_date DESC) AS SRNO,
			A.*
		FROM
		(
		SELECT 
			tm.sprinkle,tm.id,tm.txn_ref_no,tm.txn_sub_ref_no,tm.txn_branch,
			tm.home_branch,tm.txn_date,tm.txn_time,tm.txn_value_date,
			tm.txn_posting_date,tm.account_id,tm.batch_code,tm.scroll_no,
			tm.set_no,tm.txn_amount,tm.txn_nature,tm.instr_no,tm.instr_date,
			tm.narration,tm.is_active,tm.created_date,tm.activity_id,
			tm.activity_sub_type_id,tm.txn_type         
		FROM 
			bsgaccounting..transaction_master tm WITH(NOLOCK)
		WHERE 
			tm.account_id = @accountId
			and tm.is_active = 1

		UNION ALL

		SELECT 
			tm_df.sprinkle,tm_df.id,tm_df.txn_ref_no,tm_df.txn_sub_ref_no,tm_df.txn_branch,
			tm_df.home_branch,tm_df.txn_date,tm_df.txn_time,tm_df.txn_value_date,
			tm_df.txn_posting_date,tm_df.account_id,tm_df.batch_code,tm_df.scroll_no,
			tm_df.set_no,tm_df.txn_amount,tm_df.txn_nature,tm_df.instr_no,tm_df.instr_date,
			tm_df.narration,tm_df.is_active,tm_df.created_date,tm_df.activity_id,
			tm_df.activity_sub_type_id,tm_df.txn_type
		FROM 
			bsgdeepfreeze..transaction_master_df tm_df WITH(NOLOCK)
		WHERE 
			tm_df.account_id = @accountId
			and tm_df.is_active = 1
		)A		
	)Main
	WHERE
		Main.SRNO > ((@page - 1) * @p_size) 
		and Main.SRNO <= (@p_size * @page)
END

END
