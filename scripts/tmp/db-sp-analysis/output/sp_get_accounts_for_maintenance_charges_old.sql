CREATE   procedure [dbo].[sp_get_accounts_for_maintenance_charges_old] -- sp_get_accounts_for_maintenance_charges -1, -1
@branchCode int,
@classificationId int
as 
begin

declare @casaChargeActivityId int
declare @ccChargeActivityId int
declare @chargeType int
declare @financialStartYear int = 2017


set @ccChargeActivityId = 11063
set @casaChargeActivityId = 11065
set @chargeType = 21

truncate table bsgaccounting..maintenance_charges_on_accounts;

insert into bsgaccounting..maintenance_charges_on_accounts (
	account_id,
	branch_code,
	product_code,
	product_id,
	classification_id,
	account_balance
	--charge_per_transaction,
	--min_folio_charge,
	--charge_amount,
	--cgst_amount,
	--sgst_amount,
	--cgst_internal_product_id,
	--sgst_internal_product_id,
	--charges_pl_product_id,
	--charges_pl_account_id,
)
select account_id, branch_code, product_code, product_id, classification_id, 0.00 as balance
from (
select ca.account_id, ca.branch_code, 
case ca.classification_id 
	when 1 then (select top 1 product_code from BSGCORE..account_master am where am.account_id = ca.account_id and is_active=1)
	when 2 then (select top 1 product_code from BSGCORE..account_master am where am.account_id = ca.account_id and is_active=1)
	when 6 then (select top 1 loan_product_code from bsgloan..loan_account_master lam where lam.loan_account_id = ca.account_id and is_active=1)
	else -1
end as product_code,
case ca.classification_id 
	when 1 then (select top 1 product_id from BSGCORE..account_master am where am.account_id = ca.account_id and is_active=1)
	when 2 then (select top 1 product_id from BSGCORE..account_master am where am.account_id = ca.account_id and is_active=1)
	when 6 then (select top 1 loan_product_id from bsgloan..loan_account_master lam where lam.loan_account_id = ca.account_id and is_active=1)
	else -1
end as product_id,
ca.classification_id
from bsgcore..customer_accounts ca 
where 1=1 --conditions to identify Customer Non System Transactions
and ((@classificationId = -1 and ca.classification_id in(1,2,6)) or ca.classification_id = @classificationId)
and (@branchCode=-1 or ca.branch_code = @branchCode)
and ca.account_id in 
(
	select account_id from bsgcore..account_master where account_status_id <> 4 and is_active=1
	union all
	select loan_account_id from bsgloan..loan_account_master where loan_account_status <> 2 and is_active=1
)
) A
group by A.account_id, A.branch_code, A.classification_id,
A.product_code, A.product_id


-- update account_balance
-- casa
update fc
set fc.account_balance = ab.available_balance-ab.lien_amount
from BSGACCOUNTING..maintenance_charges_on_accounts fc
inner join BSGACCOUNTING..account_balance ab
on fc.account_id = ab.account_id
where classification_id in (1,2)
and txn_date = (select max(txn_date) from BSGACCOUNTING..account_balance where account_id = ab.account_id)
-- cc
update fc
set fc.account_balance = ab.available_balance
from BSGACCOUNTING..maintenance_charges_on_accounts fc
inner join BSGACCOUNTING..account_balance_loan ab
on fc.account_id = ab.loan_account_id
where classification_id in (6)
and txn_date = (select max(txn_date) from BSGACCOUNTING..account_balance_loan where loan_account_id = ab.loan_account_id)


---- Query to update min charge amount, charge per trans, pl_account_id, pl_product_id, cgst and sgst internal_product_id

update bsgaccounting..maintenance_charges_on_accounts
set cgst_internal_product_id = 
	(
		select 
			internal_product_id 
		from 
			bsgcore..product_master_internal 
		where 
			product_code = (select config_value from bsgadmin..cbs_config where config_key = 'CGST_PRODUCT')
			and branch_code = maintenance_charges_on_accounts.branch_code
			and is_active=1
	) ,--as cgst_internal_product_id,
	sgst_internal_product_id = (
		select 
			internal_product_id 
		from 
			bsgcore..product_master_internal 
		where 
			product_code = (select config_value from bsgadmin..cbs_config where config_key = 'SGST_PRODUCT')
			and branch_code = maintenance_charges_on_accounts.branch_code
			and is_active=1
	) ,--as sgst_internal_product_id,
	charges_pl_product_id = (
		select 
			internal_product_id 
		from 
			bsgcore..product_master_internal 
		where 
			product_code = (select config_value from bsgadmin..cbs_config where config_key = 'PL_PRODUCT_CODE')
			and branch_code = maintenance_charges_on_accounts.branch_code
			and is_active=1
	) ,--as charges_internal_product_id,
	charges_pl_account_id = (
		select --pl_account_id, ca.account_id, ca.account_no
		(select account_id from bsgcore..customer_accounts where account_no = right('0000'+cast(maintenance_charges_on_accounts.branch_code as varchar),4)+substring(ca.account_no,5,11)) as charge_internal_account_id
		from bsgremittance..external_product_charges epc
		inner join bsgcore..customer_accounts ca
		on epc.pl_account_id = ca.account_id
		where product_code = maintenance_charges_on_accounts.product_code
		and charge_type = @chargeType
	) ,--as charges_internal_account_id,
	charge_amount = (
	-- Below Code commented after receiving fixed charges
		--select epc.charge_value
		--from bsgremittance..external_product_charges epc
		--inner join bsgcore..customer_accounts ca
		--on epc.pl_account_id = ca.account_id
		--where product_code = maintenance_charges_on_accounts.product_code
		--and charge_type = @chargeType
		case maintenance_charges_on_accounts.classification_id 
		when 1 then 
			(
				select 
				case dbo.fn_get_quarter_no(account_open_date,@financialStartYear) 
					when 1 then 200
					when 2 then 150
					when 3 then 100
					when 4 then 50
					else 200 -- Accounts opened before current financial year
					end as charge_amount 
				from BSGCORE..account_master
				where account_id = maintenance_charges_on_accounts.account_id and is_Active=1
			)
		when 2 then 
			(
				select 
				case dbo.fn_get_quarter_no(account_open_date,@financialStartYear) 
					when 1 then 60
					when 2 then 60
					when 3 then 30
					when 4 then 30
					else 60 -- Accounts opened before current financial year
					end as charge_amount
				from BSGCORE..account_master
				where account_id = maintenance_charges_on_accounts.account_id and is_Active=1
			)
		when 6 then 
			(
				select 
				case dbo.fn_get_quarter_no(date_of_account_opening,@financialStartYear) 
					when 1 then 200
					when 2 then 150
					when 3 then 100
					when 4 then 50
					else 200 -- Accounts opened before current financial year
					end as charge_amount
				from BSGLOAN..loan_account_master
				where loan_account_id = maintenance_charges_on_accounts.account_id and is_Active=1
			)
		end
	)
	
	--- update cgst sgst amount
	update BSGACCOUNTING..maintenance_charges_on_accounts
	set 
	cgst_amount = 
	(
		select top 1 tax_percentage from bsgmaster..service_tax_master 
		where activity_id = (case maintenance_charges_on_accounts.classification_id when 1 then @casaChargeActivityId when 2 then @casaChargeActivityId when 6 then @ccChargeActivityId end)
		and tax_type=1
	)*charge_amount*0.01,
	sgst_amount = 
	(
		select top 1 tax_percentage from bsgmaster..service_tax_master 
		where activity_id = (case maintenance_charges_on_accounts.classification_id when 1 then @casaChargeActivityId when 2 then @casaChargeActivityId when 6 then @ccChargeActivityId end)
		and tax_type=2
	)*charge_amount*0.01

end


