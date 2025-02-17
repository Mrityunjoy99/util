
CREATE    PROCEDURE [dbo].[GET_CASA_INT_APPLICATION_ACCS] -- exec GET_CASA_INT_APPLICATION_ACCS
as begin

--truncate table BSGACCOUNTING..casa_interest_details;
DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1)

Declare @NRO_TDS_PERCENTAGE decimal(18,2) =(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='NRO_TDS_PERCENTAGE' AND is_active = 1)


exec BSGACCOUNTING..sp_casa_interest_accrual @cbsAppDate,786,NULL,NULL 

insert into BSGACCOUNTING..casa_interest_details
select  
ca.account_id,ca.account_no,ca.branch_code,am.product_code,am.product_id,0,0,pi.pl_account_id,ami.internal_product_id,0,
case 
	WHEN am.NRO_FLAG=1 then @NRO_TDS_PERCENTAGE
	else 0 end tds_percentage,
	0 tds_amount,
(SELECT internal_product_id FROM BSGCORE..product_master_internal WHERE product_code=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_PRODUCT' AND is_active = 1) AND branch_code=am.branch_code AND is_active=1) as tds_product_id
from BSGCORE..customer_accounts ca 
inner join BSGCORE..account_master as am 
on ca.account_id = am.account_id 
inner join bsgcore..product_interest pi 
on pi.product_id=am.product_id 
inner join BSGCORE..account_master_internal ami 
on pi.pl_account_id = ami.internal_account_id 
inner join bsgcore..product_master pm
on am.product_id = pm.product_id 
inner join bsgcore..glcode_master gm
on gm.gl_code_id = pm.gl_code_id
where am.account_status_id not in  (4,8) and am.is_active=1 and ca.is_active=1 and ca.classification_id=2 and pi.is_active=1 
and ami.is_active=1 and gm.is_active=1
and pm.is_active=1 
--and am.product_code NOT IN(2012)
--and gm.gl_code != (select config_value from bsgadmin..cbs_config where config_key='DDS_GL_CODE') ; 

update  cid set cid.interest_amount  =cast(isnull(case when ab.interest_accrual < 0 then 0 else ab.interest_accrual end,0) as decimal(18,0)),
cid.account_balance = isnull(ab.available_balance,0)
from casa_interest_details cid 
inner join 
account_balance ab 
on 
	cid.account_id = ab.account_id 
inner join 
	(select account_id,max(txn_date) txn_date from bsgaccounting..account_balance where is_Active=1 group by account_id ) a 
on  
	ab.account_id = a.account_id 
and  
	ab.txn_date = a.txn_date ;
	select 1;

UPDATE tia SET 
tia.tds_amount=cast(isnull(CEILING((tia.interest_amount*tia.tds_percentage)/100),0) as decimal(18,0))
FROM BSGACCOUNTING..casa_interest_details tia
WHERE tia.tds_percentage>0 AND tia.interest_amount>0

insert into BSGACCOUNTING..nro_casa_tds_details
select account_id,tds_amount,@cbsAppDate,-1,getdate(),1 FROM BSGACCOUNTING..casa_interest_details where tds_amount>0

end;
