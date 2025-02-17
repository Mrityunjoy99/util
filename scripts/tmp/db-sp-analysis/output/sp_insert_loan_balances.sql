-------------------------

CREATE   PROCEDURE [dbo].[sp_insert_loan_balances] -- sp_insert_loan_balances '2018-03-14'
@p_rundate date
as
BEGIN
insert into bsgaccounting..account_balance_loan
(
loan_account_id
,statement_opening_balance
,day_opening_balance
,maker_unclear_balance
,maker_clear_balance
,checker_unclear_balance
,checker_clear_balance
,day_end_balance
,interest_accrual
,interest_applied
,interest_paid
,charges_applied
,charges_paid
,penal_interest_accrual
,penal_interest_applied
,penal_interest_paid
,principal_outstanding
,legal_fee
,lawyer_fee
,npa_interest
,overdue_amount
,debit_summation
,credit_summation
,disbursement_count
,disbursement_amount
,sanction_limit
,available_dp
,available_balance
,overdue_days_count
,npa_amount
,npa_marked_date
,earmarked_amount
,created_by
,created_date
,last_modified_by
,last_modified_date
,txn_date
,is_active
,adhoc_amount
,installment_amount
,is_final_installment_amount
,received_amount
,security_amount_overdue_days
,npa_interest_amount
,npa_penal_interest_amount
,npa_charges_amount,
bddr_interest_outstanding,
principal_waived_off,
interest_waived_off,
penal_interest_waived_off,
margin_amount,
subsidy_realised,
subsidy_received,
excess_interest,
margin_realised_amount,
backdated_checker_clear_balance,
backdated_principal_outstanding,
backdated_npa_interest_amount,	
backdated_npa_penal_interest_amount,
backdated_npa_charges_amount,
principal_overdue,
interest_overdue,
principal_overdue_days,
interest_overdue_days,
branch_code
)
SELECT 
ab.loan_account_id
,ab.statement_opening_balance
,ab.day_opening_balance
,ab.checker_unclear_balance
,ab.checker_clear_balance
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
,@p_rundate
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
,ab.backdated_checker_clear_balance
,ab.backdated_principal_outstanding
,ab.backdated_npa_interest_amount
,ab.backdated_npa_penal_interest_amount
,ab.backdated_npa_charges_amount
,ab.principal_overdue
,ab.interest_overdue
,ab.principal_overdue_days
,ab.interest_overdue_days
,ab.branch_code
FROM
    bsgloan..loan_account_master lam
        INNER JOIN
    bsgaccounting..account_balance_loan ab ON lam.loan_account_id = ab.loan_account_id
        INNER JOIN
    (SELECT 
        loan_account_id, MAX(txn_date) txn_date
		FROM
        bsgaccounting..account_balance_loan WHERE    txn_date <= @p_rundate
		GROUP BY loan_account_id) a 
    ON ab.loan_account_id = a.loan_account_id
        AND ab.txn_date = a.txn_date
        LEFT OUTER JOIN
    bsgaccounting..account_balance_loan abcurrent ON ab.loan_account_id = abcurrent.loan_account_id AND abcurrent.txn_date = @p_rundate
WHERE
        abcurrent.loan_account_id IS NULL
		AND lam.loan_account_status != 2
		and lam.is_active=1
		and ab.is_active=1

exec UPDATES_IN_DAY_END @p_rundate



update abl
set abl.npa_marked_date = '1900-01-01 00:00:00.000'
from    
    BSGLOAN..loan_account_master lam with(nolock)
        inner join (
        select loan_account_id , MAX(txn_date) txn_date from BSGACCOUNTING..account_balance_loan with(nolock) group by loan_account_id
        ) a
            on a.loan_account_id = lam.loan_account_id
        inner join BSGACCOUNTING..account_balance_loan abl with(nolock)
            on abl.loan_account_id = lam.loan_account_id
                and a.txn_date = abl.txn_date
where
    lam.is_active = 1
    and lam.loan_account_status <> 2
    and lam.asset_classification = 1
    and cast(abl.npa_marked_date as date) <> '1900-01-01'

END


