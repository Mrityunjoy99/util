-- =============================================
-- Author:        <Ashish L>
-- Create date:	  <2022-12-31>
-- Description:   <ChargeCollection_LoanCommitmentCharges>
-- Eexc: ChargeCollection_LoanCommitmentCharges
-- =============================================
CREATE   PROCEDURE [dbo].[ChargeCollection_LoanCommitmentCharges]
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
where account_no like '%90000000299'

SELECT * INTO #productMasterInternal from BSGCORE..product_master_internal pl WITH(NOLOCK) where product_code IN(@cgstproduct,@sgstproduct,@igstproduct,@utgstproduct) and is_active=1

DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)
DECLARE @fromdate DATETIME = '2023-09-01'--DATEADD(month, DATEDIFF(month, 0, @cbsAppDate), 0)
DECLARE @todate DATETIME = '2023-09-30'--CAST(eomonth(@cbsAppDate) AS datetime)

DECLARE @startNo INT= 0;
DECLARE @endNo INT = (SELECT (DATEDIFF(DAY,@fromDate,@toDate)))

;WITH numGen AS
(
	SELECT @startNo AS rNum, DATEADD(DAY,@startNo,@fromDate) date
	UNION ALL
	SELECT rNum+1,DATEADD(DAY,rNum+1,@fromDate) date FROM numGen WHERE rNum+1 <= @endNo
)

SELECT rNum,CAST(date AS DATE) date,'G' type
INTO #dateGeneration
FROM numGen
OPTION (maxrecursion 5000)

--SELECT * FROM #dateGeneration

SELECT b.loan_account_id,b.loan_account_no,AVG(b.newAvailableBalance) avgBal, loan_amount
INTO #data
FROM (
SELECT 
	a.loan_account_id,
	a.loan_account_no
	,ab.checker_clear_balance+ab.checker_unclear_balance as newAvailableBalance
	,ab.available_balance
	,a.Maxtxn_date
	,a.date 
	,a.monthPart
	--,CASE WHEN ab.sanction_limit=0 THEN lab.loan_amount ELSE ab.sanction_limit END sanction_limit
	,lab.loan_amount
FROM (
SELECT 
	am.loan_account_id,
	am.loan_account_no
	,dg.rNum
	,MAX(ISNULL(ab.txn_date,am.date_of_account_opening)) Maxtxn_date
	,dg.date
	,DATEPART(M,DATEADD(DAY,dg.rNum,@fromdate)) monthPart
FROM 
	BSGLOAN..loan_account_master am WITH(NOLOCK)
	INNER JOIN #dateGeneration dg WITH(NOLOCK)
		ON dg.type='G'
		AND DATEADD(DAY,dg.rNum,@fromdate) <= @toDate
	LEFT JOIN BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK)
		ON am.loan_account_id=ab.loan_account_id
		AND ab.txn_date <= DATEADD(DAY,dg.rNum,@fromDate)
WHERE 
	am.loan_account_status<>2
	AND am.is_active=1 
	AND am.asset_classification < 3
	AND am.loan_product_code IN (6903)
	AND DATEADD(DAY,dg.rNum,@fromdate) >= am.date_of_account_opening
	--AND am.loan_account_no='74230000004455'
GROUP BY 
	am.loan_account_id,
	am.loan_account_no
	,dg.rNum
	,dg.date
) a
INNER JOIN BSGACCOUNTING..account_balance_loan ab WITH (NOLOCK)
	ON a.loan_account_id=ab.loan_account_id
	AND a.Maxtxn_date=ab.txn_date
INNER JOIN BSGLOAN..loan_account_basic lab WITH(NOLOCK)
		ON a.loan_account_id=lab.loan_account_id
		AND lab.is_active=1
		AND lab.limit_expiry_date>=@todate
		AND lab.loan_amount>0
)b
GROUP BY b.loan_account_id,b.loan_account_no, loan_amount



SELECT 
	loan_amount*0.60 AmountToUse
	,-avgBal avgb,(loan_amount - (-avgBal)) unUsedAmount,
	IIF(-avgBal<loan_amount*0.60, (loan_amount - (-avgBal))*0.02,0) ChargeAmount
	,*
INTO #ChargeAmount
FROM #data

INSERT INTO BSGACCOUNTING..[charge_collection]
(
    [account_no],[account_id],[product_code],[product_id],[pl_account_no],[pl_account_id],[sgst_product_code],[sgst_product_id],
    [cgst_product_code],[cgst_product_id],[igst_product_code],[igst_product_id],[utgst_product_code],[utgst_product_id],[charge_activity],[classification_id],[charge_amount],
    [cgst],[sgst],[igst],[utgst],[narration],[notification_mode],[status],[run_date],
    [created_by],[created_date],[modified_by],[modified_date],
    [is_active],[account_balance],[charge_type],[pl_product_id],[account_branch],[charge_id]
)    

SELECT
    am.loan_account_no,
    am.loan_account_id,
    am.loan_product_code,
    am.loan_product_id,
    pl.PLAccount PLAccount,
    pl.account_id,
    @sgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@sgstproduct and  pl.branch_code=am.branch_code),
    @cgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@cgstproduct and  pl.branch_code=am.branch_code),
    @igstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@igstproduct and  pl.branch_code=am.branch_code),
    @utgstproduct,
    (select TOP 1 internal_product_id from #productMasterInternal pl WITH(NOLOCK) where product_code=@utgstproduct and  pl.branch_code=am.branch_code),
    11137 charge_activity,
    ca.classification_id,
    CAST(tf.ChargeAmount AS DECIMAL(18,2)) ChargeAmt,
    0 cgst,
    0 sgst,
    0 igst,
    0 utgst,
   IIF(MONTH(@fromdate)!=MONTH(@todate),CONCAT('Commitment Charges.',DATENAME(month,@fromdate) ,' ',YEAR(@fromdate),' to ', Datename(month,@todate),' ',YEAR(@todate),' UnusedAmount: ',CAST(tf.unUsedAmount AS DECIMAL(18,2))
	),CONCAT('Commitment Charges.',DATENAME(MONTH,@fromdate),' ',YEAR(@fromdate),' UnusedAmount: ',CAST(tf.unUsedAmount AS DECIMAL(18,2)))),
    1 notification_mode,
    0 status,
    @cbsAppDate run_date,
    786 [created_by],
    GETDATE() [created_date],
    786 [modified_by],
    GETDATE() [modified_date],
    1 [is_active],
    ab.available_balance,
    53 [charge_type],
    pl.productId [pl_product_id],
    am.branch_code,
    1 [charge_id]
from  
    #ChargeAmount tf  WITH(NOLOCK)    
    inner join BSGLOAN..loan_account_master am WITH(NOLOCK)
        on    tf.loan_account_id = am.loan_account_id
	AND am.loan_account_status<>2
	AND am.is_active=1 
	AND am.asset_classification < 3
	AND am.loan_product_code IN (6903)
	INNER JOIN BSGCORE..customer_accounts ca WITH(NOLOCK)
	ON am.loan_account_id=ca.account_id
	AND ca.is_active=1
	INNER JOIN BSGCRM..customer_master cm WITH(NOLOCK)
	ON ca.customer_id=cm.customer_id
	AND cm.is_active=1
	AND ISNULL(cm.staff_flag,0)<>1
    inner join BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK)
        on tf.loan_account_id = ab.loan_account_id
    inner join (select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK) group by loan_account_id)a
        on ab.loan_account_id = a.loan_account_id
        and ab.txn_date = a.txn_date
    INNER JOIN #PLAccountMapp pl WITH(NOLOCK)
        ON am.branch_code=pl.branch_code

EXEC ChargeCollection_GstUpdate 1

EXEC ChargeCollection_ValidationCheck 1 

END
