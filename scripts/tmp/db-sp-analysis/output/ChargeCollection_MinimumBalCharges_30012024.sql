-- =============================================
-- Author:		<Ashish L>
-- Create date: <2023-02-27> SELECT GETDATE()
-- Description:	<MinBal. Charges>
-- Exec: ChargeCollection_MinimumBalCharges
-- =============================================

CREATE   procedure [dbo].[ChargeCollection_MinimumBalCharges]
AS
BEGIN 
DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)
--set @cbsAppDate = '2023-09-30';
DECLARE @FromDate DATETIME = '2023-07-01'--DATEADD(q, DATEDIFF(q, 0, @cbsAppDate), 0)
DECLARE @ToDate DATETIME = '2023-09-30'--DATEADD(d, -1, DATEADD(q, DATEDIFF(q, 0, @cbsAppDate) + 1, 0))

--SELECT @cbsAppDate,@fromDate,@toDate

DECLARE @startNo INT= 0;
DECLARE @endNo INT = (SELECT (DATEDIFF(DAY,@fromDate,@toDate)))

DECLARE @cgstproduct nvarchar(10)
DECLARE @sgstproduct nvarchar(10)
DECLARE @igstproduct nvarchar(10)
DECLARE @utgstproduct nvarchar(10)

select @cgstproduct = config_value from BSGADMIN..cbs_config  where config_key='CGST_PRODUCT' and is_active=1
select @sgstproduct = config_value from BSGADMIN..cbs_config  where config_key='SGST_PRODUCT' and is_active=1
select @igstproduct = config_value from BSGADMIN..cbs_config  where config_key='IGST_PRODUCT' and is_active=1
select @utgstproduct = config_value from BSGADMIN..cbs_config  where config_key='UTGST_PRODUCT' and is_active=1

SELECT * INTO #productMasterInternal from BSGCORE..product_master_internal pl WITH(NOLOCK) where product_code IN(@cgstproduct,@sgstproduct,@igstproduct,@utgstproduct) and is_active=1

----------2504	SB - Regular			100(plus GST)	Quarterly	190000000145	1	Rural - Rs. 500,Semi-Urban - Rs. 1000,Metro/ Urban -Rs. 2000
----------2506	SB- Premium				300(plus GST)	Quarterly	190000000150	2	25000
----------2508	SB-TASC					100(plus GST)	Quarterly	190000000916	3	100000
----------2509	SB-SHG NRLM				100(plus GST)	Quarterly	190001000161	4	500
----------1101	CA Regular-Corporate	100(plus GST)	Quarterly	190000000750	5	Rural - Rs. 2500,Urban & Semi-Urban - Rs. 5000
----------1102	CA Plus-Retail			300(plus GST)	Quarterly	190000000779	6	Rural - Rs. 5000,Urban & Semi-Urban - Rs. 10000
----------1109	CA - TASC-Retail		300(plus GST)	Quarterly	190000000828	7	100000
----------2510	SB - Children			50(plus GST)	Quarterly	190001000161	4	1000
----------2011	SB-Senior Citizen		150(plus GST)	Quarterly	190001000161	4	5000

--productCode,description,gstamount,frequency,placcountNo,condition



CREATE TABLE #PLAccountMapp(account_id INT, PLAccount VARCHAR(30), branch_code INT, productId INT, productCodeLogic INT)
INSERT INTO #PLAccountMapp 
select account_id,account_no,branch_code,product_id, 
CASE 
	WHEN account_no like '%90000000145' THEN 1
	WHEN account_no like '%90000000150' THEN 2
	WHEN account_no like '%90000000916' THEN 3
	WHEN account_no like '%90001000161' THEN 4
	WHEN account_no like '%90000000750' THEN 5
	WHEN account_no like '%90000000779' THEN 6
	WHEN account_no like '%90000000828' THEN 7
ELSE 0
END productCodeLogic
from BSGACCOUNTING..customer_view with(nolock)
where (account_no like '%90000000145'
OR account_no like '%90000000150'
OR account_no like '%90000000916'
OR account_no like '%90001000161'
OR account_no like '%90000000750'
OR account_no like '%90000000779'
OR account_no like '%90000000828') AND classification_id = 5;

--SB MinBal
;WITH numGen AS
(
	SELECT @startNo AS rNum, DATEADD(DAY,@startNo,@fromDate) date
	UNION ALL
	SELECT rNum+1,DATEADD(DAY,rNum+1,@fromDate) date FROM numGen WHERE rNum+1 <= @endNo
)

SELECT *,'G' type
INTO #dateGeneration
FROM numGen
OPTION (maxrecursion 1000)

SELECT b.account_id,CAST(AVG(b.available_balance) AS DECIMAL(18,2)) avgBal 
INTO #AvgBal
FROM (
SELECT 
	a.account_id
	,ab.available_balance
	,a.Maxtxn_date
	,a.date 
	,a.monthPart
FROM (
SELECT 
	am.account_id
	,dg.rNum
	,MAX(ISNULL(ab.txn_date,am.account_open_date)) Maxtxn_date
	,dg.date
	,DATEPART(M,DATEADD(DAY,dg.rNum,@fromdate)) monthPart
FROM 
	BSGCORE..customer_accounts ca WITH(NOLOCK)
	INNER JOIN BSGCRM..customer_master cm WITH(NOLOCK)
		ON ca.customer_id=cm.customer_id
		AND cm.is_active=1
		AND ISNULL(cm.staff_flag,0)<>1
	INNER JOIN BSGCORE..account_master am WITH(NOLOCK)
		ON ca.account_id=am.account_id
		AND am.is_active=1
	INNER JOIN #dateGeneration dg WITH(NOLOCK)
		ON dg.type='G'
		AND DATEADD(DAY,dg.rNum,@fromdate) <= @toDate
	LEFT JOIN BSGACCOUNTING..account_balance ab WITH(NOLOCK)
		ON am.account_id=ab.account_id
		AND ab.txn_date <= DATEADD(DAY,dg.rNum,@fromDate)
WHERE
	ca.is_active=1 
	AND am.account_open_date<=@fromDate
	AND	am.account_status_id = 1
	AND am.product_code IN (2504,2506,2508,2509,1101,1102,1109,2510,2011)
	AND DATEADD(DAY,dg.rNum,@fromdate) >= am.account_open_date
	AND ca.account_id IN (11689770,11691649,8550715,10908662,8980680,8696982,8725387,8730861,11447606)
	
GROUP BY 
	am.account_id
	,dg.rNum
	,dg.date
) a
INNER JOIN BSGACCOUNTING..account_balance ab WITH (NOLOCK)
	ON a.account_id=ab.account_id
	AND a.Maxtxn_date=ab.txn_date
)b
GROUP BY b.account_id

SELECT 
	ca.account_id,
	ca.account_no,
	ca.classification_id,
	am.branch_code,
	am.product_code,
	am.product_id,
	(SELECT pl.account_id FROM #PLAccountMapp pl WITH(NOLOCK) WHERE pl.productCodeLogic = 
	CASE
		WHEN am.product_code IN (2504) THEN 1 
		WHEN am.product_code IN (2506) THEN 2
		WHEN am.product_code IN (2508) THEN 3
		WHEN am.product_code IN (2509,2510,2011) THEN 4
		WHEN am.product_code IN (1101) THEN 5
		WHEN am.product_code IN (1102) THEN 6
		WHEN am.product_code IN (1109) THEN 7
	END AND  pl.branch_code=am.branch_code ) plAccountId,
	(SELECT pl.productId FROM #PLAccountMapp pl WITH(NOLOCK) WHERE pl.productCodeLogic = 
	CASE
		WHEN am.product_code IN (2504) THEN 1 
		WHEN am.product_code IN (2506) THEN 2
		WHEN am.product_code IN (2508) THEN 3
		WHEN am.product_code IN (2509,2510,2011) THEN 4
		WHEN am.product_code IN (1101) THEN 5
		WHEN am.product_code IN (1102) THEN 6
		WHEN am.product_code IN (1109) THEN 7
	END AND  pl.branch_code=am.branch_code ) plProductId,
	(SELECT pl.PLAccount FROM #PLAccountMapp pl WITH(NOLOCK) WHERE pl.productCodeLogic = 
	CASE
		WHEN am.product_code IN (2504) THEN 1 
		WHEN am.product_code IN (2506) THEN 2
		WHEN am.product_code IN (2508) THEN 3
		WHEN am.product_code IN (2509,2510,2011) THEN 4
		WHEN am.product_code IN (1101) THEN 5
		WHEN am.product_code IN (1102) THEN 6
		WHEN am.product_code IN (1109) THEN 7
	END AND  pl.branch_code=am.branch_code ) plAccountNo
	,
	CASE 
		WHEN am.product_code IN (2510) THEN 50
		WHEN am.product_code IN (2504,2508,2509,1101) THEN 100
		WHEN am.product_code IN (2011) THEN 150
		WHEN am.product_code IN (2506,1102,1109) THEN 300
	END charge_value
INTO #ChargeAccountId
FROM 
	#AvgBal avgb WITH(NOLOCK)
	INNER JOIN BSGCORE..customer_accounts ca WITH(NOLOCK)
		ON avgb.account_id=ca.account_id
	INNER JOIN BSGCRM..customer_master cm WITH(NOLOCK)
		ON ca.customer_id=cm.customer_id
		AND cm.is_active=1
		AND ISNULL(cm.staff_flag,0)<>1
	INNER JOIN BSGCORE..account_master am WITH(NOLOCK)
		ON avgb.account_id=am.account_id
		AND am.is_active=1
	INNER JOIN BSGMASTER..branch_master bm WITH(NOLOCK)
		ON am.branch_code=bm.branch_code
		AND bm.is_active=1
WHERE 
	ca.is_active=1
	AND avgb.avgBal < 
	CASE 
		WHEN am.product_code IN (2506) THEN 25000
		WHEN am.product_code IN (2508,1109) THEN 100000
		WHEN am.product_code IN (2509) THEN 500
		WHEN am.product_code IN (2510) THEN 1000
		WHEN am.product_code IN (2011) THEN 5000
		WHEN am.product_code IN (2504) AND bm.branch_area_type = 1 THEN 2000 --URBAN
		WHEN am.product_code IN (2504) AND bm.branch_area_type = 2 THEN 500	--RURAL
		WHEN am.product_code IN (2504) AND bm.branch_area_type = 3 THEN 1000	--SEMI-URBAN
		WHEN am.product_code IN (1101) AND bm.branch_area_type IN (1,3) THEN 5000 --URBAN,SEMI-URBAN
		WHEN am.product_code IN (1101) AND bm.branch_area_type = 2 THEN 2500	--RURAL
		WHEN am.product_code IN (1102) AND bm.branch_area_type IN (1,3) THEN 10000	--URBAN,SEMI-URBAN
		WHEN am.product_code IN (1102) AND bm.branch_area_type = 2 THEN 5000	--RURAL
	ELSE
		0
	END


--SELECT * FROM #ChargeAccountId

INSERT INTO BSGACCOUNTING..[charge_collection]
(
    [account_no],[account_id],[product_code],[product_id],[pl_account_no],[pl_account_id],[sgst_product_code],[sgst_product_id],
    [cgst_product_code],[cgst_product_id],[igst_product_code],[igst_product_id],[utgst_product_code],[utgst_product_id],[charge_activity],[classification_id],[charge_amount],
    [cgst],[sgst],[igst],[utgst],[narration],[notification_mode],[status],[run_date],
    [created_by],[created_date],[modified_by],[modified_date],
    [is_active],[account_balance],[charge_type],[pl_product_id],[account_branch],[charge_id]
) 

SELECT	
	ct.account_no,
	ct.account_id,
	ct.product_code,
	ct.product_id,
	ct.plAccountNo,
	ct.plAccountId,
	@sgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@sgstproduct and  pl.branch_code=ct.branch_code),
    @cgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@cgstproduct and  pl.branch_code=ct.branch_code),
    @igstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@igstproduct and  pl.branch_code=ct.branch_code),
    @utgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@utgstproduct and  pl.branch_code=ct.branch_code),
	11081 [charge_activity],
	ct.classification_id,
	CAST(ct.charge_value AS decimal(18,2)),
	0 cgst,
    0 sgst,
    0 igst,
    0 utgst,
	IIF(MONTH(@fromdate)!=MONTH(@todate),CONCAT('Min. Balance Charges.',DATENAME(month,@fromdate) ,' ',YEAR(@fromdate),' to ', Datename(month,@todate),' ',YEAR(@todate)),CONCAT('Min. Balance Charges.',DATENAME(MONTH,@fromdate),' ',YEAR(@fromdate))),
	1,
	0,
	@cbsAppDate,
	786 [created_by],
	GETDATE() [created_date],
	786 [modified_by],
	GETDATE() [modified_date],
	1 [is_active],
	ab.available_balance,
	25 [charge_type],
	ct.plProductId [pl_product_id],
	ct.branch_code,
	3 [charge_id]
from 
	#ChargeAccountId ct WITH(NOLOCK)
	INNER JOIN BSGACCOUNTING..account_balance ab WITH(NOLOCK)
	ON ct.account_id=ab.account_id
	INNER JOIN (SELECT account_id,MAX(txn_date) maxDate FROM BSGACCOUNTING..account_balance WITH(NOLOCK) GROUP BY account_id) abb
	ON ab.account_id=abb.account_id
	AND ab.txn_date=abb.maxDate

--DROP TABLE #AvgBal
--DROP TABLE #ChargeAccountId
--DROP table #dateGeneration
--DROP TABLE #PLAccountMapp
--DROP TABLE #productMasterInternal

	EXEC ChargeCollection_GstUpdate 3

	EXEC ChargeCollection_ValidationCheck 3
END