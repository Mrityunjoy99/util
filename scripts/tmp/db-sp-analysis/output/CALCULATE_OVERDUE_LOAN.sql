
-- =============================================

-- Author: <Abhishek,>

-- Create date: <2023-04-29, 2023-04-29>

-- Description: <Calculate Overdue, Calculate the overdue and update in balance table>

-- =============================================



CREATE PROCEDURE [dbo].[CALCULATE_OVERDUE_LOAN]

(

    @taskDate date,

    @modifyBy int

)

AS

BEGIN



-- Collect Important Parameter for Overdue Calculation

select

    lam.loan_account_id,

    lam.last_interest_applied_date,

    lab.installment_start_date,

    lab.limit_expiry_date,

    lab.no_of_installment,

    lab.installment_amount,

    lpm.repayment_mode,

    lpm.interest_frequency,

    lpm.regular_interest_quarter_type,

    lab.installment_frequency,

    lab.moratorium_based_emi,

    lab.moratorium_int_recovery_mode,

    lab.moratoriun_period,

    lab.disbursement_date,

    ISNULL(abl.checker_clear_balance,0) checker_clear_balance,

    ISNULL(abl.principal_outstanding,0) principal_outstanding,

    ISNULL(abl.npa_interest_amount,0) npa_interest_amount,

    ISNULL(abl.npa_penal_interest_amount,0) npa_penal_interest_amount,

    ISNULL(abl.npa_charges_amount,0) npa_charges_amount,

    ISNULL(abl.charges_applied,0) - ISNULL(abl.charges_paid,0) charges_oustanding,

    ISNULL(abl.interest_applied,0) - ISNULL(abl.interest_paid,0) interest_oustanding,

    ISNULL(abl.penal_interest_applied,0) - ISNULL(abl.penal_interest_paid,0) penal_oustanding,

    abl.txn_date,

    abl.principal_overdue_days,

    abl.interest_overdue_days,

    abl.overdue_days_count,

    abl.sanction_limit

INTO

    #temp_details

from

    BSGLOAN..loan_account_master lam with(nolock)

    inner join BSGLOAN..loan_account_basic lab with(nolock)

        on lam.loan_account_id = lab.loan_account_id

            and lab.is_active= 1

    LEFT JOIN (

                    select

                        loan_account_id,

                        MAX(txn_date) txn_date

                    from

                        BSGACCOUNTING..account_balance_loan with(nolock)

                    where

                        txn_date <= @taskDate

                    group by loan_account_id

                ) ab

        on ab.loan_account_id = lam.loan_account_id

    LEFT JOIN BSGACCOUNTING..account_balance_loan abl with(nolock)

        on abl.loan_account_id = ab.loan_account_id

            and abl.txn_date = ab.txn_date

    LEFT OUTER JOIN BSGLOAN..loan_product_master lpm with(nolock)

        on lpm.loan_product_id = lam.loan_product_id

            and lpm.is_active = 1

where

    lam.is_active= 1

    and lam.loan_account_status <> 2

    and lam.loan_type = 1



select

    *,

    case when interest_overdue_days > principal_overdue_days then interest_overdue_days else principal_overdue_days end overdue_days,

    ISNULL(principal_overdue,0) + ISNULL(interest_overdue,0) overdue_amount

INTO

    #temp_overdue_details

from

(

select

    id,

    loan_account_id,

    installment_no,

    due_date,

    case when

        due_date < @taskDate

        and

        (loanRepaymentChart.interest_amount-loanRepaymentChart.interest_received

            + loanRepaymentChart.od_int_accrual - loanRepaymentChart.od_int_received

            + loanRepaymentChart.penal_int_accrual - loanRepaymentChart.penal_int_received

        )

         > 0

        then DATEDIFF(D,due_date,@taskDate) else 0 end interest_overdue_days,

    case when

        due_date < @taskDate

        and (loanRepaymentChart.principal_amount-loanRepaymentChart.principal_received) > 0

        then DATEDIFF(D,due_date,@taskDate) else 0 end principal_overdue_days,

    case when

        due_date < @taskDate

        and

        (loanRepaymentChart.interest_amount-loanRepaymentChart.interest_received

            + loanRepaymentChart.od_int_accrual - loanRepaymentChart.od_int_received

            + loanRepaymentChart.penal_int_accrual - loanRepaymentChart.penal_int_received

        )

         > 0

        then (loanRepaymentChart.interest_amount-loanRepaymentChart.interest_received

            + loanRepaymentChart.od_int_accrual - loanRepaymentChart.od_int_received

            + loanRepaymentChart.penal_int_accrual - loanRepaymentChart.penal_int_received

            )

        else 0 end interest_overdue,

    case when

        due_date < @taskDate

        and (loanRepaymentChart.principal_amount-loanRepaymentChart.principal_received) > 0

        then (loanRepaymentChart.principal_amount-loanRepaymentChart.principal_received)

        else 0 end principal_overdue



from

     (

        select

            lrc.*

        from

        (



            select

                id, loan_account_id,due_date

            from

                BSGACCOUNTING..loan_repayment_chart with(nolock)

            where id in (

                select

                    MAX(id)

                from

                    BSGACCOUNTING..loan_repayment_chart with(nolock)

                where txn_posting_date <= @taskDate

                group by

                    loan_account_id,

                    installment_no

            )

        )lr

        inner join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)

            on lrc.loan_account_id = lr.loan_account_id

                and lrc.due_date = lr.due_date

                    and lrc.id = lr.id



    ) loanRepaymentChart



)a



update #temp_overdue_details

set

interest_overdue_days = case when interest_overdue_days < 0 then 0 else interest_overdue_days end,

interest_overdue = case when interest_overdue < 0 then 0 else interest_overdue end,

principal_overdue_days = case when principal_overdue_days < 0 then 0 else principal_overdue_days end,

principal_overdue = case when principal_overdue < 0 then 0 else principal_overdue end,

overdue_amount = case when overdue_amount < 0 then 0 else overdue_amount end,

overdue_days = case when overdue_days < 0 then 0 else overdue_days end







update lr

set lr.overdue_days_count = t.overdue_days,

lr.overdue_amount = t.overdue_amount

from

    #temp_overdue_details t

    inner join #temp_details tt

        on t.loan_account_id = tt.loan_account_id

    inner join BSGACCOUNTING..loan_repayment_chart lr

        on lr.loan_account_id = t.loan_account_id

        and lr.installment_no = t.installment_no

            and lr.id=t.id

where

    tt.repayment_mode = 1





select

    loan_account_id,

    total_overdue,

    overdue_days,

    case when principal_overdue < 0 then 0 else principal_overdue end principal_overdue,

    case when principal_overdue = 0 then 0

    when principal_overdue_days = 0 and principal_overdue > 0 then bal_principal_overdue_days + 1

    else principal_overdue_days end

    principal_overdue_days,

    case when principal_overdue < 0 then principal_overdue+interest_overdue else interest_overdue end interest_overdue,

    interest_overdue_days,

    txn_date

INTO

    #temp_actual_overdue

from

(

select

    loan_account_id,

    total_overdue,

    case when total_overdue = 0 then 0 else

        case when overdue_days = 0 and total_overdue > 0 then overdue_days_count + 1

        else overdue_days end

    end overdue_days,

    case when principal_overdue > 0

        then total_overdue - interest_overdue

        when total_overdue > 0 and interest_overdue = 0

        then total_overdue

        when total_overdue > 0 and interest_overdue > 0

        then total_overdue - interest_overdue

    else 0 end principal_overdue,

    principal_overdue_days,

    interest_overdue,

    interest_overdue_days,

    txn_date,

    bal_principal_overdue_days

from

(

select

    loan_account_id,

    bal_interest_overdue_days,

    bal_principal_overdue_days,

    overdue_days_count,

    interest_overdue,

    principal_overdue,

    principal_overdue_days,

    interest_overdue_days,

    case when limit_expiry_date <= @taskDate then total_oustanding

    else

        case when overdue_amount + charges_oustanding > total_oustanding

        then total_oustanding

        else overdue_amount + charges_oustanding

        end

    end total_overdue,

    charges_oustanding,

    overdue_amount,

    overdue_days,

    txn_date

from

(



select

    tt.loan_account_id,

    tt.interest_overdue_days bal_interest_overdue_days,

    tt.principal_overdue_days bal_principal_overdue_days,

    tt.overdue_days_count,

    ((case when tt.checker_clear_balance < 0 then tt.checker_clear_balance else 0 end) *-1) + tt.npa_interest_amount + tt.npa_penal_interest_amount+ tt.npa_charges_amount total_oustanding,

    charges_oustanding,

    limit_expiry_date,

    ISNULL(a.interest_overdue_days,0) interest_overdue_days,

    ISNULL(a.principal_overdue_days,0) principal_overdue_days,

    ISNULL(a.overdue_days,0) overdue_days,

    ISNULL(a.interest_overdue,0) interest_overdue,

    ISNULL(a.principal_overdue,0) principal_overdue,

    ISNULL(a.overdue_amount,0) overdue_amount,

    tt.txn_date

from

    #temp_details tt

LEFT join

(

select

    loan_account_id,

    MAX(interest_overdue_days) interest_overdue_days,

    MAX(principal_overdue_days) principal_overdue_days,

    MAX(overdue_days) overdue_days,

    SUM(interest_overdue) interest_overdue,

    SUM(principal_overdue) principal_overdue,

    SUM(overdue_amount) overdue_amount

from

    #temp_overdue_details

group by loan_account_id

) a on a.loan_account_id = tt.loan_account_id

where

    tt.repayment_mode = 1

)b

)c

)d





-- For repayment 2 and 3 (Lumpsum and Bullet Payment)



INSERT INTO #temp_actual_overdue

select

    loan_account_id,

    total_overdue,

    overdue_days,

    principal_overdue,

    case when principal_overdue > 0 then overdue_days else 0 end principal_overdue_days,

    interest_overdue,

    case when interest_overdue > 0 then overdue_days else 0 end interest_overdue_days,

    txn_date

from

(

select

    a.loan_account_id,

    a.total_overdue,

    case when total_overdue = 0 then 0 else

        case when overdue_days_count = 0 and total_overdue > 0 then overdue_days_count + 1

        else overdue_days_count + 1 end

    end overdue_days,

    case when principal_overdue > 0

        then total_overdue - interest_overdue

        when total_overdue > 0 and interest_overdue = 0

        then total_overdue

        when total_overdue > 0 and interest_overdue > 0

        then total_overdue - interest_overdue

    else 0 end principal_overdue,

    0 principal_overdue_days,

    interest_overdue,

    0 interest_overdue_days,

    txn_date

from

(

select

    tt.loan_account_id,

    case when tt.limit_expiry_date <= @taskDate

    then ((case when tt.checker_clear_balance < 0 then tt.checker_clear_balance else 0 end) *-1)

        + tt.npa_interest_amount

        + tt.npa_penal_interest_amount

        + tt.npa_charges_amount

    when repayment_mode = 2 then

                case

                    when

                    sanction_limit - ((case when tt.checker_clear_balance < 0 then tt.checker_clear_balance else 0 end) *-1)

        + tt.npa_interest_amount

        + tt.npa_penal_interest_amount

        + tt.npa_charges_amount < 0

        then (sanction_limit - ((case when tt.checker_clear_balance < 0 then tt.checker_clear_balance else 0 end) *-1)

        + tt.npa_interest_amount

        + tt.npa_penal_interest_amount

        + tt.npa_charges_amount ) *-1 else 0 end

    else 0

    end total_overdue,

    overdue_days_count,

    principal_overdue_days bal_principal_overdue_days,

    interest_overdue_days bal_interest_overdue_days,

    interest_oustanding+penal_oustanding interest_overdue,

    0 principal_overdue,

    txn_date

from

    #temp_details tt

where

    repayment_mode in (2,3)

)a

)b

-- Check total overdue is less than zero set all overdue parameter to zero

update #temp_actual_overdue set principal_overdue = 0,

principal_overdue_days =0,

interest_overdue_days = 0,

interest_overdue = 0,

overdue_days = 0,

total_overdue = 0

where total_overdue < 0





-- Check total overdue is zero the interest should be zero

update #temp_actual_overdue set principal_overdue = 0,

principal_overdue_days =0,

interest_overdue_days = 0,

interest_overdue = 0

where total_overdue = 0

and (principal_overdue > 0 or interest_overdue > 0)



-- freeze the overdue in balance table

update

abl

set

    abl.overdue_amount = t.total_overdue,

    abl.overdue_days_count = t.overdue_days,

    abl.principal_overdue = t.principal_overdue,

    abl.principal_overdue_days = t.principal_overdue_days,

    abl.interest_overdue = t.interest_overdue,

    abl.interest_overdue_days = t.interest_overdue_days,

    abl.last_modified_by = @modifyBy,

    abl.last_modified_date = CURRENT_TIMESTAMP

from

    #temp_actual_overdue t

        inner join BSGACCOUNTING..account_balance_loan abl with(nolock)

            on t.loan_account_id = abl.loan_account_id

                and t.txn_date = abl.txn_date



select

    lam.loan_account_id,

    lam.last_interest_applied_date,

    lab.installment_start_date,

    lab.limit_expiry_date,

    lab.no_of_installment,

    lab.installment_amount,

    lpm.repayment_mode,

    lpm.interest_frequency,

    lpm.regular_interest_quarter_type,

    lab.installment_frequency,

    lab.moratorium_based_emi,

    lab.moratorium_int_recovery_mode,

    lab.moratoriun_period,

    lab.disbursement_date,

    ISNULL(abl.checker_clear_balance,0) checker_clear_balance,

    ISNULL(abl.principal_outstanding,0) principal_outstanding,

    ISNULL(abl.npa_interest_amount,0) npa_interest_amount,

    ISNULL(abl.npa_penal_interest_amount,0) npa_penal_interest_amount,

    ISNULL(abl.npa_charges_amount,0) npa_charges_amount,

    ISNULL(abl.charges_applied,0) - ISNULL(abl.charges_paid,0) charges_oustanding,

    ISNULL(abl.interest_applied,0) - ISNULL(abl.interest_paid,0) interest_oustanding,

    ISNULL(abl.penal_interest_applied,0) - ISNULL(abl.penal_interest_paid,0) penal_oustanding,

    abl.txn_date,

    abl.principal_overdue_days,

    abl.interest_overdue_days,

    abl.overdue_days_count,

    abl.sanction_limit

INTO

    #temp_details_closure

from

    BSGLOAN..loan_account_master lam with(nolock)

    inner join BSGLOAN..loan_account_basic lab with(nolock)

        on lam.loan_account_id = lab.loan_account_id

            and lab.is_active= 1

    LEFT JOIN (

                    select

                        loan_account_id,

                        MAX(txn_date) txn_date

                    from

                        BSGACCOUNTING..account_balance_loan with(nolock)

                    where

                        txn_date <= @taskDate

                    group by loan_account_id

                ) ab

        on ab.loan_account_id = lam.loan_account_id

    LEFT JOIN BSGACCOUNTING..account_balance_loan abl with(nolock)

        on abl.loan_account_id = ab.loan_account_id

            and abl.txn_date = ab.txn_date

    LEFT OUTER JOIN BSGLOAN..loan_product_master lpm with(nolock)

        on lpm.loan_product_id = lam.loan_product_id

            and lpm.is_active = 1

where

    lam.is_active= 1

    and cast(lam.loan_account_closure_date as date) = @taskDate

    and lam.loan_account_status = 2

    and lam.loan_type = 1



-- for close account overdue and overdue_days count should be zero

update

abl

set

    abl.overdue_amount = 0,

    abl.overdue_days_count = 0,

    abl.principal_overdue = 0,

    abl.principal_overdue_days = 0,

    abl.interest_overdue = 0,

    abl.interest_overdue_days = 0,

    abl.last_modified_by = @modifyBy,

    abl.last_modified_date = CURRENT_TIMESTAMP

from

    #temp_details_closure t

        inner join BSGACCOUNTING..account_balance_loan abl with(nolock)

            on t.loan_account_id = abl.loan_account_id

                and t.txn_date = abl.txn_date





select count(1) successCount ,0 failureCount

from #temp_actual_overdue t

        inner join BSGACCOUNTING..account_balance_loan abl with(nolock)

            on t.loan_account_id = abl.loan_account_id

                and t.txn_date = abl.txn_date



END


