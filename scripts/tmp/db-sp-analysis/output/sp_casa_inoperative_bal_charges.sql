
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_casa_inoperative_bal_charges] -- sp_casa_inoperative_bal_charges 2,2016,4.5,4.5
@account_status int ,
@cgst decimal(18,2),
@sgst decimal(18,2)
AS
BEGIN
	

	 insert into BSGACCOUNTING..[inoperative_charges_on_accounts]
	(account_id,branch_code,product_code,product_id,classification_id
	,account_balance,charge_amount,cgst_amount,sgst_amount,
	cgst_internal_product_id,sgst_internal_product_id,
	charges_pl_product_id,charges_pl_account_id,narration
	)
	 select ca.account_id,ca.branch_code,
	 pm.product_code,
	 pm.product_id,
	 ca.classification_id,
	 ab.available_balance,
	 case ca.classification_id when 2 then 30 when 1 then 60 end,
	 isnull(cast((case ca.classification_id when 2 then 30 when 1 then 60 end * @cgst)/100 as decimal(18,2)),0.00),
	isnull(cast(( case ca.classification_id when 2 then 30 when 1 then 60 end * @cgst)/100 as decimal(18,2)),0.00),
	 (select internal_product_id from BSGCORE..product_master_internal where product_code=7176 and branch_code=ca.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=7175 and branch_code=ca.branch_code
	and is_active=1),
	 (select internal_product_id from BSGCORE..product_master_internal where product_code=9000 and branch_code=ca.branch_code
	and is_active=1),
	(select top 1 account_id from bsgcore..customer_accounts where account_no = 
	 (select top 1 replace(account_no,left(account_no,4),ca.branch_code) from BSGCORE..customer_accounts
	  where account_id = 8724 and is_Active=1) and is_Active=1),

	 'Inoperative Charges '+ Datename(month,dateadd(month,-6,getdate())) +' '+cast(year(dateadd(month,-6,getdate())) as nvarchar)
		+' to ' + Datename(month,getdate()) +' '+cast(year(getdate()) as nvarchar)
	   from BSGCORE..customer_accounts ca
	 inner join 
		BSGCORE..account_master am
	on 
		ca.account_id = am.account_id
	inner join 
		BSGCORE..product_master pm
	on
		am.product_id = pm.product_id
	inner join 
		BSGACCOUNTING..account_balance ab
	on 
		am.account_id = ab.account_id
	inner join 
		(select account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance ab group by account_id)a
	on 
		ab.account_id = a.account_id
	and 
		ab.txn_date = a.txn_date
	where ca.is_active =1 
	and 
		am.is_active = 1
	and 
		pm.is_active=1
	and am.account_status_id = @account_status


	

	select @@ROWCOUNT cnt

	declare @cbsapplicationdate datetime
	select @cbsapplicationdate = app_date from cbs_application_date where is_active=1

	insert into BSGACCOUNTING..account_balance
	(account_id,day_open_balance,maker_clear_balance,maker_unclear_balance,checker_unclear_balance
	,checker_clear_balance,day_close_balance,available_balance,interest_accrual,sprinkle,is_active
	,created_by,created_date,last_modified_by,last_modified_date,txn_date,last_accrual_date
	,encrypted_balance,lien_amount)

	select ab.account_id,day_open_balance,maker_clear_balance,maker_unclear_balance,checker_unclear_balance
	,checker_clear_balance,day_close_balance,available_balance,interest_accrual,sprinkle,is_active
	,created_by,getdate(),last_modified_by,getdate(),@cbsapplicationdate,last_accrual_date
	,encrypted_balance,lien_amount from BSGACCOUNTING..account_balance ab
	inner join (
	select account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance where account_id in (

	select amcoa.account_id from  inoperative_charges_on_accounts amcoa 
	left join 
			BSGACCOUNTING..account_balance ab  
		on 
			amcoa.account_id = ab.account_id
		and
			ab.txn_date = @cbsapplicationdate
	
	where  ab.account_id is null) group by account_id)a
	on 
		ab.account_id = a.account_id
	and 
		ab.txn_date = a.txn_date
		
END



