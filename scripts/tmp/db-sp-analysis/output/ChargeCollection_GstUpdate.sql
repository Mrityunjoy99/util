
-- =============================================
-- Author:		<ASHISH L>
-- Create date: <2023-01-23 18:24:03.097> SELECT GETDATE()
-- Description:	<Gst Update AccountWise>
-- Exec: ChargeCollection_GstUpdate 1,1
-- =============================================
CREATE     PROCEDURE [dbo].[ChargeCollection_GstUpdate]
@ChargeId INT,
@TaxMethod INT = 0
AS
BEGIN

DECLARE @cgst DECIMAL(18,2) = 9.0, @sgst DECIMAL(18,2)=9.0, @utgst DECIMAL(18,2) = 9.0, @igst DECIMAL(18,2) = 18.0

SELECT AccountId, BranchCode,
COALESCE(AccountGstStateId,CustomerGstStateId,AddressStateId,HomeBranchStateId,0) stateCode,
COALESCE(AccountUTFlag,CustomerUTFlag,AddressUTFLag,HomeBranchUTFLag,0) IsUtGst
INTO #AccountGstDetails
FROM
(
SELECT 
	a.account_id AccountId,
	a.account_branch BranchCode,
	b.state_id AccountGstStateId,
	b.is_utgst AccountUTFlag,
	d.customer_id CustomerNo,
	e.state_id CustomerGstStateId, 
	e.is_utgst CustomerUTFlag,
	j.state_id AddressStateId,
	j.is_utgst AddressUTFLag, 
	l.state_id HomeBranchStateId,
	l.is_utgst HomeBranchUTFLag
FROM 
	BSGACCOUNTING..charge_collection a WITH(NOLOCK)
	LEFT JOIN BSGCRM..customer_gst_no_mapping b WITH(NOLOCK)
		ON a.account_id=CAST(b.account_id_locker_id AS int)
		AND b.account_type=1
		AND b.is_active=1
	LEFT JOIN BSGCORE..customer_accounts c WITH(NOLOCK)
		ON a.account_id=c.account_id
		AND c.is_active=1
	LEFT JOIN BSGCRM..customer_master d WITH(NOLOCK)
		ON c.customer_id=d.customer_id
		AND d.is_active=1
	LEFT JOIN BSGMASTER..gst_state_mapping e WITH(NOLOCK)
		--ON SUBSTRING(d.gst_number,1,2) = e.gst_state_code -- GST STATE CODE LOGIC
		ON isnull(try_cast(SUBSTRING(d.gst_number,1,2) as bigint),0) = e.gst_state_code -- 1st 2 digit of GSTNO is STATE CODE
		AND e.is_active=1
	LEFT JOIN BSGCRM..customer_address h WITH(NOLOCK)
		ON d.customer_id=h.customer_id
		AND h.address_type_code=2--MAILING ADDRESS
		AND h.is_active=1
	LEFT JOIN BSGMASTER..gst_state_mapping j WITH(NOLOCK)
		ON h.state_code=j.state_id
		AND j.is_active=1
	LEFT JOIN BSGMASTER..branch_master k WITH(NOLOCK)
		ON a.account_branch=k.branch_code
		AND k.is_active=1
	LEFT JOIN BSGMASTER..gst_state_mapping l WITH(NOLOCK)
		ON k.state_code=l.state_id
		AND l.is_active=1
WHERE a.is_active=1
	AND a.charge_id=@ChargeId
) a
--SELECT * FROM #AccountGstDetails
--Exclusive Tax Calculation
IF(@TaxMethod = 0)
BEGIN
UPDATE a SET 
		igst= isnull(cast((charge_amount * @igst)/100 as decimal(18,2)),0.00)
FROM BSGACCOUNTING..charge_collection a WITH(NOLOCK)
	INNER JOIN #AccountGSTDetails b WITH(NOLOCK)
		ON a.account_id = b.AccountId
	INNER JOIN BSGMASTER..branch_master c WITH(NOLOCK)
		ON b.BranchCode=c.branch_code
		AND c.is_active=1
WHERE
	a.is_active=1
	AND a.charge_id = @ChargeId
	AND b.stateCode<>0
	AND b.stateCode<>c.state_code

UPDATE a SET 
		cgst = isnull(cast((charge_amount * @cgst)/100 as decimal(18,2)),0.00) ,
		sgst = CASE WHEN ISNULL(IsUtGst,0)=0 AND (b.stateCode=c.state_code OR b.stateCode=0) THEN   isnull(cast((charge_amount * @sgst)/100 as decimal(18,2)),0.00) ELSE 0.00 END,
		utgst = CASE WHEN IsUtGst=1 AND (b.stateCode=c.state_code) THEN  isnull(cast((charge_amount * @utgst)/100 as decimal(18,2)),0.00) ELSE 0.00 END
FROM BSGACCOUNTING..charge_collection a WITH(NOLOCK)
	INNER JOIN #AccountGSTDetails b WITH(NOLOCK)
		ON a.account_id = b.AccountId
	INNER JOIN BSGMASTER..branch_master c WITH(NOLOCK)
		ON b.BranchCode=c.branch_code
		AND c.is_active=1
WHERE
	a.is_active=1
	AND a.charge_id = @ChargeId
	AND (b.stateCode=c.state_code OR b.stateCode=0)

--UPDATE a SET
--	  cgst = isnull(cast((charge_amount * @cgst)/100 as decimal(18,2)),0.00),
--	  sgst = isnull(cast((charge_amount * @sgst)/100 as decimal(18,2)),0.00) 
--FROM BSGACCOUNTING..charge_collection a WITH(NOLOCK)
--	INNER JOIN #AccountGSTDetails b WITH(NOLOCK)
--		ON a.account_id = b.AccountId
--	INNER JOIN BSGMASTER..branch_master c WITH(NOLOCK)
--		ON b.BranchCode=c.branch_code
--		AND c.is_active=1
--WHERE
--	a.is_active=1
--	AND a.charge_id = @ChargeId
--	AND (b.stateCode=c.state_code OR b.stateCode=0)
--	AND ISNULL(IsUtGst,0)=0

END

--Inclusive Tax Calculation
IF(@TaxMethod = 1)
BEGIN

UPDATE a SET
	charge_amount = CAST(charge_amount-(charge_amount - (charge_amount * (100 / (100 + 18.0) ) )) as DECIMAL(18,2)) ,
	igst = CAST((charge_amount - (charge_amount * (100 / (100 + 18.0) ) )) as decimal(18,2)) 
FROM BSGACCOUNTING..charge_collection a WITH(NOLOCK)
	INNER JOIN #AccountGSTDetails b WITH(NOLOCK)
		ON a.account_id = b.AccountId
	INNER JOIN BSGMASTER..branch_master c WITH(NOLOCK)
		ON b.BranchCode=c.branch_code
		AND c.is_active=1
WHERE
	a.is_active=1
	AND a.charge_id = @ChargeId
	AND b.stateCode<>0
	AND b.stateCode<>c.state_code

UPDATE a SET
	charge_amount = CAST(charge_amount-(charge_amount - (charge_amount * (100 / (100 + 18.0) ) )) as DECIMAL(18,2)) ,
	cgst = CAST((charge_amount - (charge_amount * (100 / (100 + 18.0) ) ))/2 as decimal(18,2)) ,
	sgst = CASE WHEN ISNULL(IsUtGst,0)=0 AND (b.stateCode=c.state_code OR b.stateCode=0) THEN CAST((charge_amount - (charge_amount * (100 / (100 + 18.0) ) ))/2 as decimal(18,2)) ELSE 0.00 END,
	utgst = CASE WHEN IsUtGst=1 AND (b.stateCode=c.state_code) THEN  CAST((charge_amount - (charge_amount * (100 / (100 + 18.0) ) ))/2 as decimal(18,2)) ELSE 0.00 END
FROM BSGACCOUNTING..charge_collection a WITH(NOLOCK)
	INNER JOIN #AccountGSTDetails b WITH(NOLOCK)
		ON a.account_id = b.AccountId
	INNER JOIN BSGMASTER..branch_master c WITH(NOLOCK)
		ON b.BranchCode=c.branch_code
		AND c.is_active=1
WHERE
	a.is_active=1
	AND a.charge_id = @ChargeId
	AND (b.stateCode=c.state_code OR b.stateCode=0)

--UPDATE a SET
--	charge_amount = CAST(charge_amount-(charge_amount - (charge_amount * (100 / (100 + 18.0) ) )) as DECIMAL(18,2)) ,
--	cgst = CAST((charge_amount - (charge_amount * (100 / (100 + 18.0) ) ))/2 as decimal(18,2)) ,
--	sgst = CAST((charge_amount - (charge_amount * (100 / (100 + 18.0) ) ))/2 as decimal(18,2))
--FROM BSGACCOUNTING..charge_collection a WITH(NOLOCK)
--	INNER JOIN #AccountGSTDetails b WITH(NOLOCK)
--		ON a.account_id = b.AccountId
--	INNER JOIN BSGMASTER..branch_master c WITH(NOLOCK)
--		ON b.BranchCode=c.branch_code
--		AND c.is_active=1
--WHERE
--	a.is_active=1
--	AND a.charge_id = @ChargeId
--	AND (b.stateCode=c.state_code OR b.stateCode=0)
--	AND ISNULL(IsUtGst,0)=0

END

END