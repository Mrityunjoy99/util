CREATE   PROCEDURE [dbo].[sp_account_mini_statement] -- sp_account_mini_statement 70071,1,10
@accountId BIGINT,
@page INT,
@p_size INT
AS
BEGIN

declare @classificationId int,@openingBal decimal(18,2),@minTxnDate date;


set @classificationId = (select classification_id from bsgcore..customer_accounts ca with(nolock) where account_id = @accountId and is_active= 1);
	
IF(@page = 1)



BEGIN
    
	drop table if exists #temp
    SELECT
        Main.*
	into #temp
    FROM
    (
        SELECT
            ROW_NUMBER() OVER (ORDER BY A.txn_posting_date DESC,a.txn_time desc) AS SRNO,
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
    



		select @minTxnDate = max(Txn_posting_Date)
		from #temp

	if(@classificationId in (1,2))
	begin
		select @openingBal = checker_clear_balance 
		from BSGACCOUNTING..account_balance ab
		inner join (select max(txn_date) txn_date, account_id from BSGACCOUNTING..account_balance 
			where is_active = 1 and account_id = @accountId and txn_date< @minTxnDate group by account_id ) ab1
		on
			ab.account_id = ab1.account_id
		and
			ab.txn_date = ab1.txn_date
		and
			ab.is_active = 1

	end
	else if (@classificationId in (3,6))
	begin
		select @openingBal = checker_clear_balance 
		from BSGACCOUNTING..account_balance_loan ab
		inner join (select max(txn_date) txn_date, loan_account_id from BSGACCOUNTING..account_balance_loan where is_active = 1 and loan_account_id = @accountId 
			and txn_date< @minTxnDate group by loan_account_id ) ab1
		on
			ab.loan_account_id = ab1.loan_account_id
		and
			ab.txn_date = ab1.txn_date
		and
			ab.is_active = 1
	end
	else if(@classificationId in (4))
	begin
		select @openingBal = checker_clear_balance 
		from BSGACCOUNTING..account_balance_td ab
		inner join (select max(txn_date) txn_date, td_account_id from BSGACCOUNTING..account_balance_td where is_active = 1 and td_account_id = @accountId and txn_date< @minTxnDate 
			group by td_account_id ) ab1
		on
			ab.td_account_id = ab1.td_account_id
		and
			ab.txn_date = ab1.txn_date
		and
			ab.is_active = 1
	end

	--select * 
	--from #temp

	select * 
	from (
	selecT *, ROW_NUMBER() OVER (ORDER BY txn_posting_date DESC,txn_time desc) AS SRNO1
	,(sum(case when txn_nature = 'D' then -1 * txn_amount else txn_amount end)over(order by account_id,txn_posting_date,txn_time)) balance
	from #temp main
	) main
	WHERE
        Main.SRNO1 >= 1
        AND Main.SRNO1 <= @p_size
	

END



ELSE



BEGIN
    drop table if exists #temp1
    SELECT
        Main.*
	into #temp1
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
    
	
	select @minTxnDate = max(Txn_posting_Date)
	from #temp

	if(@classificationId in (1,2))
	begin
		select @openingBal = checker_clear_balance 
		from BSGACCOUNTING..account_balance ab
		inner join (select max(txn_date) txn_date, account_id from BSGACCOUNTING..account_balance 
			where is_active = 1 and account_id = @accountId and txn_date< @minTxnDate group by account_id ) ab1
		on
			ab.account_id = ab1.account_id
		and
			ab.txn_date = ab1.txn_date
		and
			ab.is_active = 1

	end
	else if (@classificationId in (3,6))
	begin
		select @openingBal = checker_clear_balance 
		from BSGACCOUNTING..account_balance_loan ab
		inner join (select max(txn_date) txn_date, loan_account_id from BSGACCOUNTING..account_balance_loan where is_active = 1 and loan_account_id = @accountId 
			and txn_date< @minTxnDate group by loan_account_id ) ab1
		on
			ab.loan_account_id = ab1.loan_account_id
		and
			ab.txn_date = ab1.txn_date
		and
			ab.is_active = 1
	end
	else if(@classificationId in (4))
	begin
		select @openingBal = checker_clear_balance 
		from BSGACCOUNTING..account_balance_td ab
		inner join (select max(txn_date) txn_date, td_account_id from BSGACCOUNTING..account_balance_td where is_active = 1 and td_account_id = @accountId and txn_date< @minTxnDate 
			group by td_account_id ) ab1
		on
			ab.td_account_id = ab1.td_account_id
		and
			ab.txn_date = ab1.txn_date
		and
			ab.is_active = 1
	end

	--select * 
	--from #temp

	select * 
	from (
	selecT *,(sum(case when txn_nature = 'D' then -1 * txn_amount else txn_amount end)over(order by account_id,txn_posting_date,txn_time)) balance
	from #temp main
	) main
	WHERE
        Main.SRNO >= 1
        AND Main.SRNO <= @p_size
END



END
