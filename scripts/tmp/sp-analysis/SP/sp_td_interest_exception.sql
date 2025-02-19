-- =============================================
-- Author:		Vatsal Sura
-- Create date: 2020-02-03
-- Description:	<Description,,>
-- =============================================
create    PROCEDURE [dbo].[sp_td_interest_exception]
	@cbsAppDate DATE,
	@fetchAllAccounts INT
AS
BEGIN
	DECLARE @txnDate DATE = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1);
	SET NOCOUNT ON;
	SELECT ca.account_no, tam.td_account_id, tam.td_amount, tadd.interest_start_date, tadd.maturity_date
	, tadd.next_interest_date, tadd.next_paid_date, tadd.base_rate, tadd.deposite_type, abt.checker_clear_balance
	, CASE WHEN tadd.deposite_type IN (1, 2) THEN tdi.interest ELSE abt.interest_accrual END interest, @cbsAppDate interest_date
	, iem.account_id exception_account_id
	, (SELECT CONCAT(employee_code, '-', name) FROM BSGADMIN..employee_master WHERE employee_id = iem.created_by AND is_active = 1) exception_created_by
	, iem.created_date exception_created_date
	, ium.account_id update_account_id, ium.old_value old_value, ium.new_value new_value
	, (SELECT CONCAT(employee_code, '-', name) FROM BSGADMIN..employee_master WHERE employee_id = ium.created_by AND is_active = 1) update_created_by
	, ium.created_date update_created_date
	FROM BSGTD..td_account_master tam
	INNER JOIN BSGTD..td_account_deposit_details tadd
	ON tadd.td_account_id = tam.td_account_id
	AND tadd.interest_start_date < @txnDate
	AND (tadd.next_interest_date = @cbsAppDate OR tadd.next_paid_date = @cbsAppDate)
	AND tadd.base_rate > 0
	AND tadd.is_active = 1
	INNER JOIN BSGCORE..customer_accounts ca
	ON ca.account_id = tam.td_account_id AND ca.is_active = 1
	INNER JOIN (SELECT td_account_id, MAX(id) id FROM BSGACCOUNTING..account_balance_td WHERE is_active = 1 GROUP BY td_account_id) maxabt
	ON maxabt.td_account_id = tam.td_account_id
	INNER JOIN BSGACCOUNTING..account_balance_td abt
	ON abt.td_account_id = tam.td_account_id
	AND abt.id = maxabt.id
	AND abt.checker_clear_balance > 0
	LEFT JOIN BSGACCOUNTING..td_datewise_interest tdi
	ON tdi.td_account_id = tam.td_account_id AND tdi.interest_date = @cbsAppDate AND tdi.is_active = 1
	LEFT JOIN BSGACCOUNTING..interest_exception_master iem
	ON iem.account_id = tam.td_account_id AND iem.txn_date = @txnDate AND iem.is_active = 1
	LEFT JOIN BSGACCOUNTING..interest_update_master ium
	ON ium.account_id = tam.td_account_id AND ium.txn_date = @txnDate AND ium.is_active = 1
	WHERE tam.account_status_id = 1 AND tam.is_active = 1
	AND tadd.td_amount + abt.interest_provided < tadd.computed_amount
	AND ((@fetchAllAccounts = 0 AND ((tadd.deposite_type IN (1, 2) AND (tdi.interest IS NULL OR tdi.interest <= 0))
	OR (tadd.deposite_type = 3 AND (abt.interest_accrual = 0))) AND iem.account_id IS NULL)
	OR (@fetchAllAccounts = 1 AND (ium.account_id IS NOT NULL OR iem.account_id IS NOT NULL)));
END
