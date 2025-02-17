CREATE   PROCEDURE [dbo].[sp_dds_closure_calculation] 
-- [sp_dds_closure_calculation] @accountId=181290,@currentDate='2020-10-17'
@accountId bigint,
@currentDate datetime
AS
BEGIN
SELECT 
    bal.*, dcr.from_months, dcr.to_months, dcr.interest_to_be_provided is_accrual_applicable, dcr.penal_interest, dcr.pl_account_id penal_pl_account_id
INTO
	#balance_details
FROM
    (SELECT 
			ab.available_balance,
            ab.interest_accrual,
            am.account_open_date,
            DATEDIFF(month, am.account_open_date, @currentDate) AS account_age,
			am.product_id,
			am.account_type_id,
			am.product_code,
			am.branch_code
    FROM
        BSGACCOUNTING..account_balance ab
    INNER JOIN 
		BSGCORE..account_master am ON am.account_id = ab.account_id
        AND am.is_active = 1
    WHERE
        ab.account_id = @accountId
            AND txn_date = (SELECT 
                MAX(ab1.txn_date)
            FROM
                BSGACCOUNTING..account_balance ab1
            WHERE
                ab1.account_id = ab.account_id)) bal
        INNER JOIN
			BSGCORE..dds_closure_rates dcr 
			ON dcr.is_active = 1
			AND dcr.from_months <= bal.account_age
			AND dcr.to_months > bal.account_age;
-- penalty
if((select penal_interest FROM #balance_details) > 0)
	BEGIN
		UPDATE #balance_details SET penal_interest = (penal_interest * available_balance) / 100;
	END
ELSE
    BEGIN
        UPDATE #balance_details SET penal_interest = 0;
    END;
	select * from #balance_details;
END
