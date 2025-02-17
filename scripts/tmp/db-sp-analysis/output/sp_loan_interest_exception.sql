-- =============================================
-- Author:		Vatsal Sura
-- Create date: 2020-02-07
-- Description:	<Description,,>
-- =============================================
CREATE     PROCEDURE [dbo].[sp_loan_interest_exception] 
--[sp_loan_interest_exception] '2020-08-31',1
	@cbsAppDate DATE, 
	@fetchAllAccounts INT
AS
BEGIN
	DECLARE @txnDate DATE = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1);
	SET NOCOUNT ON;

	SELECT lam.loan_account_no, lam.loan_account_id, lam.date_of_account_opening, lam.asset_classification 
	, lab.loan_amount, lab.rate_of_interest, lab.offset, lab.disbursement_date, lab.limit_expiry_date, abl.checker_clear_balance, abl.interest_accrual
	, lpm.interest_frequency, lpm.interest_calculation_on, lpm.interest_rate_type, lpm.prime_security_type, @cbsAppDate interest_date 
	, iem.account_id exception_account_id, iem.remarks 
	, (SELECT CONCAT(employee_code, '-', name) FROM BSGADMIN..employee_master WHERE employee_id = iem.created_by AND is_active = 1) exception_created_by 
	, iem.created_date exception_created_date 
	, ium.account_id update_account_id, ium.old_value old_value, ium.new_value new_value 
	, (SELECT CONCAT(employee_code, '-', name) FROM BSGADMIN..employee_master WHERE employee_id = ium.created_by AND is_active = 1) update_created_by 
	, ium.created_date update_created_date 
	FROM BSGLOAN..loan_account_master lam 
	INNER JOIN BSGLOAN..loan_account_basic lab 
	ON lab.loan_account_id = lam.loan_account_id AND lab.is_active = 1 
	INNER JOIN (SELECT loan_account_id, MAX(txn_date) txn_date 
	FROM BSGACCOUNTING..account_balance_loan 
	-- WHERE is_active = 1 
	GROUP BY loan_account_id) maxabl 
	ON maxabl.loan_account_id = lam.loan_account_id 
	INNER JOIN BSGACCOUNTING..account_balance_loan abl 
	ON abl.loan_account_id = lam.loan_account_id 
	AND abl.txn_date = maxabl.txn_date 
	AND abl.is_active = 1 
	INNER JOIN BSGLOAN..loan_product_master lpm 
	ON lpm.loan_product_id = lam.loan_product_id 
	AND lpm.loan_product_code NOT IN (0) 
	AND lpm.interest_frequency <= CASE MONTH(@txnDate) WHEN 3 THEN 4 WHEN 9 THEN 3 WHEN 6 THEN 2 WHEN 12 THEN 2 ELSE 1 END 
	AND lpm.is_active = 1 
	LEFT JOIN BSGACCOUNTING..interest_exception_master iem 
	ON iem.account_id = lam.loan_account_id 
	AND iem.txn_date = (SELECT MAX(txn_date) FROM BSGACCOUNTING..interest_exception_master WHERE account_id = lam.loan_account_id AND is_active = 1) 
	AND iem.is_active = 1 
	LEFT JOIN BSGACCOUNTING..interest_update_master ium 
	ON ium.account_id = lam.loan_account_id AND ium.txn_date = @txnDate AND ium.is_active = 1 
	WHERE lam.date_of_account_opening < @txnDate AND lam.loan_account_status <> 2 AND lam.is_active = 1 
	AND ((lpm.interest_calculation_on = 1 AND (abl.checker_clear_balance + ((-1) * (abl.npa_interest_amount + abl.npa_penal_interest_amount + abl.npa_charges_amount)) + (abl.subsidy_received - abl.subsidy_realised)) < 0) 
	OR (lpm.interest_calculation_on = 2 AND (abl.principal_outstanding + (abl.subsidy_received - abl.subsidy_realised)) < 0)) 
	AND ((@fetchAllAccounts = 0 AND abl.interest_accrual <= 0 AND (iem.account_id IS NULL OR iem.txn_date <> @txnDate)) 
	OR (@fetchAllAccounts = 1 AND (ium.account_id IS NOT NULL OR (iem.account_id IS NOT NULL AND iem.txn_date = @txnDate))));
END


