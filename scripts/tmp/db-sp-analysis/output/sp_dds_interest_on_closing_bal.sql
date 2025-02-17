create    PROCEDURE [dbo].[sp_dds_interest_on_closing_bal] -- sp_dds_interest_on_closing_bal 520816,'2020-11-09'
@accountId bigint,
@currentDate datetime
AS
BEGIN
DECLARE @accountOpenDate DATE = (SELECT CAST(account_open_date AS DATE) FROM BSGCORE..account_master WHERE account_id = @accountId AND is_active = 1);
    PRINT 'The @accountOpenDate is = ' + CONVERT(VARCHAR,@accountOpenDate);
DECLARE @age INT = (case WHEN (datediff(month, @accountOpenDate, @currentDate) = 6) then dbo.FullMonthsSeparation(@accountOpenDate, @currentDate)
                     WHEN (datediff(month, @accountOpenDate, @currentDate) = 12) then dbo.FullMonthsSeparation(@accountOpenDate, @currentDate)
                     WHEN (datediff(month, @accountOpenDate, @currentDate) > 12) then 12
                     else datediff(month, @accountOpenDate, @currentDate)
                     END);
    PRINT 'The @age is = ' + CONVERT(VARCHAR,@age);
DECLARE @intAge INT = @age - 1;
    PRINT 'The @intAge is = ' + CONVERT(VARCHAR,@intAge);
DECLARE @balSum DECIMAL(18,2) = 0.00;
DECLARE @counter INT = 1;
DECLARE @intDate DATE = @accountOpenDate;
WHILE ( @counter <= @intAge)
BEGIN
    SET @intDate = DATEADD(day, 1, eomonth(@intDate));
    PRINT 'The month is = ' + CONVERT(VARCHAR,@intDate);
    SET @balSum = @balSum + (SELECT ISNULL((SELECT available_balance FROM BSGACCOUNTING..account_balance WHERE account_id = @accountId and txn_date = 
        (SELECT max(txn_date) FROM BSGACCOUNTING..account_balance WHERE account_id = @accountId and txn_date < @intDate)),0));
    PRINT 'The @balSum is = ' + CAST(@balSum AS VARCHAR);
    SET @counter  = @counter  + 1;
END
DECLARE @effectiveDate DATE = (SELECT max(effective_date) FROM BSGCORE..dds_closure_rates WHERE effective_date <= @accountOpenDate AND from_months <= @age AND to_months > @age AND is_active = 1);
DECLARE @roi DECIMAL(18,2) = (SELECT roi FROM BSGCORE..dds_closure_rates WHERE effective_date = @effectiveDate AND from_months <= @age AND to_months > @age AND is_active = 1);
    PRINT 'The @effectiveDate is = ' + CONVERT(VARCHAR,@effectiveDate);
DECLARE @interest DECIMAL(18,2) = ((@balSum * @roi)/1200);
SELECT ISNULL(@interest,0) AS intAmt;
END;
