CREATE     PROCEDURE [dbo].[sp_Account_Statement_bak20230713]  -- sp_Account_Statement '50210000956175','2023-04-24','2023-07-30',1,10000,'N/A',-1,-1,'N/A'
(
@accountno varchar(20),
@fromdate datetime,
@todate datetime,
@page int = NULL,
@p_size int = NULL,
@instrNo varchar(20) = 'N/A',
@fromAmount decimal(18,2) = -1,
@toAmount decimal(18,2) = -1,
@narration varchar(50) = 'N/A'
)
AS
BEGIN
--return;
DECLARE @classificationid INT;
DECLARE @accid VARCHAR(50);
DECLARE @openingbalance DECIMAL(18,2);
DECLARE @txnMaxDate DATETIME ;
DECLARE @min int; 
DECLARE @max int ;

DECLARE @MaxBalDate DATETIME;
SET @MaxBalDate = (@fromdate - 1);

CREATE TABLE #transactions 
(
	Id int identity,sprinkle varchar(200),EntryDate datetime,TranTime time,
	ValueDate datetime,narration nvarchar(1000),Dr decimal(18,2),Credit decimal(18,2),
	Balance decimal(18,2),txnRefNo varchar(20),txntype varchar(10),
	created_date DATETIME,last_modified_date DATETIME,txn_branch INT, 
	home_branch INT, batch_code INT,scroll_no INT,set_no INT,instr_no varchar(20),
	is_active INT,batchCode INT,instrno varchar(20),txnSubRefNo varchar(20),created_by BIGINT,checkerCode VARCHAR(50),MakerCode VARCHAR(50),txndate datetime
);

select  @classificationid = classification_id, @accid =account_id from bsgcore..customer_accounts with(nolock) where account_no = @accountNo and is_active=1

SET @txnMaxDate = (SELECT MAX(txn_date) FROM bsgaccounting..account_balance  with(nolock)  WHERE account_id = @accid and txn_date <= @MaxBalDate);

IF(@txnMaxDate IS NULL)
BEGIN
    SET @txnMaxDate = @MaxBalDate;
END;

IF(@classificationid IN (1,2))
BEGIN
    IF(@txnMaxDate IS NOT NULL )
    BEGIN
        SET @openingbalance = (SELECT checker_clear_balance from bsgaccounting..account_balance  with(nolock)  where account_id = @accid and is_active=1 and txn_date = @txnMaxDate);
    END
    ELSE
    BEGIN
        set @openingbalance=0;
    END;
END 

ELSE IF (@classificationid IN (3,6))
BEGIN
    if((select  MAX(txn_date) from bsgaccounting..account_balance_loan  with(nolock)  where loan_account_id = @accid and txn_date <= @MaxBalDate) is not null )
    BEGIN
        SET @openingbalance =  (select checker_clear_balance + checker_unclear_balance from bsgaccounting..account_balance_loan  with(nolock)  where loan_account_id = @accid and is_active=1 and txn_date = 
        (select  MAX(txn_date) from bsgaccounting..account_balance_loan  with(nolock)  where loan_account_id = @accid and txn_date <= @MaxBalDate) );
    END 
    ELSE
    BEGIN
        set @openingbalance=0;
    END;
END
ELSE IF (@classificationid in (5))
BEGIN
    IF((select  MAX(txn_date) from bsgaccounting..account_balance_internal where account_id = @accid and txn_date <= @MaxBalDate) is not null )
    BEGIN
        set @openingbalance  =  
        (select checker_clear_balance from bsgaccounting..account_balance_internal  with(nolock)  where account_id = @accid and is_active=1 and txn_date = 
        (select  MAX(txn_date) from bsgaccounting..account_balance_internal  with(nolock)  where account_id = @accid and txn_date <= @MaxBalDate) );
    END
    ELSE
    BEGIN
        set @openingbalance=0;
    END;
END;

ELSE IF (@classificationid = 4)
BEGIN
	declare @deposite_type int = 
	(
	select
		tadd.deposite_type
	from
		BSGTD..td_account_deposit_details tadd WITH(NOLOCK)
	where
		tadd.td_account_id = @accid
		AND tadd.is_active = 1
	)

    if((select MAX(a.txn_date) from BSGACCOUNTING..account_balance_td a WITH(NOLOCK) where a.td_account_id = @accid and a.txn_date <= @fromdate-1) is not null )
    BEGIN
        set @openingbalance  = 
			(
			select 
				case when @deposite_type = 1 then ((isnull(abt.checker_clear_balance,0) + isnull(abt.interest_provided,0)) - isnull(abt.interest_paid,0)) 
				else isnull(abt.checker_clear_balance,0) end
			from 
				BSGACCOUNTING..account_balance_td abt WITH(NOLOCK)
			where 
				abt.td_account_id = @accid 
				and abt.is_active = 1 
				and abt.txn_date = (select MAX(a.txn_date) from BSGACCOUNTING..account_balance_td a WITH(NOLOCK) where a.td_account_id = @accid and a.txn_date <= @fromdate-1) 
			)
    END 
    ELSE
    BEGIN
        set @openingbalance=0;
    END;
END



IF @openingbalance IS NULL BEGIN SET @openingbalance = 0; END;

IF(@classificationid in (1,2,3,4,6))
BEGIN
	INSERT INTO #transactions
	(
		sprinkle,EntryDate ,TranTime ,ValueDate ,narration ,Dr ,Credit ,
		Balance ,txnRefNo ,txntype,created_date,last_modified_date,
		txn_branch,home_branch, batch_code,scroll_no,set_no,
		instr_no,is_active,batchCode,instrno,txnSubRefNo,created_by,txndate
	)
	SELECT
		A.sprinkle,
		A.txn_posting_date,
		A.txn_time,
		A.txn_value_date,
		A.narration,
		A.DEBIT,
		A.CREDIT,
		A.balance,
		A.txn_ref_no,
		A.txn_type,
		A.created_date,
		A.last_modified_date,
		A.txn_branch, 
		A.home_branch, 
		A.batch_code,
		A.scroll_no,
		A.set_no,
		A.instr_no,
		A.is_active,
		A.batchCode,
		A.instrno,
		A.txn_sub_ref_no,created_by,
		a.txn_date
	FROM
	(
	SELECT 
		109642725 + id id,sprinkle,txn_posting_date,txn_time,txn_value_date,narration,case when txn_nature ='D' then txn_amount else 0 end DEBIT,
		case when txn_nature ='C' then txn_amount else 0 end CREDIT,null as balance,txn_ref_no,txn_type,
		created_date,last_modified_date,txn_branch,home_branch,batch_code,scroll_no,set_no,instr_no,is_active,
		batch_code as batchCode,instr_no as instrno,txn_sub_ref_no,created_by,txn_date
	FROM 
		bsgaccounting..transaction_master   with(nolock) 
	WHERE 
		txn_posting_date >= @fromdate
		and txn_posting_date <= @todate
		AND account_id = @accid
		and is_active = 1
	
	UNION ALL
    
	SELECT 
		id,sprinkle,txn_posting_date,txn_time,txn_value_date,narration,case when txn_nature ='D' then txn_amount else 0 end DEBIT,
		case when txn_nature ='C' then txn_amount else 0 end CREDIT,null as balance,txn_ref_no,txn_type,
		created_date,last_modified_date,txn_branch,home_branch,batch_code,scroll_no,set_no,instr_no,is_active,
		batch_code as batchCode,instr_no as instrno,txn_sub_ref_no,created_by,txn_date
	FROM 
		bsgdeepfreeze..transaction_master_df  with(nolock) 
	WHERE 
		txn_posting_date >= @fromdate
		and txn_posting_date <= @todate
		AND account_id = @accid
		and is_active=1
	
	--UNION ALL
    
	--SELECT 
	--	id,sprinkle,txn_posting_date,txn_time,txn_value_date,narration,case when txn_nature ='D' then txn_amount else 0 end DEBIT,
	--	case when txn_nature ='C' then txn_amount else 0 end CREDIT,null as balance,txn_ref_no,txn_type,
	--	created_date,last_modified_date,txn_branch,home_branch,batch_code,scroll_no,set_no,instr_no,is_active,
	--	batch_code as batchCode,instr_no as instrno,txn_sub_ref_no
	--FROM 
	--	bsgdeepfreeze..transaction_master_history
	--WHERE 
	--	txn_posting_date >= @fromdate
	--	and txn_posting_date <= @todate
	--	AND account_id = @accid
	--	and is_active=1
	)A
    ORDER BY txn_posting_date,txn_time,id
		--txn_date,txn_posting_date,txn_time
END

ELSE

BEGIN
	INSERT INTO #transactions
	(
		sprinkle,EntryDate ,TranTime ,ValueDate ,narration ,Dr ,Credit ,
		Balance ,txnRefNo ,txntype,created_date,last_modified_date,
		txn_branch,home_branch, batch_code,scroll_no,set_no,instr_no,is_active,
		batchCode,instrno,txnSubRefNo ,created_by,txndate
	)    
	SELECT
		A.sprinkle,
		A.txn_posting_date,
		A.txn_time,
		A.txn_value_date,
		A.narration,
		A.DEBIT,
		A.CREDIT,
		A.balance,
		A.txn_ref_no,
		A.txn_type,
		A.created_date,
		A.last_modified_date,
		A.txn_branch, 
		A.home_branch, 
		A.batch_code,
		A.scroll_no,
		A.set_no,
		A.instr_no,
		A.is_active,
		A.batchCode,
		A.instrno,
        A.txn_sub_ref_no,
        created_by,
		a.txn_date
	FROM
	(
	SELECT 
		tmi.id,tmi.sprinkle,tmi.txn_posting_date,tmi.txn_time,tmi.txn_value_date,tmi.narration,case when tmi.txn_nature ='D' then tmi.txn_amount else 0 end DEBIT,
		case when tmi.txn_nature ='C' then tmi.txn_amount else 0 end CREDIT,
		null as balance,tmi.txn_ref_no,tmi.txn_type,tmi.created_date,tmi.last_modified_date,
		tmi.txn_branch,tmi.home_branch,tmi.batch_code,tmi.scroll_no,tmi.set_no,tmi.instr_no,tmi.is_active,
		tmi.batch_code as batchCode,tmi.instr_no as instrno,txn_sub_ref_no,created_by,txn_date
	from 
		bsgaccounting..transaction_master_internal tmi  with(nolock) 
	where 
		tmi.principal_id = @accid 
		and tmi.principal_type = 'IA'
		and tmi.txn_posting_date >= @fromdate
		and tmi.txn_posting_date <= @todate
		and tmi.is_active=1
	
	UNION ALL
    
	SELECT 
		tmi_df.id,tmi_df.sprinkle,tmi_df.txn_posting_date,tmi_df.txn_time,tmi_df.txn_value_date,tmi_df.narration,
		case when tmi_df.txn_nature ='D' then tmi_df.txn_amount else 0 end DEBIT,
		case when tmi_df.txn_nature ='C' then tmi_df.txn_amount else 0 end CREDIT,
		null as balance,tmi_df.txn_ref_no,tmi_df.txn_type,tmi_df.created_date,tmi_df.last_modified_date,
		tmi_df.txn_branch,tmi_df.home_branch,tmi_df.batch_code,tmi_df.scroll_no,tmi_df.set_no,tmi_df.instr_no,
		tmi_df.is_active,tmi_df.batch_code as batchCode,tmi_df.instr_no as instrno,txn_sub_ref_no,created_by,txn_date
	from 
		bsgdeepfreeze..transaction_master_internal_df tmi_df  with(nolock) 
	where 
		tmi_df.principal_id = @accid 
		and tmi_df.principal_type = 'IA'
		and tmi_df.txn_posting_date >= @fromdate
		and tmi_df.txn_posting_date <= @todate
		and tmi_df.is_active=1
    )A
    order by 
       a.txn_posting_date, a.id;

END

SET @min = (select MIN(Id) from #transactions);
SET @max = (select MAX(Id) from #transactions);

while(@min <= @max)
BEGIN
    update #transactions set Balance = (@openingbalance + Credit)-Dr where Id = @min;
    set @openingbalance = (select Balance from #transactions where Id = @min);
    set @min = @min + 1;
END;

update #transactions set instrno = null where instrno = '0';

    update t 
SET checkerCode=em.employee_code
FROM
#transactions t
INNER JOIN BSGADMIN..employee_master em  with(nolock) 
ON t.created_by=em.employee_id
and em.is_active=1

IF(@page <> 0 and @p_size <> 0)
BEGIN

if(@page = 1)
BEGIN
    select  * from  
    (
        select 
		ROW_NUMBER() OVER(order by EntryDate,TranTime) as SRNO,id,sprinkle,CONVERT(VARCHAR(10),EntryDate,103) TranDate,CONVERT(VARCHAR(10),ValueDate,103) as ValueDate,
		ISNULL(narration,'N/A') as Particulars,Dr as AmtWithdraw,Credit as AmtCredited,Balance,txnRefNo,
		CONVERT(VARCHAR(10),EntryDate,103) as txn_posting_date,txntype ,ISNULL(TranTime,created_date) TranTime, created_date,last_modified_date,
		txn_branch,home_branch, batch_code,scroll_no,set_no,ISNULL(instr_no,0) instr_no,is_active,
		batchCode,ISNULL(instrno,0) as InsrNo,txnSubRefNo,checkerCode,
		(
            SELECT employee_code FROM (
            SELECT TOP 1 created_by FROM BSGACCOUNTING..transaction_status ts  with(nolock)  WHERE ts.txn_ref_no=t.txnRefNo
            UNION ALL
            SELECT TOP 1 created_by FROM BSGDEEPFREEZE..transaction_status_df ts  with(nolock)  WHERE ts.txn_ref_no=t.txnRefNo ORDER BY id asc
            ) mk 
                INNER JOIN BSGADMIN..employee_master em 
                    ON mk.created_by=em.employee_id
                    and em.is_active=1
        ) MakerCode
        from 
            #transactions t
		where
			(@instrNo = 'N/A' OR ISNULL(instrno,'000000') = @instrNo)
			AND (@fromAmount = -1 OR Credit >= @fromAmount or Dr >= @fromAmount)
			AND (@toAmount = -1 OR (Credit <= @toAmount AND Credit <> 0) OR (Dr <= @toAmount AND Dr <> 0)) 
			AND (@narration = 'N/A' or ISNULL(narration,'N\A') like '%' + @narration + '%')
    )CUR_OUTPUT
    where 
	CUR_OUTPUT.SRNO >= 1 
	and CUR_OUTPUT.SRNO <= @p_size
	order by SRNO
	--txn_posting_date,id;
END
ELSE
BEGIN
    select  * from  
    (
        select 
		ROW_NUMBER() OVER(order by t.EntryDate,TranTime) as SRNO,id,sprinkle,CONVERT(VARCHAR(10),EntryDate,103) TranDate,CONVERT(VARCHAR(10),ValueDate,103) as ValueDate,
		ISNULL(narration,'N/A') as Particulars,Dr as AmtWithdraw,Credit as AmtCredited,Balance,txnRefNo,
		CONVERT(VARCHAR(10),EntryDate,103) as txn_posting_date,txntype ,ISNULL(TranTime,created_date) TranTime, created_date,last_modified_date,
		txn_branch,home_branch, batch_code,scroll_no,set_no,ISNULL(instr_no,0) instr_no,is_active,
		batchCode,ISNULL(instrno,0) as InsrNo,txnSubRefNo,checkerCode,
		(
            SELECT employee_code FROM (
            SELECT TOP 1 created_by FROM BSGACCOUNTING..transaction_status ts  with(nolock)  WHERE ts.txn_date=t.txndate and ts.txn_ref_no=t.txnRefNo
            UNION ALL
            SELECT TOP 1 created_by FROM BSGDEEPFREEZE..transaction_status_df ts  with(nolock)  WHERE ts.txn_date=t.txndate and ts.txn_ref_no=t.txnRefNo ORDER BY id asc
            ) mk 
                INNER JOIN BSGADMIN..employee_master em 
                    ON mk.created_by=em.employee_id
                    and em.is_active=1
        ) MakerCode
        from 
            #transactions t
		where
			(@instrNo = 'N/A' OR ISNULL(instrno,0) = @instrNo)
			AND (@fromAmount = -1 OR Credit >= @fromAmount or Dr >= @fromAmount)
			AND (@toAmount = -1 OR Credit <= @toAmount OR Dr <= @toAmount)
			AND (@narration = 'N/A' or ISNULL(narration,'N\A') like '%' + @narration + '%')
    )CUR_OUTPUT
    where 
        CUR_OUTPUT.SRNO > ((@page-1)*@p_size) 
	  and CUR_OUTPUT.SRNO <= (@p_size * @page)
	  order by CUR_OUTPUT.SRNO
	  ;
END

END

IF(@page = 0 AND @p_size = 0)

BEGIN

SELECT
	COUNT(1) txn_count
FROM
	#transactions
where
		(@instrNo = 'N/A' OR ISNULL(instrno,0) = @instrNo)
		AND (@fromAmount = -1 OR Credit >= @fromAmount or Dr >= @fromAmount)
		AND (@toAmount = -1 OR Credit <= @toAmount OR Dr <= @toAmount)
		AND (@narration = 'N/A' or ISNULL(narration,'N\A') like '%' + @narration + '%');

END


DROP TABLE #transactions


END
