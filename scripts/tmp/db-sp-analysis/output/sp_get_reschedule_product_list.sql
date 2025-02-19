
create    PROCEDURE [dbo].[sp_get_reschedule_product_list]
@rescheduleId int
AS 
BEGIN

select 	
	lrpd.product_code loan_product_code,lpm.loan_product_description,lpm.repayment_mode
from
	loan_reschedule_product_details lrpd
		inner join (select distinct loan_product_code,loan_product_description,repayment_mode from BSGLOAN..loan_product_master where is_active = 1) lpm
			on lrpd.product_code = lpm.loan_product_code
where	
	lrpd.reschedule_id = @rescheduleId
	and lrpd.is_active = 1
	and lrpd.is_reschedule = 0 -- Product Which are pending for the reschedule

END
