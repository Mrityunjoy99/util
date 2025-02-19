
CREATE   PROCEDURE [dbo].[checkDailyTrialBalanceDiff] -- checkDailyTrialBalanceDiff
AS
BEGIN


DECLARE @cbs_app_date DATETIME

SET @cbs_app_date = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1)

SET @cbs_app_date = (SELECT @cbs_app_date - 1)
PRINT 'CBS APP DATE'
PRINT @cbs_app_date

DECLARE @checkDuplicate INT

SET @checkDuplicate = (SELECT COUNT(1) FROM trial_balance_datewise WHERE tb_date = @cbs_app_date)

IF(@checkDuplicate > 0)
BEGIN
	UPDATE trial_balance_datewise SET is_active = 0 WHERE tb_date = @cbs_app_date
END

CREATE TABLE #TEMP_SUMMARY 
(
	ACCOUNTNUMBER VARCHAR(10),NAME VARCHAR(100),DEBITBAL DECIMAL(18,2),CREDITBAL DECIMAL(18,2),
	ProductType INT
)

INSERT INTO #TEMP_SUMMARY
EXEC BSGTURINGREPORTS..sp_Trial_Balance @cbs_app_date,0,'Yes','Account No','No',1

INSERT INTO trial_balance_datewise
SELECT 
	ISNULL(SUM(CREDITBAL),0) credit_sum,ISNULL(SUM(DEBITBAL),0) debit_sum,
	ISNULL(ISNULL(SUM(CREDITBAL),0) - ISNULL(SUM(DEBITBAL),0),0) balance_diff,
	@cbs_app_date tb_date,1 is_active,GETDATE() created_date 
FROM 
	#TEMP_SUMMARY

DROP TABLE #TEMP_SUMMARY

END
