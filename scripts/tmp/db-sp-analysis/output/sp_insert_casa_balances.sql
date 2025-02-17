CREATE PROCEDURE [dbo].[sp_insert_casa_balances]  -- [sp_insert_casa_balances] '2023-06-23'
(
  @P_RUNDATE  DATE 
) AS 
BEGIN



MERGE bsgaccounting..account_balance AS target   
USING (
SELECT 
    distinct 
		ab.account_id, ab.day_open_balance, 
		ab.maker_clear_balance, ab.maker_unclear_balance, ab.checker_unclear_balance, ab.checker_clear_balance, ab.day_close_balance, ab.available_balance, 
		ab.interest_accrual, ab.sprinkle, ab.is_active, ab.created_by, ab.created_date, ab.last_modified_by, ab.last_modified_date, 
		@P_RUNDATE txn_date, ab.last_accrual_date, ab.lien_amount, 
		ab.encrypted_balance, ab.branch_code, ab.product_id, ab.tds_amount,  ab.lcy_amount
	--am.account_id,
 --   ISNULL(ab.day_open_balance, 0) day_open_balance,
 --   ISNULL(ab.maker_clear_balance, 0) maker_clear_balance,
 --   ISNULL(ab.maker_unclear_balance, 0) maker_unclear_balance,
 --   ISNULL(ab.checker_unclear_balance, 0) checker_unclear_balance,
 --   ISNULL(ab.checker_clear_balance, 0) checker_clear_balance,
 --   ISNULL(ab.day_close_balance, 0) day_close_balance,
 --   ISNULL(ab.available_balance, 0) available_balance,
 --   ISNULL(ab.interest_accrual,0) interest_accrual,
 --   ISNULL(ab.sprinkle, 'N/A') sprinkle,
 --   ISNULL(ab.is_active, 1) is_active,
 --   ISNULL(ab.created_by, -999) created_by,
 --   CURRENT_TIMESTAMP created_date,
 --   ISNULL(ab.last_modified_by, -1) last_modified_by,
 --   CURRENT_TIMESTAMP modified_by,
 --   @P_RUNDATE txn_date,
 --   ISNULL(ab.last_accrual_date, @P_RUNDATE) last_accrual_date,
 --   ISNULL(ab.encrypted_balance, 'N/A') encrypted_balance,
 --   ISNULL(ab.lien_amount, 0) lien_amount,
	--ab.branch_code, 
	--ab.product_id, 
	--ab.tds_amount, 
	--ab.fcy_currency, 
	--ab.lcy_amount, 
	--ab.fcy_exchange_rate,
	--ISNULL(ab.value_dated_interest_accrual, 0) value_dated_interest_accrual
FROM
     bsgcore..account_master am
        INNER JOIN bsgaccounting..account_balance ab  with (nolock)
            ON am.account_id = ab.account_id
        INNER JOIN
        (
            SELECT 
                account_id, MAX(txn_date) txn_date
            FROM
                bsgaccounting..account_balance with (nolock)
            WHERE
                txn_date <= @P_RUNDATE
            GROUP BY account_id
        ) a 
            ON ab.account_id = a.account_id AND ab.txn_date = a.txn_date
        LEFT OUTER JOIN bsgaccounting..account_balance abcurrent with (nolock)
            ON ab.account_id = abcurrent.account_id AND abcurrent.txn_date = @P_RUNDATE
WHERE
        am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1
	)
	AS Source (account_id, day_open_balance, maker_clear_balance, maker_unclear_balance, checker_unclear_balance, checker_clear_balance, day_close_balance, available_balance, 
		interest_accrual, sprinkle, is_active, created_by, created_date, last_modified_by, last_modified_date, txn_date, last_accrual_date, lien_amount, 
		encrypted_balance, branch_code, product_id, tds_amount, lcy_amount)
 ON (target.account_id = source.account_id and target.txn_date=source.txn_Date) 
WHEN NOT MATCHED THEN  
  INSERT
	(	account_id, day_open_balance, maker_clear_balance, maker_unclear_balance, checker_unclear_balance, checker_clear_balance, day_close_balance, available_balance, 
		interest_accrual, sprinkle, is_active, created_by, created_date, last_modified_by, last_modified_date, txn_date, last_accrual_date, lien_amount, 
		encrypted_balance, branch_code, product_id, tds_amount, lcy_amount
	)
	VALUES(source.account_id, source.day_open_balance, source.maker_clear_balance, source.maker_unclear_balance, source.checker_unclear_balance, source.checker_clear_balance, source.day_close_balance, 
	source.available_balance,source.interest_accrual, source.sprinkle, source.is_active, source.created_by, source.created_date, source.last_modified_by, source.last_modified_date, source.txn_date, source.last_accrual_date, source.lien_amount,source.encrypted_balance, 
	source.branch_code, source.product_id, source.tds_amount, source.lcy_amount
	);


IF(
SELECT 
	COUNT(1)
FROM
	BSGCORE..account_master am
	 LEFT OUTER JOIN bsgaccounting..account_balance abcurrent with (nolock) ON am.account_id = abcurrent.account_id
        AND abcurrent.txn_date = @p_rundate
where
	 am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1) <100
BEGIN

		
INSERT INTO BSGACCOUNTING..account_balance (
account_id,day_open_balance,maker_clear_balance,maker_unclear_balance,checker_clear_balance,checker_unclear_balance,day_close_balance,available_balance,
interest_accrual,sprinkle,is_active,created_by,created_date,last_modified_by,last_modified_date,txn_date,last_accrual_date,encrypted_balance,lien_amount, 
		 branch_code, product_id, tds_amount, lcy_amount
		 
)
SELECT 
	am.account_id,0 day_open_balance,0 
	maker_clear_balance,
	0 maker_unclear_balance,0 checker_clear_balance,
	0 checker_unclear_balance,0 day_close_balance,0 available_balance,
	0 interest_accrual,'N/A' sprinkle,1 
	is_active,
	-777 created_by,GETDATE() created_date,
	-1 last_modified_by,GETDATE() last_modified_date,@p_rundate txn_date,
	@p_rundate last_accrual_date,'N/A'encrypted_balance, 
	ISNULL(abcurrent.lien_amount, 0) lien_amount,
	ISNULL(abcurrent.branch_code,am.branch_code) branch_code,
	ISNULL(abcurrent.product_id,am.product_id) product_id,
	ISNULL(abcurrent.tds_amount,0) tds_amount,
	abcurrent.lcy_amount
	
FROM
	BSGCORE..account_master am
	 LEFT OUTER JOIN bsgaccounting..account_balance abcurrent with (nolock) ON am.account_id = abcurrent.account_id
        AND abcurrent.txn_date = @p_rundate
where
	 am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1;
	
END


/*
DECLARE @v_noOfInsert bigint; 
DECLARE @v_maxNoOfLoop bigint; 
DECLARE @v_currentNoOfLoop bigint; 
DECLARE @v_batchSize bigint;
set @v_batchSize = 100000;


SET @v_noOfInsert = (

SELECT 
    count(1)  
FROM
    bsgcore..account_master am
        INNER JOIN bsgaccounting..account_balance ab  with (nolock)
            ON am.account_id = ab.account_id
        INNER JOIN
        (
            SELECT 
                account_id, MAX(txn_date) txn_date
            FROM
                bsgaccounting..account_balance with (nolock)
            WHERE
                txn_date <= @P_RUNDATE
            GROUP BY account_id
        ) a 
            ON ab.account_id = a.account_id AND ab.txn_date = a.txn_date
        LEFT OUTER JOIN bsgaccounting..account_balance abcurrent  with (nolock)
            ON ab.account_id = abcurrent.account_id AND abcurrent.txn_date = @P_RUNDATE
WHERE
        am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1
		);

	
SET @v_maxNoOfLoop =  ceiling(@v_noOfInsert/@v_batchSize);
SET @v_currentNoOfLoop = 0;

--Dbms_Output.Put_Line(@v_maxNoOfLoop);
--Dbms_Output.Put_Line(@v_noOfInsert);


WHILE @v_currentNoOfLoop < @v_maxNoOfLoop
BEGIN
 
	  
    
   -- Dbms_Output.Put_Line(@v_currentNoOfLoop);
	 INSERT INTO account_balance 
	(	account_id, day_open_balance, maker_clear_balance, maker_unclear_balance, checker_unclear_balance, checker_clear_balance, day_close_balance, available_balance, 
		interest_accrual, sprinkle, is_active, created_by, created_date, last_modified_by, last_modified_date, txn_date, last_accrual_date, lien_amount, 
		encrypted_balance, branch_code, product_id, tds_amount, fcy_currency, lcy_amount, fcy_exchange_rate,value_dated_interest_accrual
	)

	select 
	 distinct 
		account_id, day_open_balance, maker_clear_balance, maker_unclear_balance, checker_unclear_balance, checker_clear_balance, day_close_balance, available_balance, 
		interest_accrual, sprinkle, is_active, created_by, created_date, last_modified_by, last_modified_date, txn_date, last_accrual_date, lien_amount, 
		encrypted_balance, branch_code, product_id, tds_amount, fcy_currency, lcy_amount, fcy_exchange_rate,value_dated_interest_accrual
	from
	
	(
	SELECT 
		ROW_NUMBER() over(order by am.account_id) rownum,
		am.account_id,
		ISNULL(ab.day_open_balance, 0)day_open_balance,
		ISNULL(ab.maker_clear_balance, 0)maker_clear_balance,
		ISNULL(ab.maker_unclear_balance, 0)maker_unclear_balance,
		ISNULL(ab.checker_unclear_balance, 0)checker_unclear_balance,
		ISNULL(ab.checker_clear_balance, 0)checker_clear_balance,
		ISNULL(ab.day_close_balance, 0)day_close_balance,
		ISNULL(ab.available_balance, 0)available_balance,
		ISNULL(ab.interest_accrual,0)interest_accrual,
		ISNULL(ab.sprinkle, 'N/A')sprinkle,
		ISNULL(ab.is_active, 1) is_active,
		ISNULL(ab.created_by, -888) created_by,
		CURRENT_TIMESTAMP created_date,
		ISNULL(ab.last_modified_by, -1) last_modified_by,
		CURRENT_TIMESTAMP last_modified_date,
		@P_RUNDATE txn_date,
		ISNULL(ab.last_accrual_date, @P_RUNDATE) last_accrual_date,
		ISNULL(ab.encrypted_balance, 'N/A') encrypted_balance,
		ISNULL(ab.lien_amount, 0) lien_amount,
		ISNULL(ab.branch_code,am.branch_code) branch_code,
		ISNULL(ab.product_id,am.product_id) product_id,
		ISNULL(ab.tds_amount,0) tds_amount,
		ab.fcy_currency,
		ab.lcy_amount,ab.fcy_exchange_rate,
		ISNULL(ab.value_dated_interest_accrual,0) value_dated_interest_accrual
	FROM
		bsgcore..account_master am
			INNER JOIN bsgaccounting..account_balance ab  with (nolock)
				ON am.account_id = ab.account_id
			INNER JOIN
			(
				SELECT 
					account_id, MAX(txn_date) txn_date
				FROM
					bsgaccounting..account_balance with (nolock)
				WHERE
					txn_date <= @P_RUNDATE
				GROUP BY account_id
			) a 
				ON ab.account_id = a.account_id AND ab.txn_date = a.txn_date
			LEFT OUTER JOIN bsgaccounting..account_balance abcurrent with (nolock)
				ON ab.account_id = abcurrent.account_id AND abcurrent.txn_date = @P_RUNDATE
	WHERE
			am.account_status_id <> 4
			AND abcurrent.account_id IS NULL
			--and ab.interest_accrual > 0
			AND am.is_Active = 1 
		)A
	Where	
			A.rownum <= @v_batchSize;


	SET  @v_currentNoOfLoop = @v_currentNoOfLoop + 1;

	 
   
 END ;

INSERT INTO account_balance 
(	account_id,
    day_open_balance,
    maker_clear_balance,
    maker_unclear_balance,
    checker_unclear_balance,
    checker_clear_balance,
    day_close_balance,
    available_balance,
    interest_accrual,
    sprinkle,
    is_active,
    created_by,
    created_date,
    last_modified_by,
    last_modified_date,
    txn_date,
    last_accrual_date,
    encrypted_balance,
    lien_amount,branch_code, product_id, tds_amount, fcy_currency, lcy_amount, fcy_exchange_rate,value_dated_interest_accrual
)
SELECT 
    distinct am.account_id,
    ISNULL(ab.day_open_balance, 0),
    ISNULL(ab.maker_clear_balance, 0),
    ISNULL(ab.maker_unclear_balance, 0),
    ISNULL(ab.checker_unclear_balance, 0),
    ISNULL(ab.checker_clear_balance, 0),
    ISNULL(ab.day_close_balance, 0),
    ISNULL(ab.available_balance, 0),
    ISNULL(ab.interest_accrual,0),
    ISNULL(ab.sprinkle, 'N/A'),
    ISNULL(ab.is_active, 1),
    ISNULL(ab.created_by, -999),
    CURRENT_TIMESTAMP,
    ISNULL(ab.last_modified_by, -1),
    CURRENT_TIMESTAMP,
    @P_RUNDATE txn_date,
    ISNULL(ab.last_accrual_date, @P_RUNDATE),
    ISNULL(ab.encrypted_balance, 'N/A'),
    ISNULL(ab.lien_amount, 0) lien_amount,
	ISNULL(ab.branch_code,am.branch_code) branch_code,
	ISNULL(ab.product_id,am.product_id) product_id,
	ISNULL(ab.tds_amount,0) tds_amount,
	ab.fcy_currency,
	ab.lcy_amount,ab.fcy_exchange_rate,
	ISNULL(ab.value_dated_interest_accrual,0) value_dated_interest_accrual
FROM
     bsgcore..account_master am
        INNER JOIN bsgaccounting..account_balance ab  with (nolock)
            ON am.account_id = ab.account_id
        INNER JOIN
        (
            SELECT 
                account_id, MAX(txn_date) txn_date
            FROM
                bsgaccounting..account_balance with (nolock)
            WHERE
                txn_date <= @P_RUNDATE
            GROUP BY account_id
        ) a 
            ON ab.account_id = a.account_id AND ab.txn_date = a.txn_date
        LEFT OUTER JOIN bsgaccounting..account_balance abcurrent with (nolock)
            ON ab.account_id = abcurrent.account_id AND abcurrent.txn_date = @P_RUNDATE
WHERE
        am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1;

		
INSERT INTO BSGACCOUNTING..account_balance (
account_id,day_open_balance,maker_clear_balance,maker_unclear_balance,checker_clear_balance,checker_unclear_balance,day_close_balance,available_balance,
interest_accrual,sprinkle,is_active,created_by,created_date,last_modified_by,last_modified_date,txn_date,last_accrual_date,encrypted_balance,lien_amount, 
		 branch_code, product_id, tds_amount, fcy_currency, lcy_amount, fcy_exchange_rate,
		 value_dated_interest_accrual
)
SELECT 
	am.account_id,0 day_open_balance,0 
	maker_clear_balance,
	0 maker_unclear_balance,0 checker_clear_balance,
	0 checker_unclear_balance,0 day_close_balance,0 available_balance,
	0 interest_accrual,'N/A' sprinkle,1 
	is_active,
	-777 created_by,GETDATE() created_date,
	-1 last_modified_by,GETDATE() last_modified_date,@p_rundate txn_date,
	@p_rundate last_accrual_date,'N/A'encrypted_balance, 
	ISNULL(abcurrent.lien_amount, 0) lien_amount,
	ISNULL(abcurrent.branch_code,am.branch_code) branch_code,
	ISNULL(abcurrent.product_id,am.product_id) product_id,
	ISNULL(abcurrent.tds_amount,0) tds_amount,
	abcurrent.fcy_currency,
	abcurrent.lcy_amount,abcurrent.fcy_exchange_rate,
	ISNULL(abcurrent.value_dated_interest_accrual,0) value_dated_interest_accrual
FROM
	BSGCORE..account_master am
	 LEFT OUTER JOIN bsgaccounting..account_balance abcurrent with (nolock) ON am.account_id = abcurrent.account_id
        AND abcurrent.txn_date = @p_rundate
where
	 am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1;
*/

END ;