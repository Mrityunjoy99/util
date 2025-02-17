-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_interest_accrual_pnr_pl_posting_pre_processing]  -- sp_interest_accrual_pnr_pl_posting_pre_processing @cbsApplicationDate='2023-04-26' ,@modifiedby=1
@cbsApplicationDate datetime,
@modifiedby nvarchar(10)
AS
BEGIN

IF OBJECT_ID('tempdb..#tempCasa') IS NOT NULL DROP TABLE #tempCasa
IF OBJECT_ID('tempdb..#tempTd') IS NOT NULL DROP TABLE #tempTd
IF OBJECT_ID('tempdb..#temploanCcRegularInt') IS NOT NULL DROP TABLE #temploanCcRegularInt
IF OBJECT_ID('tempdb..#temploanCcPenalInt') IS NOT NULL DROP TABLE #temploanCcPenalInt

------- branch code ,product_id null update block-----
update a
set a.branch_code=tam.branch_code,a.product_id=tam.product_id
from 
(
select ab.* from 	
	BSGACCOUNTING.dbo.account_balance_td ab with (nolock)
inner join 
	(select td_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_td  with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by td_account_id) maxDate
on 
	ab.td_account_id = maxDate.td_account_id
and 
	ab.txn_date =maxDate.txn_date
) a 
inner join BSGTD..td_account_master tam on a.td_account_id=tam.td_account_id and tam.is_active=1
and (a.branch_code is null or a.product_id is null)



update a
set a.branch_code=tam.branch_code,a.product_id=tam.product_id
from 
(
select ab.* from 	
	BSGACCOUNTING.dbo.account_balance ab with (nolock)
inner join 
	(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by account_id) maxDate
on 
	ab.account_id = maxDate.account_id
and 
	ab.txn_date =maxDate.txn_date
) a 
inner join BSGCORE..account_master tam on a.account_id=tam.account_id and tam.is_active=1
and (a.branch_code is null or a.product_id is null or a.product_id=0 or a.branch_code=0)


update a
set a.branch_code=tam.branch_code,a.product_id=tam.loan_product_id
from 
(
select ab.* from 	
	BSGACCOUNTING.dbo.account_balance_loan ab with (nolock)
inner join 
	(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_loan with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by loan_account_id) maxDate
on 
	ab.loan_account_id = maxDate.loan_account_id
and 
	ab.txn_date =maxDate.txn_date
) a 
inner join BSGLOAN..loan_account_master tam on a.loan_account_id=tam.loan_account_id and tam.is_active=1
and (a.branch_code is null or a.product_id is null)

--------- end block-----
--------casa block-----
select accountBalance.branch_code,accountBalance.interest_accrual,plAccountId.* into #tempCasa
from
(
select  branch_code,product_id,sum(interest_accrual) interest_accrual

from
	BSGACCOUNTING.dbo.account_balance ab with (nolock)
inner join 
	(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by account_id) maxDate
on 
	ab.account_id = maxDate.account_id
and 
	ab.txn_date =maxDate.txn_date
group by 
	branch_code,product_id
) accountBalance
inner join
	(
	select 
		a.product_id,pl_account_id payable_account_id
	from 
		BSGCORE..product_interest a with (nolock)
	inner join
		(select product_id,max(effective_date) effective_date from BSGCORE..product_interest b with (nolock) 
				where b.is_active=1 group by product_id) maxEffectiveDate
	on
		a.product_id=maxEffectiveDate.product_id
	and
		a.effective_date=maxEffectiveDate.effective_date
	where
		a.is_active=1
	) plAccountId
on
	accountBalance.product_id=plAccountId.product_id


	insert into interest_accrual_pnr_pl_posting
	select 
	casaData.branch_code,
	pnrPLMapping.classification_id,
	casaData.product_id, 
	'IA' source_principal_type,
	pnrPLMapping.pl_account_id,
	'',
	case 
		when casaData.interest_accrual>Isnull(payableBalance.checker_clear_balance,0)
		then 'D' else 'C' 
	end source_txn_nature,
	casaData.interest_accrual source_balance,
	'IA' destination_principal_type,
	pnrPLMapping.pnr_account_id,
	'',
	case 
		when casaData.interest_accrual>Isnull(payableBalance.checker_clear_balance,0)
		then 'C' else 'D'
	end destination_txn_nature,
	Isnull(payableBalance.checker_clear_balance,0) destination_balance,
	case 
		when casaData.interest_accrual>Isnull(payableBalance.checker_clear_balance,0)
		then
			casaData.interest_accrual -Isnull(payableBalance.checker_clear_balance,0)
		else
			Isnull(payableBalance.checker_clear_balance,0) - casaData.interest_accrual
	end txn_amount,
	'Consolidated Int. Posting Date: '+format(@cbsApplicationDate,'dd-MMM-yyyy')
	+ ' BrCd: '+ cast(casaData.branch_code as nvarchar(4))
	+' PrCd: '+ cast(pm.product_code as nvarchar(4)) 
	narration,
		@cbsApplicationDate,
		0,
		1,
		@modifiedby,
		getdate(),
		@modifiedby,
		getdate()

	from #tempCasa casaData
	inner join 
	BSGACCOUNTING..interest_pnr_pl_mapping pnrPLMapping
on 
	casaData.payable_account_id=pnrPLMapping.pnr_account_id
and 
	pnrPLMapping.is_active=1
Left join
(
select  abi.account_id,abi.checker_clear_balance

from
	BSGACCOUNTING.dbo.account_balance_internal abi with (nolock)
inner join 
	(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_internal with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) and is_active=1 group by account_id) maxDate
on 
	abi.account_id = maxDate.account_id
and 
	abi.txn_date =maxDate.txn_date
where
	abi.is_active=1
) payableBalance
on
	pnrPLMapping.pnr_account_id=payableBalance.account_id
inner join BSGCORE..product_master pm 
on casaData.product_id=pm.product_id and pm.is_active=1
where
pm.classification_id=2 and pnrPLMapping.classification_id=2 and
casaData.interest_accrual -Isnull(payableBalance.checker_clear_balance,0)<>0

---------


---------Loan/cc block-----

---- regular int --
select ISNULL(accountBalance.interest_accrual,0) interest_accrual,plAccountId.* 
into #temploanCcRegularInt
from
(
	select 
		a.loan_product_id product_id,interest_income_pl_code payable_account_id,loan_product_code,pm.branch_code
	from 
		BSGLOAN..loan_product_master a
		inner join BSGCORE..product_master pm	
			on a.loan_product_id = pm.product_id
				and pm.is_active = 1
	where
		a.is_active=1
	) plAccountId
	left outer join 
(
select  branch_code,product_id product_id,sum(interest_accrual) interest_accrual

from
	BSGACCOUNTING.dbo.account_balance_loan ab with (nolock)
inner join 
	(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_loan with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by loan_account_id) maxDate
on 
	ab.loan_account_id = maxDate.loan_account_id
and 
	ab.txn_date =maxDate.txn_date
inner join(
select 
	distinct 
	loan_account_id,
	loan_product_id 
from
	BSGLOAN..loan_account_master lam 
where 
	lam.asset_classification=1 
	and lam.is_active=1 
	and lam.loan_account_status<>2
)nonNpa on ab.loan_account_id = nonNpa.loan_account_id
group by 
	branch_code,product_id
) accountBalance
on
	accountBalance.product_id=plAccountId.product_id

--inner join(select distinct loan_product_id from
--BSGLOAN..loan_account_master lam 
--where lam.asset_classification=1 and lam.is_active=1 and lam.loan_account_status=1
--) lam on accountBalance.product_id=lam.loan_product_id


	insert into interest_accrual_pnr_pl_posting
	select 
	loanCcData.branch_code,
	pnrPLMapping.classification_id,
	loanCcData.product_id, 
	'IA' source_principal_type,
	pnrPLMapping.pl_account_id,
	'',
	case 
		when loanCcData.interest_accrual>(-1*Isnull(payableBalance.checker_clear_balance,0))
		then 'C' else 'D' 
	end source_txn_nature,
	loanCcData.interest_accrual source_balance,
	'IA' destination_principal_type,
	pnrPLMapping.pnr_account_id,
	'',
	case 
		when loanCcData.interest_accrual>(-1*Isnull(payableBalance.checker_clear_balance,0))
		then 'D' else 'C'
	end destination_txn_nature,
	Isnull(payableBalance.checker_clear_balance,0) destination_balance,
	case 
		when loanCcData.interest_accrual>(-1*Isnull(payableBalance.checker_clear_balance,0))
		then
			loanCcData.interest_accrual -(-1*Isnull(payableBalance.checker_clear_balance,0))
		else
			(-1*Isnull(payableBalance.checker_clear_balance,0)) - loanCcData.interest_accrual
	end txn_amount,
	'Consolidated Int. Posting Date: '+format(@cbsApplicationDate,'dd-MMM-yyyy')
	+ ' BrCd: '+ cast(loanCcData.branch_code as nvarchar(4))
	+' PrCd: '+ cast(loanCcData.loan_product_code as nvarchar(4)) 
	narration,
		@cbsApplicationDate,
		0,
		1,
		@modifiedby,
		getdate(),
		@modifiedby,
		getdate()

	from #temploanCcRegularInt loanCcData
	inner join 
	BSGACCOUNTING..interest_pnr_pl_mapping pnrPLMapping
on 
	loanCcData.payable_account_id=pnrPLMapping.pnr_account_id
and 
	pnrPLMapping.is_active=1
Left join
(
select  abi.account_id,abi.checker_clear_balance

from
	BSGACCOUNTING.dbo.account_balance_internal abi with (nolock)
inner join 
	(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_internal with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) and is_active=1 group by account_id) maxDate
on 
	abi.account_id = maxDate.account_id
and 
	abi.txn_date =maxDate.txn_date
where
	abi.is_active=1
) payableBalance
on
	pnrPLMapping.pnr_account_id=payableBalance.account_id
where loanCcData.interest_accrual -(-1*Isnull(payableBalance.checker_clear_balance,0))<>0

----

------ penal int --

select ISNULL(accountBalance.interest_accrual,0) interest_accrual,plAccountId.* 
into #temploanCcPenalInt
from
(
	select 
		a.loan_product_id product_id,penal_interest_pl_account_id payable_account_id,loan_product_code,pm.branch_code
	from 
		BSGLOAN..loan_product_master a
		inner join BSGCORE..product_master pm	
			on a.loan_product_id = pm.product_id
				and pm.is_active = 1
	where
		a.is_active=1
	) plAccountId
	left outer join 
(
select  branch_code,product_id product_id,sum(penal_interest_accrual) interest_accrual

from
	BSGACCOUNTING.dbo.account_balance_loan ab with (nolock)
inner join 
	(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_loan with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by loan_account_id) maxDate
on 
	ab.loan_account_id = maxDate.loan_account_id
and 
	ab.txn_date =maxDate.txn_date
inner join(
select 
	distinct 
	loan_account_id,
	loan_product_id 
from
	BSGLOAN..loan_account_master lam 
where 
	lam.asset_classification=1 
	and lam.is_active=1 
	and lam.loan_account_status<>2
)nonNpa on ab.loan_account_id = nonNpa.loan_account_id
group by 
	branch_code,product_id
) accountBalance
on
	accountBalance.product_id=plAccountId.product_id

--inner join(
--select 
--	distinct 
--	loan_account_id,
--	loan_product_id 
--from
--	BSGLOAN..loan_account_master lam 
--where 
--	lam.asset_classification=1 
--	and lam.is_active=1 
--	and lam.loan_account_status<>1
--) lam on accountBalance.product_id=lam.loan_product_id

	insert into interest_accrual_pnr_pl_posting
	select 
	loanCcData.branch_code,
	pnrPLMapping.classification_id,
	loanCcData.product_id, 
	'IA' source_principal_type,
	pnrPLMapping.pl_account_id,
	'',
	case 
		when loanCcData.interest_accrual>(-1*Isnull(payableBalance.checker_clear_balance,0))
		then 'C' else 'D' 
	end source_txn_nature,
	loanCcData.interest_accrual source_balance,
	'IA' destination_principal_type,
	pnrPLMapping.pnr_account_id,
	'',
	case 
		when loanCcData.interest_accrual>(-1*Isnull(payableBalance.checker_clear_balance,0))
		then 'D' else 'C'
	end destination_txn_nature,
	Isnull(payableBalance.checker_clear_balance,0) destination_balance,
	case 
		when loanCcData.interest_accrual>(-1*Isnull(payableBalance.checker_clear_balance,0))
		then
			loanCcData.interest_accrual -(-1*Isnull(payableBalance.checker_clear_balance,0))
		else
			(-1*Isnull(payableBalance.checker_clear_balance,0)) - loanCcData.interest_accrual
	end txn_amount,
	'Consolidated Penal Int. Posting Date: '+format(@cbsApplicationDate,'dd-MMM-yyyy')
	+ ' BrCd: '+ cast(loanCcData.branch_code as nvarchar(4))
	+' PrCd: '+ cast(loanCcData.loan_product_code as nvarchar(4)) 
	narration,
		@cbsApplicationDate,
		0,
		1,
		@modifiedby,
		getdate(),
		@modifiedby,
		getdate()

	from #temploanCcPenalInt loanCcData
	inner join 
	BSGACCOUNTING..interest_pnr_pl_mapping pnrPLMapping
on 
	loanCcData.payable_account_id=pnrPLMapping.pnr_account_id
and 
	pnrPLMapping.is_active=1
Left join
(
select  abi.account_id,abi.checker_clear_balance

from
	BSGACCOUNTING.dbo.account_balance_internal abi with (nolock)
inner join 
	(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_internal with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) and is_active=1 group by account_id) maxDate
on 
	abi.account_id = maxDate.account_id
and 
	abi.txn_date =maxDate.txn_date
where
	abi.is_active=1
) payableBalance
on
	pnrPLMapping.pnr_account_id=payableBalance.account_id
where loanCcData.interest_accrual -(-1*Isnull(payableBalance.checker_clear_balance,0))<>0

---------
------- TD Block -----
select accountBalance.branch_code,accountBalance.interest_accrual,plAccountId.* into #tempTd
from
(
select  branch_code,product_id,sum(interest_accrual) interest_accrual

from
	BSGACCOUNTING.dbo.account_balance_td ab with (nolock)
inner join 
	(select td_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_td with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) group by td_account_id) maxDate
on 
	ab.td_account_id = maxDate.td_account_id
and 
	ab.txn_date =maxDate.txn_date
where
	is_active=1
group by 
	branch_code,product_id
) accountBalance
inner join
	(
	select 
		a.product_id product_id,pl_account_id payable_account_id,product_code
	from 
		BSGTD..td_product_master a
	where
		a.is_active=1
	) plAccountId
on
	accountBalance.product_id=plAccountId.product_id


	insert into interest_accrual_pnr_pl_posting
	select 
	tdData.branch_code,
	pnrPLMapping.classification_id,
	tdData.product_id, 
	'IA' source_principal_type,
	pnrPLMapping.pl_account_id,
	'',
	case 
		when tdData.interest_accrual>Isnull(payableBalance.checker_clear_balance,0)
		then 'D' else 'C' 
	end source_txn_nature,
	tdData.interest_accrual source_balance,
	'IA' destination_principal_type,
	pnrPLMapping.pnr_account_id,
	'',
	case 
		when tdData.interest_accrual>Isnull(payableBalance.checker_clear_balance,0)
		then 'C' else 'D'
	end destination_txn_nature,
	Isnull(payableBalance.checker_clear_balance,0) destination_balance,
	case 
		when tdData.interest_accrual>Isnull(payableBalance.checker_clear_balance,0)
		then
			tdData.interest_accrual -Isnull(payableBalance.checker_clear_balance,0)
		else
			Isnull(payableBalance.checker_clear_balance,0) - tdData.interest_accrual
	end txn_amount,
	'Consolidated Int. Posting Date: '+format(@cbsApplicationDate,'dd-MMM-yyyy')
	+ ' BrCd: '+ cast(tdData.branch_code as nvarchar(4))
	+' PrCd: '+ cast(tdData.product_code as nvarchar(4)) 
	narration,
		@cbsApplicationDate,
		0,
		1,
		@modifiedby,
		getdate(),
		@modifiedby,
		getdate()

	from #tempTd tdData
	inner join 
	BSGACCOUNTING..interest_pnr_pl_mapping pnrPLMapping
on 
	tdData.payable_account_id=pnrPLMapping.pnr_account_id
and 
	pnrPLMapping.is_active=1
Left join
(
select  abi.account_id,abi.checker_clear_balance

from
	BSGACCOUNTING.dbo.account_balance_internal abi with (nolock)
inner join 
	(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_internal with (nolock) where cast(txn_date as date)<=cast(@cbsApplicationDate as date) and is_active=1 group by account_id) maxDate
on 
	abi.account_id = maxDate.account_id
and 
	abi.txn_date =maxDate.txn_date
where
	abi.is_active=1
) payableBalance
on
	pnrPLMapping.pnr_account_id=payableBalance.account_id
where tdData.interest_accrual -Isnull(payableBalance.checker_clear_balance,0)<>0


---------

---------internal product id update block-----

update a
set a.source_principal_product_id=b.internal_product_id
from BSGACCOUNTING..interest_accrual_pnr_pl_posting a 
inner join bsgcore..account_master_internal b on a.source_principal_id=b.internal_account_id
where b.is_active=1


update a
set a.destination_principal_product_id=b.internal_product_id
from BSGACCOUNTING..interest_accrual_pnr_pl_posting a 
inner join bsgcore..account_master_internal b on a.destination_principal_id=b.internal_account_id
where b.is_active=1

---------

--select 1

END
























