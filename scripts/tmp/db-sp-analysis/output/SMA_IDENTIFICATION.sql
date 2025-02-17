
-- =============================================
-- Author:		Abhishek Vichhi
-- Create date: 2022-03-08
-- Description:	<SMA_IDENTIFICATION, Identify the sma classification and store it,>
-- =============================================

CREATE    PROCEDURE [dbo].[SMA_IDENTIFICATION] -- SMA_IDENTIFICATION '2023-06-27'
(
	@cbsAppDate date
)
AS 
BEGIN

DECLARE @sma0Days int = 30
DECLARE @sma1Days int = 60
DECLARE @sma2Days int = 90



DECLARE @fromDateSM0 date = DATEADD(d,-@sma0Days,@cbsAppDate)
DECLARE @fromDateSM1 date = DATEADD(d,-@sma1Days,@cbsAppDate)
DECLARE @fromDateSM2 date = DATEADD(d,-@sma2Days,@cbsAppDate)
DECLARE @defaultDate date = '1900-01-01'

-- SPLITING LOGIC OF STAFF HOUSING LOAN
DECLARE  @Input NVARCHAR(MAX)  = (select config_value from BSGADMIN..cbs_config where config_key = 'LOAN_ORDER_REVERSAL_PRODUCTS' and is_active = 1),
      @Character CHAR(1) = ','

  
CREATE TABLE #temp_product_details (
		product_code varchar(500)
)

DECLARE @StartIndex INT, @EndIndex INT
 
SET @StartIndex = 1
IF SUBSTRING(@Input, LEN(@Input) - 1, LEN(@Input)) <> @Character
BEGIN
	SET @Input = @Input + @Character
END
 
WHILE CHARINDEX(@Character, @Input) > 0
BEGIN
	SET @EndIndex = CHARINDEX(@Character, @Input)
           
	INSERT INTO #temp_product_details
	SELECT TRIM(SUBSTRING(@Input, @StartIndex, @EndIndex - 1))
           
	SET @Input = SUBSTRING(@Input, @EndIndex + 1, LEN(@Input))
END

-- Getting SMA-0 Details
select 
	account_id,
	txn_date,
	CASE WHEN ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) < 0 THEN 0 else ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) end Interest
INTO
	#temp_sm0_details
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
Where
	lam.loan_account_status <> 2
	and id.txn_date >= @fromDateSM0
	and id.txn_date <= @cbsAppDate
	and id.activity_id in (
							3004,3006,6003,6005, -- Loan Interest Debit Activtity,Loan Penal Debit Activtity,CC Interest Debit Activtity,CC Penal Debit Activtity
							3005,3014,6004,6006  -- Loan Interest Reversal Activtity,Loan Penal Reversal Activtity,CC Interest Reversal Activtity,CC Penal Reversal Activtity
						   )
group by id.account_id
)a

-- Getting SMA-1 Details
select 
	account_id,
	txn_date,
	CASE WHEN ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) < 0 THEN 0 else ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) end Interest
INTO
	#temp_sm1_details
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
Where
	lam.loan_account_status <> 2
	and id.txn_date >= @fromDateSM1
	and id.txn_date <= @cbsAppDate
	and id.activity_id in (
							3004,3006,6003,6005, -- Loan Interest Debit Activtity,Loan Penal Debit Activtity,CC Interest Debit Activtity,CC Penal Debit Activtity
							3005,3014,6004,6006  -- Loan Interest Reversal Activtity,Loan Penal Reversal Activtity,CC Interest Reversal Activtity,CC Penal Reversal Activtity
						   )
group by id.account_id
)a


-- Getting SMA-2 Details
select 
	account_id,
	txn_date,
	CASE WHEN ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) < 0 THEN 0 else ISNULL(InterestDebit,0) - ISNULL(InterestReversal,0) end Interest
INTO
	#temp_sm2_details
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
Where
	lam.loan_account_status <> 2
	and id.txn_date >= @fromDateSM2
	and id.txn_date <= @cbsAppDate
	and id.activity_id in (
							3004,3006,6003,6005, -- Loan Interest Debit Activtity,Loan Penal Debit Activtity,CC Interest Debit Activtity,CC Penal Debit Activtity
							3005,3014,6004,6006  -- Loan Interest Reversal Activtity,Loan Penal Reversal Activtity,CC Interest Reversal Activtity,CC Penal Reversal Activtity
						   )
group by id.account_id
)a

select 
	*,
	--,
	--ISNULL(case when repayment_mode = 1
	--	and cast(installment_start_date as date) <= @cbsAppDate
	--	and overdue_amount > 0
	--then 
	--case when  case when installment_frequency = 8 then (DATEDIFF(d,DATEADD(d,-monthStartFromOverdue,lastInstallmentDueDate),@cbsAppDate) + 1 )
	-- else (DATEDIFF(d,DATEADD(M,-monthStartFromOverdue,lastInstallmentDueDate),@cbsAppDate)) end < 0 then 
	-- 0 else case when installment_frequency = 8 then (DATEDIFF(d,DATEADD(d,-monthStartFromOverdue,lastInstallmentDueDate),@cbsAppDate) +1 )
	-- else (DATEDIFF(d,DATEADD(M,-monthStartFromOverdue,lastInstallmentDueDate),@cbsAppDate)) end end
	--else overdue_days_count end,overdue_days_count) overdue_days_count_for_sma_calulation
	overdue_days_count overdue_days_count_for_sma_calulation
INTO	
	#temp_sma_calculation_details
from
(
select 
	*,
	case when totalInstallmentReceived = 0 then disbursement_date else
	 '1900-01-01' end lastInstallmentDueDate
FROM
(
select 
	*,
case installment_frequency when 8
then DATEADD(D,(case when totalInstallmentReceived > no_of_installment then no_of_installment else totalInstallmentReceived end - 1) * frequencyMultiplier,installment_start_date)
else DATEADD(M,(case when totalInstallmentReceived > no_of_installment then no_of_installment else totalInstallmentReceived end - 1) * frequencyMultiplier,installment_start_date)
end lastInstallmentDueDate1,
case when smaclassificationforInterest > 0 then 
DATEDIFF(d,smaclassificationforDate,@cbsAppDate)
else 0 end overdueDaysForInterestSMA



from
(

select 
	*,
	case installment_frequency 
	when 1 -- MONTHLY
	then totalMonthsPassed 
	when 2 -- QUARTERLY
	then ((totalMonthsPassed + 2)/3)
	when 3 -- HALF-YEARLY
	then ((totalMonthsPassed + 5)/6)
	when 4 -- YEARLY
	then ((totalMonthsPassed + 11)/12)
	when 5 -- BI-Monthly
	then ((totalMonthsPassed + 1)/2)
	when 6 -- Daily
	then  case when (DATEDIFF(d,installment_start_date,@cbsAppDate) + 1) > 0 then (DATEDIFF(d,installment_start_date,@cbsAppDate) + 1) else 0 end 
	else totalMonthsPassed end
	totalInstallmentReceived,
	case 
		installment_frequency 
	when 1 -- MONTHLY
	then (lostInstallment - 1 ) 
	when 2 -- QUARTERLY
	then ((lostInstallment - 1 )  * 3)
	when 3 -- HALF-YEARLY
	then ((lostInstallment - 1 )  * 6)
	when 4 -- YEARLY
	then ((lostInstallment - 1 )  * 12)
	when 5 -- BI-Monthly
	then ((lostInstallment - 1 )  * 2)
	when 6 -- Daily
	then  (lostInstallment - 1 ) 
	else (lostInstallment - 1 )  end monthStartFromOverdue,
	case when asset_classification = 1 and IsStaffHousing <> 1 -- Not staffhousing
				and repayment_mode <> 3 and pendingInterest > 0
	then case when pendingInterest >= sma2Interest and sma2Date<sma1Date and sma2MoratoriumCheck = 1 then 2 -- SMA - 2
			  when pendingInterest >= sma1Interest and sma1Date<sma0Date and sma1MoratoriumCheck = 1 then 1 -- SMA - 1
			  when (pendingInterest >= sma0Interest or pendingInterest < sma1Interest) and sma1Date<=sma0Date and sma0MoratoriumCheck = 1 and loan_type = 1 then 0 -- SMA - 0	
			  else -1 end													
	else -1 end smaclassificationforInterest,
	case when asset_classification = 1 and IsStaffHousing <> 1 -- Not staffhousing
				and repayment_mode <> 3 and pendingInterest > 0
	then case when pendingInterest >= sma2Interest and sma2Date<sma1Date and sma2MoratoriumCheck = 1 then sma2Date -- SMA - 2
			  when pendingInterest >= sma1Interest and sma1Date<sma0Date and sma1MoratoriumCheck = 1 then sma1Date -- SMA - 1
			  when (pendingInterest >= sma0Interest or pendingInterest < sma1Interest) and sma1Date<=sma0Date and sma0MoratoriumCheck = 1 and loan_type = 1 then sma0Date -- SMA - 0	
			  else @defaultDate end													
	else @defaultDate end smaclassificationforDate

from
    (   
	select 
		LAM.loan_account_id,
	--	lam.asset_classification,
		lab.installment_start_date,
		lam.loan_product_code,
		lab.limit_expiry_date,
		lab.moratorium_based_emi,
		lab.moratorium_int_recovery_mode,
		lab.moratoriun_period,
		lab.disbursement_date,
		lpm.repayment_mode,
		lam.loan_type,
		lpm.is_agricultural,
		lpm.prime_security_type,
		lab.installment_frequency,
		lpm.interest_frequency,
		abl.installment_amount,
		abl.overdue_amount,
		abl.overdue_days_count,
		CASE WHEN LPM.interest_rate_type = 1  THEN 
					 LAB.rate_of_interest 

			WHEN LPM.interest_rate_type = 2 THEN	
			(select 
				top 1 rate_of_interest 
			from 
				bsgloan..loan_interest_slab_master with(nolock)
			where 
				is_active=1 
				and effective_date = (select 
										MAX(i.effective_date) 
										from 
										bsgloan..loan_interest_slab_master i  with(nolock)
										where 
										i.effective_date <= @cbsAppDate
										and i.loan_product_id=lpm.loan_product_id 
										) 
				and loan_product_id=lpm.loan_product_id 
				and lab.loan_amount>=from_amount 
				and lab.loan_amount<=to_amount
				AND from_months <= ((lab.loan_tenure_year * 12) + lab.loan_tenure_month + (lab.loan_tunure_days / 30) ) 
				AND to_months >= ((lab.loan_tenure_year * 12) + lab.loan_tenure_month + (lab.loan_tunure_days / 30)  )
			order by 
				effective_date desc, from_months, to_months)  END rate_of_interest,
		lab.offset,
		lam.asset_classification,
		CEILING(
		case when overdue_amount > 0 
			and abl.installment_amount > 0
			then ISNULL(overdue_amount/abl.installment_amount,0)
			else 0 end
		) lostInstallment,
	0
	totalMonthsPassed,
	case installment_frequency 
	when 1 -- MONTHLY
	then 1 
	when 2 -- QUARTERLY
	then 3
	when 3 -- HALF-YEARLY
	then 6
	when 4 -- YEARLY
	then 12
	when 5 -- BI-Monthly
	then 2
	when 6 -- Daily
	then  1
	else 1 end frequencyMultiplier,
	ISNULL(sma0.txn_date,@fromDateSM0) sma0Date,
	ISNULL(sma0.Interest,0) sma0Interest,	
	ISNULL(sma1.txn_date,@fromDateSM1) sma1Date,
	ISNULL(sma1.Interest,0) sma1Interest, 
	ISNULL(sma2.txn_date,@fromDateSM2) sma2Date,
	ISNULL(sma2.Interest,0) sma2Interest,
	ISNULL(abl.interest_applied,0) - ISNULL(abl.interest_paid,0) 
	+ ISNULL(abl.penal_interest_applied,0) - ISNULL(abl.penal_interest_paid,0)  pendingInterest,
	case when lpm.repayment_mode = 1 and moratorium_based_emi = 1 and lab.moratorium_int_recovery_mode = 2 and moratoriun_period > 0 and ISNULL(sma0.txn_date,@fromDateSM0) <= lab.installment_start_date
	then 0
	when cast(date_of_account_opening as date) > @fromDateSM0 then 0
	 else  1 end sma0MoratoriumCheck,
	case when lpm.repayment_mode = 1 and moratorium_based_emi = 1 and lab.moratorium_int_recovery_mode = 2 and moratoriun_period > 0 and ISNULL(sma1.txn_date,@fromDateSM1) <= lab.installment_start_date
	then 0 
	when cast(date_of_account_opening as date) > @fromDateSM1 then 0
	else  1 end sma1MoratoriumCheck,
	case when lpm.repayment_mode = 1 and moratorium_based_emi = 1 and lab.moratorium_int_recovery_mode = 2 and moratoriun_period > 0 and ISNULL(sma2.txn_date,@fromDateSM2) <= lab.installment_start_date
	then 0 
	when cast(date_of_account_opening as date) > @fromDateSM2 then 0
	else  1 end sma2MoratoriumCheck,
	case when staffHousing.product_code is not null then  1 else  0 end IsStaffHousing,
	lab.no_of_installment
	from
		BSGLOAN..loan_account_master LAM WITH(NOLOCK) 
		LEFT JOIN BSGLOAN..loan_product_master LPM  WITH(NOLOCK)
			ON LAM.loan_product_id = LPM.loan_product_id
				and LPM.is_active = 1
		LEFT JOIN BSGLOAN..loan_account_basic LAB WITH(NOLOCK)
			ON LAB.loan_account_id = LAM.loan_account_id
				and LAB.is_active = 1 
		LEFT JOIN (
					select	
						ABL.loan_account_id ,
						MAX(txn_date) txn_date
					FROM
						BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
					Where	
						txn_date <= @cbsAppDate 
					Group by 
						ABL.loan_account_id
					)AB
				ON AB.loan_account_id = LAM.loan_account_id
		LEFT JOIN BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
			ON ABL.loan_account_id = AB.loan_account_id	
				and ABL.txn_date = AB.txn_date
		LEFT OUTER JOIN #temp_sm0_details sma0
			on lam.loan_account_id = sma0.account_id
		LEFT OUTER JOIN #temp_sm1_details sma1
			on lam.loan_account_id = sma1.account_id
		LEFT OUTER JOIN #temp_sm2_details sma2
			on lam.loan_account_id = sma2.account_id	
		LEFT OUTER JOIN #temp_product_details staffHousing
			on 	staffHousing.product_code = cast(lam.loan_product_code as varchar(50))
					--and ABL.is_active = 1
	Where
		LAM.is_active = 1
		and LAM.loan_account_status <> 2
	)totalMonths
)totalRecivedInstallment
)lastInstallmentDueDate
)lastInstallmentDueDate1
	
-- SMA For Repayment Mode EMI -- calculation from chart
update s
set  s.overdue_days_count_for_sma_calulation =
 case when s.overdue_days_count > ABL.interest_overdue_days then s.overdue_days_count else ABL.interest_overdue_days end  ,
smaclassificationforInterest = -1
from
	#temp_sma_calculation_details s
	left outer join BSGLOAN..loan_account_master l  WITH(NOLOCK)
		on l.loan_account_id = s.loan_account_id
			and l.is_active = 1
	LEFT JOIN BSGLOAN..loan_product_master LPM  WITH(NOLOCK)
			ON l.loan_product_id = LPM.loan_product_id
				and LPM.is_active = 1
 LEFT JOIN (
					select	
						ABL.loan_account_id ,
						MAX(txn_date) txn_date
					FROM
						BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
					Where	
						txn_date <= @cbsAppDate 
					Group by 
						ABL.loan_account_id
					)AB
				ON AB.loan_account_id = s.loan_account_id
		LEFT JOIN BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
			ON ABL.loan_account_id = AB.loan_account_id	
				and ABL.txn_date = AB.txn_date
Where
	lpm.repayment_mode = 1
		
INSERT INTO loan_sma_classification_details

select 
	loan_account_id,
	txn_date,
	case when sma_classification < smaclassificationforInterest then smaclassificationforInterest
	else  sma_classification end  sma_classification,
	asset_classification,
	rate_of_interest,
	offset,
	overdue_days_count_for_sma_calulation,
	sma_classification smaclassificationforOverdue,
	smaclassificationforInterest,
	overdueDaysForInterestSMA,
	0,0
from
(

select 
	loan_account_id,
	@cbsAppDate txn_date,
	ISNULL(
		case when 
		asset_classification = 1 -- Standard
		then 
		case when loan_type= 1 and overdue_days_count_for_sma_calulation > 0 and  overdue_days_count_for_sma_calulation <= @sma0Days -- SMA -- 0
		then 0
		when overdue_days_count_for_sma_calulation > @sma0Days  and  overdue_days_count_for_sma_calulation <= @sma1Days -- SMA -- 1
		then 1
		when overdue_days_count_for_sma_calulation > @sma1Days  -- and  overdue_days_count_for_sma_calulation <= 90 -- SMA -- 2
		then 2
		else -1 
		end	
		else -1 end
		,-1) sma_classification,
	asset_classification,
	rate_of_interest,
	offset,
	overdue_days_count_for_sma_calulation,
	smaclassificationforInterest,
	overdueDaysForInterestSMA
from	
	#temp_sma_calculation_details
)A


exec BSGACCOUNTING.dbo.npa_provision_details @cbsAppDate

/*
select 
	ll.branch_code,ll.loan_product_code,ll.loan_account_no,ll.account_name,
	case  t.sma_classification  
	when 0 then 'SMA 0'
	when 1 then 'SMA 1'
	when 2 then 'SMA 2'
	else '' end sma_classification,
	case 
		when t.asset_classification=1 then 'STANDARD'
		when t.asset_classification=3 then 'SUBSTANDARD'
		when t.asset_classification=4 then 'DOUBTFUL-1'
		WHEN t.asset_classification=5 THEN 'DOUBTFUL-2'
		WHEN t.asset_classification=6 THEN 'DOUBTFUL-3'
		WHEN t.asset_classification=7 THEN 'LOSS ASSET' 
	END asset_classification
		
	
from
	#Temp_SMA_IDENTIFICATION t
	left outer join BSGLOAN..loan_account_master ll
		on ll.loan_account_id = t.loan_account_id
			and ll.is_active=  1
order by	
	ll.branch_code,ll.loan_product_code,ll.loan_account_no

*/	
END
