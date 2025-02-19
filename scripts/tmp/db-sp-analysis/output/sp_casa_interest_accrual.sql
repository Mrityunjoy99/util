-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_casa_interest_accrual]  -- sp_casa_interest_accrual @cbsApplicationDate='2022-12-01' ,@modifiedby=1,@successCount=null,@failureCount=null
@cbsApplicationDate datetime,
@modifiedby nvarchar(10),
@successCount int OUTPut,
@failureCount int OUTPut

AS
BEGIN

Declare @NRO_TDS_PERCENTAGE decimal(18,2) =(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='NRO_TDS_PERCENTAGE' AND is_active = 1)


SELECT ROW_NUMBER() OVER(Partition by product_id ORDER BY to_amount) rn,* INTO #intRate_rn 
FROM  
			bsgcore.dbo.casa_interest_slab_master ias
		where 				
			ias.effective_date = 
			(
			select max(effective_date) from bsgcore.dbo.casa_interest_slab_master ias1 where ias.product_id=ias1.product_id and is_active=1
			)
		and 
			ias.is_active=1

select * into #temp
from 
(
select *,
	case when is_staff = 1 
	then ((checker_unclear_balance + available_balance) *(intrestrate+isnull(offset_percentage,0)))/36500.00 
	else ((checker_unclear_balance + available_balance) *intrestrate)/36500.00 
	end
	interest,
	case when available_balance is null then 'Account Balance Not Found' else 'Success' end msg
 from 
	(select 
		am.is_staff,
		ca.account_id,
		ca.account_no,						
		(select 
			top 1 ias.rate_of_interest 
		from 
			bsgcore.dbo.casa_interest_slab_master ias
		where 				
			ias.effective_date <= ab.intrestdate 
		and
			ias.product_id=am.product_id
		and
			ab.available_balance between ias.from_amount and ias.to_amount
		and 
			ias.is_active=1 
		order by ias.effective_date desc) intrestrate,
	pom.offset_percentage,
	ab.intrestdate,
	ab.available_balance,
	ab.checker_unclear_balance,
	ab.txn_date,
	isnull(am.NRO_FLAG,0) NRO_FLAG,
	am.product_code,
	am.branch_code,
	am.interest_type,
	am.product_id
from 
	bsgcore.dbo.customer_accounts ca  with (nolock)
inner join 
	bsgcore.dbo.account_master am with (nolock)
on 
	ca.account_id = am.account_id
and 
	am.is_active=1
left outer join 	
	(select lasttxndate.*,
			ab.available_balance,
			case when ab.checker_unclear_balance > 0 then ab.checker_unclear_balance else 0 end checker_unclear_balance
	from 
		(select 
			intdate.account_id,
			intdate.intrestdate,
			max(ab.txn_date) txn_date  
		from 
			(select 
				ab.*,
				dateadd(day,sv.number+1,ab.last_accrual_date) intrestdate,
				sv.number+1 diff 
			from 
				(select 
					account_id,
					max(last_accrual_date) last_accrual_date 
				from 
					BSGACCOUNTING.dbo.account_balance  with (nolock)
				where 
					account_id in (select ca.account_id from BSGCORE..customer_accounts ca with (nolock) inner join BSGCORE..account_master am with (nolock)
					on ca.account_id = am.account_id
					 where ca.is_active=1 and am.is_active = 1
					 and ca.classification_id=2 and am.account_status_id in (1,6,7))	
				group by account_id)ab
left outer join 
	master..spt_values sv
on 	
	dateadd(day,sv.number+1,last_accrual_date) <= @cbsApplicationDate 
and 
	sv.type = 'P') intdate
inner join 
	BSGACCOUNTING.dbo.account_balance ab with (nolock)
on 
	intdate.account_id = ab.account_id
and 
	intdate.intrestdate >= ab.txn_date
group by intdate.account_id,
		intdate.intrestdate) lasttxndate
inner join 
	BSGACCOUNTING.dbo.account_balance ab with (nolock)
on 
	lasttxndate.account_id = ab.account_id
and 
	lasttxndate.txn_date = ab.txn_date) ab
on 
	ca.account_id = ab.account_id
left outer join  
	bsgcore.dbo.product_offset_master pom
on 
	am.product_id = pom.product_id
and 
	pom.is_active = 1
where 
	ca.is_active=1 
and 
	am.account_status_id in (1,6,7)
and 
	ca.classification_id = 2
and ca.account_id not in (select account_id from BSGACCOUNTING..casa_daily_interest_eligible_accounts where is_active = 1)
--and 
--	am.interest_type = 1
--and 
	--ca.account_id = 1014
) final
--union all

--select
--is_staff,
--	account_id,
--	account_no,
--	rate_of_interest intrestrate,
--	offset_percentage,
--	intrestdate,
--	available_balance,
--	checker_unclear_balance,
--	txn_date,
--	isnull(NRO_FLAG,0) NRO_FLAG,
--	product_code,
--	branch_code,
--	interest_type,
--	product_id1,
--	case when is_staff = 1 
--	then (balance *(rate_of_interest+isnull(offset_percentage,0)))/36500.00 
--	else (balance *rate_of_interest)/36500.00 
--	end
--	interest,
--	case when available_balance is null then 'Account Balance Not Found' else 'Success' end msg
--from
--(
--select is_staff,
--	account_id,
--	account_no,
--	b.rate_of_interest,
--	offset_percentage,
--	intrestdate,
--	available_balance,
--	checker_unclear_balance,
--	txn_date,
--	isnull(NRO_FLAG,0) NRO_FLAG,
--	product_code,
--	branch_code,
--	interest_type,
--	final.product_id1,
--	(checker_unclear_balance + available_balance) balance,
--	case when available_balance is null then 'Account Balance Not Found' else 'Success' end msg
-- from 
--	(select 
--		am.is_staff,
--		ca.account_id,
--		ca.account_no,						
--	pom.offset_percentage,
--	ab.intrestdate,
--	ab.available_balance,
--	ab.checker_unclear_balance,
--	ab.txn_date,
--	isnull(am.NRO_FLAG,0) NRO_FLAG,
--	am.product_code,
--	am.branch_code,
--	am.interest_type,
--	am.product_id product_id1
--from 
--	bsgcore.dbo.customer_accounts ca  with (nolock)
--inner join 
--	bsgcore.dbo.account_master am with (nolock)
--on 
--	ca.account_id = am.account_id
--and 
--	am.is_active=1
--left outer join 	
--	(select lasttxndate.*,
--			ab.available_balance,
--			case when ab.checker_unclear_balance > 0 then ab.checker_unclear_balance else 0 end checker_unclear_balance
--	from 
--		(select 
--			intdate.account_id,
--			intdate.intrestdate,
--			max(ab.txn_date) txn_date  
--		from 
--			(select 
--				ab.*,
--				dateadd(day,sv.number+1,ab.last_accrual_date) intrestdate,
--				sv.number+1 diff 
--			from 
--				(select 
--					account_id,
--					max(last_accrual_date) last_accrual_date 
--				from 
--					BSGACCOUNTING.dbo.account_balance  with (nolock)
--				where 
--					account_id in (select ca.account_id from BSGCORE..customer_accounts ca with (nolock) inner join BSGCORE..account_master am with (nolock)
--					on ca.account_id = am.account_id
--					 where ca.is_active=1 and am.is_active = 1
--					 and ca.classification_id=2 and am.account_status_id in (1,6,7))	
--				group by account_id)ab
--left outer join 
--	master..spt_values sv
--on 	
--	dateadd(day,sv.number+1,last_accrual_date) <= @cbsApplicationDate 
--and 
--	sv.type = 'P') intdate
--inner join 
--	BSGACCOUNTING.dbo.account_balance ab with (nolock)
--on 
--	intdate.account_id = ab.account_id
--and 
--	intdate.intrestdate >= ab.txn_date
--group by intdate.account_id,
--		intdate.intrestdate) lasttxndate
--inner join 
--	BSGACCOUNTING.dbo.account_balance ab with (nolock)
--on 
--	lasttxndate.account_id = ab.account_id
--and 
--	lasttxndate.txn_date = ab.txn_date) ab
--on 
--	ca.account_id = ab.account_id
--left outer join  
--	bsgcore.dbo.product_offset_master pom
--on 
--	am.product_id = pom.product_id
--and 
--	pom.is_active = 1
--where 
--	ca.is_active=1 
--and 
--	am.account_status_id in (1,6,7)
--and 
--	ca.classification_id = 2
--and 
--	(am.interest_type = 2 or am.interest_type is null)
--) final
--inner join 
-- #intRate_rn b 
--on 
--	final.product_id1=b.product_id
--and s
--	b.from_amount < (final.checker_unclear_balance+final.available_balance) 
--and 
--	b.to_amount >= (final.checker_unclear_balance+final.available_balance) 
-- ) a

) d

update BSGACCOUNTING.dbo.account_balance
set interest_accrual = interest_accrual+isnull(interest,0)
,last_accrual_date = isnull(intrestdate,@cbsApplicationDate)
,last_modified_by = @modifiedby
,last_modified_date = getdate()
,tds_amount = (case when isnull(NRO_FLAG,0)=1 then cast(((interest_accrual+isnull(interest,0))*@NRO_TDS_PERCENTAGE)/100 as decimal(18,2)) 
else 0
end)
from
BSGACCOUNTING.dbo.account_balance ab
inner join 
(select account_id,max(txn_date) txn_date from BSGACCOUNTING.dbo.account_balance group by account_id) a
on ab.account_id = a.account_id
and ab.txn_date =a .txn_date
inner join 
 (select account_id,sum(interest) interest,max(intrestdate) intrestdate,isnull(NRO_FLAG,0) NRO_FLAG from #temp   group by account_id,isnull(NRO_FLAG,0))
 ints	
on 
	ints.account_id = ab.account_id



	insert into bsgturing.dbo.turing_task_result(task_id,task_ref_id,task_ref_table,response_code,message,created_date,created_by)	
	select 1,account_id,'account_master', case when interest > 0.00 then 1 when interest = 0.00 then 3 when interest is null 
	then 2 else 0 end,
	  case when interest > 0.00 then 'Success' when interest = 0.00 then 'Day diff or interest calculation may be 0' when interest is null then 'Account balance not found' else 'Failed' end,
	  getdate(),@modifiedby from 
	  (select account_id,txn_date,sum(interest) interest,max(intrestdate) intrestdate from #temp  group by account_id,txn_date)a
	
	select  @successCount =  (select count(1) from (select distinct account_id from #temp where interest > 0.00)a) 
	, @failureCount = (select count(1) from (select distinct account_id from #temp where (interest = 0.00 or interest is null))b) 
	drop table #temp
	--drop table #account_balance
	print @successCount
	print @failureCount

DECLARE @maxDate DATETIME=(SELECT MAX(created_date) FROM BSGDEEPFREEZE..transaction_master_current_fy_df)

INSERT INTO BSGDEEPFREEZE..transaction_master_current_fy_df
SELECT
	trm.txn_ref_no, txn_sub_ref_no, txn_branch, home_branch, txn_date, txn_time, txn_type, txn_posting_date, txn_value_date, account_id, batch_code, scroll_no, set_no, txn_amount, txn_nature, instr_no, instr_date, activity_id,activity_sub_type_id, narration, 
	trm.sprinkle, trm.is_active, trm.created_by, trm.created_date, trm.last_modified_by, trm.last_modified_date, fund_ext_date, fund_date

FROM      
	BSGDEEPFREEZE..transaction_master_df trm  WITH(NOLOCK)  
	INNER JOIN BSGTD..td_account_master a
		ON trm.account_id=a.td_account_id
		and a.is_active=1
WHERE	 
		trm.created_date>@maxDate

end



