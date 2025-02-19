create    PROCEDURE  [dbo].[sp_turing_testing_cheksum]  -- sp_turing_testing_cheksum
as

select
		1 Srno,
		1 CheckingId,
		'OBC_POSTAGE_PL account(config key) present in account_master_internal and customer_accounts table' QueryDescription,
		'Select config.config_key,config.config_value from bsgadmin..cbs_config config
inner join 
bsgcore..account_master_internal ami
on config.config_value=ami.internal_account_id
inner join 
bsgcore..customer_accounts ca
on config.config_value=ca.account_id
where ami.is_active=1 
and config.config_key=OBC_POSTAGE_PL 
and ca.is_active=1 
and config.is_active=1' Query,
config.config_key,config.config_value,'OBC_POSTAGE_PL' result,'1' sr_no from bsgadmin..cbs_config config
inner join 
bsgcore..account_master_internal ami
on config.config_value=ami.internal_account_id
inner join 
bsgcore..customer_accounts ca
on config.config_value=ca.account_id
where ami.is_active=1 
and config.config_key='OBC_POSTAGE_PL' 
and ca.is_active=1 
and config.is_active=1;

select 
		2 Srno,
		2 CheckingId,
		'OBC_PRODUCT product(config key) present in product_master_internal table' QueryDescription,
		'Select config.config_key,config.config_value,pmi.branch_code from bsgadmin..cbs_config config
inner join 
bsgcore..product_master_internal pmi
on config.config_value=pmi.product_code
where pmi.is_active=1 
and config.config_key=OBC_PRODUCT
and config.is_active=1;'  Query,
		config.config_key,config.config_value,pmi.branch_code,'OBC_PRODUCT' result,'2' sr_no from bsgadmin..cbs_config config
inner join 
bsgcore..product_master_internal pmi
on config.config_value=pmi.product_code
where pmi.is_active=1 
and config.config_key='OBC_PRODUCT' 
and config.is_active=1 ;

select 
		3 Srno,
		3 CheckingId,
		'IBC_COMMISSION_PL account (config key) present in account_master_internal and customer_accounts table' QueryDescription,
		'Select config.config_key,config.config_value from bsgadmin..cbs_config config
inner join 
bsgcore..customer_accounts ca
on config.config_value=ca.account_no
inner join 
bsgcore..account_master_internal ami
on ca.account_id=ami.internal_account_id
where ami.is_active=1 
and config.config_key=IBC_COMMISSION_PL 
and ca.is_active=1 
and config.is_active=1;'  Query,
config.config_key,config.config_value,'IBC_COMMISSION_PL' result,'3' sr_no from bsgadmin..cbs_config config
inner join 
bsgcore..customer_accounts ca
on config.config_value=ca.account_no
inner join 
bsgcore..account_master_internal ami
on ca.account_id=ami.internal_account_id
where ami.is_active=1 
and config.config_key='IBC_COMMISSION_PL' 
and ca.is_active=1 
and config.is_active=1;


select 
		4 Srno,
		4 CheckingId,
		'IBC_POSTAGE_PL account (config key) present in account_master_internal and customer_accounts table' QueryDescription,
		'Select config.config_key,config.config_value from bsgadmin..cbs_config config
inner join 
bsgcore..customer_accounts ca
on config.config_value=ca.account_no
inner join 
bsgcore..account_master_internal ami
on ca.account_id=ami.internal_account_id
where ami.is_active=1 
and config.config_key=IBC_POSTAGE_PL 
and ca.is_active=1 
and config.is_active=1;'  Query,
config.config_key,config.config_value,'IBC_POSTAGE_PL' result,'4' sr_no from bsgadmin..cbs_config config
inner join 
bsgcore..customer_accounts ca
on config.config_value=ca.account_no
inner join 
bsgcore..account_master_internal ami
on ca.account_id=ami.internal_account_id
where ami.is_active=1 
and config.config_key='IBC_POSTAGE_PL' 
and ca.is_active=1 
and config.is_active=1;


select 
		5 Srno,
		5 CheckingId,
		'IBC_PRODUCT product(config key) present in product_master_internal table' QueryDescription,
		'Select config.config_key,config.config_value,pmi.branch_code from bsgadmin..cbs_config config
inner join 
bsgcore..product_master_internal pmi
on config.config_value=pmi.product_code
where pmi.is_active=1 
and config.config_key=IBC_PRODUCT
and config.is_active=1;'  Query,
		config_key,config_value,pmi.branch_code,'IBC_PRODUCT' result,'5' sr_no from bsgadmin..cbs_config config
inner join 
bsgcore..product_master_internal pmi
on config.config_value=pmi.product_code
where pmi.is_active=1 
and config.config_key='IBC_PRODUCT' 
and config.is_active=1 ;

select 
		6 Srno,
		6 CheckingId,
		'NEFT_RTGS_START_TIME and END_TIME (Time Format should be : [HH:MM]  )' QueryDescription,
		'Select config_key,config_value from bsgadmin..cbs_config 
         where config_key in (NEFT_START_TIME,NEFT_END_TIME,RTGS_START_TIME,RTGS_END_TIME) and is_active=1'  Query,
         config_key,config_value,'NEFT_RTGS_START_TIME' result,'6' sr_no from bsgadmin..cbs_config where config_key in ('NEFT_START_TIME','NEFT_END_TIME','RTGS_START_TIME','RTGS_END_TIME') and is_active=1;



		 select 
		7 Srno,
		7 CheckingId,
		'NEFT_PRODUCT product(config key) present in product_master_internal table and its
		 gl_code_id should be match with gl_code_master' QueryDescription,
		'Select config.config_key,config.config_value,pmi.branch_code,gm.gl_code_id,pmi.gl_code_id,gm.description from bsgadmin..cbs_config config
         inner join 
         bsgcore..product_master_internal pmi
         on config.config_value=pmi.product_code
         inner join
         bsgcore..glcode_master gm
         on pmi.gl_code_id=gm.gl_code_id
         where pmi.is_active=1 and config.config_key=NEFT_PRODUCT and config.is_active=1 and gm.description=NEFT and gm.is_active=1 '  Query,
		 config.config_key,config.config_value,pmi.branch_code,gm.gl_code_id,pmi.gl_code_id,gm.description,'NEFT_PRODUCT' result,'7' sr_no from bsgadmin..cbs_config config
         inner join 
         bsgcore..product_master_internal pmi
         on config.config_value=pmi.product_code
         inner join
         bsgcore..glcode_master gm
         on pmi.gl_code_id=gm.gl_code_id
         where pmi.is_active=1 and config.config_key='NEFT_PRODUCT' and config.is_active=1 and gm.description='NEFT'and gm.is_active=1 ;


		 select 
		8 Srno,
		8 CheckingId,
		'RTGS_PRODUCT product(config key) present in product_master_internal table and its
		gl_code_id should be match with gl_code_master' QueryDescription,
		'Select Select config.config_key,config.config_value,pmi.branch_code,gm.gl_code_id,pmi.gl_code_id,gm.description from bsgadmin..cbs_config config
         inner join 
         bsgcore..product_master_internal pmi
         on config.config_value=pmi.product_code
         inner join
         bsgcore..glcode_master gm
         on pmi.gl_code_id=gm.gl_code_id
         where pmi.is_active=1 and config.config_key=RTGS_PRODUCT and config.is_active=1 and gm.description=RTGS and gm.is_active=1 '  Query,
         config.config_key,config.config_value,pmi.branch_code,gm.gl_code_id,pmi.gl_code_id,gm.description,'RTGS_PRODUCT' result,'8' sr_no from bsgadmin..cbs_config config
         inner join 
         bsgcore..product_master_internal pmi
         on config.config_value=pmi.product_code
         inner join
         bsgcore..glcode_master gm
         on pmi.gl_code_id=gm.gl_code_id
         where pmi.is_active=1 and config.config_key='RTGS_PRODUCT' and config.is_active=1 and gm.description='RTGS' and gm.is_active=1 ;



		 select 
		9 Srno,
		9 CheckingId,
		'NEFT_SETTLEMENT_PRODUCT product(config key) present in product_master_internal table' QueryDescription,
		'Select config.config_key,config.config_value,pmi.branch_code from bsgadmin..cbs_config config
         inner join 
         bsgcore..product_master_internal pmi
         on config.config_value=pmi.product_code
         where pmi.is_active=1 and config.config_key=NEFT_SETTLEMENT_PRODUCTand config.is_active=1;'  Query,
		config.config_key,config.config_value,pmi.branch_code,'NEFT_SETTLEMENT_PRODUCT' result,'9' sr_no from bsgadmin..cbs_config config
        inner join 
        bsgcore..product_master_internal pmi
        on config.config_value=pmi.product_code
        where pmi.is_active=1 and config.config_key='NEFT_SETTLEMENT_PRODUCT' and config.is_active=1 ;

			select 
			10 Srno,
			10 CheckingId,
			'RTGS_SETTLEMENT_PRODUCT product(config key) present in product_master_internal table' QueryDescription,
			'Select config.config_key,config.config_value,pmi.branch_code from bsgadmin..cbs_config config
				inner join 
				bsgcore..product_master_internal pmi
				on config.config_value=pmi.product_code
				where pmi.is_active=1 and config.config_key=RTGS_SETTLEMENT_PRODUCT and config.is_active=1;'  Query,
			config.config_key,config.config_value,pmi.branch_code,'RTGS_SETTLEMENT_PRODUCT' result,'10' sr_no from bsgadmin..cbs_config config
			inner join 
		   bsgcore..product_master_internal pmi
	on config.config_value=pmi.product_code
	where pmi.is_active=1 
	and config.config_key='RTGS_SETTLEMENT_PRODUCT' 
	and config.is_active=1 ;
