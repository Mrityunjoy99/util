create    PROCEDURE [dbo].[CashHandlingCharges]
AS
BEGIN

DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)

SET @cbsAppDate=DATEADD(D,-1,@cbsAppDate)

--SELECT TOP 10  * FROM BSGACCOUNTING..account_charges
--INSERT INTO account_charges
SELECT * FROM
(
select 
	-1 txn_ref_no,
	-1 chg_ref_no,
	account_id, 11107 activity_id,
	(CASE WHEN (DenomCnt) < 3 THEN 0  ELSE  ((DenomCnt)-3)*5 END)
	 charges_amount,
	(CASE WHEN (DenomCnt) < 3 THEN 0  ELSE  ((DenomCnt)-3)*5 END) * .09 cgst_amount,
	(CASE WHEN (DenomCnt) < 3 THEN 0  ELSE  ((DenomCnt)-3)*5 END) * .09  sgst_amount,
	38 charge_type,
	product_code product_code,
	786 created_by,
	GETDATE() created_date,
	786 last_modified_by,
	GETDATE() last_modified_date,
	0 status, 
	'EP' principal_type,
	 @cbsAppDate post_date,
	1 is_active,
	(CASE WHEN TenDenom>=0 THEN CONCAT('10Rs note deposited: ',TenDenom) ELSE  '' END)+
	(CASE WHEN TwentyDenom>=0 THEN CONCAT(' 20Rs note deposited: ',TwentyDenom) ELSE  '' END )
	REMARKS
from(
SELECT 
		tr.account_id,
		SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=10 THEN qty ELSE 0 END) TenDenom,
		SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=20 THEN qty ELSE 0 END) TwentyDenom,
		CEILING((SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=10 THEN qty ELSE 0 END)+SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=20 THEN qty ELSE 0 END))/100.0) DenomCnt,
		tr.txn_posting_date,
		pm.product_code
		FROM
			BSGACCOUNTING..transaction_master tr
			INNER JOIN BSGACCOUNTING..txn_ref_token_mapping tok 
				ON tr.txn_ref_no=tok.txn_ref_no
				and tok.is_active=1
			INNER JOIN BSGACCOUNTING..transaction_denomination trd
				ON tok.token_id=trd.token_id
			INNER JOIN BSGACCOUNTING..customer_view ca
				ON tr.account_id=ca.account_id
				--and ca.is_active=1
			INNER JOIN BSGCORE..product_master pm
				ON ca.product_id=pm.product_id
				and pm.is_active=1
		WHERE
			tr.is_active=1
			and tr.txn_nature='C'
			and tr.txn_type=1
			and tr.txn_posting_date = @cbsAppDate
			and qty>0
			and ca.classification_id=2
		GROUP BY tr.account_id,tr.txn_posting_date,pm.product_code,ca.account_no
		having ((SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=10 THEN qty ELSE 0 END)+
		SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=20 THEN qty ELSE 0 END))>300)
		)c
UNION ALL
select 
	-1 txn_ref_no,
	-1 chg_ref_no,
	account_id, 11107 activity_id,
	(CASE WHEN (DenomCnt) < 3 THEN 0  ELSE  ((DenomCnt)-3)*5 END)
	 charges_amount,
	(CASE WHEN (DenomCnt) < 3 THEN 0  ELSE  ((DenomCnt)-3)*5 END) * .09 cgst_amount,
	(CASE WHEN (DenomCnt) < 3 THEN 0  ELSE  ((DenomCnt)-3)*5 END) * .09  sgst_amount,
	38 charge_type,
	product_code product_code,
	786 created_by,
	GETDATE() created_date,
	786 last_modified_by,
	GETDATE() last_modified_date,
	0 status, 
	'EP' principal_type,
	@cbsAppDate post_date,
	1 is_active,
	(CASE WHEN TenDenom>=0 THEN CONCAT('10Rs note deposited: ',TenDenom) ELSE  '' END)+
	(CASE WHEN TwentyDenom>=0 THEN CONCAT(' 20Rs note deposited: ',TwentyDenom) ELSE  '' END )
	REMARKS
from(
SELECT 
		tr.account_id,
		SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=10 THEN qty ELSE 0 END) TenDenom,
		SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=20 THEN qty ELSE 0 END) TwentyDenom,
		CEILING((SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=10 THEN qty ELSE 0 END)+SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=20 THEN qty ELSE 0 END))/100.0) DenomCnt,
		tr.txn_posting_date,
		pm.product_code
		FROM
			BSGACCOUNTING..transaction_master tr
			INNER JOIN BSGACCOUNTING..txn_ref_token_mapping tok 
				ON tr.txn_ref_no=tok.txn_ref_no
				and tok.is_active=1
			INNER JOIN BSGACCOUNTING..transaction_denomination trd
				ON tok.token_id=trd.token_id
			INNER JOIN BSGACCOUNTING..customer_view ca
				ON tr.account_id=ca.account_id
				--and ca.is_active=1
			INNER JOIN BSGCORE..product_master pm
				ON ca.product_id=pm.product_id
				and pm.is_active=1
		WHERE
			tr.is_active=1
			and tr.txn_nature='C'
			and tr.txn_type=1
			and tr.txn_posting_date = @cbsAppDate
			and qty>0
			and ca.classification_id IN (1,6)
		GROUP BY tr.account_id,tr.txn_posting_date,pm.product_code,ca.account_no
		having ((SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=10 THEN qty ELSE 0 END)+
		SUM(CASE WHEN CAST(dname as DECIMAL(18,2))=20 THEN qty ELSE 0 END))>300)
		)c
		)FINAL
			WHERE charges_amount >0
UPDATE account_charges SET txn_ref_no=id,chg_ref_no=id WHERE txn_ref_no=-1 and is_active=1
END
