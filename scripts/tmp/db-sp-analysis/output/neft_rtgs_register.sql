CREATE   PROCEDURE [dbo].[neft_rtgs_register] -- neft_rtgs_register 0,'2019-02-02','2019-02-14','I',1
(  
@BranchCode		INT,
@FromDate		DATETIME,
@ToDate		DATETIME,
@ClearingType	VARCHAR(10),
@ReportType		INT
)
AS
BEGIN

-- @ClearingType = 'I' -> Inward 
-- @ClearingType = 'O' -> Outward 

CREATE TABLE #temp_outward
(
	transfer_type VARCHAR(20),
	txn_ref_no BIGINT, 	
	utr_no VARCHAR(100),
	branch_name VARCHAR(100),
	account_no VARCHAR(150),
	name VARCHAR(200),
	ben_acc_no VARCHAR(50),
	ben_name VARCHAR(200),
	amount DECIMAL(18,2),
	issue_date DATETIME,
	ifsc_code VARCHAR(50),
	remitter_principal_id INT,
	remitter_principal_type VARCHAR(50)
)

	   
IF(@ClearingType = 'I')

BEGIN
	
SELECT
	A.txn_ref_no,	
	A.principal_id,
	A.branch_code,
	A.account_no,
	A.account_name name,
	A.txn_amount amount,	
	A.utr_no,
	A.created_date issue_date,
	A.transfer_type,
	A.principal_type
INTO 
	#temp_inward 
FROM
(
SELECT 
	nrit.txn_ref_no,	
	nrit.principal_id,
	CASE WHEN nrit.principal_type = 'IP' THEN pmi.branch_code else ca.branch_code end branch_code,
	CASE WHEN nrit.principal_type = 'IP' THEN pmi.product_code else ca.account_no end account_no,
	CASE WHEN nrit.principal_type = 'IP' THEN pmi.description else bsgturingreports.dbo.fn_GetAccountName(ca.account_id) end account_name,
	nrit.txn_amount,	
	nrit.utr_no,
	CAST(nrit.created_date AS DATE) created_date,
	nrit.transfer_type,
	nrit.principal_type			
FROM
	BSGACCOUNTING..neft_rtgs_inward_transaction nrit WITH (NOLOCK)
	LEFT OUTER JOIN BSGCORE..customer_accounts ca WITH (NOLOCK)
		ON nrit.principal_id = ca.account_id and ca.is_active = 1
	LEFT OUTER JOIN bsgcore..product_master_internal pmi WITH (NOLOCK)
		ON nrit.principal_id = pmi.internal_product_id and pmi.is_Active = 1
WHERE
	nrit.is_active = 1
)A
LEFT OUTER JOIN
(
	SELECT ts.txn_ref_no,ts.txn_validation_code FROM BSGACCOUNTING..transaction_status ts WITH(NOLOCK) 
	WHERE ts.is_active = 1 AND ts.txn_date >= @FromDate AND ts.txn_date <= @Todate
	UNION ALL
	SELECT ts_df.txn_ref_no,ts_df.txn_validation_code FROM BSGDEEPFREEZE..transaction_status_df ts_df WITH(NOLOCK) 
	WHERE ts_df.is_active = 1 AND ts_df.txn_date >= @FromDate AND ts_df.txn_date <= @Todate
)B
	ON A.txn_ref_no = B.txn_ref_no 
WHERE
	(@BranchCode = 0 OR A.branch_code = @BranchCode)
	AND (@FromDate IS NULL OR A.created_date >= @FromDate)
	AND (@ToDate IS NULL OR A.created_date <= @ToDate)
	AND B.txn_validation_code = 1

SELECT 
	t.txn_ref_no,	
	t.principal_id,
	CAST(t.branch_code AS VARCHAR) + ' - ' + bm.branch_name branch_name,
	t.account_no,
	t.name,
	t.amount,	
	t.utr_no,
	t.issue_date,
	t.transfer_type,
	t.principal_type,
	NULL ben_acc_no,
	NULL ben_name,
	NULL ifsc_code,
	NULL remitter_principal_id,
	NULL remitter_principal_type
from 
	#temp_inward t
	LEFT OUTER JOIN BSGMASTER..branch_master bm WITH(NOLOCK)
		ON t.branch_code = bm.branch_code AND bm.is_Active = 1
ORDER BY 
	account_no,created_date;

SELECT
	NULL txn_ref_no,	
	NULL principal_id,
	NULL branch_name,
	NULL account_no,
	'TOTAL' name,
	SUM(amount) amount,	
	NULL utr_no,
	NULL issue_date,
	NULL transfer_type,
	NULL principal_type,
	NULL ben_acc_no,
	NULL ben_name,
	NULL ifsc_code,
	NULL remitter_principal_id,
	NULL remitter_principal_type
FROM
	#temp_inward;

SELECT COUNT(*) total_count , SUM(amount) total_amount FROM #temp_inward;

DROP TABLE #temp_inward

END 
	
IF(@ClearingType = 'O')
    
BEGIN
		
	IF(@ReportType = 1)
		
	BEGIN        

	INSERT INTO #temp_outward
	SELECT 
		CASE WHEN nr.rem_txn_type = 'N' THEN 'NEFT' WHEN nr.rem_txn_type = 'R' THEN 'RTGS' END transfer_type,
		nr.txn_ref_no,
		nr.utr_no,
		CAST(nr.txn_branch_code AS VARCHAR) + ' - ' + bm.branch_name as branch_name,
		CASE WHEN nr.remitter_principal_type = 'A' THEN ca.account_no ELSE pmi.product_code END account_no,
		CASE WHEN nr.remitter_principal_type = 'A' THEN bsgturingreports.dbo.fn_GetAccountName(ca.account_id) ELSE pmi.description END name,
		nr.ben_acc_no,
		nr.ben_name,	
		nr.amount,	
		CAST(nr.issue_date AS DATE) issue_date,
		nr.ben_ifsc ifsc_code,
		nr.remitter_principal_id,
		nr.remitter_principal_type
	FROM
		BSGACCOUNTING..neft_rtgs nr WITH(NOLOCK)
		LEFT OUTER JOIN bsgcore..customer_accounts ca WITH(NOLOCK)
			ON nr.remitter_principal_id = ca.account_id AND ca.is_active = 1
		LEFT OUTER JOIN BSGCORE..product_master_internal pmi WITH(NOLOCK)
			ON nr.product_id = pmi.internal_product_id and pmi.is_active = 1
		LEFT OUTER JOIN BSGMASTER..branch_master bm WITH(NOLOCK)
			ON nr.txn_branch_code = bm.branch_code AND bm.is_Active = 1
	WHERE
		nr.is_active = 1	
		AND CAST(nr.issue_date AS DATE) >= @FromDate 
		AND CAST(nr.issue_date AS DATE) <= @ToDate		
			
	SELECT * FROM #temp_outward;
            
	SELECT 
		NULL txn_ref_no,
		NULL utr_no,
		NULL branch_name,
		'TOTAL' ben_acc_no,
		NULL ben_name,
		NULL account_no,
		NULL name,
		SUM(amount) amount, 				
		NULL issue_date,
		NULL ifsc_code,
		NULL transfer_type
	FROM 
		#temp_outward;
            
	SELECT COUNT(*) total_count , SUM(amount) total_amount FROM #temp_outward;
			
	END

	IF(@ReportType = 2)
        
	BEGIN
	
	INSERT INTO #temp_outward	
	SELECT
		NULL transfer_type,
		Main.txn_ref_no,
		NULL utr_no,
		CAST(Main.txn_branch AS VARCHAR) + ' - ' + bm.branch_name as branch_name,
		CASE WHEN Main.principal_type = 'IA' THEN ca.account_no ELSE pmi.product_code END account_no,
		CASE WHEN Main.principal_type = 'IA' THEN bsgturingreports.dbo.fn_GetAccountName(ca.account_id) ELSE pmi.description END name,
		NULL ben_acc_no,
		NULL ben_name,	
		Main.txn_amount amount,	
		Main.txn_posting_date issue_date,
		NULL ifsc_code,
		Main.principal_id remitter_principal_id,
		Main.principal_type remitter_principal_type
	FROM
		(
		SELECT 
			tmi.*
		FROM 
			bsgaccounting..transaction_master_internal tmi
		WHERE
			tmi.is_active = 1 
			AND tmi.principal_id = (
							SELECT pmi.internal_product_id 
							FROM bsgcore..product_master_internal pmi WITH(NOLOCK)
							WHERE pmi.product_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'NEFT_SETTLEMENT_PRODUCT' AND is_active = 1)
							AND pmi.branch_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'HO_BRANCH_ID' AND is_active = 1)
							AND pmi.is_active = 1
							) 
			AND CAST(tmi.txn_posting_date AS DATE) >= @FromDate 
			AND CAST(tmi.txn_posting_date AS DATE) <= @ToDate 
			AND tmi.txn_nature = 'C'
			AND tmi.activity_id in (5022,5023)

		UNION ALL

		SELECT 
			tmi_df.*
		FROM 
			bsgdeepfreeze..transaction_master_internal_df tmi_df WITH(NOLOCK)
		WHERE
			tmi_df.is_active = 1 
			AND tmi_df.principal_id = (
								SELECT pmi.internal_product_id 
								FROM bsgcore..product_master_internal pmi WITH(NOLOCK)
								WHERE pmi.product_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'NEFT_SETTLEMENT_PRODUCT' AND is_active = 1)
								AND pmi.branch_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'HO_BRANCH_ID' AND is_active = 1)
								AND pmi.is_active = 1
							  ) 
			AND CAST(tmi_df.txn_posting_date AS DATE) >= @FromDate 
			AND CAST(tmi_df.txn_posting_date AS DATE) <= @ToDate 
			AND tmi_df.txn_nature = 'C'
			AND tmi_df.activity_id in (5022,5023)
		)Main
	LEFT OUTER JOIN bsgcore..customer_accounts ca WITH(NOLOCK)
		ON Main.principal_id = ca.account_id AND ca.is_active = 1
	LEFT OUTER JOIN BSGCORE..product_master_internal pmi WITH(NOLOCK)
		ON Main.principal_id = pmi.internal_product_id and pmi.is_active = 1
	LEFT OUTER JOIN BSGMASTER..branch_master bm WITH(NOLOCK)
		ON Main.txn_branch = bm.branch_code AND bm.is_Active = 1;
			
	SELECT * FROM #temp_outward;
            
	select 
		NULL txn_ref_no,
		NULL utr_no,
		NULL branch_name,
		'TOTAL' ben_acc_no,
		NULL ben_name,
		NULL account_no,
		NULL name,
		SUM(amount) amount, 				
		NULL issue_date,
		NULL ifsc_code,
		NULL transfer_type
	FROM 
		#temp_outward;
            
	SELECT COUNT(*) total_count , SUM(amount) total_amount FROM #temp_outward;
        
	END

	IF(@ReportType = 3)
        
	BEGIN 			

	INSERT INTO #temp_outward
	SELECT
		NULL transfer_type,
		Main.txn_ref_no,
		NULL utr_no,
		CAST(Main.txn_branch AS VARCHAR) + ' - ' + bm.branch_name as branch_name,
		CASE WHEN Main.principal_type = 'IA' THEN ca.account_no ELSE pmi.product_code END account_no,
		CASE WHEN Main.principal_type = 'IA' THEN bsgturingreports.dbo.fn_GetAccountName(ca.account_id) ELSE pmi.description END name,
		NULL ben_acc_no,
		NULL ben_name,	
		Main.txn_amount amount,	
		Main.txn_posting_date issue_date,
		NULL ifsc_code,
		Main.principal_id remitter_principal_id,
		Main.principal_type remitter_principal_type
	FROM
		(
		SELECT 
			tmi.*
		FROM 
			bsgaccounting..transaction_master_internal tmi WITH(NOLOCK)
		WHERE
			tmi.is_active = 1 
			AND tmi.principal_id = (
							SELECT pmi.internal_product_id 
							FROM bsgcore..product_master_internal pmi WITH(NOLOCK)
							WHERE pmi.product_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'NEFT_SETTLEMENT_PRODUCT' AND is_active = 1)
							AND pmi.branch_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'HO_BRANCH_ID' AND is_active = 1)
							AND pmi.is_active = 1
							) 
			AND CAST(tmi.txn_posting_date AS DATE) >= @FromDate 
			AND CAST(tmi.txn_posting_date AS DATE) <= @ToDate 
			AND tmi.txn_nature = 'C'
			AND tmi.activity_id in (5022,5023)
			AND tmi.txn_ref_no NOT IN (SELECT txn_ref_no FROM BSGACCOUNTING..neft_rtgs WITH(NOLOCK) WHERE CAST(issue_date AS DATE) >=  @FromDate AND CAST(issue_date AS DATE) <= @ToDate AND is_active = 1)

		UNION ALL

		SELECT 
			tmi_df.*
		FROM 
			bsgdeepfreeze..transaction_master_internal_df tmi_df WITH(NOLOCK)
		WHERE
			tmi_df.is_active = 1 
			AND tmi_df.principal_id = (
								SELECT pmi.internal_product_id 
								FROM bsgcore..product_master_internal pmi WITH(NOLOCK)
								WHERE pmi.product_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'NEFT_SETTLEMENT_PRODUCT' AND is_active = 1)
								AND pmi.branch_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'HO_BRANCH_ID' AND is_active = 1)
								AND pmi.is_active = 1
							  ) 
			AND CAST(tmi_df.txn_posting_date AS DATE) >= @FromDate 
			AND CAST(tmi_df.txn_posting_date AS DATE) <= @ToDate 
			AND tmi_df.txn_nature = 'C'
			AND tmi_df.activity_id in (5022,5023)
			AND tmi_df.txn_ref_no NOT IN (SELECT txn_ref_no FROM BSGACCOUNTING..neft_rtgs WITH(NOLOCK) WHERE CAST(issue_date AS DATE) >= @FromDate AND CAST(issue_date AS DATE) <= @ToDate AND is_active = 1)
		)Main
	LEFT OUTER JOIN bsgcore..customer_accounts ca WITH(NOLOCK)
		ON Main.principal_id = ca.account_id AND ca.is_active = 1
	LEFT OUTER JOIN BSGCORE..product_master_internal pmi WITH(NOLOCK)
		ON Main.principal_id = pmi.internal_product_id and pmi.is_active = 1
	LEFT OUTER JOIN BSGMASTER..branch_master bm WITH(NOLOCK)
		ON Main.txn_branch = bm.branch_code AND bm.is_Active = 1;
			
	SELECT * FROM #temp_outward
            
	SELECT 
		NULL txn_ref_no,
		NULL utr_no,
		NULL branch_name,
		'TOTAL' ben_acc_no,
		NULL ben_name,
		NULL account_no,
		NULL name,
		SUM(amount) amount, 				
		NULL issue_date,
		NULL ifsc_code,
		NULL transfer_type
	FROM 
		#temp_outward
            
	SELECT COUNT(*) total_count , SUM(amount) total_amount FROM #temp_outward
            
	END
	
	IF(@ReportType = 4)
        
	BEGIN 
	
	INSERT INTO #temp_outward	
	SELECT 
		CASE WHEN nr.rem_txn_type = 'N' THEN 'NEFT' WHEN nr.rem_txn_type = 'R' THEN 'RTGS' END transfer_type,
		nr.txn_ref_no,
		nr.utr_no,
		CAST(nr.txn_branch_code AS VARCHAR) + ' - ' + bm.branch_name as branch_name,
		CASE WHEN nr.remitter_principal_type = 'A' THEN ca.account_no ELSE pmi.product_code END account_no,
		CASE WHEN nr.remitter_principal_type = 'A' THEN bsgturingreports.dbo.fn_GetAccountName(ca.account_id) ELSE pmi.description END name,
		nr.ben_acc_no,
		nr.ben_name,	
		nr.amount,	
		CAST(nr.issue_date AS DATE) issue_date,
		nr.ben_ifsc ifsc_code,
		nr.remitter_principal_id,
		nr.remitter_principal_type
	FROM
		BSGACCOUNTING..neft_rtgs nr WITH(NOLOCK)
		LEFT OUTER JOIN bsgcore..customer_accounts ca WITH(NOLOCK)
			ON nr.remitter_principal_id = ca.account_id AND ca.is_active = 1
		LEFT OUTER JOIN BSGCORE..product_master_internal pmi WITH(NOLOCK)
			ON nr.product_id = pmi.internal_product_id and pmi.is_active = 1
		LEFT OUTER JOIN BSGMASTER..branch_master bm WITH(NOLOCK)
			ON nr.txn_branch_code = bm.branch_code AND bm.is_Active = 1
	WHERE
		nr.is_active = 1	
		AND CAST(nr.issue_date AS DATE) >= @FromDate 
		AND CAST(nr.issue_date AS DATE) <= @ToDate
		AND nr.txn_ref_no NOT IN 
		(
			SELECT
				Main.txn_ref_no
			FROM
			(
			SELECT 
				tmi.*
			FROM 
				bsgaccounting..transaction_master_internal tmi WITH(NOLOCK)
			WHERE
				tmi.is_active = 1 
				AND tmi.principal_id = (
								SELECT pmi.internal_product_id 
								FROM bsgcore..product_master_internal pmi WITH(NOLOCK)
								WHERE pmi.product_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'NEFT_SETTLEMENT_PRODUCT' AND is_active = 1)
								AND pmi.branch_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'HO_BRANCH_ID' AND is_active = 1)
								AND pmi.is_active = 1
								) 
				AND CAST(tmi.txn_posting_date AS DATE) >= @FromDate 
				AND CAST(tmi.txn_posting_date AS DATE) <= @ToDate 
				AND tmi.txn_nature = 'C'
				AND tmi.activity_id in (5022,5023)

			UNION ALL

			SELECT 
				tmi_df.*
			FROM 
				bsgdeepfreeze..transaction_master_internal_df tmi_df WITH(NOLOCK)
			WHERE
				tmi_df.is_active = 1 
				AND tmi_df.principal_id = (
									SELECT pmi.internal_product_id 
									FROM bsgcore..product_master_internal pmi WITH(NOLOCK)
									WHERE pmi.product_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'NEFT_SETTLEMENT_PRODUCT' AND is_active = 1)
									AND pmi.branch_code = (SELECT config_value FROM bsgadmin..cbs_config WITH(NOLOCK) WHERE config_key = 'HO_BRANCH_ID' AND is_active = 1)
									AND pmi.is_active = 1
								 ) 
				AND CAST(tmi_df.txn_posting_date AS DATE) >= @FromDate 
				AND CAST(tmi_df.txn_posting_date AS DATE) <= @ToDate 
				AND tmi_df.txn_nature = 'C'
				AND tmi_df.activity_id in (5022,5023)
			)Main    
		);
			
	SELECT * FROM #temp_outward
            
	SELECT 
		NULL txn_ref_no,
		NULL utr_no,
		NULL branch_name,
		'TOTAL' ben_acc_no,
		NULL ben_name,
		NULL account_no,
		NULL name,
		SUM(amount) amount, 				
		NULL issue_date,
		NULL ifsc_code,
		NULL transfer_type
	FROM 
		#temp_outward
            
	SELECT COUNT(*) total_count , SUM(amount) total_amount FROM #temp_outward;
       
	END 

	DROP TABLE #temp_outward

END 

END

