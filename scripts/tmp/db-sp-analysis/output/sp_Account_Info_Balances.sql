CREATE   PROCEDURE [dbo].[sp_Account_Info_Balances]  -- sp_Account_Info_Balances '100120051160410','01-JAN-2015','18-JAN-2019',10
@accountno varchar(50),
@fromdate datetime,
@todate datetime,
@p_size int = NULL
AS

BEGIN

DECLARE @classification_id int = 
(
SELECT
	classification_id
FROM 
	BSGCORE.dbo.customer_accounts WITH(NOLOCK)
WHERE 
	account_no = @accountno
	AND is_active = 1
)

DECLARE @tempbasicdetails TABLE 
(
	branch_code bigint,branch_name varchar(50),product_code varchar(10),product_id varchar(20),
	product_description varchar(100),account_id varchar(100),customer_id varchar(20),account_no varchar(50),
	salutation varchar(20),full_name varchar(100),registered_mobile_no varchar(20),address1 varchar(200),
	address2 varchar(200),address3 varchar(200),pin_code varchar(10),ifsccode varchar(50)
)

DECLARE @transactions TABLE 
(
      Id int IDENTITY,EntryDate datetime,TranTime time,
      ValueDate datetime,narration nvarchar(1000),instrno varchar(20),
      Dr decimal(18,2),Credit decimal(18,2),Balance decimal(18,2),txnRefNo varchar(20),
	txntype varchar(10),batchCode int,created_date DATETIME,last_modified_date DATETIME
)

DECLARE @min INT
DECLARE @max INT
DECLARE @txncnt DECIMAL(18,2)

IF (@classification_id IN (1, 2))
BEGIN

INSERT INTO @tempbasicdetails

SELECT
      AM.branch_code,BM.branch_name,AM.product_code,AM.product_id,
      PM.product_description,AM.account_id,AM.customer_id,CA.account_no,
      CASE 
		WHEN Cm.salutation IN ('-1', 'N/A', 'Select') OR Cm.salutation IS NULL THEN ''
      ELSE 
		(SELECT data_description FROM bsgmaster..picklist_type_data with(nolock) WHERE type_code = 116 AND data_code = Cm.salutation AND is_active = 1)
      END salutation,CM.full_name,
      CM.registered_mobile_no,ISNULL(CUSTADD.address1, ''),ISNULL(CUSTADD.address2, ''),ISNULL(CUSTADD.address3, ''),
      ISNULL(CUSTADD.pin_code, ''),NULL
FROM 
	BSGCORE.dbo.account_master AM WITH(NOLOCK)
	LEFT OUTER JOIN BSGCORE.dbo.customer_accounts CA WITH(NOLOCK)
		ON AM.account_id = CA.account_id AND CA.is_active = 1
	LEFT OUTER JOIN BSGCRM.dbo.customer_master CM WITH(NOLOCK)
		ON AM.customer_id = CM.customer_id AND CM.is_active = 1
	LEFT OUTER JOIN BSGCORE.dbo.product_master PM WITH(NOLOCK)
		ON AM.product_code = PM.product_code AND AM.product_id = PM.product_id AND PM.is_active = 1
	LEFT OUTER JOIN BSGCRM.dbo.customer_address CUSTADD WITH(NOLOCK)
		ON CM.customer_id = CUSTADD.customer_id AND CUSTADD.address_type_code = 1 AND CUSTADD.is_active = 1
	LEFT OUTER JOIN BSGMASTER.dbo.branch_master BM WITH(NOLOCK)
		ON AM.branch_code = BM.branch_code AND BM.is_active = 1
WHERE 
	AM.is_active = 1
	AND (AM.account_status_id <> 4 OR (AM.account_status_id = 4 OR AM.account_closure_date > @fromdate))
	AND CA.account_no = @accountno

END

IF (@classification_id IN (3, 6))
BEGIN

INSERT INTO @tempbasicdetails

SELECT
      AM.branch_code,BM.branch_name,AM.loan_product_code,AM.loan_product_id,
      PM.product_description,AM.loan_account_id,AM.customer_no,CA.account_no,
      CASE 
		WHEN Cm.salutation IN ('-1', 'N/A', 'Select') OR Cm.salutation IS NULL THEN ''
	ELSE 
		(SELECT data_description FROM bsgmaster..picklist_type_data with(nolock) WHERE type_code = 116 AND data_code = Cm.salutation AND is_active = 1)
      END salutation,
      CM.full_name,CM.registered_mobile_no,
      ISNULL(CUSTADD.address1, ''),ISNULL(CUSTADD.address2, ''),ISNULL(CUSTADD.address3, ''),
	ISNULL(CUSTADD.pin_code, ''),NULL
FROM 
	BSGLOAN.dbo.loan_account_master AM WITH(NOLOCK)
	LEFT OUTER JOIN BSGCORE.dbo.customer_accounts CA WITH(NOLOCK)
		ON AM.loan_account_id = CA.account_id AND CA.is_active = 1
	LEFT OUTER JOIN BSGCRM.dbo.customer_master CM WITH(NOLOCK)
		ON AM.customer_no = CM.customer_id AND CM.is_active = 1
	LEFT OUTER JOIN BSGCORE.dbo.product_master PM WITH(NOLOCK)
		ON AM.loan_product_code = PM.product_code AND AM.loan_product_id = PM.product_id AND PM.is_active = 1
	LEFT OUTER JOIN BSGCRM.dbo.customer_address CUSTADD WITH(NOLOCK)
		ON CM.customer_id = CUSTADD.customer_id AND CUSTADD.address_type_code = 1 AND CUSTADD.is_active = 1
	LEFT OUTER JOIN BSGMASTER.dbo.branch_master BM WITH(NOLOCK)
		ON AM.branch_code = BM.branch_code AND BM.is_active = 1
WHERE 
	AM.is_active = 1
	AND (AM.loan_account_status <> 2 OR (AM.loan_account_status = 2 OR AM.loan_account_closure_date > @fromdate))
	AND CA.account_no = @accountno

END

IF (@classification_id IN (5))

BEGIN

INSERT INTO @tempbasicdetails

SELECT
      AM.branch_code,BM.branch_name,AM.product_code,AM.internal_product_id,
      PM.description,AM.internal_account_id,NULL,CA.account_no,
      NULL salutation,AM.description,
      NULL,NULL,NULL,NULL,NULL,NULL
FROM 
	BSGCORE.dbo.account_master_internal AM WITH(NOLOCK)
	LEFT OUTER JOIN BSGCORE.dbo.customer_accounts CA WITH(NOLOCK)
		ON AM.internal_account_id = CA.account_id AND CA.is_active = 1
	LEFT OUTER JOIN BSGCORE.dbo.product_master_internal PM WITH(NOLOCK)
		ON AM.product_code = PM.product_code AND AM.internal_product_id = PM.internal_product_id AND PM.is_active = 1
	LEFT OUTER JOIN BSGMASTER.dbo.branch_master BM WITH(NOLOCK)
		ON AM.branch_code = BM.branch_code AND BM.is_active = 1
WHERE 
	AM.is_active = 1
	AND CA.account_no = @accountno

END

DECLARE @accid varchar(50) = (SELECT TOP 1 account_id FROM @tempbasicdetails)

UPDATE 
	@tempbasicdetails
SET 
	ifsccode = (SELECT TOP 1 ifsc_code FROM BSGMASTER.dbo.branch_master WITH(NOLOCK)
			WHERE is_active = 1 
			AND branch_code = (SELECT branch_code FROM BSGCORE.dbo.account_master WITH(NOLOCK) WHERE account_id = @accid AND is_active = 1))

DECLARE @openingbalance decimal(18, 2)

DECLARE @txnMaxDate datetime = (SELECT MAX(txn_date) FROM BSGACCOUNTING.dbo.account_balance WITH(NOLOCK)
						WHERE account_id = @accid AND txn_date <= @fromdate - 1)


IF (@classification_id IN (1, 2))
BEGIN

	IF (@txnMaxDate IS NOT NULL)
	BEGIN

	SET @openingbalance = (SELECT checker_clear_balance FROM BSGACCOUNTING.dbo.account_balance WITH(NOLOCK)
					WHERE account_id = @accid AND is_active = 1 AND txn_date = @txnMaxDate)

	END

	ELSE
	BEGIN

	SET @openingbalance = 0

	END

END
   
IF (@classification_id IN (3,6))
BEGIN

      IF ((SELECT MAX(txn_date) 
		FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK)
		WHERE loan_account_id = @accid AND txn_date <= @fromdate - 1)
		IS NOT NULL)
      BEGIN
      
	SET @openingbalance = (SELECT checker_clear_balance + checker_unclear_balance
					FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK)
					WHERE loan_account_id = @accid AND is_active = 1 
					AND txn_date = (SELECT MAX(txn_date)
								FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK)
								WHERE loan_account_id = @accid AND txn_date <= @fromdate - 1))
      END
      
	ELSE
      BEGIN

      SET @openingbalance = 0
      
	END
END


IF (@classification_id IN (5))
BEGIN

      IF ((SELECT MAX(txn_date)
		FROM BSGACCOUNTING.dbo.account_balance_internal WITH(NOLOCK)
		WHERE account_id = @accid AND txn_date <= @fromdate - 1) IS NOT NULL)
      BEGIN
      
	SET @openingbalance = (SELECT checker_clear_balance
					FROM BSGACCOUNTING.dbo.account_balance_internal WITH(NOLOCK)
					WHERE account_id = @accid AND is_active = 1 
					AND txn_date = (SELECT MAX(txn_date)
								FROM BSGACCOUNTING.dbo.account_balance_internal WITH(NOLOCK)
								WHERE account_id = @accid AND txn_date <= @fromdate - 1))
      
	END
      
	ELSE
      BEGIN

      SET @openingbalance = 0
      
	END

END


DECLARE @opbal decimal(18, 2) = ISNULL(@openingbalance, 0)

IF(@classification_id in (1,2,3,4,6))

BEGIN
	INSERT INTO @transactions(EntryDate ,TranTime ,ValueDate ,narration ,instrno ,Dr ,Credit ,Balance ,txnRefNo ,txntype ,batchCode,created_date,last_modified_date )
	SELECT
		A.txn_posting_date,
		A.txn_time,
		A.txn_value_date,
		A.narration,
		A.instr_no, 
		A.DEBIT,
		A.CREDIT,
		A.balance,
		A.txn_ref_no,
		A.txn_type,
		A.batch_code,
		A.created_date,
		A.last_modified_date
	FROM
	(
	SELECT 
		id,txn_posting_date,txn_time,txn_value_date,narration,instr_no,case when txn_nature ='D' then txn_amount else 0 end DEBIT,
		case when txn_nature ='C' then txn_amount else 0 end CREDIT,null as balance,txn_ref_no,txn_type,batch_code,
		created_date,last_modified_date
	FROM 
		bsgaccounting..transaction_master WITH(NOLOCK)
	WHERE 
		txn_posting_date >= @fromdate
		and txn_posting_date <= @todate
		AND account_id = @accid and is_active=1
	
    UNION ALL
    
    SELECT 
		id,txn_posting_date,txn_time,txn_value_date,narration,instr_no,case when txn_nature ='D' then txn_amount else 0 end DEBIT,
		case when txn_nature ='C' then txn_amount else 0 end CREDIT,null as balance,txn_ref_no,txn_type,batch_code,
		created_date,last_modified_date
	FROM 
		bsgdeepfreeze..transaction_master_df WITH(NOLOCK)
	WHERE 
		txn_posting_date >= @fromdate
		and txn_posting_date <= @todate
		AND account_id = @accid
		and is_active=1
	UNION ALL
	 SELECT 
		id,txn_posting_date,txn_time,txn_value_date,narration,instr_no,case when txn_nature ='D' then txn_amount else 0 end DEBIT,
		case when txn_nature ='C' then txn_amount else 0 end CREDIT,null as balance,txn_ref_no,txn_type,batch_code,
		created_date,last_modified_date
	FROM 
		bsgdeepfreeze..transaction_master_history WITH(NOLOCK)
	WHERE 
		txn_posting_date >= @fromdate
		and txn_posting_date <= @todate
		AND account_id = @accid
		and is_active=1
	)A
    ORDER BY
		A.id;
END

ELSE

BEGIN

    INSERT INTO @transactions(EntryDate ,TranTime ,ValueDate ,narration ,instrno ,Dr ,Credit ,Balance ,txnRefNo ,txntype ,batchCode,created_date,last_modified_date )
    
	SELECT
		A.txn_posting_date,
		A.txn_time,
		A.txn_value_date,
		A.narration,
		A.instr_no,
		A.DEBIT,
		A.CREDIT,
		A.balance,
		A.txn_ref_no,
		A.txn_type,
		A.batch_code,
		A.created_date,
		A.last_modified_date
	FROM
	(
	SELECT 
		  tmi.id,tmi.txn_posting_date,tmi.txn_time,tmi.txn_value_date,tmi.narration,tmi.instr_no,case when tmi.txn_nature ='D' then tmi.txn_amount else 0 end DEBIT,
		  case when tmi.txn_nature ='C' then tmi.txn_amount else 0 end CREDIT,
		  null as balance,tmi.txn_ref_no,tmi.txn_type,tmi.batch_code,tmi.created_date,tmi.last_modified_date
	from  
		bsgaccounting..transaction_master_internal tmi WITH(NOLOCK)
	where 
		tmi.principal_id = @accid 
		and tmi.principal_type = 'IA'
		and tmi.txn_posting_date >= @fromdate
		and tmi.txn_posting_date <= @todate
		and tmi.is_active = 1
	
    UNION ALL
    
	SELECT 
		tmi_df.id,tmi_df.txn_posting_date,tmi_df.txn_time,tmi_df.txn_value_date,tmi_df.narration,
		tmi_df.instr_no,case when tmi_df.txn_nature ='D' then tmi_df.txn_amount else 0 end DEBIT,
		case when tmi_df.txn_nature ='C' then tmi_df.txn_amount else 0 end CREDIT,
		null as balance,tmi_df.txn_ref_no,tmi_df.txn_type,tmi_df.batch_code,tmi_df.created_date,tmi_df.last_modified_date
	from 
		bsgdeepfreeze..transaction_master_internal_df tmi_df WITH(NOLOCK)
	where 
		tmi_df.principal_id = @accid 
		and tmi_df.principal_type = 'IA'
		and tmi_df.txn_posting_date >= @fromdate
		and tmi_df.txn_posting_date <= @todate
		and tmi_df.is_active=1
    )A
    order by 
        A.id;

END

SET @min = (SELECT MIN(Id) FROM @transactions);
SET @max = (SELECT MAX(Id) FROM @transactions);

WHILE(@min <= @max)
BEGIN

UPDATE @transactions SET Balance = (@openingbalance + Credit)-Dr WHERE Id = @min;

SET @openingbalance = (SELECT Balance FROM @transactions WHERE Id = @min);

set @min = @min + 1;

END

UPDATE @transactions SET instrno = NULL WHERE instrno = '0';

SET @txncnt = (SELECT count(*) FROM @transactions);

SELECT 
	*,@opbal AS OPENINGBALANCE,@openingbalance AS ClosingBalance,
	cast(ceiling(@txncnt/@p_size ) AS INT) noofpages 
FROM 
	@tempbasicdetails

END
