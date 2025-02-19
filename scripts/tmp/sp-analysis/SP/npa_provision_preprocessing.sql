-- =============================================
-- Author:        <Ashish L>
-- Create date:      <2023-07-06 11:25:41.177> SELECT GETDATE()
-- Description:   <NPA PROVISION PRE-PROCESSING DATA>
-- Exec: npa_provision_preprocessing '2023-06-30'
-- =============================================
CREATE   PROCEDURE [dbo].[npa_provision_preprocessing]
(
    @cbsAppDate DATE = null,
	@employeeId INT = -223
)
AS
BEGIN

 

--DECLARE @cbsAppDate DATE = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date NOLOCK WHERE is_active=1)
--SET @cbsAppDate = DATEADD(DAY,-1,@cbsAppDate)
PRINT @cbsAppDate

 

--============================================================
-- Details Provided By North East Bank
--PL-ACCOUNT
--90000000350: Provision of Standard A
--90000000352: Provision of NPA
--GL Product
--7805: Provision for Standard Assets-L
--7801: Provision for Sub-Standard Assets
--7802: Provision for Doubtfull Assets-L
--============================================================

 

CREATE TABLE #PLAccountNo
(
    plAccountNo VARCHAR(20),
    plAccountId INT,
    branchCode INT,
    assetClassification VARCHAR(20)
)
INSERT INTO #PLAccountNo
SELECT 
    cv.account_no,cv.account_id,cv.branch_code,'STANDARD' 
FROM 
    BSGACCOUNTING..customer_view cv WITH(NOLOCK)
    INNER JOIN BSGCORE..account_master_internal ami WITH(NOLOCK)
        ON cv.account_id=ami.internal_account_id
        AND ami.is_active=1
WHERE 
    cv.account_no LIKE '%90000000350'
UNION
SELECT 
    cv.account_no,cv.account_id,cv.branch_code,'NPA' 
FROM 
    BSGACCOUNTING..customer_view cv WITH(NOLOCK)
    INNER JOIN BSGCORE..account_master_internal ami WITH(NOLOCK)
        ON cv.account_id=ami.internal_account_id
        AND ami.is_active=1
WHERE 
    cv.account_no LIKE '%90000000352'

 

--SELECT * FROM #PLAccountNo

 

CREATE TABLE #GLProductCode
(
    creditProductCode INT,
    creditProductId INT,
    branchCode INT,
    assetClassification VARCHAR(20)
)

 

INSERT INTO #GLProductCode
SELECT product_code,internal_product_id,branch_code,'STANDARD' FROM BSGCORE..product_master_internal NOLOCK WHERE product_code=7805 and is_active = 1
UNION
SELECT product_code,internal_product_id,branch_code,'SUB-STANDARD' FROM BSGCORE..product_master_internal NOLOCK WHERE product_code=7801 and is_active = 1
UNION
SELECT product_code,internal_product_id,branch_code,'NPA' FROM BSGCORE..product_master_internal NOLOCK WHERE product_code=7802 and is_active = 1

 

--SELECT * FROM #GLProductCode

 

INSERT INTO BSGACCOUNTING..npa_provision_preprocessing_data
(
    [branch_code],[product_code],[asset_classification],[sum_of_provision_amount],[txn_date],[txn_ref_no],
    [is_processing],[is_reversal],[pl_account_id],[gl_product_id],[created_by],[created_date],[last_modified_by],
    [last_modified_date],[is_active],[reversal_txn_ref_no]
)

 

SELECT 
    pro1.branch_code,
    pro1.loan_product_code,
    pro1.asset_classification,
    pro1.sumOfProvisionAmount,
    @cbsAppDate txnDate,
    -1 txnRefNo,
    0 isProcessing,
    0 isReversal,
    CASE 
        WHEN asset_classification IN (1,2) THEN (SELECT plAccountId FROM #PLAccountNo pl WHERE pl.branchCode=pro1.branch_code AND pl.assetClassification = 'STANDARD')
        ELSE (SELECT plAccountId FROM #PLAccountNo pl WHERE pl.branchCode=pro1.branch_code AND pl.assetClassification = 'NPA')
    END DebitPlAccountId,
    CASE 
        WHEN asset_classification IN (1,2) THEN (SELECT gl.creditProductId FROM #GLProductCode gl WHERE gl.branchCode=pro1.branch_code AND gl.assetClassification = 'STANDARD')
        WHEN asset_classification IN (3) THEN (SELECT gl.creditProductId FROM #GLProductCode gl WHERE gl.branchCode=pro1.branch_code AND gl.assetClassification = 'SUB-STANDARD')
        ELSE (SELECT gl.creditProductId FROM #GLProductCode gl WHERE gl.branchCode=pro1.branch_code AND gl.assetClassification = 'NPA')
    END CreditGLProductId,
    @employeeId,
    GETDATE(),
    @employeeId,
    GETDATE(),
    1,
	-1
FROM(
SELECT 
    SUM(provision_amount) sumOfProvisionAmount,
    branch_code,
    loan_product_code,
    asset_classification
FROM(
    SELECT 
        lam.loan_account_id,
        lam.loan_account_no,
        lscd.asset_classification,
        lam.loan_product_code,
        lam.branch_code,
        lscd.provision_amount
    FROM
        BSGACCOUNTING..loan_sma_classification_details lscd WITH(NOLOCK)
        INNER JOIN BSGLOAN..loan_account_master lam WITH(NOLOCK)
        ON lscd.loan_account_id=lam.loan_account_id
        AND lam.is_active=1
    WHERE 
        txn_date = @cbsAppDate
) pro
GROUP BY 
    branch_code,
    loan_product_code,
    asset_classification
) pro1
ORDER BY branch_code,loan_product_code,asset_classification

 

END
