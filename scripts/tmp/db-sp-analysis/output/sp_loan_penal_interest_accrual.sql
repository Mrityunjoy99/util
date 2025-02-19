-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE    PROCEDURE [dbo].[sp_loan_penal_interest_accrual] -- [sp_loan_penal_interest_accrual] @toDate='2017-08-16',@modifiedby=null,@successCount=null,@failureCount=null
@toDate date = null,
@modifiedby nvarchar(10) = null
AS
BEGIN
	
	select 
		od.*,case when od.overdue_amount is null then null  when od.penal_int_mode_for_overdue =1 then od.penal_interest_for_overdue else  (penal_interest_for_overdue * od.overdue_amount)/36500 /*CASE WHEN dbo.IsLeapYear(od.intrdate) = 1 THEN 36600 ELSE  36500 END*/ end  pnlAmount into #temp
	from 
		(select ac.*,
				(select 
					overdue_amount /*+ npa_interest_amount + npa_penal_interest_amount + npa_charges_amount*/
				from 
					BSGACCOUNTING.dbo.account_balance_loan 
				where 
					txn_date =( 
								select 
									max(txn_date) 
								from 
									BSGACCOUNTING.dbo.account_balance_loan 
				 				where 
									loan_account_id = ac.loan_account_id 
								and 
									txn_date <= Dateadd(day,sv.number+1,ac.accrual_date )
								and is_active=1 )
				and 
					loan_account_id = ac.loan_account_id
				and 
					is_active=1 ) overdue_amount,
				Dateadd(day,sv.number+1,ac.accrual_date ) intrdate from (select 
			lam.*,
			isnull(lastAccuralDate.accrual_date ,dateadd(day,-1,lab.disbursement_date)) accrual_date
			,lpm.penal_int_mode_for_overdue
			,lpm.penal_interest_for_overdue				
		from  
			BSGLOAN.dbo.loan_account_master lam  
		left outer join 
			(select 
				loan_account_id,
				max(penal_accrual_date) accrual_date  
			from 
				BSGACCOUNTING.dbo.account_loan_last_accrual 
			where 
				is_active=1 
			group by 
				loan_account_id)lastAccuralDate
			on 
				lam.loan_account_id = lastAccuralDate.loan_account_id
			left join 
				BSGLOAN.dbo.loan_account_basic lab
			on 
				lam.loan_account_id = lab.loan_account_id
			and 
				lab.is_active=1
			left join 
				BSGLOAN.dbo.loan_product_master lpm
			on 
				lam.loan_product_id = lpm.loan_product_id
			and 
				lpm.is_active =1
			where lam.is_active=1 and lam.loan_account_status  in (1) and lam.loan_type=1
				)ac
			left outer join 
				master..spt_values sv
			on Dateadd(day,sv.number+1,ac.accrual_date ) <= @toDate
			and type='P')od
			--select * from #temp

			select pnl.*,txnDate.txn_date into #temp1 from  (select loan_account_id,sum(pnlAmount) pnlAmount from #temp  group by loan_account_id) pnl
				left outer join 
				(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_loan abl where is_active = 1 group by loan_account_id) txnDate
			on 
				pnl.loan_account_id = txnDate.loan_account_id




update BSGACCOUNTING.dbo.account_balance_loan
set penal_interest_accrual = penal_interest_accrual+interest
--,last_accrual_date = intrestdate
,last_modified_by = @modifiedby
,last_modified_date = getdate()
from 
(select loan_account_id,txn_date,sum(pnlAmount) interest from #temp1 where pnlAmount > 0.00   group by loan_account_id,txn_date)
 ints
inner join 
	BSGACCOUNTING.dbo.account_balance_loan ab
on 
	ints.loan_account_id = ab.loan_account_id
and 
	ints.txn_date  = ab.txn_date 

 MERGE BSGACCOUNTING.dbo.account_loan_last_accrual  AS target  
    USING (SELECT loan_account_id,@toDate from #temp1 group by loan_account_id having sum(pnlAmount) >= 0.00  ) AS source (loan_account_id, penal_accrual_date)  
    ON (target.loan_account_id = source.loan_account_id)  
    WHEN MATCHED THEN  
        UPDATE SET penal_accrual_date = source.penal_accrual_date ,last_modified_by = @modifiedby,last_modified_date=getdate()
WHEN NOT MATCHED THEN  
    INSERT (loan_account_id, penal_accrual_date,created_by,created_date)  
    VALUES (source.loan_account_id, source.penal_accrual_date,@modifiedby,getdate());
	-- OUTPUT deleted.*, $action, inserted.* INTO #MyTempTable;      
 
 --select * from BSGACCOUNTING.dbo.account_loan_last_accrual 

insert into bsgturing.dbo.turing_task_result(task_id,task_ref_id,task_ref_table,response_code,message,created_date,created_by)	
	select 26,loan_account_id,'account_balance_loan', case when interest >= 0.00 then 1 when interest = 0.00 then 3 when interest is null then 2 else 0 end,
	  case when interest >= 0.00 then 'Success' when interest = 0.00 then 'Day diff or interest calculation may be 0' when interest is null then 'Account balance not found' else 'Failed' end,
	  getdate(),@modifiedby from 
	  (select loan_account_id,txn_date,sum(pnlAmount) interest from #temp1  group by loan_account_id,txn_date)a
	DECLARE @successCount int, @failureCount int;
	select  @successCount =  (select count(1) from (select distinct loan_account_id from #temp1 where pnlAmount > 0.00 or pnlAmount = 0.00)a) 
	, @failureCount = (select count(1) from (select distinct loan_account_id from #temp1 where (pnlAmount is null ))b) 
	drop table #temp
	--drop table #account_balance
	select @successCount successCount ,@failureCount failureCount;
	print @successCount
	print @failureCount
	--select * from BSGLOAN.dbo.loan_product_master
	--select * from BSGLOAN.dbo.loan_account_master
	

	
END



