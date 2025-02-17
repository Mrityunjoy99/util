-- =============================================
-- Author:		<ASHISH L.>
-- Create date: <2023-09-08 19:18:05.283>SELECT GETDATE()
-- Description:	<INSERT td_customer_interest_tds in TD from ACCOUNTING>
-- EXEC : sp_insert_td_customer_interest_tds
-- =============================================
CREATE   PROCEDURE [dbo].[sp_insert_td_customer_interest_tds] --[sp_insert_td_customer_interest_tds] 2169,18804325116713
@createdBy varchar(100) = -137,
@txnRefNo varchar(100) = -1
AS
BEGIN
return 1;
PRINT SUBSTRING(CAST(CAST(GETDATE() AS time) AS varchar(MAX)),4,2)

IF(SUBSTRING(CAST(CAST(GETDATE() AS time) AS varchar(MAX)),4,2) IN (0))
BEGIN

IF EXISTS(SELECT 1 FROM BSGACCOUNTING..td_customer_interest_tds NOLOCK WHERE is_active=1)
BEGIN

INSERT INTO BSGTD..td_customer_interest_tds
SELECT td_account_id, customer_id, interest,tds, interest_reversal, tds_reversal, txn_date, 1 is_active, cast(@createdBy as bigint) created_by, GETDATE() created_date
FROM BSGACCOUNTING..td_customer_interest_tds NOLOCK
WHERE is_active=1

UPDATE BSGACCOUNTING..td_customer_interest_tds SET is_active=0 WHERE is_active=1

END

END

END
