-- Author - Abhishek
-- get the active account list for reschedule details
CREATE PROCEDURE [dbo].[sp_get_active_account_list_from_product] 
@productCode bigint
AS 
BEGIN

select loan_account_id from BSGLOAN..loan_account_master where
loan_account_id in (
select loan_account_id from loan_reschedule_account_list where is_active = 1
) and is_active = 1

/*
select loan_account_id from BSGLOAN..loan_account_master where
loan_product_id in (
select loan_product_id from BSGLOAN..loan_product_master where is_active = 1 and repayment_mode = 1

) and is_active = 1
and loan_type = 1
and loan_account_status <> 2
*/
--loan_product_code = @productCode and loan_account_status <> 2 and is_active = 1

END
