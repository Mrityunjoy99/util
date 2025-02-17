
CREATE   PROCEDURE [dbo].[sp_rectify_balance] -- sp_rectify_balance 3567259
(
@accountId int
)
AS  
BEGIN
    DECLARE @cbsAppDate DATE = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WITH(NOLOCK) WHERE is_active = 1);
    DECLARE @txnCount INT =(SELECT count(1) FROM BSGACCOUNTING..transaction_master WITH(NOLOCK) WHERE account_id = @accountId and txn_posting_date = @cbsAppDate 
                            and is_active = 1);
    DECLARE @classificationId INT = (SELECT classification_id FROM BSGCORE..customer_accounts WITH(NOLOCK) WHERE account_id = @accountId and is_active = 1);
    DECLARE @openingBal DECIMAL(18,2) = 0.00;
    DECLARE @computedBal DECIMAL(18,2) = 0.00;
    DECLARE @currentBal DECIMAL(18,2) = 0.00;
    --PRINT 'txnCount: ' + CAST(@txnCount AS VARCHAR);
    CREATE TABLE #output 
    (
        successCount INT, failureCount INT, description varchar(200)
    );
    IF(@txnCount < 1)
    BEGIN
        INSERT INTO #output
        (
            successCount, failureCount, description
        ) 
        SELECT 1, 0, 'Txn Count: ' + CAST(@txnCount AS VARCHAR);
    END;
    IF(@txnCount > 0)
    BEGIN
        IF(@classificationId IN (1,2))
        BEGIN
            --PRINT 'CASA';
        IF((SELECT count(1) from BSGACCOUNTING..account_balance ab WITH(NOLOCK) WHERE ab.account_id = @accountId and ab.txn_date = @cbsAppDate) = 0)
        BEGIN
            INSERT INTO BSGACCOUNTING..account_balance
                SELECT ab2.account_id, ab2.day_open_balance, ab2.maker_clear_balance, ab2.maker_unclear_balance, ab2.checker_unclear_balance, ab2.checker_clear_balance,
                ab2.day_close_balance, ab2.available_balance, ab2.interest_accrual, ab2.sprinkle, ab2.is_active, -73, GETDATE(), -73, GETDATE(), @cbsAppDate, 
                ab2.last_accrual_date, ab2.encrypted_balance, ab2.lien_amount,ab2.branch_code,ab2.product_id,ab2.tds_amount,lcy_amount
                FROM BSGACCOUNTING..account_balance ab2 WITH(NOLOCK) where ab2.account_id = @accountId and ab2.txn_date = 
                    (SELECT MAX(ab1.txn_date) FROM BSGACCOUNTING..account_balance ab1 WITH(NOLOCK) WHERE ab1.account_id = @accountId and ab1.txn_date < @cbsAppDate);
        END;
            SET @openingBal = (SELECT ab.available_balance from BSGACCOUNTING..account_balance ab WITH(NOLOCK) WHERE ab.account_id = @accountId and ab.txn_date = 
                (SELECT MAX(ab1.txn_date) FROM BSGACCOUNTING..account_balance ab1 WITH(NOLOCK) WHERE ab1.account_id = @accountId and ab1.txn_date < @cbsAppDate));
            SET @openingBal = @openingBal + 
                (SELECT 
                    ISNULL(SUM(cott.txn_amount) ,0) 
                FROM
                    BSGACCOUNTING..clearing_outward_transaction cott
                INNER JOIN
                    BSGACCOUNTING..transaction_status ts
                    ON
                        ts.txn_ref_no = cott.txn_ref_no
                        AND ts.fund_date = @cbsAppDate
                        AND ts.post_date <> ts.fund_date
                        AND ts.txn_state = 'OS'
                        AND ts.is_active = 1
                WHERE
                    cott.account_id = @accountId
                    AND cott.is_active = 1);
            --PRINT 'openingBal: ' + CAST(@openingBal AS VARCHAR);
            SET @currentBal = (SELECT ab.available_balance from BSGACCOUNTING..account_balance ab WITH(NOLOCK) WHERE ab.account_id = @accountId and ab.txn_date = @cbsAppDate);
            SET @computedBal = 
                (SELECT 
                    @openingBal - SUM(A.debitAmt) + SUM(A.creditAmt)
                FROM 
                    (SELECT 
                        ISNULL(CASE WHEN tm.txn_nature = 'D' THEN SUM(tm.txn_amount) END, 0) AS debitAmt,
                        ISNULL(CASE WHEN tm.txn_nature = 'C' THEN SUM(tm.txn_amount) END, 0) AS creditAmt
                    FROM 
                        BSGACCOUNTING..transaction_master tm WITH(NOLOCK)
                    LEFT JOIN
                        BSGACCOUNTING..transaction_status ts WITH(NOLOCK)
                        ON 
                            ts.txn_ref_no = tm.txn_ref_no
                            AND ts.post_date = tm.txn_posting_date
                            AND ts.is_active = 1
                    WHERE 
                        tm.txn_posting_date = @cbsAppDate
                        AND tm.account_id = @accountId
                        AND ISNULL(ts.txn_state,'A') not in ('OT', 'OR', 'ORG')
                        AND tm.is_active = 1
                    GROUP BY 
                        tm.txn_nature
                    UNION ALL
                    SELECT 
                        ISNULL(CASE WHEN tp.txn_nature = 'D' THEN SUM(tp.txn_amount) END, 0) AS debitAmt,
                        ISNULL(CASE WHEN tp.txn_nature = 'C' THEN SUM(tp.txn_amount) END, 0) AS creditAmt
                    FROM 
                        BSGACCOUNTING..transaction_status ts WITH(NOLOCK)
                    INNER JOIN
                        BSGACCOUNTING..transaction_pending tp WITH(NOLOCK)
                        ON 
                            tp.txn_ref_no = ts.txn_ref_no
                            AND tp.account_id = @accountId
                            AND tp.txn_date = ts.post_date
                            AND tp.is_active = 1
                    WHERE 
                        ts.txn_state = 'IP'
                        AND ts.post_date = @cbsAppDate
                        AND ts.is_active = 1
                    GROUP BY 
                        tp.txn_nature)A);
                IF(@computedBal = @currentBal)
                BEGIN
                    --SELECT 'No need for rectification' AS 'OUTPUT';
                    INSERT INTO #output
                    (
                         successCount, failureCount, description
                    ) 
                    SELECT 1, 0, 'CASA: No need for rectification';
                END;
                IF(@computedBal <> @currentBal)
                BEGIN
                    --UPDATE 
                    --  BSGACCOUNTING..account_balance
                    --SET 
                    --  checker_clear_balance = @computedBal,
                    --  available_balance = @computedBal,
                    --  last_modified_date = GETDATE(),
                    --  last_modified_by = -73
                    --WHERE
                    --  account_id = @accountId
                    --AND 
                    --  txn_date = @cbsAppDate;
                    INSERT INTO #output
                    (
                         successCount, failureCount, description
                    ) 
                    SELECT 0, 1, 'CASA: Old Bal: ' + CAST(@currentBal AS VARCHAR)  + ', New Bal: ' + CAST(@computedBal AS VARCHAR);
                END;    
            END;
        IF(@classificationId = 6)
        BEGIN
            --PRINT 'CC';
            SET @openingBal = (SELECT lab.checker_clear_balance from BSGACCOUNTING..account_balance_loan lab WITH(NOLOCK) WHERE lab.loan_account_id = @accountId and lab.txn_date = 
                (SELECT MAX(lab1.txn_date) FROM BSGACCOUNTING..account_balance_loan lab1 WITH(NOLOCK) WHERE lab1.loan_account_id = @accountId and lab1.txn_date < @cbsAppDate));
            SET @openingBal = @openingBal + 
            (SELECT 
                ISNULL(SUM(cott.txn_amount) ,0)
            FROM
                BSGACCOUNTING..clearing_outward_transaction cott
            INNER JOIN
                BSGACCOUNTING..transaction_status ts
                ON
                    ts.txn_ref_no = cott.txn_ref_no
                    AND ts.post_date <> ts.fund_date
                    AND ts.fund_date = @cbsAppDate
                    AND ts.txn_state = 'OS'
                    AND ts.is_active = 1
            WHERE
                cott.account_id = @accountId
                AND cott.is_active = 1);
            --PRINT 'openingBal: ' + CAST(@openingBal AS VARCHAR);
            SET @computedBal = 
                (SELECT 
                    @openingBal - SUM(A.debitAmt) + SUM(A.creditAmt)
                FROM 
                    (SELECT 
                        ISNULL(CASE WHEN tm.txn_nature = 'D' THEN SUM(tm.txn_amount) END, 0) AS debitAmt,
                        ISNULL(CASE WHEN tm.txn_nature = 'C' THEN SUM(tm.txn_amount) END, 0) AS creditAmt
                    FROM 
                        BSGACCOUNTING..transaction_master tm WITH(NOLOCK)
                    LEFT JOIN
                        BSGACCOUNTING..transaction_status ts WITH(NOLOCK)
                        ON 
                            ts.txn_ref_no = tm.txn_ref_no
                            AND ts.post_date = tm.txn_posting_date
                            AND ts.is_active = 1
                    WHERE 
                        tm.txn_posting_date = @cbsAppDate
                        AND tm.account_id = @accountId
                        AND ISNULL(ts.txn_state,'A') not in ('OT', 'OR', 'ORG')
                        AND tm.is_active = 1
                    GROUP BY 
                        tm.txn_nature
                    UNION ALL
                    SELECT 
                        ISNULL(CASE WHEN tp.txn_nature = 'D' THEN SUM(tp.txn_amount) END, 0) AS debitAmt,
                        ISNULL(CASE WHEN tp.txn_nature = 'C' THEN SUM(tp.txn_amount) END, 0) AS creditAmt
                    FROM 
                        BSGACCOUNTING..transaction_status ts WITH(NOLOCK)
                    INNER JOIN
                        BSGACCOUNTING..transaction_pending tp WITH(NOLOCK)
                        ON 
                            tp.txn_ref_no = ts.txn_ref_no
                            AND tp.account_id = @accountId
                            AND tp.txn_date = ts.post_date
                            AND tp.is_active = 1
                    WHERE 
                        ts.txn_state = 'IP'
                        AND ts.post_date = @cbsAppDate
                        AND ts.is_active = 1
                    GROUP BY 
                        tp.txn_nature)A);
                SET @currentBal = (SELECT lab.checker_clear_balance from BSGACCOUNTING..account_balance_loan lab WITH(NOLOCK) WHERE lab.loan_account_id = @accountId 
                and lab.txn_date = @cbsAppDate);
                DECLARE @availableDp decimal(18,2) = (SELECT lab.available_dp from BSGACCOUNTING..account_balance_loan lab WITH(NOLOCK) WHERE lab.loan_account_id = @accountId 
                and lab.txn_date = @cbsAppDate);
                DECLARE @availableBalance decimal(18,2) = (SELECT lab.available_balance from BSGACCOUNTING..account_balance_loan lab WITH(NOLOCK) WHERE lab.loan_account_id =                       @accountId and lab.txn_date = @cbsAppDate);
                IF(@computedBal = @currentBal)
                BEGIN
                    INSERT INTO #output
                    (
                         successCount, failureCount, description
                    ) 
                    SELECT 1, 0, 'CC: Old Checker Clr Bal: ' + CAST(@currentBal AS VARCHAR)  + ', New Checker Clr Bal: ' + CAST(@computedBal AS VARCHAR)
                    + ', Old Bal: ' + CAST(@availableBalance AS VARCHAR) + ', New Bal: ' + CAST((@computedBal + @availableDp) AS VARCHAR);
                    --IF((@computedBal + @availableDp) <> @availableBalance)
                    --BEGIN
                        --UPDATE 
                        --  BSGACCOUNTING..account_balance_loan
                        --SET 
                        --  checker_clear_balance = @computedBal,
                        --  available_balance = @computedBal + available_dp,
                        --  last_modified_by = -73,
                        --  last_modified_date = GETDATE()
                        --WHERE
                        --  loan_account_id = @accountId
                        --AND 
                        --  txn_date = @cbsAppDate;
                    --END;
                END;
                IF(@computedBal <> @currentBal)
                BEGIN
                    INSERT INTO #output
                    (
                         successCount, failureCount, description
                    ) 
                    SELECT 0, 1, 'CC: Old Checker Clr Bal: ' + CAST(@currentBal AS VARCHAR)  + ', New Checker Clr Bal: ' + CAST(@computedBal AS VARCHAR)
                    + ', Old Bal: ' + CAST(@availableBalance AS VARCHAR) + ', New Bal: ' + CAST((@computedBal + @availableDp) AS VARCHAR)
                    --UPDATE 
                    --  BSGACCOUNTING..account_balance_loan
                    --SET 
                    --  checker_clear_balance = @computedBal,
                    --  available_balance = @computedBal + available_dp,
                    --  last_modified_by = -73,
                    --  last_modified_date = GETDATE()
                    --WHERE
                    --  loan_account_id = @accountId
                    --AND 
                    --  txn_date = @cbsAppDate;
                END;
        END;
    END;
    SELECT successCount, failureCount, description from #output;
END;