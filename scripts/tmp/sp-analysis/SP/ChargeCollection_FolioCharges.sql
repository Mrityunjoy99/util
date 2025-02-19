-- =============================================
-- Author:		<Author,gourav>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[ChargeCollection_FolioCharges] -- [sp_get_accounts_for_folio_charges] '2019-01-01','2019-03-31',9,9
AS
BEGIN
	DECLARE @cgst decimal(18,2)=9,@sgst decimal(18,2)=9
	DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)
DECLARE @FromDate DATETIME =  IIF(MONTH(CAST (@cbsAppDate AS DATE)) BETWEEN 4 AND 9,CONCAT(YEAR(@cbsAppDate),'-04-01'), CONCAT(YEAR(DATEADD(YEAR,-1,@cbsAppDate)),'-10-01'))
DECLARE @ToDate DATETIME =  IIF(MONTH(CAST (@cbsAppDate AS DATE)) BETWEEN 4 AND 9,CONCAT(YEAR(@cbsAppDate),'-09-30'), CONCAT(YEAR(DATEADD(YEAR,1,@cbsAppDate)),'-03-31'))

declare @cgstproduct nvarchar(10)
declare @sgstproduct nvarchar(10)	
select @cgstproduct = config_value from BSGADMIN..cbs_config  where config_key='CGST_PRODUCT' and is_active=1
select @sgstproduct = config_value from BSGADMIN..cbs_config  where config_key='SGST_PRODUCT' and is_active=1

CREATE TABLE #PLAccountMapp(ProductCode INT, PLAccount BIGINT)
INSERT INTO #PLAccountMapp SELECT 0000, 90000000130

select 
		a.account_no,
		a.account_id,
		a.classification_id,
		a.customer_id
into #tempaccountids
from 
	(select 
			ca.account_no,
			ca.account_id,
			ca.classification_id,
			ca.customer_id
	from 
		BSGCORE..customer_accounts ca 
	inner join
		BSGCRM..customer_master cm
	on
		ca.customer_id = cm.customer_id
	and 
		ca.is_active=1
	and 
		cm.is_active=1
	and ISNULL(cm.staff_flag,0)<>1
	left outer join 
		BSGCORE..account_master am
	on 
		ca.account_id = am.account_id
	and 
		am.is_active = 1
	and 
		am.account_status_id NOT IN (4, 8)
	and am.product_code in (1014,2005)
	left outer join BSGLOAN..loan_account_master lam
	on ca.account_id=lam.loan_account_id
	and lam.is_active=1
	and lam.loan_product_code in (3041)
	and lam.asset_classification<3
	and lam.loan_account_status<>2
	where 
		ca.classification_id in (1,2,3)
		AND ISNULL(am.account_id,lam.loan_account_id) is not null
		and (am.product_code in (1014,2005) OR lam.loan_product_code in (3041))
	) a

	INSERT INTO BSGACCOUNTING..[charge_collection]
(
	[account_no],[account_id],[product_code],[product_id],[pl_account_no],[pl_account_id],[sgst_product_code],[sgst_product_id],
	[cgst_product_code],[cgst_product_id],[igst_product_code],[igst_product_id],[charge_activity],[classification_id],[charge_amount],
	[cgst],[sgst],[igst],[narration],[notification_mode],[status],[run_date],
	[created_by],[created_date],[modified_by],[modified_date],
	[is_active],[account_balance],[charge_type],[pl_product_id],[account_branch],[charge_id]
)

select
	tf.account_no,
	tf.account_id,
	am.product_code,
	am.product_id,
	CONCAT(RIGHT(CONCAT('0000',am.branch_code),4),pl.PLAccount) PLAccount,
	(select top 1 account_id from bsgcore..customer_accounts WITH(NOLOCK) where account_no =  CONCAT(right('0000'+ cast(am.branch_code as nvarchar),4),pl.PLAccount) and is_Active=1),
	@sgstproduct,
	(select top 1 internal_product_id from BSGCORE..product_master_internal WITH(NOLOCK) where product_code=@sgstproduct and branch_code=am.branch_code and is_active=1),
	@cgstproduct,
	(select top 1 internal_product_id from BSGCORE..product_master_internal WITH(NOLOCK) where product_code=@cgstproduct and branch_code=am.branch_code and is_active=1),
	-1,-1,
	11067 charge_activity,
	tf.classification_id,
	CASE WHEN  am.product_code=1014 THEN 50 ELSE 10 END,
	isnull(cast((CASE WHEN  am.product_code=1014 THEN 50 ELSE 10 END * @cgst)/100 as decimal(18,2)),0.00),
	isnull(cast((CASE WHEN  am.product_code=1014 THEN 50 ELSE 10 END * @cgst)/100 as decimal(18,2)),0.00),
	0,
	'Service Charges '+ Datename(month,@fromdate) +' '+cast(year(@fromdate) as nvarchar)+' to ' + Datename(month,@todate) +' '+cast(year(@todate) as nvarchar),
	1,
	0,
	@cbsAppDate,
	786 [created_by],
	GETDATE() [created_date],
	786 [modified_by],
	GETDATE() [modified_date],
	1 [is_active],
	ab.available_balance,
	23 [charge_type],
	(SELECT top 1 internal_product_id FROM BSGCORE..account_master_internal WHERE internal_account_id=
	(select top 1 account_id from bsgcore..customer_accounts WITH(NOLOCK) where account_no =  CONCAT(right('0000'+	cast(am.branch_code as nvarchar),4),pl.PLAccount) and is_Active=1)) [pl_product_id],
	am.branch_code,
	1 [charge_id]
from 
		#tempaccountids tf 		
	inner join 
		BSGCORE..account_master am
	on	
		tf.account_id = am.account_id
	and 
		am.is_active=1
	--inner join 
	--	BSGCORE..product_master pm
	--on 
	--	am.product_id = pm.product_id	
	--and 
	--	pm.is_active=1
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
	CROSS JOIN 
		#PLAccountMapp pl

union all
select
	tf.account_no,
	tf.account_id,
	lam.loan_product_code,
	lam.loan_product_id,
	CONCAT(RIGHT(CONCAT('0000',lam.branch_code),4),pl.PLAccount) PLAccount,
	(select top 1 account_id from bsgcore..customer_accounts WITH(NOLOCK) where account_no =  CONCAT(right('0000'+ cast(lam.branch_code as nvarchar),4),pl.PLAccount) and is_Active=1),
	@sgstproduct,
	(select top 1 internal_product_id from BSGCORE..product_master_internal WITH(NOLOCK) where product_code=@sgstproduct and branch_code=lam.branch_code and is_active=1),
	@cgstproduct,
	(select top 1 internal_product_id from BSGCORE..product_master_internal WITH(NOLOCK) where product_code=@cgstproduct and branch_code=lam.branch_code and is_active=1),
	-1,-1,
	11067 charge_activity,
	tf.classification_id,
	60,
	isnull(cast((60 * @cgst)/100 as decimal(18,2)),0.00),
	isnull(cast((60 * @cgst)/100 as decimal(18,2)),0.00),
	0,
	'Service Charges '+ Datename(month,@fromdate) +' '+cast(year(@fromdate) as nvarchar)+' to ' + Datename(month,@todate) +' '+cast(year(@todate) as nvarchar),
	1,
	0,
	@cbsAppDate,
	786 [created_by],
	GETDATE() [created_date],
	786 [modified_by],
	GETDATE() [modified_date],
	1 [is_active],
	ab.available_balance,
	23 [charge_type],
	(SELECT top 1 internal_product_id FROM BSGCORE..account_master_internal WHERE internal_account_id=
	(select top 1 account_id from bsgcore..customer_accounts WITH(NOLOCK) where account_no =  CONCAT(right('0000'+	cast(lam.branch_code as nvarchar),4),pl.PLAccount) and is_Active=1)) [pl_product_id],
	lam.branch_code,
	1 [charge_id]

	from 
		#tempaccountids tf 		
	inner join 
		BSGLOAN..loan_account_master lam
	on	
		tf.account_id = lam.loan_account_id
	and 
		lam.is_active=1
	--inner join 
	--	BSGCORE..product_master pm
	--on 
	--	am.product_id = pm.product_id	
	--and 
	--	pm.is_active=1
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
	CROSS JOIN 
		#PLAccountMapp pl
	where 
		tf.classification_id=3
		and lam.loan_product_code=3041;

EXEC ChargeCollection_ValidationCheck 1
		
END
