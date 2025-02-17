-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_loan_interest_accrual] 
-- [sp_loan_interest_accural] @cbsApplicationDate='2017-08-04' ,@modifiedby=1,@successCount=null,@failureCount=null
@cbsApplicationDate datetime =  null,
@modifiedby nvarchar(10) = null
AS
BEGIN
--return 1;

	select *,case when prime_security_type = 2 and principal_amount  < 0 then 
 -1*dbo.fn_calcInterestForLoanAgainstDeposit(loan_account_id,intDate,principal_amount,offset)
when principal_amount  < 0 then   (principal_amount*(rate_of_interest+offset))/36500 /*CASE WHEN dbo.IsLeapYear(intRate.intDate) = 1 THEN 36600 ELSE  36500 END*/ else 0 end intAcc into #temp
 from (select *,(select --top 1 
            case ab.interest_calculation_on 
                when 1 then abl.checker_clear_balance +(-1) *(npa_interest_amount + npa_penal_interest_amount +
				npa_charges_amount)+(subsidy_received-subsidy_realised)
                when 2 then abl.principal_outstanding + (subsidy_received-subsidy_realised)
                else 0
                end
            from bsgaccounting.dbo.account_balance_loan abl 
            where 
                abl.loan_account_id = ab.loan_account_id 
                and abl.txn_date = (select max(txn_date) from bsgaccounting.dbo.account_balance_loan ablinner 
                                    where txn_date<=ab.intDate and is_active=1
                                    and ablinner.loan_account_id = abl.loan_account_id)
				and is_active=1
        )
        as principal_amount,
        case ab.interest_rate_type
            when 1 then ab.labIntrate -- doubt : or effective_rate_of_interest
            when 2 then ab.produatRateOfInt
            else 0
        end as rate_of_interest from (select * from (select 
	lam.* ,isnull(alla.accrual_date,dateadd(day,-1,lab.disbursement_date))accrual_date,
	lpm.interest_rate_type,lpm.interest_calculation_on,lpm.prime_security_type,
	dateadd(day,sv.number+1,isnull(alla.accrual_date,dateadd(day,-1,lab.disbursement_date))) intDate
	,lab.rate_of_interest labIntrate,
--	lpm.rate_of_interest produatRateOfInt,
	isnull((select 
				top 1 rate_of_interest 
			from 
				bsgloan..loan_interest_slab_master 
			where 
				is_active=1 
				and effective_date = (select 
										MAX(i.effective_date) 
									 from 
										bsgloan..loan_interest_slab_master i  
									 where 
										i.effective_date <= dateadd(day,sv.number+1,isnull(alla.accrual_date,dateadd(day,-1,lab.disbursement_date))) 
										and i.loan_product_id=lpm.loan_product_id 
									 ) 
				and loan_product_id=lpm.loan_product_id 
				and lab.loan_amount>=from_amount 
				and lab.loan_amount<=to_amount
				AND from_months <= ((lab.loan_tenure_year * 12) + lab.loan_tenure_month + (lab.loan_tunure_days / 30)) 
				AND to_months >= ((lab.loan_tenure_year * 12) + lab.loan_tenure_month + (lab.loan_tunure_days / 30))
			order by 
				effective_date desc, from_months, to_months), lab.rate_of_interest) produatRateOfInt,
	lab.offset
from 
	BSGLOAN..loan_account_master lam
left outer join 
	BSGACCOUNTING..account_loan_last_accrual alla
on 
	lam.loan_account_id = alla.loan_account_id
and 
	alla.is_active=1
left outer join
	BSGLOAN..loan_account_basic lab
on 
	lam.loan_account_id = lab.loan_account_id
and 
	lab.is_active=1 
left outer join 
	BSGLOAN.dbo.loan_product_master lpm
on 
	lam.loan_product_id = lpm.loan_product_id
and
	lpm.is_active =1
left outer join 
	master..spt_values sv
 on 
	dateadd(day,sv.number+1,isnull(alla.accrual_date,dateadd(day,-1,lab.disbursement_date))) <= @cbsApplicationDate
 and 
    sv.type = 'P'
where 
	lam.is_active=1 
and 
	lam.loan_account_status=1 
and 
	lam.loan_type=1)a
)ab )intRate

	--select * from #temp where loan_account_id=1130
	select pnl.*,txnDate.txn_date into #temp1 from  (select loan_account_id,sum(intAcc) inteAmount from #temp  group by loan_account_id) pnl
				left outer join 
				(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_loan abl  where is_active = 1 group by loan_account_id) txnDate
			on 
				pnl.loan_account_id = txnDate.loan_account_id

update BSGACCOUNTING.dbo.account_balance_loan
set interest_accrual = ab.interest_accrual+(-1*(inteAmount))
--,last_accrual_date = intrestdate
,last_modified_by = @modifiedby
,last_modified_date = getdate()
from 
(select loan_account_id,txn_date,sum(inteAmount) inteAmount from #temp1   group by loan_account_id,txn_date)
 ints
inner join 
	BSGACCOUNTING.dbo.account_balance_loan ab
on 
	ints.loan_account_id = ab.loan_account_id
and 
	ints.txn_date  = ab.txn_date 

	--select * from #temp1
 MERGE BSGACCOUNTING.dbo.account_loan_last_accrual  AS target  
    USING (SELECT loan_account_id,@cbsApplicationDate from #temp1   ) 
	AS source (loan_account_id, interestDate)  
    ON (target.loan_account_id = source.loan_account_id)  
    WHEN MATCHED THEN  
        UPDATE SET accrual_date = source.interestDate ,last_modified_by = @modifiedby,last_modified_date=getdate()
WHEN NOT MATCHED THEN  
    INSERT (loan_account_id, accrual_date,created_by,created_date,last_modified_by,last_modified_date,is_active)  
    VALUES (source.loan_account_id, source.interestDate,@modifiedby,getdate(),@modifiedby,getdate(),1);
	-- OUTPUT deleted.*, $action, inserted.* INTO #MyTempTable;      
 
 --select * from BSGACCOUNTING.dbo.account_loan_last_accrual 

insert into bsgturing.dbo.turing_task_result(task_id,task_ref_id,task_ref_table,response_code,message,created_date,created_by)	
	select 24,loan_account_id,'account_balance_loan', case when abs(interest) > 0.00 then 1 when interest = 0.00 then 3 when interest is null then 2 else 0 end,
	  case when abs(interest) > 0.00 then 'Success' when interest = 0.00 then 'Day diff or interest calculation may be 0' when interest is null then 'Account balance not found' else 'Failed' end,
	  getdate(),@modifiedby from 
	  (select loan_account_id,txn_date,sum(inteAmount) interest from #temp1  group by loan_account_id,txn_date)a
	DECLARE @successCount int, @failureCount int;
	select  @successCount =  (select count(1) from (select distinct loan_account_id from #temp1 )a) 
	, @failureCount = (select count(1) from (select distinct loan_account_id from #temp1 where (inteAmount > 0.00 or inteAmount is null))b) 
	drop table #temp
	--drop table #account_balance
	select @successCount successCount ,@failureCount failureCount;
	print @successCount
	print @failureCount

	exec BSGACCOUNTING..SMA_IDENTIFICATION @cbsApplicationDate
END
