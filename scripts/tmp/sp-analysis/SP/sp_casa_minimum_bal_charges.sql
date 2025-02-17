CREATE  PROCEDURE  [dbo].[sp_casa_minimum_bal_charges]  -- sp_casa_minimum_bal_charges 7,2018,4.5,4.5
(
@month int, --= dateadd(@month,-1,sysdate)
@year int, --= sysdate
@cgst decimal(18,2) ,
@sgst decimal(18,2) )
AS
BEGIN

DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)
DECLARE @todate DATETIME = DATEADD(DAY,-1,@cbsAppDate)
DECLARE @fromdate DATETIME = DATEADD(month, -1, @todate)


--IF OBJECT_ID('tempdb..#min_bal_charges') IS NOT NULL
--    DROP TABLE #min_bal_charges

IF OBJECT_ID('tempdb..#AccountList') IS NOT NULL
    DROP TABLE #AccountList

IF OBJECT_ID('tempdb..#GSTProducts') IS NOT NULL
    DROP TABLE #GSTProducts
	
IF OBJECT_ID('tempdb..#PLAccountMapp') IS NOT NULL
    DROP TABLE #PLAccountMapp

--CREATE TABLE min_bal_charges_history
--(
--	id BIGINT IDENTITY(1,1) PRIMARY KEY,
--	account_id BIGINT,
--	branch_code INT,
--	product_code INT,
--	product_id INT,
--	avaulable_balance DECIMAL(18,2),
--	charge_ammount DECIMAL(18,2),
--	cgst_amount DECIMAL(18,2),
--	sgst_amount DECIMAL(18,2),
--	cgst_product_id INT,
--	sgst_product_id INT ,
--	pl_product_id INT,
--	pl_account_id INT,
--	remarks VARCHAR(200),
--	txn_date DATETIME
--)

CREATE TABLE #GSTProducts(productId INT,branch_code INT,gstType VARCHAR(10))
INSERT INTO #GSTProducts 
SELECT 
	internal_product_id,branch_code,'CGST'
FROM 
	BSGCORE..product_master_internal 
WHERE 
	product_code=(SELECT config_value FROM BSGADMIN..cbs_config  WHERE config_key='CGST_PRODUCT' AND is_active=1)
	and is_active=1
UNION ALL
SELECT 
	internal_product_id,branch_code,'SGST'
FROM 
	BSGCORE..product_master_internal 
WHERE 
	product_code=(SELECT config_value FROM BSGADMIN..cbs_config  WHERE config_key='SGST_PRODUCT' AND is_active=1)
	and is_active=1


CREATE TABLE #PLAccountMapp(account_id INT, PLAccount VARCHAR(30), branch_code INT, productId INT)
INSERT INTO #PLAccountMapp 
select account_id,account_no,branch_code,product_id
from BSGACCOUNTING..customer_view
where account_no like '%90000000295'

SELECT 
	--max(ab.txn_date) txn_date, 
	am.account_id,am.product_code,am.branch_code,am.customer_id,pbm.minimum_balance,am.product_id
	INTO #AccountList
FROM 
	BSGCORE..account_master am 
	INNER JOIN bsgcore..product_balance_minimum pbm
		ON am.product_id=pbm.product_id
		and pbm.is_active=0
		and pbm.channel_type='B'
	LEFT OUTER JOIN BSGACCOUNTING..account_balance ab
		ON am.account_id=ab.account_id
		and txn_date >=@fromdate
		and ab.available_balance>pbm.minimum_balance
	LEFT OUTER JOIN min_bal_charges_history mbc
		ON am.account_id=mbc.account_id
		and mbc.txn_date>@fromdate
WHERE 
	 am.account_status_id IN(1,3)
	and am.is_active=1
	and am.account_open_date<@fromdate
	--
	and am.account_id=21121
	and mbc.account_id IS NULL
GROUP BY
	am.account_id,am.product_code,am.branch_code,am.customer_id,pbm.minimum_balance,am.product_id
HAVING
	(max(ab.txn_date) IS NULL)


--insert into BSGACCOUNTING..min_bal_charges_on_accounts
--(
--	account_id,branch_code,product_code,product_id,classification_id
--	,account_balance,charge_amount,cgst_amount,sgst_amount,
--	cgst_internal_product_id,sgst_internal_product_id,
--	charges_pl_product_id,charges_pl_account_id,narration
--)
SELECT 
	ac.account_id,ac.branch_code,product_code,product_id,classification_id,available_balance,
	CAST((chargableAmount*10/100.00) AS DECIMAL(18,2)) AS charge,
	CAST((chargableAmount*10/100.00)*.09 AS DECIMAL(18,2)) cgst,
	CAST((chargableAmount*10/100.00)*.09 AS DECIMAL(18,2)) sgst,
	(SELECT gp.productId FROM #GSTProducts gp WHERE gp.branch_code=ac.branch_code and gp.gstType='CGST') CGSTProductId,
	(SELECT gp.productId FROM #GSTProducts gp WHERE gp.branch_code=ac.branch_code and gp.gstType='SGST') SGSTProductId,
	pl.productId,pl.account_id,
	'Min. Balance Charges '+ Datename(month,@fromdate) +' '+cast(year(@fromdate) as nvarchar)+' to ' +
	Datename(month,@todate) +' '+cast(year(@todate) as nvarchar)
FROM 
(
SELECT 
	ac.*,ab.available_balance,ab.txn_date,
	ac.minimum_balance-ab.available_balance chargableAmount,ca.classification_id
FROM 
	BSGACCOUNTING..account_balance ab
	INNER JOIN 
	(
		SELECT MAX(txn_date) txn_date,account_id FROM BSGACCOUNTING..account_balance GROUP BY account_id
	) m
	ON ab.account_id=m.account_id
		and ab.txn_date=m.txn_date
	INNER JOIN #AccountList ac
		ON ab.account_id=ac.account_id
	INNER JOIN BSGCORE..customer_accounts ca
		ON ac.account_id=ca.account_id
		and ca.is_active=1
	
) ac 
LEFT OUTER JOIN #PLAccountMapp pl
		ON ac.branch_code=pl.branch_code
ORDER BY txn_date desc

--INSERT INTO min_bal_charges_history
SELECT 
	account_id,
	branch_code,
	product_code,
	product_id,
	account_balance,
	charge_amount,
	cgst_amount,
	sgst_amount,
	cgst_internal_product_id,
	sgst_internal_product_id,
	charges_pl_product_id,
	charges_pl_account_id,
	narration,
	@ToDate
FROM 
	BSGACCOUNTING..min_bal_charges_on_accounts

END
