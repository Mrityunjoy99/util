-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_td_interest_accrual_2020_06-30] -- [sp_td_interest_accrual] @cbsApplicationDate='2017-08-23',@modifiedby=1,@successCount=null,@failureCount=null
@cbsApplicationDate date,
@modifiedby int
AS
BEGIN
	
	select tdacc.*,(available_balance*base_rate/36500.00) inte into #temp  from (select acc.*,	
					case when next_interest_date <= @cbsApplicationDate then next_interest_date 
					when maturity_date = '1900-01-01' then @cbsApplicationDate
					when 
						maturity_date <= @cbsApplicationDate then  maturity_date 
					else @cbsApplicationDate end interestDate ,
			(select 
					top 1 available_balance 
				from 
					BSGACCOUNTING.dbo.account_balance_td 
				where 
					txn_date =( 
								select 
									max(txn_date) 
								from 
									BSGACCOUNTING.dbo.account_balance_td 
								where 
									td_account_id = acc.td_account_id 
								and 
									txn_date <= acc.intdate and is_active=1)
				and 
					td_account_id = acc.td_account_id and is_active=1) available_balance
	from (select 
		product_id,
		tam.td_account_id,
		interest_start_date,
		maturity_date,
		next_interest_date,
		case when accrual_date < interest_start_date then interest_start_date else  isnull(tdla.accrual_date ,dateadd(day,-1,interest_start_date )) end accrual_date,
		dateadd(day,sv.number+1,isnull(tdla.accrual_date,dateadd(day,-1,tadd.interest_start_date))) intdate,
		base_rate
	from 
		BSGTD..td_account_master tam
	 inner join 
		BSGTD..td_account_deposit_details tadd
	on 
		tam.td_account_id = tadd.td_account_id AND tadd.deposite_type=3
	and 
		tadd.is_active=1
	left outer join
		BSGACCOUNTING..account_td_last_accrual tdla
	on 
		tam.td_account_id = tdla.td_account_id
	left outer join 
		master..spt_values sv
	on 
		dateadd(day,sv.number+1,isnull(tdla.accrual_date,dateadd(day,-1,tadd.interest_start_date))) <= case 
					when next_interest_date <= @cbsApplicationDate then next_interest_date 
					when maturity_date = '1900-01-01' then @cbsApplicationDate
					when maturity_date <= @cbsApplicationDate then maturity_date 
					else @cbsApplicationDate end
	and 
		sv.type = 'P'
	where 
		tam.is_active=1 and  account_status_id in (1,3,4)
	--and tam.td_account_id=147841
		)acc	
	)tdacc

		select pnl.*,txnDate.txn_date into #temp1 from  (select td_account_id,sum(inte) inteAmount,max(interestDate) interestDate from #temp  group by td_account_id) pnl
				left outer join 
				(select td_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_td abl  where txn_date <= @cbsApplicationDate group by td_account_id) txnDate
			on 
				pnl.td_account_id = txnDate.td_account_id

				--select * from #temp1 --where td_account_id=147841

				update BSGACCOUNTING..account_balance_td
				set interest_accrual = abt.interest_accrual + maxd.inteAmount					
					,last_modified_by = @modifiedby
					,last_modified_date = getdate()
				from 
					BSGACCOUNTING..account_balance_td abt
					inner join 
					(select td_account_id,
							max(txn_date) txn_date 
					from 
						BSGACCOUNTING..account_balance_td 
					where 
						is_Active=1 
					group by td_account_id ) maxdate
				on abt.td_account_id =maxdate.td_account_id
				and abt.txn_date = maxdate.txn_date 
					inner join
					(select td_account_id,
							sum(inte) inteAmount,
							max(interestDate) interestDate 
					from #temp  
						group by td_account_id) maxd
					on abt.td_account_id = maxd.td_account_id
					 

	INSERT BSGACCOUNTING.dbo.account_td_last_accrual
	 (td_account_id, accrual_date,created_by,created_date,last_modified_by,last_modified_date) 
	 select  source.td_account_id, source.interestDate,@modifiedby,getdate(),@modifiedby,getdate() from 
	 #temp1 source where inteAmount > 0 and 
	 not exists(select * from BSGACCOUNTING.dbo.account_td_last_accrual 
	 where td_account_id = source.td_account_id)

	 update BSGACCOUNTING.dbo.account_td_last_accrual
	 set accrual_date = source.interestDate ,last_modified_by = @modifiedby,last_modified_date=getdate()
	 from BSGACCOUNTING.dbo.account_td_last_accrual atla 
	 inner join (SELECT td_account_id,max(interestDate) interestDate,sum(inteAmount) inteAmount  from #temp1 where inteAmount > 0 group by td_account_id )source
	 on atla.td_account_id = source.td_account_id
	 where source.inteAmount > 0

insert into bsgturing.dbo.turing_task_result(task_id,task_ref_id,task_ref_table,response_code,message,created_date,created_by)	
	select 3,td_account_id,'td_account_deposit_details,account_balance_td', case when interest > 0.00 then 1 when interest = 0.00 then 3 when interest is null then 2 else 0 end,
	  case when interest > 0.00 then 'Success' when interest = 0.00 then 'Day diff or interest calculation is 0' when interest is null then 'Account balance not found' else 'Failed' end,
	  getdate(),@modifiedby from 
	  (select td_account_id,txn_date,sum(inteAmount) interest from #temp1  group by td_account_id,txn_date)a
	
	DECLARE @successCount int, @failureCount int;
	select  @successCount =  (select count(1) from (select distinct td_account_id from #temp1 where inteAmount > 0.00)a) 
	, @failureCount = (select count(1) from (select distinct td_account_id from #temp1 where (inteAmount = 0.00 or inteAmount is null))b) 
	drop table #temp
	--drop table #account_balance
	select @successCount successCount ,@failureCount failureCount;
	print @successCount
	print @failureCount
end
	/*
	[sp_td_interest_accrual] @cbsApplicationDate='2017-08-21',@modifiedby=1,@successCount=null,@failureCount=null
	*/


