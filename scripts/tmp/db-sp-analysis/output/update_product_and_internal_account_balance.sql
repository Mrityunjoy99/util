-- =============================================
-- Author:		<Author,,Shubham Bhalerao>
-- Create date: <Create Date,,30/01/2023>
-- Description:	<Description,,EP/ IA Transaction/ Balance Sync>
-- EXEC update_product_and_internal_account_balance '2022-04-01', '2022-04-02', 1, ''
-- =============================================
create    PROCEDURE [dbo].[update_product_and_internal_account_balance] 
	-- Add the parameters for the stored procedure here
	@fromDate date,
	@toDate date,
	@isDfRequired int,
	@principalType varchar(10) --- IP, EP, IA
AS
BEGIN

   SELECT 11 as successCount, 0 as failureCount

--   DECLARE @fromDateExt date = @fromDate
--   DECLARE @toDateExt date = @toDate
	
--   DECLARE @fromDateIA date = @fromDate
--   DECLARE @toDateIA date = @toDate

--	 DROP TABLE IF EXISTS #internal_product
--	 CREATE TABLE #internal_product(
--	   product_id bigint,
--	   product_code bigint
--	 )

--	 CREATE TABLE #external_product(
--	    product_id bigint,
--		product_code bigint
--	)

--	CREATE TABLE #internal_accounts(
--	    account_id bigint,
--		internal_product_id bigint
--	)


--INSERT INTO #internal_product
--SELECT internal_product_id, product_code 
--FROM BSGCORE..product_master_internal 
--WHERE is_active = 1


--INSERT INTO #external_product
--SELECT product_id, product_code 
--FROM BSGCORE..product_master 
--WHERE is_active = 1


--INSERT INTO #internal_accounts 
--SELECT internal_account_id, internal_product_id 
--FROM BSGCORE..account_master_internal

----SELECT COUNT(1) FROM #internal_product

----SELECT COUNT(DISTINCT(product_id)) FROM #internal_product

----FOR INTERNAL PRODUCT-----------------------------------------------
--WHILE (@fromDate<=@toDate)
--BEGIN
-- DROP TABLE if exists #product_balance_int
--	CREATE TABLE #product_balance_int(
--	  product_id bigint,
--	  day_open_balance decimal(18,2),
--	  checker_clear_balance decimal(18,2),
--	  day_close_balance decimal(18,2),
--	  txn_date date
--	) 

--DECLARE @previousDate date = DATEADD(DAY, -1, @fromDate)

----truncate table #product_balance_int
--INSERT INTO 
--#product_balance_int
--SELECT 
--pbi.internal_product_id,
--ISNULL(pbi.checker_clear_balance,0.00) day_open_balance,
--ISNULL(pbi.checker_clear_balance,0.00) checker_clear_balance,
--ISNULL(pbi.checker_clear_balance,0.00) day_close_balance,
--@fromDate
--FROM #internal_product ip 
--LEFT JOIN 
--BSGACCOUNTING..product_balance_internal pbi 
--ON pbi.internal_product_id = ip.product_id
--AND pbi.is_active = 1
--INNER JOIN 
--(SELECT internal_product_id, Max(txn_date) txn_date FROM BSGACCOUNTING..product_balance_internal 
--WHERE txn_date <= @previousDate AND is_active = 1 group by internal_product_id) pbi1
--ON pbi1.internal_product_id = pbi.internal_product_id 
--AND pbi.txn_date = pbi1.txn_date

--SELECT * FROM #product_balance_int ORDER BY product_id

--UPDATE pbi_temp 
-- SET checker_clear_balance = 
--  case 
--    when tmi.txn_nature = 'C'
--	then ISNULL(pbi_temp.checker_clear_balance,0) + tmi.txn_amount
--	else ISNULL(pbi_temp.checker_clear_balance,0) - tmi.txn_amount
--  end
--FROM 
--#product_balance_int pbi_temp
--INNER JOIN
--BSGACCOUNTING..transaction_master_internal tmi
--ON tmi.principal_id = pbi_temp.product_id 
--AND tmi.txn_date = @fromDate
--WHERE tmi.is_active = 1 

--SELECT * FROM #product_balance_int ORDER BY product_id


--    MERGE BSGACCOUNTING..product_balance_internal  AS target  
--    USING (SELECT product_id, day_open_balance,checker_clear_balance,day_close_balance,txn_date FROM #product_balance_int)
--    AS source (product_id, day_open_balance,checker_clear_balance,day_close_balance,txn_date )  
--    ON (target.internal_product_id = source.product_id and target.is_active=1 and target.txn_date = @fromDate)  
--    WHEN MATCHED THEN
--        UPDATE SET target.checker_clear_balance = source.checker_clear_balance ,
--		target.last_modified_date = getDate(),
--		target.last_modified_by = -1
--    WHEN NOT MATCHED THEN  
--    INSERT (internal_product_id, day_open_balance,checker_clear_balance,day_close_balance,sprinkle,is_active
--	,created_by, created_date, last_modified_by, last_modified_date, txn_date, lcy_amount)  
--    VALUES (source.product_id,
--    source.day_open_balance,
--	source.checker_clear_balance,
--	source.day_close_balance,
--	'N/A',
--	1,
--	-1,
--	GETDATE(),
--	-1,
--	GETDATE(),
--	@fromDate,
--	NULL
--    );

--set @fromDate = DATEADD(DAY,1,@fromDate)

--END




---- FOR EXTERNAL PRODUCT---------------------------------------------------
--WHILE (@fromDateExt <= @toDateExt )
--BEGIN
--    DROP TABLE if exists #product_balance_ext
--	CREATE TABLE #product_balance_ext(
--	  product_id bigint,
--	  day_open_balance decimal(18,2),
--	  checker_clear_balance decimal(18,2),
--	  day_close_balance decimal(18,2),
--	  txn_date date
--	 )

--DECLARE @previousDateExt date = DATEADD(DAY, -1, @fromDateExt)

--INSERT INTO 
--#product_balance_ext
--SELECT 
--pb.product_id,
--ISNULL(pb.checker_clear_balance,0.00) day_open_balance,
--ISNULL(pb.checker_clear_balance,0.00) checker_clear_balance,
--ISNULL(pb.checker_clear_balance,0.00) day_close_balance,
--@fromDateExt
--FROM #external_product ep 
--LEFT JOIN 
--BSGACCOUNTING..product_balance pb 
--ON pb.product_id = ep.product_id
--AND pb.is_active = 1
--INNER JOIN 
--(SELECT product_id, Max(txn_date) txn_date FROM BSGACCOUNTING..product_balance 
--WHERE txn_date < @fromDateExt AND is_active = 1 group by product_id) pbi1
--ON pbi1.product_id = pb.product_id 
--AND pb.txn_date = pbi1.txn_date

--SELECT * FROM #product_balance_ext ORDER BY product_id

--UPDATE pbe_temp 
-- SET checker_clear_balance = 
--  case 
--    when tmi.txn_nature = 'C'
--	then ISNULL(pbe_temp.checker_clear_balance,0) + tmi.txn_amount
--	else ISNULL(pbe_temp.checker_clear_balance,0) - tmi.txn_amount
--  end
--FROM 
--#product_balance_ext pbe_temp
--INNER JOIN
--BSGACCOUNTING..transaction_master_internal tmi
--ON tmi.principal_id = pbe_temp.product_id 
--AND tmi.txn_date = @fromDateExt
--WHERE tmi.is_active = 1 

--SELECT * FROM #product_balance_ext ORDER BY product_id


--    MERGE BSGACCOUNTING..product_balance  AS target  
--    USING (SELECT product_id, day_open_balance,checker_clear_balance,day_close_balance,txn_date FROM #product_balance_ext)
--    AS source (product_id, day_open_balance,checker_clear_balance,day_close_balance,txn_date )  
--    ON (target.product_id = source.product_id and target.is_active=1 and target.txn_date = @fromDate)  
--    WHEN MATCHED THEN
--        UPDATE SET target.checker_clear_balance = source.checker_clear_balance ,
--		target.last_modified_date = getDate(),
--		target.last_modified_by = -1
--    WHEN NOT MATCHED THEN  
--    INSERT (product_id, day_open_balance,checker_clear_balance,day_close_balance,sprinkle,is_active
--	,created_by, created_date, last_modified_by, last_modified_date, txn_date, lcy_amount)  
--    VALUES (source.product_id,
--    source.day_open_balance,
--	source.checker_clear_balance,
--	source.day_close_balance,
--	'N/A',
--	1,
--	-1,
--	GETDATE(),
--	-1,
--	GETDATE(),
--	@fromDateExt,
--	NULL
--    );

--set @fromDateExt = DATEADD(DAY,1,@fromDateExt)

--END


--WHILE(@fromDateIA <= @toDateIA)
--BEGIN
--DROP TABLE IF EXISTS #account_balance_int
--CREATE TABLE #account_balance_int
--(
--internal_account_id bigint,
--day_open_balance decimal(18,2),
--maker_unclear_balance decimal(18,2),
--maker_clear_balance decimal(18,2),
--checker_unclear_balance decimal(18,2),
--checker_clear_balance decimal(18,2),
--available_balance decimal(18,2),
--day_close_balance decimal(18,2),
--txn_date date 
--)

--INSERT INTO #account_balance_int 
--SELECT 
--ami.account_id,
--ISNULL(ami.day_open_balance,0) day_open_balance,
--ISNULL(ami.maker_unclear_balance,0) maker_unclear_balance,
--ISNULL(ami.maker_clear_balance,0) maker_clear_balance,
--ISNULL(ami.checker_unclear_balance,0) checker_unclear_balance,
--ISNULL(ami.checker_clear_balance,0) checker_clear_balance,
--ISNULL(ami.available_balance,0) available_balance,
--ISNULL(ami.day_close_balance,0) day_close_balance,
--@fromDateIA
--FROM #internal_accounts ia
--LEFT JOIN 
--BSGACCOUNTING..account_balance_internal ami	
--ON ia.account_id = ami.account_id 
--AND ami.is_active = 1
--INNER JOIN 
--(SELECT account_id, MAX(txn_date) txn_date FROM BSGACCOUNTING..account_balance_internal WHERE txn_date < @fromDateIA and is_active = 1 GROUP BY account_id) ami1
--ON ami.account_id = ami1.account_id 
--AND ami.txn_date = ami1.txn_date

--UPDATE abi
--SET 
--   checker_clear_balance = 
--   case 
--     when txn_nature = 'C'
--	 then ISNULL(checker_clear_balance,0) + txn_amount 
--	 else ISNULL(checker_clear_balance,0) - txn_amount
--   end
--FROM 
--  #account_balance_int abi
--INNER JOIN 
--  BSGACCOUNTING..transaction_master_internal tmi
--ON tmi.principal_id = abi.internal_account_id
--AND tmi.txn_date = @fromDateIA
--WHERE tmi.is_active = 1 



--MERGE BSGACCOUNTING..account_balance_internal  AS target  
--    USING (SELECT internal_account_id,day_open_balance, maker_unclear_balance,maker_clear_balance,
--	checker_unclear_balance,checker_clear_balance,available_balance,day_close_balance,txn_date FROM #account_balance_int)
--    AS source (internal_account_id,day_open_balance, maker_unclear_balance,maker_clear_balance,checker_unclear_balance,day_close_balance,checker_clear_balance,available_balance,txn_date )  
--    ON (target.account_id = source.internal_account_id and target.is_active=1 and target.txn_date = @fromDate)  
--    WHEN MATCHED THEN
--        UPDATE SET target.checker_clear_balance = source.checker_clear_balance ,
--		target.last_modified_date = getDate(),
--		target.last_modified_by = -1
--    WHEN NOT MATCHED THEN  
--    INSERT (account_id, day_open_balance, maker_clear_balance, maker_unclear_balance,checker_unclear_balance, checker_clear_balance, day_close_balance, available_balance, is_active,
--      created_by, created_date, last_modified_by, last_modified_date, txn_date, lcy_amount)  
--    VALUES (source.internal_account_id,
--    source.day_open_balance,
--	source.maker_unclear_balance,
--	source.maker_clear_balance,
--	source.checker_unclear_balance,
--	source.checker_clear_balance,
--	source.day_close_balance,
--	source.available_balance,
--	source.day_close_balance,
--	-1,
--	GETDATE(),
--	-1,
--	GETDATE(),
--	-1,
--	@fromDateIA,
--	NULL
--    );

--set @fromDateIA = DATEADD(DAY,1,@fromDateIA)

--END

END
