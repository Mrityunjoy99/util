
CREATE   PROCEDURE [dbo].[sp_Product_Statement]  -- sp_Product_Statement '9999','01-Mar-2019','02-Apr-2019',7001,'ALL','Internal',50,'N/A','-1.0','10','N/A','2'
@PRODUCTCODE VARCHAR(10),
	@FROMDATE DATETIME,
	@TODATE DATETIME,
	@BRCODE INT,
	@TYPE VARCHAR(20),
	@PRODTYPE VARCHAR(20),
	@P_SIZE INT,
	@INSTRNO VARCHAR(20) = 'N/A',
	@FROMAMOUNT DECIMAL(18,2) = -1,
	@TOAMOUNT DECIMAL(18,2) = -1,
	@NARRATION VARCHAR(50) = 'N/A',
	@PAGE INT
as
begin

DECLARE @min int; 
DECLARE @max int;

declare @producttype char(1)
if(@ProdType = 'External')
BEGIN

set @producttype='E'
end
else
begin

set @producttype='I'

end

declare @openingbalance decimal(18,2)

if(@producttype = 'E')
BEGIN
set @openingbalance=(select checker_clear_balance from BSGACCOUNTING.dbo.product_balance WITH(NOLOCK) where is_active=1
and product_id in (select product_id from BSGCORE.dbo.product_master  WITH(NOLOCK) where is_active=1 and product_code=@productCode and branch_code=@brcode)
and txn_date=(select MAX(txn_date) from BSGACCOUNTING.dbo.product_balance  WITH(NOLOCK) where product_id in (select product_id from BSGCORE.dbo.product_master  WITH(NOLOCK) where is_active=1 and product_code=@productCode and branch_code=@brcode)
and txn_date<=@fromdate-1 ))
end
else
begin

set @openingbalance=(select checker_clear_balance from BSGACCOUNTING.dbo.product_balance_internal  WITH(NOLOCK) where is_active=1
and internal_product_id in (select internal_product_id from BSGCORE.dbo.product_master_internal  WITH(NOLOCK) where is_active=1 and product_code=@productCode and branch_code=@brcode)
and txn_date=(select MAX(txn_date) from BSGACCOUNTING.dbo.product_balance_internal WITH(NOLOCK) where internal_product_id in (select internal_product_id from BSGCORE.dbo.product_master_internal  WITH(NOLOCK)
where is_active=1 and product_code=@productCode and branch_code=@brcode)
and txn_date<=@fromdate-1 ))

end


declare @transactions table 
(
	Id bigint identity,txnrefno varchar(20),Dated datetime,description_tran varchar(200),
	Instrno varchar(15),debitamt decimal(18,2),credit decimal(18,2),closingbal decimal(18,2),
	FLG char(5),txntype varchar(20),txnBranch INT,homeBranch INT,balance decimal(18,2)
)

if(@producttype = 'E')
BEGIN

insert into @transactions
SELECT 
	txn_ref_no,txn_value_date,narration,instr_no,DEBIT,
	CREDIT,A,B,txntype ,txn_branch,home_branch,null
FROM
(
/*
select 
	txn_ref_no,txn_value_date,narration,instr_no,case when txn_nature='D' then txn_amount else 0 end DEBIT,
	case when txn_nature='C' then txn_amount else 0 end CREDIT,0 A,null B ,case when txn_type=1 then 'CASH' when txn_type=2
	then 'TRANSFER' when txn_type=3 then 'CLEARING' END as txntype,txn_posting_date,id,txn_branch,home_branch
from 
	BSGDEEPFREEZE.dbo.transaction_master_internal_df WITH(NOLOCK) where is_active=1
	and principal_id in
	(select product_id from BSGCORE.dbo.product_master WITH(NOLOCK) where product_code=@productCode and is_active=1 and branch_code=@brcode)
	and principal_type='EP' 
	and txn_posting_date >= @fromdate and txn_posting_date<=@todate 
UNION ALL */
select 
	txn_ref_no,txn_value_date,narration,instr_no,case when txn_nature='D' then txn_amount else 0 end DEBIT,
	case when txn_nature='C' then txn_amount else 0 end CREDIT,0 A,null B ,case when txn_type=1 then 'CASH' when txn_type=2
	then 'TRANSFER' when txn_type=3 then 'CLEARING' END as txntype,txn_posting_date,id,txn_branch,home_branch
from 
	BSGACCOUNTING.dbo.transaction_master_internal WITH(NOLOCK) where is_active=1
	and principal_id in
	(select product_id from BSGCORE.dbo.product_master WITH(NOLOCK) where product_code=@productCode and is_active=1 and branch_code=@brcode)
	and principal_type='EP' 
	and txn_posting_date >= @fromdate and txn_posting_date<=@todate
) K
ORDER by cast(txn_posting_date as date),id

end
else
BEGIN

if(@type = 'ALL' or @type is null)
BEGIN

insert into @transactions
SELECT 
	txn_ref_no,txn_value_date,narration,instr_no,DEBIT,
	CREDIT,A,B,
	txntype,txn_branch,home_branch,null
FROM(
/*
select 
	txn_ref_no,txn_value_date,narration,instr_no,case when txn_nature='D' then txn_amount else 0 end DEBIT,
	case when txn_nature='C' then txn_amount else 0 end CREDIT,0 A,null B,
	case when txn_type=1 then 'CASH' when txn_type=2
	then 'TRANSFER' when txn_type=3 then 'CLEARING' END as txntype,txn_posting_date,id,txn_branch,home_branch
from 
	BSGDEEPFREEZE.dbo.transaction_master_internal_df WITH(NOLOCK) where is_active=1
	and principal_id in
	(select internal_product_id from BSGCORE.dbo.product_master_internal WITH(NOLOCK) where product_code=@productCode and is_active=1 and branch_code=@brcode)
	and principal_type='IP' 
	and txn_posting_date >= @fromdate and txn_posting_date<=@todate 
UNION ALl*/
select 
	txn_ref_no,txn_value_date,narration,instr_no,case when txn_nature='D' then txn_amount else 0 end DEBIT,
	case when txn_nature='C' then txn_amount else 0 end CREDIT,0 A,null B,
	case when txn_type=1 then 'CASH' when txn_type=2
	then 'TRANSFER' when txn_type=3 then 'CLEARING' END as txntype,txn_posting_date,id,txn_branch,home_branch
from 
	BSGACCOUNTING.dbo.transaction_master_internal WITH(NOLOCK) where is_active=1
and principal_id in
(select internal_product_id from BSGCORE.dbo.product_master_internal WITH(NOLOCK) where product_code=@productCode and is_active=1 and branch_code=@brcode)
and principal_type='IP' 
and txn_posting_date >= @fromdate and txn_posting_date<=@todate 
) K
ORDER by cast(txn_posting_date as date),id

END
ELSE
BEGIN




declare @temptrans table (txnrefno varchar(20),txn_type int,txn_value_date datetime,Parti varchar(max),instr_no varchar(max),DEBIT decimal(18,2),	
CREDIT decimal(18,2),Balance decimal(18,2),Test decimal(18,2),activity_id varchar(max),txntype varchar(max)
,txn_branch INT,home_branch INT)

insert into @temptrans

SELECT 
	txn_ref_no,txn_type,txn_value_date,Parti,instr_no,DEBIT,
	CREDIT,Balance,Test,A,txntype,txn_branch,home_branch
FROM
	(
	select 
		tmi.txn_ref_no,tmi.txn_type,tmi.txn_value_date,tmi.narration Parti,instr_no,case when tmi.txn_nature='D' then tmi.txn_amount else 0 end DEBIT,
		case when tmi.txn_nature='C' then tmi.txn_amount else 0 end CREDIT,0 Balance,null as Test,null A,
		case when txn_type=1 then 'CASH' when txn_type=2
		then 'TRANSFER' when txn_type=3 then 'CLEARING' END as txntype,txn_branch,home_branch
	from 
		BSGACCOUNTING.dbo.transaction_master_internal tmi WITH(NOLOCK) 
	where 
		tmi.is_active=1
		and tmi.principal_id in
		(select internal_product_id from BSGCORE.dbo.product_master_internal WITH(NOLOCK) where product_code=@productCode and is_active=1 and branch_code=@brcode)
		and tmi.principal_type='IP' 
		and tmi.txn_posting_date >= @fromdate and tmi.txn_posting_date<=@todate
	/*UNION ALL
	select 
		tmi.txn_ref_no,tmi.txn_type,tmi.txn_value_date,tmi.narration Parti,instr_no,case when tmi.txn_nature='D' then tmi.txn_amount else 0 end DEBIT,
		case when tmi.txn_nature='C' then tmi.txn_amount else 0 end CREDIT,0 Balance,null as Test,null A,
		case when txn_type=1 then 'CASH' when txn_type=2
		then 'TRANSFER' when txn_type=3 then 'CLEARING' END as txntype,txn_branch,home_branch
	from 
		BSGDEEPFREEZE.dbo.transaction_master_internal_df tmi WITH(NOLOCK) 
	where 
		tmi.is_active=1
		and tmi.principal_id in
		(select internal_product_id from BSGCORE.dbo.product_master_internal WITH(NOLOCK) where product_code=@productCode and is_active=1 and branch_code=@brcode)
		and tmi.principal_type='IP' 
		and tmi.txn_posting_date >= @fromdate and tmi.txn_posting_date<=@todate
		*/
)K
		ORDER by  cast(txn_value_date as date)


update tt
set tt.Parti='OW CLG'
from @temptrans tt
left outer join
BSGACCOUNTING.dbo.clearing_outward_transaction cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
left outer join 
BSGACCOUNTING.dbo.transaction_status TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state<>'OR' and TS.is_active=1
where cotr.is_active=1 
and TS.txn_state<>'OR' and TS.is_active=1

/*
update tt
set tt.Parti='OW CLG'
from @temptrans tt
left outer join
BSGDEEPFREEZE.dbo.clearing_outward_transaction_df cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
left outer join 
BSGDEEPFREEZE.dbo.transaction_status_df TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state<>'OR' and TS.is_active=1
where cotr.is_active=1 
and TS.txn_state<>'OR' and TS.is_active=1
*/

update tt
set tt.Parti='INW RT'
from @temptrans tt
left outer join
BSGACCOUNTING.dbo.clearing_inward_transaction cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
left outer join 
BSGACCOUNTING.dbo.transaction_status TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state in (select status_code from BSGTURINGREPORTS..statusmaster where status_type = 'INWARD'
and Active=1 and status_name  like '%return%') and TS.is_active=1
where cotr.is_active=1 --and tt.DEBIT<>0 and tt.CREDIT=0
and TS.txn_state in (select status_code from BSGTURINGREPORTS..statusmaster where status_type = 'INWARD'
and Active=1 and status_name  like '%return%') and TS.is_active=1

/*
update tt
set tt.Parti='INW RT'
from @temptrans tt
inner join
BSGDEEPFREEZE.dbo.clearing_inward_transaction_df cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
inner join
BSGDEEPFREEZE.dbo.transaction_status_df TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state in (select status_code from statusmaster where status_type = 'INWARD'
and Active=1 and status_name  like '%return%') and TS.is_active=1
where cotr.is_active=1 --and tt.DEBIT<>0 and tt.CREDIT=0
and TS.txn_state in (select status_code from statusmaster where status_type = 'INWARD'
and Active=1 and status_name  like '%return%') and TS.is_active=1
*/

update tt
set tt.Parti='OW RTN'
from @temptrans tt
left outer join
BSGACCOUNTING.dbo.clearing_outward_transaction cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
left outer join 
BSGACCOUNTING.dbo.transaction_status TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state='OR' and TS.is_active=1
where cotr.is_active=1 --and tt.DEBIT=0 and tt.CREDIT<>0
and TS.txn_state='OR' and TS.is_active=1


/*
update tt
set tt.Parti='OW RTN'
from @temptrans tt
iNneR join
BSGDEEPFREEZE.dbo.clearing_outward_transaction_df cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
iNneR join
BSGDEEPFREEZE.dbo.transaction_status_df TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state='OR' and TS.is_active=1
where cotr.is_active=1 --and tt.DEBIT=0 and tt.CREDIT<>0
and TS.txn_state='OR' and TS.is_active=1
*/

update tt
set tt.Parti='INW CLG'
from @temptrans tt
left outer join
BSGACCOUNTING.dbo.clearing_inward_transaction cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
left outer join 
BSGACCOUNTING.dbo.transaction_status TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state not in (select status_code from BSGTURINGREPORTS..statusmaster where status_type = 'INWARD'
and Active=1 and status_name not like '%return%') and TS.is_active=1
where cotr.is_active=1 --and tt.DEBIT=0 and tt.CREDIT<>0
and TS.txn_state not in (select status_code from BSGTURINGREPORTS..statusmaster where status_type = 'INWARD'
and Active=1 and status_name not like '%return%') and TS.is_active=1

/*
update tt
set tt.Parti='INW CLG'
from @temptrans tt
iNneR join
BSGDEEPFREEZE.dbo.clearing_inward_transaction_df cotr
on
tt.txnrefno=cotr.txn_ref_no and cotr.is_active=1
iNneR join
BSGDEEPFREEZE.dbo.transaction_status_df TS
on
cotr.txn_ref_no=TS.txn_ref_no and TS.txn_state not in (select status_code from statusmaster where status_type = 'INWARD'
and Active=1 and status_name not like '%return%') and TS.is_active=1
where cotr.is_active=1 --and tt.DEBIT=0 and tt.CREDIT<>0
and TS.txn_state not in (select status_code from statusmaster where status_type = 'INWARD'
and Active=1 and status_name not like '%return%') and TS.is_active=1
*/


insert into @transactions
select NULL,txn_value_date,Parti,instr_no,DEBIT,CREDIT,0,NULL ,txntype,txn_branch,home_branch,null from @temptrans
where Parti not in ('INW CLG','OW RTN','INW RT','OW CLG') 
order by txn_value_date


insert into @transactions
select NULL,txn_value_date,Parti,null,sum(DEBIT),sum(CREDIT),0,NULL,txntype,txn_branch,home_branch,null from @temptrans
where Parti  in ('INW CLG','OW RTN','INW RT','OW CLG') 
group by txn_value_date,Parti,txntype,txn_branch,home_branch
order by txn_value_date,Parti

end


end

--select ISNULL(@openingbalance,0) as OpeningBal

--select
--	A.*,
--	case when A.closingbal >= 0 then 'CR' when A.closingbal <0 then 'debitamt' end FLG
--from
--(
--select 
--	T.Id,
--	T.txnrefno,
--	CONVERT(VARCHAR(10),T.Dated,103) as Dated,
--	T.description_tran,
--	T.Instrno,
--	T.debitamt,
--	T.credit,
--	(SELECT ISNULL(@openingbalance,0) + ISNULL(SUM(credit),0) - ISNULL(SUM(debitamt),0) FROM @transactions TB WHERE TB.Id <= T.Id) closingbal,
--	T.txntype,
--	txnBranch,
--	homeBranch 
--from 
--	@transactions T
--)A
--order by A.Id

----select 
----	NULL AS Dated,null txnrefno ,'TOTAL' description_tran,null Instrno,SUM(ISNULL(debitamt,0)) debitamt,SUM(ISNULL(credit,0)) credit,
----	null as closingbal,null as FLG,null as txntype ,NULL txnBranch, NULL homeBranch 
----from 
----	@transactions

----SELECT  ISNULL((SELECT ISNULL(@openingbalance,0) + ISNULL(SUM(Credit),0) - ISNULL(SUM(debitamt),0) FROM @transactions TB),0) ClosingBalance

SET @min = (select MIN(Id) from @transactions);
SET @max = (select MAX(Id) from @transactions);

while(@min <= @max)
BEGIN
    update @transactions set Balance = (@openingbalance + Credit)-debitamt where Id = @min;
    set @openingbalance = (select Balance from @transactions where Id = @min);
    set @min = @min + 1;
END;


update @transactions set instrno = null where instrno = '0';

IF(@page <> 0 and @p_size <> 0)
BEGIN

if(@page = 1)
BEGIN
    select  * from  
    (
        select 
		ROW_NUMBER() OVER(order by id) as SRNO,id,CONVERT(VARCHAR(10),Dated,103) TranDate,
		ISNULL(description_tran,'N/A') as Particulars,debitamt as AmtWithdraw,Credit as AmtCredited,Balance,txnRefNo,
		CONVERT(VARCHAR(10),Dated,103) as txn_posting_date,
		txnBranch,homeBranch,ISNULL(Instrno,0) instr_no,ISNULL(instrno,0) as InsrNo 
        from 
            @transactions
		where
			(@instrNo = 'N/A' OR ISNULL(instrno,'000000') = @instrNo)
			AND (@fromAmount = -1 OR Credit >= @fromAmount or debitamt >= @fromAmount)
			AND (@toAmount = -1 OR (Credit <= @toAmount AND Credit <> 0) OR (debitamt <= @toAmount AND debitamt <> 0)) 
			AND (@narration = 'N/A' or ISNULL(description_tran,'N\A') like '%' + @narration + '%')
    )CUR_OUTPUT
    where 
	CUR_OUTPUT.SRNO >= 1 
	and CUR_OUTPUT.SRNO <= @p_size
	
	order by id;
END
ELSE
BEGIN
    select  * from  
    (
        select 
		ROW_NUMBER() OVER(order by id) as SRNO,id,CONVERT(VARCHAR(10),Dated,103) TranDate,
		ISNULL(description_tran,'N/A') as Particulars,debitamt as AmtWithdraw,Credit as AmtCredited,Balance,txnRefNo,
		CONVERT(VARCHAR(10),Dated,103) as txn_posting_date ,
		txnBranch,homeBranch,ISNULL(Instrno,0) instr_no,ISNULL(instrno,0) as InsrNo 
        from 
            @transactions
		where
			(@instrNo = 'N/A' OR ISNULL(instrno,0) = @instrNo)
			AND (@fromAmount = -1 OR Credit >= @fromAmount or debitamt >= @fromAmount)
			AND (@toAmount = -1 OR (Credit <= @toAmount AND Credit <> 0) OR (debitamt <= @toAmount AND debitamt <> 0))
			AND (@narration = 'N/A' or ISNULL(description_tran,'N\A') like '%' + @narration + '%')
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
	@transactions
where
		(@instrNo = 'N/A' OR ISNULL(instrno,0) = @instrNo)
		AND (@fromAmount = -1 OR Credit >= @fromAmount or debitamt >= @fromAmount)
		AND (@toAmount = -1 OR Credit <= @toAmount OR debitamt <= @toAmount)
		AND (@narration = 'N/A' or ISNULL(description_tran,'N\A') like '%' + @narration + '%');

END




end

