CREATE   procedure [dbo].[sp_get_accounts_for_maintenance_charges]
@branchCode int,
@classificationId int
as 
begin
with cte as(
	select a.* from (select 
		ca.customer_id,ca.account_id,ca.branch_code,ca.classification_id,isnull(am.product_id,lam.loan_product_id) product_id,
		isnull(am.product_code,lam.loan_product_code) product_code,
		ROW_NUMBER() over (partition by ca.customer_id  order by ca.customer_id,ca.classification_id desc)  srno
	from 
		bsgcrm..customer_master cm
	inner join 
		bsgcore..customer_accounts ca 
	on 
		cm.customer_id = ca.customer_id
	and  
			isnull(rtrim(ltrim(cm.registered_mobile_no)) ,'N/A') <> 'N/A'	
	and 
		cm.is_active=1
	and 
		len(rtrim(ltrim(cm.registered_mobile_no))) > 9 
	and 
		rtrim(ltrim(cm.registered_mobile_no)) not in ('0000000000','9999999999')
	left join 
		BSGCORE..account_master am
	on 
		ca.account_id = am.account_id
	and
		am.is_active=1
	and 
		am.account_status_id not in (4,8)
	left join 
		bsgloan..loan_account_master lam
	on 
		ca.account_id = lam.loan_account_id
	and
		lam.is_active=1
	and 
		lam.loan_account_status <> 2
	where 
		ca.is_active =1 
	and 
		ca.classification_id in (1,2,6)
	and 
		isnull(am.account_id ,lam.loan_account_id) is not null
		)a
	where a.srno =1)
	, casabalance as (
	select ab.* from BSGACCOUNTING..account_balance ab
	inner join 
		(select account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance where account_id in 
		(select account_id from cte where classification_id in (1,2)) group by account_id)a
	on 
		ab.account_id = a.account_id
	and
		ab.txn_date = a.txn_date		
	),
	loanbalance as (
		select ab.* from BSGACCOUNTING..account_balance_loan ab
	inner join 
		(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance_loan where loan_account_id in 
		(select account_id from cte where classification_id in (6)) group by loan_account_id)a
	on 
		ab.loan_account_id = a.loan_account_id
	and
		ab.txn_date = a.txn_date		
	)
	--select * from maintenance_charges_on_accounts

	

insert into bsgaccounting..maintenance_charges_on_accounts (
	account_id,
	branch_code,
	product_code,
	product_id,
	classification_id,
	account_balance,
	charge_amount,	 
	cgst_amount,
	sgst_amount,
	cgst_internal_product_id,
	sgst_internal_product_id,
	charges_pl_product_id,
	charges_pl_account_id
)
	select c.account_id,c.branch_code,c.product_code,c.product_id,c.classification_id
	,cb.available_balance,60,60*.09,60*.09,
	  (select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'CGST_PRODUCT' AND is_active = 1) and branch_code=c.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'SGST_PRODUCT' AND is_active = 1) and branch_code=c.branch_code
	and is_active=1),
    (SELECT 
            internal_product_id
        FROM
            BSGCORE..product_master_internal
        WHERE
            product_code = 9000
                AND branch_code = c.branch_code
                AND is_active = 1),
    (SELECT 
           top 1  account_id
        FROM
            bsgcore..customer_accounts
        WHERE
            account_no = (SELECT top 1 
                    REPLACE(account_no,
                            LEFT(account_no, 4),
                            c.branch_code)
                FROM
                    BSGCORE..customer_accounts
                WHERE
                    account_id = 8726 AND is_Active = 1
               )
                AND is_Active = 1
       )
	 from cte c inner join  casabalance cb
	on 
		c.account_id = cb.account_id
	union all
	select c.account_id,c.branch_code,c.product_code,c.product_id,c.classification_id
	,cb.available_balance,60,60*.09,60*.09,
	  (select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'CGST_PRODUCT' AND is_active = 1) and branch_code=c.branch_code
	and is_active=1),
	(select internal_product_id from BSGCORE..product_master_internal where product_code=(select config_value from bsgadmin..cbs_config where config_key = 'SGST_PRODUCT' AND is_active = 1) and branch_code=c.branch_code
	and is_active=1),
    (SELECT 
            internal_product_id
        FROM
            BSGCORE..product_master_internal
        WHERE
            product_code = 9000
                AND branch_code = c.branch_code
                AND is_active = 1),
    (SELECT 
           top 1  account_id
        FROM
            bsgcore..customer_accounts
        WHERE
            account_no = (SELECT top 1 
                    REPLACE(account_no,
                            LEFT(account_no, 4),
                            c.branch_code)
                FROM
                    BSGCORE..customer_accounts
                WHERE
                    account_id = 8726 AND is_Active = 1
               )
                AND is_Active = 1
       )
	 from cte c inner join  loanbalance cb
	on 
		c.account_id = cb.loan_account_id

end

