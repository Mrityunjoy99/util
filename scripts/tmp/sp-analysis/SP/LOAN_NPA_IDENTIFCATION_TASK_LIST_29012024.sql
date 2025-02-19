-- =============================================
-- Author:		<Abhishek,>
-- Create date: <2023-04-29, 2023-04-29>
-- Description:	<Loan Npa Identification task list, Business Logic for loan npa identification task change >
-- =============================================

CREATE PROCEDURE [dbo].[LOAN_NPA_IDENTIFCATION_TASK_LIST] -- LOAN_NPA_IDENTIFCATION_TASK_LIST '2023-10-08',1
(
	@taskDate date,
	@modifyBy int
)
AS 
BEGIN
DECLARE @npaDays int = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'NPA_TRANSACTION_DAYS' and is_active = 1 ),91)
DECLARE @fromDate date =  DATEADD(d,-@npaDays,@taskDate)
--DECLARE @halfyearlyInterestDays int = 365
--DECLARE @yearlyInterestDays int = 730
--DECLARE @quaterlyInterestDays int = 182
CREATE TABLE #temp_npa_mark_account_list
(
	loan_account_id bigint,
	npa_reason varchar(250)
)


CREATE TABLE #temp_asset_classification_details
(
	loan_account_id bigint,
	is_agriculture int,
	npa_period int,
	limit_expiry_date date,
	overdue_amount decimal(18,2),
	overdue_days bigint,
	repayment_mode int,
	prime_security_type_npa int,
	security_overdue_days int,
	interest_frequency int,
	charges_applied decimal(18,2),
	charges_paid decimal(18,2),
	charges_applied_npa_days decimal(18,2),
	charges_paid_npa_days decimal(18,2),

)
INSERT INTO #temp_asset_classification_details
select
	a.*
from
(
select 
	lam.loan_account_id,
	lpm.is_agricultural,
	case when ISNULL(lpm.npa_period,0) < 3 then 3 else ISNULL(lpm.npa_period,0) end  npa_period,
	lab.limit_expiry_date,
	abl.overdue_amount,
	abl.overdue_days_count,
	lpm.repayment_mode,
	case when lpm.prime_security_type in (2,12,13,14) then 1 else 0 end security_npa, -- Deposit,KVP,NSC,LIC
	ISNULL(abl.security_amount_overdue_days,0) security_amount_overdue_days,
	lpm.interest_frequency,
	ISNULL(ABL.charges_applied,0) charges_applied,
	ISNULL(ABL.charges_paid,0) charges_paid,
	ISNULL(abl1.charges_applied,0) charges_applied_npa,
	ISNULL(abl1.charges_paid,0) charges_paid_npa
from
	BSGLOAN..loan_account_master lam with(nolock)
	left join BSGLOAN..loan_account_basic lab with(nolock)
			on lab.loan_account_id = lam.loan_account_id
				and lab.is_active =1 
	left outer join BSGLOAN..loan_product_master lpm with(nolock)
		on lpm.loan_product_id = lam.loan_product_id
			and lpm.is_active = 1
	    left outer join  (
							select 
								loan_account_id,
								MAX(txn_date)txn_date
							from
								BSGACCOUNTING..account_balance_loan abl with(nolock)
							where
								txn_date <= @taskDate
							group by 
								loan_account_id
						) ab
					on ab.loan_account_id = lam.loan_account_id
		 left outer join BSGACCOUNTING..account_balance_loan abl with(nolock)
			on abl.loan_account_id = ab.loan_account_id
				and abl.txn_date = ab.txn_date
		left outer join  (
							select 
								loan_account_id,
								MAX(txn_date)txn_date
							from
								BSGACCOUNTING..account_balance_loan abl with(nolock)
							where
								txn_date <= @fromDate
							group by 
								loan_account_id
						) ab1
					on ab1.loan_account_id = lam.loan_account_id
		 left outer join BSGACCOUNTING..account_balance_loan abl1 with(nolock)
			on abl1.loan_account_id = ab1.loan_account_id
				and abl1.txn_date = ab1.txn_date
where
	lam.is_active = 1
	and lam.loan_account_id not in (select account_id from bsgdeepfreeze..manipur_accounts)
	and lam.loan_account_status <> 2
	and lam.loan_type= 1 -- Loan Account Only
	and lam.asset_classification = 1 -- -Standard 
	and lpm.npa_applicable = 1 -- Only NPA Applicable Product Only
	and abl.checker_clear_balance < 0 -- debit balance account only
)a
/*Agriculture account yes : */
insert into #temp_npa_mark_account_list	
select
	loan_account_id,
	'Account is out of order from last 90 or more days-Agri Loan' npa_reasons
from
(
select 
	*,
	dbo.FullMonthsSeparation(limit_expiry_date,@taskDate) month_passed
from
	#temp_asset_classification_details
where	
	is_agriculture = 1
	and limit_expiry_date <= @taskDate
) a 
where month_passed >= npa_period


/*Check for Term Loan EMI /Bullet payment */
insert into #temp_npa_mark_account_list	
select
	t.loan_account_id,
	'Overdue not serverd from last 90 or more days' npa_reason
from
	#temp_asset_classification_details  t
		left outer join #temp_npa_mark_account_list npa
			on t.loan_account_id = npa.loan_account_id
where
	npa.loan_account_id is null
	and repayment_mode in (1,3) -- EMI, Bullet payment
	and is_agriculture = 0 -- Non- Agri
	and overdue_amount > 0
	and overdue_days >= @npaDays

/*Check for Term Loan Lumpsum Security Check */
insert into #temp_npa_mark_account_list	
select 
	t.loan_account_id,
	'Security Overdue from last 90 or more days' npa_reasons
from
	#temp_asset_classification_details t
		left outer join #temp_npa_mark_account_list npa
			on t.loan_account_id = npa.loan_account_id
where
	npa.loan_account_id is null
	and repayment_mode = 2 -- LUMPSUM
	and is_agriculture= 0
	and security_overdue_days >= @npaDays
	and prime_security_type_npa = 1 -- Deposit,KVP,NSC,LIC


/*Check for Term Loan Lumpsum and on limit expiry(bullet payment) Limit Expiry Check */
insert into #temp_npa_mark_account_list	
select 
	t.loan_account_id,
	'Loan Expire for more than 90 days'
from
	#temp_asset_classification_details t
		left outer join #temp_npa_mark_account_list npa
			on t.loan_account_id = npa.loan_account_id
where
	npa.loan_account_id is null
	and repayment_mode in (2,3) -- LUMPSUM,Bullet payment
	and is_agriculture = 0
	and DATEADD(d,@npaDays,limit_expiry_date) <= @taskDate -- Limit is expire more than 90 days



-- Getting Pending Interest Details -For Lumpsum

select 
	account_id,
	txn_date,
	CASE WHEN ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) < 0 THEN 0 else ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) end Interest
INTO
	#temp_due_interest_details
From
(

select
	id.account_id,
	SUM(CASE WHEN activity_id in (3004,3006,6003,6005) then  id.interest_amount else 0 end) InterestDebit,
	SUM(CASE WHEN activity_id in (3005,3014,6004,6006) then  id.interest_amount else 0 end) InterestReversal,
	MIN(txn_date) txn_date
from
	BSGACCOUNTING..interest_details id with(nolock)
	left outer join BSGLOAN..loan_account_master lam with(nolock)
		on id.account_id = lam.loan_account_id
			and lam.is_active = 1
	inner join #temp_asset_classification_details t
		on id.account_id = t.loan_account_id
			and t.repayment_mode in (2)
			and t.is_agriculture = 0
Where
	lam.loan_account_status <> 2
	and id.txn_date >= @fromDate
	and id.txn_date <= @taskDate
	and id.activity_id in (
							3004,3006,6003,6005, -- Loan Interest Debit Activtity,Loan Penal Debit Activtity,CC Interest Debit Activtity,CC Penal Debit Activtity
							3005,3014,6004,6006  -- Loan Interest Reversal Activtity,Loan Penal Reversal Activtity,CC Interest Reversal Activtity,CC Penal Reversal Activtity
						   )
group by id.account_id
)a

--CREATE TABLE #temp_interest_and_charges_details
--(
--	loan_account_id bigint,
--	interest_pending decimal(18,2),
--	interest_debit decimal(18,2)
--)

/*Interest Not Served for 90 days*/
insert into #temp_npa_mark_account_list	
select 
	loan_account_id,
	'Interest is not serverd from last 90 or more days' npa_reason
from
(

select 
	loan_account_id,
	case when interest_pending < 0 then 0 else interest_pending end interest_pending,
	case when Interest < 0 then 0 else Interest end interest_debit
from
(
select 
	t.loan_account_id,
	ISNULL(abl.interest_applied,0) - ISNULL(abl.interest_paid,0) + ISNULL(abl.penal_interest_applied,0) - ISNULL(abl.penal_interest_paid,0) interest_pending,
	i.Interest 
from
	#temp_asset_classification_details t
		left outer join #temp_npa_mark_account_list npa
			on t.loan_account_id = npa.loan_account_id
		 left outer join  (
							select 
								loan_account_id,
								MAX(txn_date)txn_date
							from
								BSGACCOUNTING..account_balance_loan abl with(nolock)
							where
								txn_date <= @taskDate
							group by 
								loan_account_id
						) ab
					on ab.loan_account_id = t.loan_account_id
		 left outer join BSGACCOUNTING..account_balance_loan abl with(nolock)
			on abl.loan_account_id = ab.loan_account_id
				and abl.txn_date = ab.txn_date
		left outer join #temp_due_interest_details i
			on t.loan_account_id = i.account_id

where
	npa.loan_account_id is null
	and repayment_mode = 2 -- LUMPSUM
	and is_agriculture= 0
	and prime_security_type_npa = 0
)a
)npa
where 
	interest_pending > interest_debit



/*charges Not Served for 90 days*/
insert into #temp_npa_mark_account_list	
select 
	t.loan_account_id,
	'Charges is not serverd from last 90 or more days' npa_reason
from
	#temp_asset_classification_details t
		left outer join #temp_npa_mark_account_list npa
			on t.loan_account_id = npa.loan_account_id
			
where
	npa.loan_account_id is null
	and is_agriculture = 0
	and (charges_applied - charges_paid) > 0
	and (
			charges_applied_npa_days > charges_paid
			and charges_applied >= charges_applied_npa_days
		) -- Charges Pending for more than 90 days




select 
	  *
from
	#temp_npa_mark_account_list
order by 
	loan_account_id

END
