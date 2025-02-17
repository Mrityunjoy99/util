CREATE   PROCEDURE [dbo].[zeroBalance_ProductCheck] -- zeroBalance_ProductCheck 1,1
(
@branchCode INT,
@condition  INT -- 1 For Count And 2 For Details
)
AS
BEGIN

DECLARE @cbsAppDate DATETIME
DECLARE @ProductCode VARCHAR(500)

SET @ProductCode = 
(
	SELECT cc.config_value FROM BSGADMIN..cbs_config cc WITH(NOLOCK) WHERE cc.config_key = 'ZERO_BALANCE_PRODUCTS' AND cc.is_active = 1
)

SET @cbsAppDate = 
(
	SELECT app_date FROM cbs_application_date WITH(NOLOCK) WHERE is_active = 1
)

CREATE TABLE #temp_zeroBalanceProducts (Id INT IDENTITY,product_codes VARCHAR(200))

IF(@ProductCode <> '0')
BEGIN
	DECLARE @length VARCHAR(200) = (SELECT LEN(@ProductCode))
	DECLARE @cnt INT = 1

	WHILE(@cnt <= @length)
	BEGIN
		INSERT INTO #temp_zeroBalanceProducts
		SELECT SUBSTRING(@ProductCode,@cnt,4);
		SET @cnt = @cnt + 5;
	END
END

IF(@condition = 1)
BEGIN

	SELECT 
		COUNT(p.product_code) productCountOrDetails
	FROM 
		BSGCORE..product_master_internal p
	WHERE 
		p.internal_product_id IN
		(
			SELECT 
				pbi.internal_product_id 
			FROM 
				product_balance_internal pbi WITH(NOLOCK)
			WHERE 
				pbi.internal_product_id IN 
				(
					SELECT 
						pmi.internal_product_id 
					FROM 
						BSGCORE..product_master_internal pmi WITH(NOLOCK)
					WHERE 
					pmi.product_code IN ( select product_codes from #temp_zeroBalanceProducts )
					AND pmi.branch_code = @branchCode
					AND pmi.is_active = 1
				)
				AND pbi.txn_date = @cbsAppDate
				AND pbi.is_active = 1
				AND pbi.checker_clear_balance <> 0
		) AND is_active = 1
END

ELSE
BEGIN

	SELECT 
		(CAST(p.product_code AS VARCHAR(10)) + ' - ' + p.description) productCountOrDetails
	FROM 
		BSGCORE..product_master_internal p
	WHERE 
		p.internal_product_id IN
		(
			SELECT 
				pbi.internal_product_id 
			FROM 
				product_balance_internal pbi WITH(NOLOCK)
			WHERE 
				pbi.internal_product_id IN 
				(
					SELECT 
						pmi.internal_product_id 
					FROM 
						BSGCORE..product_master_internal pmi WITH(NOLOCK)
					WHERE 
					pmi.product_code IN ( select product_codes from #temp_zeroBalanceProducts )
					AND pmi.branch_code = @branchCode
					AND pmi.is_active = 1
				)
				AND pbi.txn_date = @cbsAppDate
				AND pbi.is_active = 1
				AND pbi.checker_clear_balance <> 0
		) AND is_active = 1
END

END
