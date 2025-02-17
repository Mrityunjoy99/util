create    PROCEDURE [dbo].[ChargeCollection_ValidationCheck]
@ChargeId INT
AS

BEGIN

DECLARE @cbsAppDate DATETIME = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active=1)

INSERT INTO bsgaccounting..account_balance 
(	
	account_id,day_open_balance,maker_clear_balance,maker_unclear_balance,checker_unclear_balance,checker_clear_balance,day_close_balance,available_balance,
	interest_accrual,sprinkle,is_active,created_by,created_date,last_modified_by,last_modified_date,txn_date,last_accrual_date,encrypted_balance,lien_amount,
	branch_code,product_id,tds_amount
)
SELECT 
    ab.account_id,
    ab.day_open_balance,
    ab.maker_clear_balance,
    ab.maker_unclear_balance,
    ab.checker_unclear_balance,
    ab.checker_clear_balance,
    ab.day_close_balance,
    ab.available_balance,
    ISNULL(ab.interest_accrual,0),
    ab.sprinkle,
    ab.is_active,
    ab.created_by,
    GETDATE(),
    ab.last_modified_by,
    GETDATE(),
    @cbsAppDate txn_date,
    ab.last_accrual_date,
    ab.encrypted_balance,
    ab.lien_amount,
	ab.branch_code,
	ab.product_id,
	ab.tds_amount
FROM
    bsgcore..account_master am
    INNER JOIN bsgaccounting..account_balance ab 
		ON am.account_id = ab.account_id
    INNER JOIN 
	(
		SELECT 
			account_id, MAX(txn_date) txn_date
		FROM
			bsgaccounting..account_balance
		WHERE
			txn_date <= @cbsAppDate
		GROUP BY account_id
	) a 
		ON ab.account_id = a.account_id
		AND ab.txn_date = a.txn_date
    LEFT OUTER JOIN bsgaccounting..account_balance abcurrent 
		ON ab.account_id = abcurrent.account_id
        AND abcurrent.txn_date = @cbsAppDate
	WHERE
        am.account_status_id <> 4
        AND abcurrent.account_id IS NULL
        --and ab.interest_accrual > 0
		AND am.is_Active = 1
		and am.account_id IN(
		SELECT 
			c.account_id 
		FROM 
			charge_collection c WITH(NOLOCK)
		WHERE 
			is_active=1
			and charge_id=@ChargeId
			and classification_id IN(1,2)
		)


INSERT INTO bsgaccounting..account_balance_loan
(
	loan_account_id,statement_opening_balance,day_opening_balance,maker_unclear_balance,maker_clear_balance,checker_unclear_balance,checker_clear_balance,day_end_balance,
	interest_accrual,interest_applied,interest_paid,charges_applied,charges_paid,penal_interest_accrual,penal_interest_applied,penal_interest_paid,principal_outstanding,
	legal_fee,lawyer_fee,npa_interest,overdue_amount,debit_summation,credit_summation,disbursement_count,disbursement_amount,sanction_limit,available_dp,available_balance,
	overdue_days_count,npa_amount,npa_marked_date,earmarked_amount,created_by,created_date,last_modified_by,last_modified_date,txn_date,is_active,adhoc_amount,
	installment_amount,is_final_installment_amount,received_amount,security_amount_overdue_days,npa_interest_amount,npa_penal_interest_amount,npa_charges_amount,bddr_interest_outstanding,
	principal_waived_off,interest_waived_off,penal_interest_waived_off,margin_amount,subsidy_realised,subsidy_received,excess_interest,margin_realised_amount,branch_code
)
SELECT 
ab.loan_account_id
,ab.statement_opening_balance
,ab.day_opening_balance
,ab.maker_unclear_balance
,ab.maker_clear_balance
,ab.checker_unclear_balance
,ab.checker_clear_balance
,ab.day_end_balance
,ab.interest_accrual
,ab.interest_applied
,ab.interest_paid
,ab.charges_applied
,ab.charges_paid
,ab.penal_interest_accrual
,ab.penal_interest_applied
,ab.penal_interest_paid
,ab.principal_outstanding
,ab.legal_fee
,ab.lawyer_fee
,ab.npa_interest
,ab.overdue_amount
,ab.debit_summation
,ab.credit_summation
,ab.disbursement_count
,ab.disbursement_amount
,ab.sanction_limit
,ab.available_dp
,ab.available_balance
,ab.overdue_days_count
,ab.npa_amount
,ab.npa_marked_date
,ab.earmarked_amount
,ab.created_by
,ab.created_date
,ab.last_modified_by
,ab.last_modified_date
,@cbsAppDate
,ab.is_active
,ab.adhoc_amount
,ab.installment_amount
,ab.is_final_installment_amount
,ab.received_amount
,ab.security_amount_overdue_days
,ab.npa_interest_amount
,ab.npa_penal_interest_amount
,ab.npa_charges_amount
,ab.bddr_interest_outstanding
,ab.principal_waived_off
,ab.interest_waived_off
,ab.penal_interest_waived_off
,ab.margin_amount
,ab.subsidy_realised
,ab.subsidy_received
,ab.excess_interest
,ab.margin_realised_amount
,ab.branch_code
FROM
    bsgloan..loan_account_master lam
	INNER JOIN bsgaccounting..account_balance_loan ab 
		ON lam.loan_account_id = ab.loan_account_id
    INNER JOIN
    (
		SELECT 
			loan_account_id, MAX(txn_date) txn_date
		FROM
			bsgaccounting..account_balance_loan WHERE    txn_date <= @cbsAppDate
		GROUP BY 
			loan_account_id
	) a 
    ON ab.loan_account_id = a.loan_account_id
        AND ab.txn_date = a.txn_date
	LEFT OUTER JOIN bsgaccounting..account_balance_loan abcurrent 
		ON ab.loan_account_id = abcurrent.loan_account_id 
		AND abcurrent.txn_date = @cbsAppDate
WHERE
        abcurrent.loan_account_id IS NULL
		AND lam.loan_account_status != 2
		and lam.is_active=1
		and ab.is_active=1
		and lam.loan_account_id IN(
			SELECT 
				c.account_id 
			FROM 
				charge_collection c WITH(NOLOCK)
			WHERE 
				is_active=1
				and charge_id=@ChargeId
				and classification_id IN(3,6)
		)
	--SELECT
	--*
	--FROM
	UPDATE
	charge_collection 
		SET is_active=0,modified_by=-2,modified_date=GETDATE(),status=-2
	WHERE charge_collection.%%physloc%% not in 
	(
		SELECT max(b.%%physloc%%)
		FROM charge_collection b WITH (NOLOCK)
		WHERE b.is_active=1
		and b.status=0
		and b.charge_id=@ChargeId
		GROUP BY b.account_id
	)
	and charge_collection.is_active=1
	and charge_collection.status=0
	and charge_collection.charge_id=@ChargeId

	UPDATE c
		SET c.is_active=0,c.modified_by=-2,c.modified_date=GETDATE(),status=-2
	FROM
	BSGCORE..account_master am
	INNER JOIN charge_collection c
		ON am.account_id=c.account_id
		and c.is_active=1
		and c.charge_id=@ChargeId
	WHERE
		am.account_status_id IN(4,8)
		and am.is_active=1

	UPDATE c
		SET c.is_active=0,c.modified_by=-2,c.modified_date=GETDATE(),status=-2
	FROM
	BSGLOAN..loan_account_master am
	INNER JOIN charge_collection c
		ON am.loan_account_id=c.account_id
		and c.is_active=1
		and c.charge_id=@ChargeId
	WHERE
		am.loan_account_status IN(2,8)
		and am.is_active=1
		

UPDATE cc 
	 SET cc.is_active=0,status=-1 
	FROM 
	charge_collection cc 
	INNER JOIN charge_exclusion ce 
	 on cc.account_id = ce.account_id 
	 and cc.charge_id = ce.charge_activity and ce.is_active = 1 
	where 
	 cc.is_active = 1 and cc.status = 0 
	 and cc.charge_id=@ChargeId
END
