
-- =============================================
-- Author:		Siddharth Mangroliya
-- Create date: 27-Jan-2020
-- Description:	Get Non Empty Pre processing tables list
-- =============================================
CREATE     PROCEDURE [dbo].[sp_get_count_non_empty_preprocessing_tables] 
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'loan_interest_details' AS tables_name, COUNT(1) AS table_count FROM loan_interest_details HAVING COUNT(1) > 0 
	UNION ALL 
	SELECT 'td_interest_application', COUNT(1) FROM td_interest_application HAVING COUNT(1) > 0 
	UNION ALL 
	SELECT 'casa_interest_details', COUNT(1) FROM casa_interest_details  HAVING COUNT(1) > 0 
	UNION ALL 
	SELECT 'min_bal_charges_on_accounts', COUNT(1) FROM min_bal_charges_on_accounts HAVING COUNT(1) > 0 
	UNION ALL 
	SELECT 'folio_charges_on_accounts', COUNT(1) FROM folio_charges_on_accounts HAVING COUNT(1) > 0 
	UNION ALL 
	SELECT 'maintenance_charges_on_accounts', COUNT(1) FROM maintenance_charges_on_accounts HAVING COUNT(1) > 0 
	UNION ALL 
	SELECT 'inoperative_charges_on_accounts', COUNT(1) FROM inoperative_charges_on_accounts HAVING COUNT(1) > 0
	UNION ALL 
	SELECT 'interest_accural_pnr_pl_posting', COUNT(1) FROM interest_accrual_pnr_pl_posting HAVING COUNT(1) > 0;
END


