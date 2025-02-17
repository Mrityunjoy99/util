-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE    PROCEDURE [dbo].[sp_get_overdue_details] 
	-- Add the parameters for the stored procedure here
	@CustomerId BIGINT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT lam.loan_account_no account_no, 
		   a.overdue_amount    overdue_amount
		FROM   bsgloan..loan_account_master lam 
			INNER JOIN bsgaccounting..account_balance_loan a 
				   ON
				   lam.customer_no = @CustomerId
					   AND lam.loan_account_id = a.loan_account_id 	
						AND lam.loan_account_status <> 2 
						AND lam.is_active = 1 
			INNER JOIN (SELECT loan_account_id, 
							  Max(txn_date) date 
					   FROM 
		   bsgaccounting..account_balance_loan 
					   GROUP  BY loan_account_id) c 
				   ON a.loan_account_id = c.loan_account_id 
					  AND a.txn_date = c.date;
END
