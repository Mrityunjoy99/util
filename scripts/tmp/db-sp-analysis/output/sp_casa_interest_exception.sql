
-- =============================================
-- Author:		Vatsal Sura
-- Create date: 2020-02-10
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_casa_interest_exception] 
AS
BEGIN
	DECLARE @txnDate DATE = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1);
	SET NOCOUNT ON;

	SELECT CONCAT('Product Code-', am.product_code, ', Count-', COUNT(1)) details 
	FROM BSGCORE..account_master am 
	INNER JOIN BSGCORE..customer_accounts ca 
	ON ca.account_id = am.account_id AND ca.classification_id = 2 AND ca.is_active = 1 
	INNER JOIN (SELECT account_id, MAX(txn_date) txn_date FROM BSGACCOUNTING..account_balance WHERE is_active = 1 GROUP BY account_id) maxab 
	ON maxab.account_id = am.account_id 
	INNER JOIN BSGACCOUNTING..account_balance ab 
	ON ab.account_id = am.account_id 
	AND ab.txn_date = maxab.txn_date 
	AND ab.is_active = 1 
	LEFT JOIN BSGACCOUNTING..account_accrual_reset aar 
	ON aar.classification_id = ca.classification_id 
	AND (aar.branch_code = am.branch_code OR aar.branch_code = -1) 
	AND (aar.product_code = am.product_code OR aar.product_code = -1) 
	AND aar.txn_date = @txnDate AND aar.is_active = 1 
	WHERE am.account_status_id NOT IN (4, 8) AND am.is_active = 1 
	AND ab.interest_accrual <= 0 AND aar.id IS NULL  
	GROUP BY am.product_code;
END

