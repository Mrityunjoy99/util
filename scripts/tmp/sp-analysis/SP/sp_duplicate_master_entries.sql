
-- =============================================
-- Author:		Siddharth Mangroliya
-- CREATE OR ALTER date: 30-1-2020
-- Description:	Duplicate Master Entries
-- =============================================
CREATE   PROCEDURE [dbo].[sp_duplicate_master_entries]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CONCAT('td_account_master', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT td_account_id, COUNT(1) AS totalAccount FROM BSGTD..td_account_master WHERE is_active = 1 GROUP BY td_account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.td_account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('td_account_deposit_details', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT td_account_id, COUNT(1) AS totalAccount FROM BSGTD..td_account_deposit_details WHERE is_active = 1 GROUP BY td_account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.td_account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('td_interest_payment', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT td_account_id, COUNT(1) AS totalAccount FROM BSGTD..td_interest_payment WHERE is_active = 1 GROUP BY td_account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.td_account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('td_product_master', '-', product_code, '-', product_id, '-', COUNT(1)) AS details FROM BSGTD..td_product_master WHERE is_active = 1 GROUP BY product_id, product_code HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('customer_accounts', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT account_id, COUNT(1) AS totalAccount FROM BSGCORE..customer_accounts WHERE is_active = 1 GROUP BY account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('account_master', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT account_id, COUNT(1) AS totalAccount FROM BSGCORE..account_master WHERE is_active = 1 GROUP BY account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('product_master', '-', product_code, '-', product_id, '-', COUNT(1)) AS details FROM BSGCORE..product_master WHERE is_active = 1 GROUP BY product_code, product_id HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('account_master_internal', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT internal_account_id, COUNT(1) AS totalAccount FROM BSGCORE..account_master_internal WHERE is_active = 1 GROUP BY internal_account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.internal_account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('product_master_internal', '-', product_code, '-', internal_product_id, '-', COUNT(1)) AS details FROM BSGCORE..product_master_internal WHERE is_active = 1 GROUP BY product_code, internal_product_id HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('customer_master', '-', customer_id, '-', COUNT(1)) AS details FROM BSGCRM..customer_master WHERE is_active = 1 GROUP BY customer_id HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('customer_ind_info', '-', customer_id, '-', COUNT(1)) AS details FROM BSGCRM..customer_ind_info WHERE is_active = 1 GROUP BY customer_id HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('customer_corp_info', '-', customer_id, '-', COUNT(1)) AS details FROM BSGCRM..customer_corp_info WHERE is_active = 1 GROUP BY customer_id HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('customer_tds', '-', customer_id, '-', COUNT(1)) AS details FROM BSGCRM..customer_tds WHERE is_active = 1 GROUP BY customer_id HAVING COUNT(1) > 1 
	UNION ALL 
	SELECT CONCAT('td_datewise_interest', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT td_account_id, COUNT(1) AS totalAccount FROM BSGACCOUNTING..td_datewise_interest WHERE is_active = 1 GROUP BY td_account_id, interest_date HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.td_account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('account_td_last_accrual', '-', ca.account_no, '-', ca.account_id, '-', a.totalAccount) AS details FROM 
	(SELECT td_account_id, COUNT(1) AS totalAccount FROM BSGACCOUNTING..account_td_last_accrual GROUP BY td_account_id HAVING COUNT(1) > 1) AS a 
	INNER JOIN BSGCORE..customer_accounts ca ON ca.account_id = a.td_account_id AND ca.is_active = 1 
	UNION ALL 
	SELECT CONCAT('product_offset_master', '-', pm.product_code, '-', pm.product_id, '-', a.totalAccount) AS details FROM 
	(SELECT product_id, COUNT(1) AS totalAccount FROM BSGCORE..product_offset_master WHERE is_active = 1 GROUP BY product_id HAVING COUNT(1) > 1) a 
	INNER JOIN BSGCORE..product_master pm ON pm.product_id = a.product_id AND pm.is_active = 1;
END

