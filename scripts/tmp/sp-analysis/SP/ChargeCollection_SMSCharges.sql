-- =============================================
-- Author:        <Ashish L>
-- Create date:	  <2022-12-31>
-- Description:   <ChargeCollection_SMSCharges>
-- Eexc: ChargeCollection_SMSCharges
-- =============================================
CREATE   PROCEDURE [dbo].[ChargeCollection_SMSCharges]
AS
BEGIN

DECLARE @cgstproduct nvarchar(10)
DECLARE @sgstproduct nvarchar(10)
DECLARE @igstproduct nvarchar(10)
DECLARE @utgstproduct nvarchar(10)

select @cgstproduct = config_value from BSGADMIN..cbs_config  where config_key='CGST_PRODUCT' and is_active=1
select @sgstproduct = config_value from BSGADMIN..cbs_config  where config_key='SGST_PRODUCT' and is_active=1
select @igstproduct = config_value from BSGADMIN..cbs_config  where config_key='IGST_PRODUCT' and is_active=1
select @utgstproduct = config_value from BSGADMIN..cbs_config  where config_key='UTGST_PRODUCT' and is_active=1

CREATE TABLE #PLAccountMapp(account_id INT, PLAccount VARCHAR(30), branch_code INT, productId INT)
INSERT INTO #PLAccountMapp 
select account_id,account_no,branch_code,product_id
from BSGACCOUNTING..customer_view WITH (NOLOCK)
where account_no like '%90000001057'

SELECT * INTO #productMasterInternal from BSGCORE..product_master_internal pl WITH(NOLOCK) where product_code IN(@cgstproduct,@sgstproduct,@igstproduct,@utgstproduct) and is_active=1

DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WITH(NOLOCK) WHERE is_active=1)
--QUATERLY
DECLARE @FromDate DATETIME = '2023-07-01'--DATEADD(q, DATEDIFF(q, 0, @cbsAppDate), 0)
DECLARE @ToDate DATETIME = '2023-09-30'--DATEADD(d, -1, DATEADD(q, DATEDIFF(q, 0, @cbsAppDate) + 1, 0))

	SELECT 
		ca.account_no,
		ca.customer_id,
		ca.account_id,
		ca.branch_code,
		ca.classification_id,
		am.product_id,
		am.product_code,
		CASE
			WHEN am.product_code IN (2502,2504,2506,2508,2509,2517,1101,1102,1109,2507) THEN 30.00
			WHEN am.product_code IN (2510,2011) THEN 15.00
			WHEN am.product_code IN (2501,2521) THEN 10.00
		END chargeAmount
	INTO #AllAccounts
	FROM 
		BSGCRM..customer_master cm WITH(NOLOCK)
		INNER JOIN bsgcore..customer_accounts ca WITH(NOLOCK)
			ON cm.customer_id = ca.customer_id
			AND ISNULL(cm.staff_flag,0)<>1
			AND isnull(rtrim(ltrim(cm.registered_mobile_no)) ,'N/A') <> 'N/A'	
			AND cm.is_active=1
			AND len(rtrim(ltrim(cm.registered_mobile_no))) > 9 
			AND rtrim(ltrim(cm.registered_mobile_no)) not in ('0000000000','9999999999')
		INNER JOIN BSGCORE..account_master am WITH(NOLOCK)
			ON ca.account_id = am.account_id
			AND am.is_active=1
			AND am.account_status_id not in (4,8)
			AND am.product_code in (2501,2502,2504,2506,2508,2509,2517,2521,1101,1102,1109,2507,2510,2011)
	where 
		ca.is_active =1
		AND ca.classification_id IN(1,2)

--	DELETE FROM #AllAccounts WHERE srno>1


	SELECT 
		ab.*
		INTO #casabalance 
	FROM 
		BSGACCOUNTING..account_balance ab WITH(NOLOCK)
		INNER JOIN #AllAccounts ac WITH(NOLOCK)
			ON ab.account_id = ac.account_id
			AND ac.classification_id IN(1,2)
		INNER JOIN 
		(
			SELECT 
				account_id,max(txn_date) txn_date 
			FROM 
				BSGACCOUNTING..account_balance WITH(NOLOCK)
			 GROUP BY account_id
		)a
		on ab.account_id = a.account_id
		and ab.txn_date = a.txn_date		
	
SELECT 
	a.*,
	b.available_balance,
	ROW_NUMBER() over (partition by a.customer_id  order by a.customer_id,b.available_balance DESC)  srno
	INTO #AllAccountsWithBal
FROM
	#AllAccounts a WITH(NOLOCK)
	INNER JOIN #casabalance b WITH(NOLOCK)
		ON a.account_id =b.account_id

DELETE FROM #AllAccountsWithBal WHERE srno>1

INSERT INTO BSGACCOUNTING..[charge_collection]
(
    [account_no],[account_id],[product_code],[product_id],[pl_account_no],[pl_account_id],[sgst_product_code],[sgst_product_id],
    [cgst_product_code],[cgst_product_id],[igst_product_code],[igst_product_id],[utgst_product_code],[utgst_product_id],[charge_activity],[classification_id],[charge_amount],
    [cgst],[sgst],[igst],[utgst],[narration],[notification_mode],[status],[run_date],
    [created_by],[created_date],[modified_by],[modified_date],
    [is_active],[account_balance],[charge_type],[pl_product_id],[account_branch],[charge_id]
)    

SELECT
    tf.account_no,
    tf.account_id,
    tf.product_code,
    tf.product_id,
    pl.PLAccount PLAccount,
    pl.account_id,
    @sgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@sgstproduct and  pl.branch_code=tf.branch_code),
    @cgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@cgstproduct and  pl.branch_code=tf.branch_code),
    @igstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@igstproduct and  pl.branch_code=tf.branch_code),
    @utgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@utgstproduct and  pl.branch_code=tf.branch_code),
    11141 charge_activity,
    tf.classification_id,
    CAST(tf.chargeAmount AS DECIMAL(18,2)) ChargeAmt,
    0 cgst,
    0 sgst,
    0 igst,
    0 utgst,
   IIF(MONTH(@fromdate)!=MONTH(@todate),CONCAT('SMS Charges.',DATENAME(month,@fromdate) ,' ',YEAR(@fromdate),' to ', Datename(month,@todate),' ',YEAR(@todate)
	),CONCAT('SMS Charges.',DATENAME(MONTH,@fromdate),' ',YEAR(@fromdate))),
    1 notification_mode,
    0 status,
    @cbsAppDate run_date,
    786 [created_by],
    GETDATE() [created_date],
    786 [modified_by],
    GETDATE() [modified_date],
    1 [is_active],
    ab.available_balance,
    52 [charge_type],
    pl.productId [pl_product_id],
    tf.branch_code,
    2 [charge_id]
from  
    #AllAccountsWithBal tf  WITH(NOLOCK)    
    inner join BSGACCOUNTING..account_balance ab WITH(NOLOCK)
        on tf.account_id = ab.account_id
    inner join (select account_id,max(txn_date) maxDate from BSGACCOUNTING..account_balance WITH(NOLOCK) group by account_id)abb
        on ab.account_id = abb.account_id
        and ab.txn_date = abb.maxDate
    INNER JOIN #PLAccountMapp pl WITH(NOLOCK)
        ON tf.branch_code=pl.branch_code

EXEC ChargeCollection_GstUpdate 2

EXEC ChargeCollection_ValidationCheck 2 

END
