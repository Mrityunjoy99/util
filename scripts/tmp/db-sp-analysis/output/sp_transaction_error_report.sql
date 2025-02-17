
-- =============================================
-- Author: Ashish Lalbige
-- Create date: 2022-10-28 18:24:08.987 --SELECT GETDATE()
-- Description: Transaction Error report for instr no 000000 CASA account Debit Nature. 
-- exec sp_transaction_error_report
-- =============================================

create    PROCEDURE [dbo].[sp_transaction_error_report]
AS
BEGIN

DECLARE @cbsAppDate date = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)

SELECT ca.account_no,t.txn_nature,t.txn_amount,classification_id, t.instr_no, t.created_by, t.last_modified_by
FROM 
	BSGCORE..customer_accounts ca WITH(NOLOCK)
	INNER JOIN	BSGACCOUNTING..transaction_master t WITH(NOLOCK)
	ON ca.account_id=ca.account_id
	AND ca.is_active=1
WHERE 
	t.is_active=1 
	AND t.instr_no=000000 
	AND t.txn_nature='D'
	AND t.txn_posting_date = @cbsAppDate
	AND ca.classification_id IN (1,2)

END
