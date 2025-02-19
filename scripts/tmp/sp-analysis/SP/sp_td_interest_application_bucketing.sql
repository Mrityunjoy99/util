
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_td_interest_application_bucketing]  -- exec sp_td_interest_application_bucketing '2018-10-31'
@txn_date date
AS
BEGIN

INSERT INTO bsgtd..td_customer_interest_tds
SELECT td_account_id,customer_id,current_interest,current_tds,0,0,txn_date,1,-1,getdate() 
FROM BSGACCOUNTING..td_interest_application WHERE txn_date=@txn_date AND current_interest>0
AND status=1 AND is_applied=1

END


