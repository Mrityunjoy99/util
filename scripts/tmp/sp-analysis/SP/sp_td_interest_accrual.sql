-- =============================================
-- Author:		<Author,,Name>
-- CREATE OR ALTER date: <23-09-2024>
-- Description:	<Latest edit with changes for interest start date>
-- =============================================
CREATE PROCEDURE [dbo].[sp_td_interest_accrual] -- [sp_td_interest_accrual] @cbsApplicationDate='2022-12-29',@modifiedby=1,@successCount=null,@failureCount=null
@cbsApplicationDate date,
@modifiedby int
AS
BEGIN

update  bsgtd..td_interest_payment set beneficiary_ifsc=UPPER(beneficiary_ifsc) where  beneficiary_ifsc != UPPER(beneficiary_ifsc) COLLATE Latin1_General_CS_AS 

update  bsgtd..td_maturity_payment set beneficiary_ifsc=UPPER(beneficiary_ifsc) where  beneficiary_ifsc != UPPER(beneficiary_ifsc) COLLATE Latin1_General_CS_AS 


	
	select tdacc.*,(available_balance*base_rate/CASE WHEN dbo.IsLeapYear(tdacc.intdate) = 1 THEN 36600.00 ELSE  36500.00 END) inte into #temp  from (select acc.*,	
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
								and (
                                case 
                                    when cast(account_open_date as date) = @cbsApplicationDate then cast(interest_start_date as date)
                                    else txn_date     
                                end ) <= acc.intdate
                                and 
                                	is_active=1)
				and 
					td_account_id = acc.td_account_id and is_active=1) available_balance
	from (select 
		product_id,
		tam.td_account_id,
		interest_start_date,
		maturity_date,
		next_interest_date,
		case when accrual_posting_date < interest_start_date then interest_start_date else  isnull(tdla.accrual_posting_date ,dateadd(day,-1,interest_start_date )) end accrual_date,
		dateadd(day,sv.number+1,isnull(tdla.accrual_posting_date	,dateadd(day,-1,tadd.interest_start_date))) intdate,
		base_rate,
		tadd.deposite_type,
        tam.account_open_date
	from 
		BSGTD..td_account_master tam
	 inner join 
		BSGTD..td_account_deposit_details tadd
	on 
		tam.td_account_id = tadd.td_account_id --AND tadd.deposite_type=3
	and 
		tadd.is_active=1
	left outer join
		BSGACCOUNTING..account_td_last_accrual tdla
	on 
		tam.td_account_id = tdla.td_account_id
	left outer join 
		master..spt_values sv
	on 
		dateadd(day,sv.number+1,isnull(tdla.accrual_posting_date,dateadd(day,-1,tadd.interest_start_date))) <= case 
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

		select pnl.*,txnDate.txn_date into #temp1 from  (select td_account_id,sum(inte) inteAmount,max(interestDate) interestDate,deposite_type from #temp  group by td_account_id,deposite_type) pnl
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
					from #temp  where deposite_type=3
						group by td_account_id) maxd
					on abt.td_account_id = maxd.td_account_id


					update BSGACCOUNTING..account_balance_td
				set interest_accrual = isnull(abt.interest_accrual, 0) + isnull(maxd.inteAmount,0)
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
					from #temp  where deposite_type in (1,2)
						group by td_account_id) maxd
					on abt.td_account_id = maxd.td_account_id
				Left join 
				(select tdi.*
				from 
				BSGACCOUNTING..td_datewise_interest tdi
				inner join
				(select tdi1.td_account_id,max(interest_date)  interest_date
				from BSGACCOUNTING..td_datewise_interest tdi1 
				where  tdi1.is_active=1 group by td_account_id) tdi2
				on 
					tdi.td_account_id=tdi2.td_account_id 
				and
					tdi.interest_date=tdi2.interest_date
				where tdi.is_active=1
				) tdi
					on maxd.td_account_id=tdi.td_account_id
			
	update b set b.interest_accrual=0,last_modified_by=@modifiedby,last_modified_date=getdate()
--select * 
from
(
select * from BSGTD..td_account_master where is_active=1 and account_status_id in (2,5)
)a
inner join
(
select ab.* from 	
		BSGACCOUNTING.dbo.account_balance_td ab with (nolock)
	inner join 
		(select td_account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance_td with (nolock) group by td_account_id) maxDate
	on 
		ab.td_account_id = maxDate.td_account_id
	and 
		ab.txn_date =maxDate.txn_date
) b on a.td_account_id=b.td_account_id
where interest_accrual>0 and checker_clear_balance=0

	INSERT BSGACCOUNTING.dbo.account_td_last_accrual
	 (td_account_id, accrual_date,accrual_posting_date,created_by,created_date,last_modified_by,last_modified_date) 
	 select  source.td_account_id, source.interestDate,source.interestDate,@modifiedby,getdate(),@modifiedby,getdate() from 
	 #temp1 source 
	 Left join 
		(select * from BSGACCOUNTING.dbo.account_td_last_accrual) a
	 on
		source.td_account_id=a.td_account_id
	 where inteAmount > 0 and source.deposite_type=3 and a.td_account_id is null

	 update BSGACCOUNTING.dbo.account_td_last_accrual
	 set accrual_date = source.interestDate,accrual_posting_date =source.interestDate ,last_modified_by = @modifiedby,last_modified_date=getdate()
	 from BSGACCOUNTING.dbo.account_td_last_accrual atla 
	 inner join (SELECT td_account_id,max(interestDate) interestDate,sum(inteAmount) inteAmount,deposite_type  from #temp1 where inteAmount > 0 group by td_account_id,deposite_type )source
	 on atla.td_account_id = source.td_account_id
	 where source.inteAmount > 0 and source.deposite_type=3


	 	INSERT BSGACCOUNTING.dbo.account_td_last_accrual
	 (td_account_id, accrual_date,accrual_posting_date,created_by,created_date,last_modified_by,last_modified_date) 
	 select  source.td_account_id, a.accrual_date,source.interestDate,@modifiedby,getdate(),@modifiedby,getdate() from 
	 #temp1 source 
	 Left join 
		(select * from BSGACCOUNTING.dbo.account_td_last_accrual) a
	 on
		source.td_account_id=a.td_account_id
	 where inteAmount > 0 and source.deposite_type in (1,2) and a.td_account_id is null

	 update BSGACCOUNTING.dbo.account_td_last_accrual
	 set accrual_posting_date =source.interestDate ,last_modified_by = @modifiedby,last_modified_date=getdate()
	 from BSGACCOUNTING.dbo.account_td_last_accrual atla 
	 inner join (SELECT td_account_id,max(interestDate) interestDate,sum(inteAmount) inteAmount,deposite_type  from #temp1 where inteAmount > 0 group by td_account_id,deposite_type )source
	 on atla.td_account_id = source.td_account_id
	 where source.inteAmount > 0 and source.deposite_type in (1,2)

	 


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
