
CREATE   PROCEDURE [dbo].[getAvgMonthlyBalanceForCasa] -- getAvgMonthlyBalanceForCasa '2019-12-01','2019-12-31'
(
    @fromDate   DATETIME,
    @toDate     DATETIME
)
AS
BEGIN

DECLARE @DateDiff INT;
DECLARE @balMonth VARCHAR(7);
SET @balMonth = (SELECT concat(right('0' + cast(month(app_date) as varchar(2)), 2), year(app_date)) from BSGACCOUNTING..cbs_application_date where is_active=1);
SET @DateDiff = DATEDIFF(day,@fromDate,@toDate) + 1;
CREATE TABLE #Temp_averageBalanceDetails
(
    accountId BIGINT,
    customerId BIGINT,
    avgBalance DECIMAL(18,2)
)
INSERT INTO #Temp_averageBalanceDetails
    SELECT
        Main.account_id as accountId,
        Main.customer_id as customerId,
        CAST(ISNULL((SUM(ISNULL(available_balance,0)) / ISNULL(@DateDiff,1)),0) AS DECIMAL(18,2)) avg_balance   
    FROM
    (
        SELECT 
            A.account_id,
            A.customer_id,
            A.increment_date,
			ab.available_balance
        FROM 
        (
            SELECT 
                am.account_id, ca.customer_id, DATEADD(Day, sp.number, @fromDate) increment_date 
            FROM 
                BSGCORE..account_master am WITH(NOLOCK)
                INNER JOIN BSGCORE..customer_accounts ca WITH(NOLOCK)
                    ON am.account_id = ca.account_id AND ca.is_active = 1
                LEFT JOIN master..spt_values sp 
                    ON sp.type = 'P' AND @toDate >= DATEADD(Day, sp.number, @fromDate)
            WHERE       
                am.is_active = 1
                AND ca.classification_id = 1--IN (1,2)
                AND am.account_status_id IN (1,2,3,5)		
        ) A
        LEFT JOIN BSGACCOUNTING..account_balance ab WITH(NOLOCK)
            ON A.account_id = ab.account_id 
            AND 
                ab.txn_date IN
                (
                    SELECT 
                        MAX(b.txn_date) 
                    FROM 
                        BSGACCOUNTING..account_balance b WITH(NOLOCK)
                    WHERE 
                        b.account_id = ab.account_id AND b.txn_date <= A.increment_date
                )
    )Main
    GROUP BY Main.account_id,Main.customer_id;

SELECT 
    * 
FROM 
    #Temp_averageBalanceDetails

	--INSERT INTO BSGACCOUNTING..casa_average_monthly_balance (balance_month,account_id,customer_id,avg_balance)
	--select @balMonth,accountId,customerId,avg_balance from #Temp_averageBalanceDetails;


DROP TABLE #Temp_averageBalanceDetails
END
