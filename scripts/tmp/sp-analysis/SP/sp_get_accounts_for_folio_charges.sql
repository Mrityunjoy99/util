

-- =============================================
-- Author:		<Author,,gourav>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_get_accounts_for_folio_charges] -- [sp_get_accounts_for_folio_charges] '2019-01-01','2019-03-31',9,9
@fromdate datetime,
@todate datetime,
@cgst decimal(18,2),
@sgst decimal(18,2)
AS
BEGIN
	
declare @cgstproduct nvarchar(10)
declare @sgstproduct nvarchar(10)	
select @cgstproduct = config_value from BSGADMIN..cbs_config  where config_key='CGST_PRODUCT' and is_active=1
	select @sgstproduct = config_value from BSGADMIN..cbs_config  where config_key='SGST_PRODUCT' and is_active=1

	 select 
		a.account_id,
		a.classification_id,
		a.customer_id,
		ceiling(count(1)  / 30.00) cnt,
		case when ceiling(count(1)  / 30.00)  = 0 then  75  - (ISNULL(a.percentage,0)* 75)/100
	else ceiling(count(1)  / 30.00)  * 90 - (ISNULL(a.percentage,0) * ceiling(count(1)  / 30.00)  * 90 )/100  end charges_amount 
		into #tempaccountids
	from 
	(select 
			ca.account_id,
			ca.classification_id,
			ca.customer_id,
			cfcd.percentage
	from 
	
		BSGCORE..customer_accounts ca 
	
	left outer join 
		BSGACCOUNTING..customer_folio_charges_discount cfcd
	on 
		ca.customer_id =cfcd.customer_id
	and 
		cfcd.is_active=1
	--and 
		--cfcd.percentage <> 100
	left outer join 
		BSGCORE..account_master am
	on 
		ca.account_id = am.account_id
	and 
		am.is_active = 1
	and 
		am.account_status_id NOT IN (4, 8)
	left outer join 
		BSGLOAN..loan_account_master lam
	on 
		ca.account_id = lam.loan_account_id
	and 
		lam.loan_account_status <> 2
	and 
		lam.is_active=1
	where 
		ca.classification_id in (1,6)
	and 
		ca.is_active=1
	and 
		isnull(am.account_id,lam.loan_account_id) is not null
	) a
	inner join 
	(select * from 	BSGACCOUNTING..transaction_master tm
	where 
		tm.txn_date>= @fromdate
	and 
		tm.txn_date <= @todate
	and is_active=1
	union all 
	select * from 	BSGDEEPFREEZE..transaction_master_df tm
	where 
		tm.txn_date>= @fromdate
	and 
		tm.txn_date <= @todate
	and 
		is_active=1
		)tm
	on 
		a.account_id = tm.account_id
	
	group by a.account_id,
		a.classification_id ,
		a.customer_id,
		a.percentage

	--select 
	--	c.*,
	--	DATEADD(day,spv.number,@fromdate) balance_date into #temp 
	--from 
	--	#tempaccountids c,
	--master..spt_values spv
	--where 
	--	spv.type = 'P'
	--and 
	--	DATEADD(day,spv.number,@fromdate) < @todate
	--and c.classification_id=1



	/*
select 
	*,
	case when cnt = 0 then 75 
	else cnt * 90  end charges_amount into #tempFinal
from (
		select tai.account_id,
	   tai.classification_id,
	   tai.cnt,
	   a.avg_available_balance,
case when a.avg_available_balance < 25000  then 0 
	 when a.avg_available_balance < 50000  then 3
	 when a.avg_available_balance < 75000 then 5
	 when a.avg_available_balance < 100000 then 10 
	 when a.avg_available_balance is null then 0
else cnt end discount
 from #tempaccountids tai
left outer join 
 (select 
	a.account_id,
	avg(ab.available_balance) avg_available_balance 
from
	 (select 
			t.account_id,
			t.balance_date,
			max(txn_date)txn_date 
	from #temp t
inner join 
	BSGACCOUNTING..account_balance ab
on 
	t.account_id  = ab.account_id
and 
	t.balance_date >= ab.txn_date
group by t.account_id,t.balance_date
)a
inner join 
	BSGACCOUNTING..account_balance ab
on 
	a.account_id = ab.account_id
and 
	a.txn_date = ab.txn_date
group by a.account_id
)a
on 
	tai.account_id = a.account_id
	)a
where case 
	when  (cnt-discount) * 60  <=  0 then 0
	when  (cnt-discount) * 60 >= 2500 then 2500
	when (cnt-discount) * 60 < 100 then 100
	else (cnt-discount) * 60 end > 0
	*/
	
	 insert into BSGACCOUNTING..[folio_charges_on_accounts]
	(account_id,branch_code,product_code,product_id,classification_id
	,account_balance,charge_amount,cgst_amount,sgst_amount,
	cgst_internal_product_id,sgst_internal_product_id,
	charges_pl_product_id,charges_pl_account_id,narration,information
	)
		
	select 
		tf.account_id,am.branch_code,pm.product_code,pm.product_id,tf.classification_id,
		ab.available_balance,tf.charges_amount, 
		isnull(cast((tf.charges_amount * @cgst)/100 as decimal(18,2)),0.00),
		isnull(cast(( tf.charges_amount * @cgst)/100 as decimal(18,2)),0.00),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=@cgstproduct and branch_code=am.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=@sgstproduct and branch_code=am.branch_code
	and is_active=1),
	 (select internal_product_id from BSGCORE..product_master_internal where product_code=9000 and branch_code=am.branch_code
	and is_active=1),
	(select top 1 account_id from bsgcore..customer_accounts where account_no =  right('0000'+ cast(am.branch_code as nvarchar),4) + '90001001091'
	  and is_Active=1),

	 'Folio Charges '+ Datename(month,@fromdate) +' '+cast(year(@fromdate) as nvarchar)
		+' to ' + Datename(month,@todate) +' '+cast(year(@todate) as nvarchar),

		'Total Count :'+cast(cnt as varchar)
	from 
		#tempaccountids tf 		
	inner join 
		BSGCORE..account_master am
	on	
		tf.account_id = am.account_id
	and 
		am.is_active=1
		and tf.charges_amount  <> 0
	inner join 
		BSGCORE..product_master pm
	on 
		am.product_id = pm.product_id	
	and 
		pm.is_active=1
	inner join 
		BSGACCOUNTING..account_balance ab
	on 
		tf.account_id = ab.account_id
	inner join 
		(select account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance ab group by account_id)a
	on 
		ab.account_id = a.account_id
	and 
		ab.txn_date = a.txn_date
	where 
		tf.classification_id=1

	union all
			
	select 
		tf.account_id,am.branch_code,pm.product_code,pm.product_id,tf.classification_id,
		ab.available_balance,tf.charges_amount, 
		isnull(cast((tf.charges_amount * @cgst)/100 as decimal(18,2)),0.00),
		isnull(cast(( tf.charges_amount * @cgst)/100 as decimal(18,2)),0.00),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=@cgstproduct and branch_code=am.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=@sgstproduct and branch_code=am.branch_code
	and is_active=1),
	 (select internal_product_id from BSGCORE..product_master_internal where product_code=9000 and branch_code=am.branch_code
	and is_active=1),
	(select top 1 account_id from bsgcore..customer_accounts where account_no =  right('0000'+ cast(am.branch_code as nvarchar),4) + '90001001116'
	  and is_Active=1),

	 'Folio Charges '+ Datename(month,@fromdate) +' '+cast(year(@fromdate) as nvarchar)
		+' to ' + Datename(month,@todate) +' '+cast(year(@todate) as nvarchar),
		'Total Count :'+cast(cnt as varchar)
	from 
		#tempaccountids tf 		
	inner join 
		bsgloan..loan_account_master am
	on	
		tf.account_id = am.loan_account_id
	and 
		am.is_active=1
	and tf.charges_amount  <> 0
	inner join 
		BSGCORE..product_master pm
	on 
		am.loan_product_id = pm.product_id	
	and
		pm.product_code <> 6009
	and 
		pm.is_active=1
	inner join 
		BSGACCOUNTING..account_balance_loan ab
	on 
		tf.account_id = ab.loan_account_id
	inner join 
		(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance_loan ab group by loan_account_id)a
	on 
		ab.loan_account_id = a.loan_account_id
	and 
		ab.txn_date = a.txn_date
	where 
		tf.classification_id=6
		
END

