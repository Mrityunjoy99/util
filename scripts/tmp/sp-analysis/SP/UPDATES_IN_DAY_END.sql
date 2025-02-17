CREATE    PROCEDURE [dbo].[UPDATES_IN_DAY_END]
@p_rundate date= null
as
begin

if(@p_rundate is null)
BEGIN
set @p_rundate = (select app_date from BSGACCOUNTING..cbs_application_date where is_active = 1)
END

/*update rate in loan_account_basic for floating product */
UPDATE lab SET lab.rate_of_interest = a.rate_of_interest   
FROM BSGLOAN..loan_account_basic lab   
INNER JOIN   
(SELECT ROW_NUMBER() OVER(PARTITION BY lab.loan_account_id ORDER BY lism.from_months, lism.to_months) AS RowNum,   
lab.loan_account_id, lab.loan_amount, lab.loan_tenure_year, lab.loan_tenure_month, lab.loan_tunure_days, lism.*   
FROM BSGLOAN..loan_account_master lam   
INNER JOIN BSGLOAN..loan_account_basic lab   
ON lab.loan_account_id = lam.loan_account_id AND lab.is_active = 1   
INNER JOIN BSGLOAN..loan_product_master lpm   
ON lpm.loan_product_id = lam.loan_product_id AND lpm.interest_rate_type = 2 AND lpm.is_active = 1   
INNER JOIN BSGLOAN..loan_interest_slab_master lism   
ON lism.loan_product_id = lam.loan_product_id   
AND lism.effective_date = (SELECT MAX(effective_date) FROM BSGLOAN..loan_interest_slab_master WHERE loan_product_id = lam.loan_product_id AND effective_date <= @p_rundate AND is_active = 1)   
AND lism.from_months <= ((lab.loan_tenure_year * 12) + lab.loan_tenure_month + (lab.loan_tunure_days / 30)) --+ (CASE WHEN lab.loan_tunure_days % 30 > 0 THEN 1 ELSE 0 END)   
AND lism.to_months >= ((lab.loan_tenure_year * 12) + lab.loan_tenure_month + (lab.loan_tunure_days / 30)) --+ (CASE WHEN lab.loan_tunure_days % 30 > 0 THEN 1 ELSE 0 END)   
AND lism.from_amount <= lab.loan_amount AND lism.to_amount >= lab.loan_amount   
AND lism.is_active = 1   
WHERE lam.loan_account_status <> 2 AND lam.is_active = 1) a   
ON a.loan_account_id = lab.loan_account_id AND a.RowNum = 1   
WHERE lab.is_active = 1;  
  

/*update checker_balance in maker balance */
update 
ab
set ab.maker_clear_balance = ab.checker_clear_balance,
ab.maker_unclear_balance = ab.checker_unclear_balance
from
(
select 
	c.account_id,
	MAX(txn_date) txn_date
from
	BSGACCOUNTING..account_balance c
group by c.account_id
) a
inner join BSGACCOUNTING..account_balance ab
	on ab.account_id = a.account_id
		and ab.txn_date = a.txn_date

/* Update the fd od rate in loan_account_basic */


   DECLARE @loanOffsetRate  decimal(18,2) = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'LOAN_AGAINST_FD_OFFSET_RATE' and is_active = 1),0)
   DECLARE @ccOffsetRate  decimal(18,2) = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'CC_OD_OFFSET_RATE' and is_active = 1),0)
   DECLARE @thirdPartyRate  decimal(18,2) = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'THIRD_PARTY_FD_OFFSET_RATE' and is_active = 1),0)
	-- INSERT INTO BSGADMIN..cbs_config
	-- select 'LOAN_AGAINST_FD_OFFSET_RATE',1,1,-97,GETDATE(),-97,GETDATE(),-1,0,-1,-1,'A'
	
-- select @loanOffsetRate,@ccOffsetRate,@thirdPartyRate
   Select 
		 l.loan_account_id, 
		 lam.loan_type,
		 security_id, 
		 ISNULL(security_amount,0) security_amount,
		 ISNULL(third_party,0)third_party,
		 lam.loan_account_no
	INTO	
		#temp_security_details
	from
		BSGLOAN..loan_security_type_details l with(nolock)
		inner join BSGLOAN..loan_account_master lam
			on l.loan_account_id = lam.loan_account_id
				and lam.is_active = 1
				and lam.loan_account_status <> 2
		INNER JOIN BSGLOAN..loan_product_master LPM
						ON LAM.loan_product_id = LPM.loan_product_id
							and LPM.is_active = 1
							and LPM.prime_security_type = 2 --  LOAN ACCOUNTS WITH PRIMARY SECUIRTY AS FIX DEPOSIT
	where
		 security_type = 2 -- DEPOSIT
		and security_classification = 1 -- PRIMARY 
		and l.is_active=1


	select 
		t.loan_account_id,
		t.loan_account_no,
		MAX(lbdv.rate_of_interest) 
		 +  case when loan_type = 1 then @loanOffsetRate else @ccOffsetRate end
		 +	case when MAX(t.third_party) = 1 then  @thirdPartyRate else 0 end
		rate_of_interest 
		 
   INTO #temp_details
	from
		BSGLOAN..loan_bank_deposit_view lbdv
			LEFT join #temp_security_details t
				on lbdv.security_id = t.security_id
	where
		lbdv.is_active = 1
	group by t.loan_account_id,
		t.loan_account_no,
		t.loan_type
	

		--select distinct loan_account_id from #temp_security_details
	   update l
	   set l.rate_of_interest = t.rate_of_interest
	   from 
	   #temp_details t
		inner join BSGLOAN..loan_account_basic l
			on t.loan_account_id = l.loan_account_id
				and l.is_active = 1
		where
			l.rate_of_interest <> t.rate_of_interest
/*
-- LOAN_OVERDUE_WITH_NPA_INTEREST
/*update overdue amount in repayment chart */
DECLARE @overdueWithNpa int =	ISNULL((select config_value from BSGADMIN..cbs_config where config_key ='LOAN_OVERDUE_WITH_NPA_INTEREST' and is_active = 1),0)

select 
	lam.loan_account_id,ISNULL(abl.overdue_amount,0)  + 
 case when @overdueWithNpa = 1  then 0 else ISNULL(abl.npa_interest_amount,0) 
	+ ISNULL(abl.npa_penal_interest_amount,0) +  ISNULL(abl.npa_charges_amount ,0) end overdue
INTO 
	#temp_overdue_details
from
BSGLOAN..loan_account_master lam
inner join BSGLOAN..loan_product_master lpm
	on lam.loan_product_id = lpm.loan_product_id
		and lpm.is_active =1
inner join 
(
select  
	loan_account_id,
	MAX(txn_date) txn_date
from
	BSGACCOUNTING..account_balance_loan a

Group by 
	loan_account_id
)a on a.loan_account_id = lam.loan_account_id

 left outer join BSGACCOUNTING..account_balance_loan abl
	on abl.loan_account_id = a.loan_account_id
		and abl.txn_date = a.txn_date
where
	lam.is_active = 1
	and lpm.repayment_mode = 1
	and lam.loan_type  = 1
	and lam.loan_account_status <> 2
	and ISNULL(abl.overdue_amount,0)  + 
	 case when @overdueWithNpa = 1  then 0 else ISNULL(abl.npa_interest_amount,0) 
	+ ISNULL(abl.npa_penal_interest_amount,0) +  ISNULL(abl.npa_charges_amount ,0) end = 0




update lrc
set  lrc.overdue_amount  = 0,
lrc.overdue_days_count = 0
from
	
(
select
    loan_account_id,
    installment_no,
    MAX(id) id
from
    BSGACCOUNTING..loan_repayment_chart with(nolock)
where
	due_date < @p_rundate
group by
    loan_account_id,
   installment_no
)a
inner join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)
    on lrc.loan_account_id = a.loan_account_id
        and lrc.installment_no = a.installment_no
            and lrc.id = a.id
inner join #temp_overdue_details tod
	on tod.loan_account_id = a.loan_account_id
where 
	(lrc.overdue_amount <> 0 or lrc.overdue_days_count <> 0)

*/
end
