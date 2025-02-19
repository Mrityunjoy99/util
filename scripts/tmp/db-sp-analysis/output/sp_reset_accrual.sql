-- =============================================
-- Author:		Vatsal Sura
-- Create date: 2020-02-11
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_reset_accrual] 
	@accountId BIGINT, 
	@branchCode INT, 
	@productCode INT, 
	@classificationId INT, 
	@lastInterestAppliedDate DATE, 
	@updateInterestAccrual INT, 
	@updatePenalInterestAccrual INT
AS
BEGIN
	SET NOCOUNT ON;

	IF @classificationId IN (3, 6)
	BEGIN 

		UPDATE abl SET abl.interest_accrual = CASE WHEN @updateInterestAccrual = 1 THEN 0 ELSE abl.interest_accrual END
		, abl.penal_interest_accrual = CASE WHEN @updatePenalInterestAccrual = 1 THEN 0 ELSE abl.penal_interest_accrual END
		FROM BSGLOAN..loan_account_master lam 
		INNER JOIN BSGLOAN..loan_account_basic lab 
		ON lab.loan_account_id = lam.loan_account_id AND lab.is_active = 1 
		INNER JOIN (SELECT loan_account_id, MAX(txn_date) txn_date FROM BSGACCOUNTING..account_balance_loan WHERE is_active = 1 GROUP BY loan_account_id) maxabl 
		ON maxabl.loan_account_id = lam.loan_account_id 
		INNER JOIN BSGACCOUNTING..account_balance_loan abl 
		ON abl.loan_account_id = lam.loan_account_id 
		AND abl.txn_date = maxabl.txn_date 
		AND abl.is_active = 1 
		LEFT JOIN BSGACCOUNTING..account_loan_last_accrual alla 
		ON alla.loan_account_id = lam.loan_account_id AND alla.is_active = 1 
		WHERE (lam.loan_account_id = @accountId OR @accountId = -1) 
		AND (lam.branch_code = @branchCode OR @branchCode = -1) 
		AND (lam.loan_product_code = @productCode OR @productCode = -1) 
		AND lam.loan_type = CASE WHEN @classificationId = 3 THEN 1 WHEN @classificationId = 6 THEN 2 END 
		AND lam.loan_account_status <> 2 AND lam.is_active = 1;

		UPDATE alla SET alla.accrual_date = CASE WHEN @updateInterestAccrual = 1 THEN @lastInterestAppliedDate ELSE alla.accrual_date END 
		, alla.penal_accrual_date = CASE WHEN @updatePenalInterestAccrual = 1 THEN @lastInterestAppliedDate ELSE alla.penal_accrual_date END 
		FROM BSGLOAN..loan_account_master lam 
		INNER JOIN BSGLOAN..loan_account_basic lab 
		ON lab.loan_account_id = lam.loan_account_id AND lab.is_active = 1 
		INNER JOIN (SELECT loan_account_id, MAX(txn_date) txn_date FROM BSGACCOUNTING..account_balance_loan WHERE is_active = 1 GROUP BY loan_account_id) maxabl 
		ON maxabl.loan_account_id = lam.loan_account_id 
		INNER JOIN BSGACCOUNTING..account_balance_loan abl 
		ON abl.loan_account_id = lam.loan_account_id 
		AND abl.txn_date = maxabl.txn_date 
		AND abl.is_active = 1 
		LEFT JOIN BSGACCOUNTING..account_loan_last_accrual alla 
		ON alla.loan_account_id = lam.loan_account_id AND alla.is_active = 1 
		WHERE (lam.loan_account_id = @accountId OR @accountId = -1) 
		AND (lam.branch_code = @branchCode OR @branchCode = -1) 
		AND (lam.loan_product_code = @productCode OR @productCode = -1) 
		AND lam.loan_type = CASE WHEN @classificationId = 3 THEN 1 WHEN @classificationId = 6 THEN 2 END 
		AND lam.loan_account_status <> 2 AND lam.is_active = 1;

	END

	IF @classificationId IN (4)
	BEGIN
		UPDATE abt SET abt.interest_accrual = 0 
		FROM BSGTD..td_account_master tam 
		INNER JOIN BSGTD..td_account_deposit_details tadd 
		ON tadd.td_account_id = tam.td_account_id AND tadd.deposite_type = 3 AND tadd.is_active = 1 
		INNER JOIN (SELECT td_account_id, MAX(id) id FROM BSGACCOUNTING..account_balance_td WHERE is_active = 1 GROUP BY td_account_id) maxabt 
		ON maxabt.td_account_id = tam.td_account_id 
		INNER JOIN BSGACCOUNTING..account_balance_td abt 
		ON abt.td_account_id = tam.td_account_id 
		AND abt.id = maxabt.id 
		LEFT JOIN BSGACCOUNTING..account_td_last_accrual atla 
		ON atla.td_account_id = tam.td_account_id 
		WHERE (tam.td_account_id = @accountId OR @accountId = -1) 
		AND (tam.branch_code = @branchCode OR @branchCode = -1) 
		AND (tam.product_code = @productCode OR @productCode = -1) 
		AND tam.account_status_id = 1 AND tam.is_active = 1;

		UPDATE atla SET atla.accrual_date = @lastInterestAppliedDate 
		FROM BSGTD..td_account_master tam 
		INNER JOIN BSGTD..td_account_deposit_details tadd 
		ON tadd.td_account_id = tam.td_account_id AND tadd.deposite_type = 3 AND tadd.is_active = 1 
		INNER JOIN (SELECT td_account_id, MAX(id) id FROM BSGACCOUNTING..account_balance_td WHERE is_active = 1 GROUP BY td_account_id) maxabt 
		ON maxabt.td_account_id = tam.td_account_id 
		INNER JOIN BSGACCOUNTING..account_balance_td abt 
		ON abt.td_account_id = tam.td_account_id 
		AND abt.id = maxabt.id 
		LEFT JOIN BSGACCOUNTING..account_td_last_accrual atla 
		ON atla.td_account_id = tam.td_account_id 
		WHERE (tam.td_account_id = @accountId OR @accountId = -1) 
		AND (tam.branch_code = @branchCode OR @branchCode = -1) 
		AND (tam.product_code = @productCode OR @productCode = -1) 
		AND tam.account_status_id = 1 AND tam.is_active = 1;
	END
END
