
-- =============================================
-- Author:		Siddharth Mangroliya
-- Create date: 31-01-2020
-- Description:	Verify Pl Accounts
-- =============================================
CREATE     PROCEDURE [dbo].[sp_verify_pl_account]  -- sp_verify_pl_account
AS
BEGIN
	SET NOCOUNT ON;

	SELECT pm.product_description, pm.product_code 
	FROM BSGLOAN..loan_product_master lpm 
	INNER JOIN BSGCORE..product_master pm 
	ON lpm.loan_product_id = pm.product_id AND lpm.is_active = 1 AND pm.is_active = 1 
	LEFT JOIN BSGCORE..account_master_internal ami 
	ON CAST(ami.internal_account_id AS nvarchar(50)) = lpm.interest_income_pl_code AND ami.is_active = 1 
	WHERE --pm.branch_code <> ami.branch_code OR
	ami.internal_account_id IS NULL 
	UNION ALL 
	SELECT pm.product_description, pm.product_code 
	FROM BSGLOAN..loan_product_master lpm 
	INNER JOIN BSGCORE..product_master pm 
	ON lpm.loan_product_id = pm.product_id AND lpm.is_active = 1 AND pm.is_active = 1 
	LEFT JOIN BSGCORE..account_master_internal ami 
	ON CAST(ami.internal_account_id AS nvarchar(50)) = lpm.penal_interest_pl_account_id AND ami.is_active = 1 
	WHERE --pm.branch_code <> ami.branch_code OR 
	ami.internal_account_id IS NULL 
	UNION ALL 
	SELECT pm.product_description, pm.product_code 
	FROM BSGTD..td_product_master tpm 
	INNER JOIN BSGCORE..product_master pm 
	ON tpm.product_id = pm.product_id AND tpm.is_active = 1 AND pm.is_active = 1 
	LEFT JOIN BSGCORE..account_master_internal ami 
	ON CAST(ami.internal_account_id AS bigint) = tpm.pl_account_id AND ami.is_active = 1 
	WHERE --pm.branch_code <> ami.branch_code OR 
	ami.internal_account_id IS NULL 
	UNION ALL 
	SELECT pm.product_description, pm.product_code 
	FROM BSGCORE..product_interest pi 
	INNER JOIN BSGCORE..product_master pm 
	ON pi.product_id = pm.product_id AND pi.is_active = 1 AND pm.is_active = 1 
	LEFT JOIN BSGCORE..account_master_internal ami 
	ON cast(ami.internal_account_id AS bigint) = pi.pl_account_id AND ami.is_active = 1 
	WHERE --pm.branch_code <> ami.branch_code OR 
	ami.internal_account_id IS NULL;
END

