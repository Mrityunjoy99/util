CREATE   procedure [dbo].[sp_kiosk_receipt_printing]	-- sp_kiosk_receipt_printing '10000802268',21018039172
@token_id varchar(50),
@txn_ref_no bigint
AS 
BEGIN

	SELECT 
		token_no,
		total_amount,
		txn_date,
		txn_nature
	FROM 
		BSGACCOUNTING..token_status 
	WHERE 
		token_id = @token_id and 
		is_active=1
--------------------------------------------------------------- 
	SELECT 
		CASE WHEN batch_code = 102 THEN cast((SELECT machine_id FROM kiosk_master) AS VARCHAR(10)) ELSE 'N/A' END AS machine_id
	FROM 
		BSGACCOUNTING..transaction_pending 
	WHERE 
		txn_ref_no = @txn_ref_no
---------------------------------------------------------------  
	SELECT 
		name 
	FROM 
		BSGADMIN..employee_master 
	WHERE 
		employee_id in (select teller_id from BSGACCOUNTING..kiosk_master) and 
		is_active=1
 --------------------------------------------------------------- 
	SELECT 
		dname,
		qty,
		dval,
		CASE WHEN LOWER(dtype) = 'c' THEN 'Coins' WHEN LOWER(dtype) = 'p' THEN 'Paper' ELSE 'N/A' END AS dtype 
	FROM 
		BSGACCOUNTING..transaction_denomination 
	WHERE 
		token_id = @token_id and 
		is_active=1
--------------------------------------------------------------- 
END


