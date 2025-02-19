-- =============================================
-- Author:        <Ashish L>
-- Create date:	  <2023-06-27 19:21:30.957> SELECT GETDATE()
-- Description:   <NPA PROVISION>
-- Exec: npa_provision_details '2023-06-26'
-- =============================================
CREATE    PROCEDURE [dbo].[npa_provision_details]
(
	@cbsAppDate DATE
)
AS
BEGIN

SELECT 
	lam.loan_account_id,
	lam.loan_account_no,
	lam.loan_account_status,
	lam.asset_classification,
	lam.loan_product_code,
	lam.loan_product_id,
	lam.branch_code,
	lam.customer_no,
	lam.date_of_account_opening,
	lab.loan_amount,
	CASE WHEN ISNULL(abb.checker_clear_balance,0)<0 THEN -1*ISNULL(abb.checker_clear_balance,0) ELSE 0 END  checker_clear_balance,
	ISNULL(lpm.is_secured,0) is_secured
	--ISNULL(abb.available_balance,0) available_balance,
	--ISNULL(abb.available_dp,0) available_dp,
	--ISNULL(abb.checker_unclear_balance,0) checker_unclear_balance,
	--ISNULL(abb.principal_outstanding,0) principal_outstanding,
	--ISNULL(abb.sanction_limit,0) sanction_limit,
INTO #loanBasicDetails
FROM 
	BSGLOAN..loan_account_master lam WITH(NOLOCK)
	INNER JOIN BSGLOAN..loan_account_basic lab WITH(NOLOCK)
	ON lam.loan_account_id=lab.loan_account_id
	AND lab.is_active=1
	LEFT JOIN BSGLOAN..loan_product_master lpm WITH(NOLOCK)
	ON lam.loan_product_id=lpm.loan_product_id
	AND lpm.is_active=1
	LEFT JOIN (
			SELECT 
				abl.checker_clear_balance,
				abl.loan_account_id
				--abl.available_balance,
				--abl.available_dp,
				--abl.checker_unclear_balance,
				--abl.principal_outstanding,
				--abl.sanction_limit,
			FROM BSGACCOUNTING..account_balance_loan abl WITH(NOLOCK)
			INNER JOIN (SELECT loan_account_id loanAccountId,MAX(txn_date) maxTxnDate FROM BSGACCOUNTING..account_balance_loan WITH(NOLOCK) 
			where txn_date <= @cbsAppDate GROUP BY loan_account_id) abbl
			ON abl.loan_account_id=abbl.loanAccountId
			AND abl.txn_date=abbl.maxTxnDate) abb
	ON lam.loan_account_id=abb.loan_account_id
WHERE 
	lam.is_active=1
	AND (lam.loan_account_status!=2 OR abb.checker_clear_balance <> 0)

SELECT 
	lbd.*,
	ISNULL(dmmu.defaulter_type,-1) defaulter_type
INTO #LoanAccountDefaulter
FROM 
	#loanBasicDetails lbd WITH(NOLOCK)
	LEFT JOIN BSGLOAN..defaulter_master_marking_unmarking dmmu WITH(NOLOCK)
	ON lbd.loan_account_id=dmmu.loan_account_id
	AND dmmu.is_active=1

SELECT 
	DISTINCT
	loan_account_id,
	is_secured,
	--defaulter_type,
	STUFF (
	(SELECT ','+CAST(defaulter_type AS VARCHAR(50)) FROM #LoanAccountDefaulter a
	WHERE a.loan_account_id=b.loan_account_id order by  loan_account_id,defaulter_type
	FOR XML PATH('')), 1, 1, '') [defaulter_match]
INTO #DefaulterDetails
FROM 
	#LoanAccountDefaulter b

SELECT dd.*,
	ISNULL(df_matrix_id,-1) df_matrix_id,
	ISNULL(df_mapping_description,'REGULAR') df_mapping_description
INTO #DefaulterCompleteDetails
FROM 
	#DefaulterDetails dd WITH(NOLOCK)
	LEFT JOIN BSGACCOUNTING..npa_defaulter_matrix ndm WITH(NOLOCK)
	ON dd.defaulter_match=ndm.df_mapping
	AND ndm.is_active=1

----

UPDATE TMP SET
TMP.df_matrix_id = CASE WHEN PM.is_secured=0 AND is_agricultural=0 THEN 4
		WHEN PM.is_secured=0 AND is_agricultural=1 THEN 5
	  WHEN PM.is_secured=1 AND is_agricultural=0 THEN 6
	  ELSE -1 end
FROM #DefaulterCompleteDetails tmp
INNER JOIN BSGLOAN..loan_account_master lm
	ON TMP.loan_account_id=LM.loan_account_id AND LM.is_active=1
	AND TMP.df_matrix_id=-1
INNER JOIN BSGLOAN..loan_product_master PM
	ON LM.loan_product_id=PM.loan_product_id
	and pm.is_active=1

----
SELECT 
	IIF(dcd.is_secured=1,npm.secured_percentage,npm.unsecured_percentage) provision_percentage,
	IIF(dcd.is_secured=1,(lbd.checker_clear_balance*(npm.secured_percentage/100.00)),(lbd.checker_clear_balance*(npm.unsecured_percentage/100.00))) provision_amount,
	lbd.loan_account_no,
	dcd.loan_account_id,
	dcd.is_secured,
	dcd.df_matrix_id,
	dcd.defaulter_match,
	dcd.df_mapping_description,
	lbd.checker_clear_balance,
	lbd.asset_classification
	--,npm.*
INTO #npaProvisionDetails
FROM 
	#DefaulterCompleteDetails dcd WITH(NOLOCK)
	INNER JOIN #loanBasicDetails lbd WITH(NOLOCK)
	ON dcd.loan_account_id=lbd.loan_account_id
	INNER JOIN BSGACCOUNTING..npa_provision_matrix npm WITH(NOLOCK)
	ON dcd.df_matrix_id=npm.df_matrix_id
	AND lbd.asset_classification=npm.asset_classification
	AND npm.is_active=1
	INNER JOIN (
		SELECT df_matrix_id,
		asset_classification,
		MAX(effective_date) maxDate 
		FROM BSGACCOUNTING..npa_provision_matrix npm WITH(NOLOCK)
		WHERE is_active=1
		GROUP BY df_matrix_id,asset_classification) npmm
	ON npm.df_matrix_id=npmm.df_matrix_id
	AND npm.asset_classification=npmm.asset_classification
	AND npm.effective_date=npmm.maxDate

--SELECT 
--	a.*,
--	b.provision_amount,
--	b.provision_percentage
UPDATE 
	a
SET
	a.provision_amount=b.provision_amount,
	a.provision_percentage=b.provision_percentage
FROM 
	BSGACCOUNTING..loan_sma_classification_details a WITH(NOLOCK)
	INNER JOIN #npaProvisionDetails b
	ON a.loan_account_id=b.loan_account_id
	INNER JOIN (
		SELECT 
			loan_account_id,MAX(txn_date) maxDate 
		FROM 
			BSGACCOUNTING..loan_sma_classification_details WITH(NOLOCK)
		WHERE txn_date<=@cbsAppDate
		GROUP BY loan_account_id
	) c
	ON a.loan_account_id=c.loan_account_id
	AND a.txn_date=c.maxDate

END