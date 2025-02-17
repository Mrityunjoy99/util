
CREATE    PROCEDURE [dbo].[update_loan_repayment_chart_post_interest_application]

@txn_date date,
@modify_by bigint,
@processing_type int = 1 -- Calender

AS

BEGIN


Select 
	lid.interest_amount interest_debit,lid.penal_interest_amount,
	lrc.*
INTO
	#temp_loan_interest_details
from
	BSGACCOUNTING..loan_interest_details lid with(nolock) 
	left join 
	(

		select 
			r.loan_account_id,
			r.due_date due_date,
			MAX(r.id) id
		from
		(

		select 
			loan_account_id,
			MIN(due_date) due_date
			
		from
			BSGACCOUNTING..loan_repayment_chart with(nolock)
		Where
			(
				(@processing_type = 2 and  due_date = @txn_date ) 
				or (@processing_type = 1 and due_date > @txn_date)
			)
			and is_active = 1		
		group by loan_account_id
		)ll 
		 left outer join  BSGACCOUNTING..loan_repayment_chart r  with(nolock)
			on ll.loan_account_id = r.loan_account_id
				and ll.due_date = r.due_date
		group by r.loan_account_id,
			r.due_date
	)lr
		 on lr.loan_account_id = lid.account_id
	left join 
	(
		select 
			r.loan_account_id,
			r.due_date due_date,
			MAX(r.id) id
		from
		(

		select 
			loan_account_id,
			MAX(due_date) due_date
			
		from
			BSGACCOUNTING..loan_repayment_chart with(nolock)
		Where
			is_active = 1
			-- and due_date > '2022-08-31'
		group by loan_account_id
		)ll 
		 left outer join  BSGACCOUNTING..loan_repayment_chart r  with(nolock)
			on ll.loan_account_id = r.loan_account_id
				and ll.due_date = r.due_date
		group by r.loan_account_id,
			r.due_date
		
	)lrLastInstallmentNo
		 on lrLastInstallmentNo.loan_account_id = lid.account_id

	left join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)
		on lrc.loan_account_id = ISNULL(lr.loan_account_id,lrLastInstallmentNo.loan_account_id)
			and lrc.due_date =  ISNULL(lr.due_date,lrLastInstallmentNo.due_date)
				and lrc.id = ISNULL(lr.id,lrLastInstallmentNo.id)
	LEFT OUTER JOIN BSGLOAN..loan_product_master lpm with(nolock)
		on lid.product_id = lpm.loan_product_id
			and lpm.is_active = 1

where	
	lpm.repayment_mode = 1 -- EMI

IF(@processing_type= 1)
BEGIN
/* Identify the moratorium account list */
select 
	lam.loan_account_id,lab.installment_start_date,lab.disbursement_date,
	lab.moratoriun_period,
	lab.moratorium_int_recovery_mode,
	lpm.interest_frequency,
	lpm.regular_interest_quarter_type,
	lpm.interest_calculation_on
INTO
	#temp_moratorium_account_list
from
	BSGLOAN..loan_account_master lam with(nolock)
	 LEFT OUTER JOIN BSGLOAN..loan_account_basic lab with(nolock)
		on lab.loan_account_id = lam.loan_account_id
			and lab.is_active = 1
	LEFT OUTER JOIN BSGLOAN..loan_product_master lpm with(nolock)
		on lam.loan_product_id =  lpm.loan_product_id
			and lpm.is_active =1 
where
	lam.is_active =1
	and lam.loan_account_status <> 2
	and cast( installment_start_date  as date) > @txn_date
	and lab.moratoriun_period > 0
	and lab.moratorium_int_recovery_mode = 2 -- EMI



select 
	*
into
	#temp_moratorium_list_with_moratorium_end_date
from
(
select 
	*,
	case when regular_interest_quarter_type = 1 then cast(EOMONTH(DATEADD(M,-1,installment_start_date)) as date)
	when regular_interest_quarter_type = 2 then cast(DATEADD(M,-1,installment_start_date) as date) 
	else installment_start_date END moratorium_end_date
from
	#temp_moratorium_account_list
)a
	

select 
	loan_account_id
INTO 
	#temp_moratorium_exlude_list
from
	#temp_moratorium_list_with_moratorium_end_date
where
	moratorium_end_date < @txn_date or regular_interest_quarter_type = 1

	

/**/

select 
	*
INTO
	#moratorium_account_list_balance_bucket_updation
from
	#temp_moratorium_list_with_moratorium_end_date
where
	moratorium_end_date = @txn_date

/*Keep Backup of old bucket*/
INSERT INTO [BSGDEEPFREEZE].[dbo].[account_balance_loan_moratorium_updation_bucket]
           ([loan_account_id]
           ,[statement_opening_balance]
           ,[day_opening_balance]
           ,[maker_unclear_balance]
           ,[maker_clear_balance]
           ,[checker_unclear_balance]
           ,[checker_clear_balance]
           ,[day_end_balance]
           ,[interest_accrual]
           ,[interest_applied]
           ,[interest_paid]
           ,[charges_applied]
           ,[charges_paid]
           ,[penal_interest_accrual]
           ,[penal_interest_applied]
           ,[penal_interest_paid]
           ,[principal_outstanding]
           ,[legal_fee]
           ,[lawyer_fee]
           ,[npa_interest]
           ,[overdue_amount]
           ,[debit_summation]
           ,[credit_summation]
           ,[disbursement_count]
           ,[disbursement_amount]
           ,[sanction_limit]
           ,[available_dp]
           ,[available_balance]
           ,[overdue_days_count]
           ,[npa_amount]
           ,[npa_marked_date]
           ,[earmarked_amount]
           ,[created_by]
           ,[created_date]
           ,[last_modified_by]
           ,[last_modified_date]
           ,[txn_date]
           ,[is_active]
           ,[adhoc_amount]
           ,[installment_amount]
           ,[is_final_installment_amount]
           ,[received_amount]
           ,[security_amount_overdue_days]
           ,[npa_interest_amount]
           ,[npa_penal_interest_amount]
           ,[npa_charges_amount]
           ,[bddr_interest_outstanding]
           ,[principal_waived_off]
           ,[interest_waived_off]
           ,[penal_interest_waived_off]
           ,[margin_amount]
           ,[subsidy_received]
           ,[subsidy_realised]
           ,[excess_interest]
           ,[margin_realised_amount]
           ,[interest_provision]
           ,[excess_recovery]
           ,[backdated_checker_clear_balance]
           ,[backdated_principal_outstanding]
           ,[backdated_npa_interest_amount]
           ,[backdated_npa_penal_interest_amount]
           ,[backdated_npa_charges_amount]
           ,[principal_overdue]
           ,[interest_overdue]
           ,[principal_overdue_days]
           ,[interest_overdue_days]
           ,[branch_code]
           ,[product_id]
           ,[fcy_currency]
           ,[lcy_amount])
	select 
			[loan_account_id]
           ,[statement_opening_balance]
           ,[day_opening_balance]
           ,[maker_unclear_balance]
           ,[maker_clear_balance]
           ,[checker_unclear_balance]
           ,[checker_clear_balance]
           ,[day_end_balance]
           ,[interest_accrual]
           ,[interest_applied]
           ,[interest_paid]
           ,[charges_applied]
           ,[charges_paid]
           ,[penal_interest_accrual]
           ,[penal_interest_applied]
           ,[penal_interest_paid]
           ,[principal_outstanding]
           ,[legal_fee]
           ,[lawyer_fee]
           ,[npa_interest]
           ,[overdue_amount]
           ,[debit_summation]
           ,[credit_summation]
           ,[disbursement_count]
           ,[disbursement_amount]
           ,[sanction_limit]
           ,[available_dp]
           ,[available_balance]
           ,[overdue_days_count]
           ,[npa_amount]
           ,[npa_marked_date]
           ,[earmarked_amount]
           ,[created_by]
           ,[created_date]
           ,[last_modified_by]
           ,[last_modified_date]
           ,[txn_date]
           ,[is_active]
           ,[adhoc_amount]
           ,[installment_amount]
           ,[is_final_installment_amount]
           ,[received_amount]
           ,[security_amount_overdue_days]
           ,[npa_interest_amount]
           ,[npa_penal_interest_amount]
           ,[npa_charges_amount]
           ,[bddr_interest_outstanding]
           ,[principal_waived_off]
           ,[interest_waived_off]
           ,[penal_interest_waived_off]
           ,[margin_amount]
           ,[subsidy_received]
           ,[subsidy_realised]
           ,[excess_interest]
           ,[margin_realised_amount]
           ,[interest_provision]
           ,[excess_recovery]
           ,[backdated_checker_clear_balance]
           ,[backdated_principal_outstanding]
           ,[backdated_npa_interest_amount]
           ,[backdated_npa_penal_interest_amount]
           ,[backdated_npa_charges_amount]
           ,[principal_overdue]
           ,[interest_overdue]
           ,[principal_overdue_days]
           ,[interest_overdue_days]
           ,[branch_code]
           ,[product_id]
           ,[fcy_currency]
           ,[lcy_amount]
from
	BSGACCOUNTING..account_balance_loan with(nolock) 
where
	loan_account_id in (select loan_account_id from #moratorium_account_list_balance_bucket_updation)
	and txn_date = @txn_date

/*Update the moratorium account interest capitilization */
update 
	BSGACCOUNTING..account_balance_loan
set principal_outstanding = principal_outstanding - (interest_applied - interest_paid + penal_interest_applied - penal_interest_paid),
	interest_applied = 0,interest_paid= 0,penal_interest_applied = 0,penal_interest_paid = 0,last_modified_by = @modify_by , last_modified_date = CURRENT_TIMESTAMP
where
	loan_account_id in (select loan_account_id from #moratorium_account_list_balance_bucket_updation)
	and txn_date = @txn_date

select 
	[loan_account_id]  
    , case when [principal_outstanding] < 0 then [principal_outstanding] *-1 else 0 end ideal_balance
INTO 
	#temp_ideal_balance
from
	BSGACCOUNTING..account_balance_loan with(nolock) 
where
	loan_account_id in (select loan_account_id from #moratorium_account_list_balance_bucket_updation)
	and txn_date = @txn_date


INSERT INTO BSGACCOUNTING..loan_repayment_chart
(
			[loan_account_id]
           ,[installment_no]
           ,[due_date]
           ,[txn_posting_date]
           ,[txn_value_date]
           ,[installment_amount]
           ,[principal_amount]
           ,[principal_received]
           ,[interest_amount]
           ,[interest_received]
           ,[ideal_balance]
           ,[od_int_rate]
           ,[od_int_accrual]
           ,[od_int_provision]
           ,[od_int_received]
           ,[penal_int_rate]
           ,[penal_int_accrual]
           ,[penal_int_provision]
           ,[penal_int_received]
           ,[penal_int_gst]
           ,[overdue_amount]
           ,[overdue_days_count]
           ,[full_installment_received]
           ,[txn_ref_no]
           ,[txn_amount]
           ,[activity_id]
           ,[is_reversal]
           ,[reversal_ref_no]
           ,[is_active]
           ,[created_by]
           ,[created_date]
           ,[last_modified_by]
           ,[last_modified_date]
           ,[installment_proportion]
           ,[excess_payment_date]
           ,[excess_id]
		   ,grace_days
)
select
			i.[loan_account_id]
           ,[installment_no]
           ,[due_date]
           ,@txn_date [txn_posting_date]
           ,@txn_date [txn_value_date]
           ,[installment_amount]
           ,[principal_amount]
           ,[principal_received]
           ,[interest_amount]
           ,[interest_received]
           ,i.ideal_balance - [principal_amount] [ideal_balance]
           ,[od_int_rate]
           ,[od_int_accrual]
           ,[od_int_provision]
           ,[od_int_received]
           ,[penal_int_rate]
           ,[penal_int_accrual]
           ,[penal_int_provision]
           ,[penal_int_received]
           ,[penal_int_gst]
           ,[overdue_amount]
           ,[overdue_days_count]
           ,[full_installment_received]
           ,[txn_ref_no]
           ,[txn_amount]
           ,3099 [activity_id]
           ,[is_reversal]
           ,[reversal_ref_no]
           ,[is_active]
           , @modify_by [created_by]
           , CURRENT_TIMESTAMP [created_date]
           , @modify_by [last_modified_by]
           ,CURRENT_TIMESTAMP [last_modified_date]
           ,[installment_proportion]
           ,[excess_payment_date]
           ,-8[excess_id]
		   ,ISNULL(grace_days,0) grace_days
from
	#temp_loan_interest_details t
		inner join #temp_ideal_balance i
			on t.loan_account_id = i.loan_account_id




INSERT INTO loan_actual_interest_ideal_interest_diff
(
	loan_account_id ,
	installment_no ,
	due_date ,
	actual_interest_amount ,
	ideal_interest_amount ,
	diff_amount,
	txn_date,
	is_active 
)
select 
	loan_account_id,
	-8,
	'1900-01-01',
	0,
	0,
	0,
	@txn_date,
	1
from
	#temp_ideal_balance
	
/*Remove account from list */
delete from #temp_loan_interest_details
where loan_account_id in (
select 
	loan_account_id
from
	#temp_moratorium_exlude_list
)


END


INSERT INTO loan_actual_interest_ideal_interest_diff
(
	loan_account_id ,
	installment_no ,
	due_date ,
	actual_interest_amount ,
	ideal_interest_amount ,
	diff_amount,
	txn_date,
	is_active 
)
select 
	loan_account_id,
	installment_no,
	due_date,
	interest_debit actual_interest_amount,
	interest_amount ideal_interest_amount,
	(interest_amount - interest_debit ) ,
	@txn_date,1
from
	#temp_loan_interest_details
where
	(interest_amount - interest_debit ) > 0 
	and		(
				(@processing_type = 2 and  due_date = @txn_date ) 
				or (@processing_type = 1 and due_date > @txn_date)
			) -- To Check that it is not last installment or after limit expire date

INSERT INTO BSGACCOUNTING..loan_repayment_chart
(
			[loan_account_id]
           ,[installment_no]
           ,[due_date]
           ,[txn_posting_date]
           ,[txn_value_date]
           ,[installment_amount]
           ,[principal_amount]
           ,[principal_received]
           ,[interest_amount]
           ,[interest_received]
           ,[ideal_balance]
           ,[od_int_rate]
           ,[od_int_accrual]
           ,[od_int_provision]
           ,[od_int_received]
           ,[penal_int_rate]
           ,[penal_int_accrual]
           ,[penal_int_provision]
           ,[penal_int_received]
           ,[penal_int_gst]
           ,[overdue_amount]
           ,[overdue_days_count]
           ,[full_installment_received]
           ,[txn_ref_no]
           ,[txn_amount]
           ,[activity_id]
           ,[is_reversal]
           ,[reversal_ref_no]
           ,[is_active]
           ,[created_by]
           ,[created_date]
           ,[last_modified_by]
           ,[last_modified_date]
           ,[installment_proportion]
           ,[excess_payment_date]
           ,[excess_id]
		   ,grace_days
)
select
			[loan_account_id]
           ,[installment_no]
           ,[due_date]
           ,@txn_date [txn_posting_date]
           ,@txn_date [txn_value_date]
           ,[installment_amount]
           ,[principal_amount]
           ,[principal_received]
           ,case when interest_amount > interest_debit
		   and 			
					(
						(@processing_type = 2 and  due_date = @txn_date ) 
						or (@processing_type = 1 and due_date > @txn_date)
					) 
		   then interest_debit 
		   else interest_amount 
		   end [interest_amount]
           ,[interest_received]
           ,[ideal_balance]
           ,[od_int_rate]
           ,od_int_accrual + ISNULL(
				case 
					when interest_debit -  interest_amount > 0 and 			
					(
						(@processing_type = 2 and  due_date = @txn_date ) 
						or (@processing_type = 1 and due_date > @txn_date)
					) 
					then interest_debit -  interest_amount -- actual od interest
					when (
						(@processing_type = 2 and  due_date < @txn_date ) 
						or (@processing_type = 1 and due_date <= @txn_date)
					)  then interest_debit -- od_interest + actual interest  after limit expire
					-- when interest_amount -  interest_debit <= 0 then 0
					else 0 end
				,0)	
				[od_int_accrual]
           ,[od_int_provision]
           ,[od_int_received]
           ,[penal_int_rate]
           ,penal_int_accrual + ISNULL(penal_interest_amount,0) [penal_int_accrual]
           ,[penal_int_provision]
           ,[penal_int_received]
           ,[penal_int_gst]
           ,[overdue_amount]
           ,[overdue_days_count]
           ,[full_installment_received]
           ,[txn_ref_no]
           ,[txn_amount]
           ,3004 [activity_id]
           ,[is_reversal]
           ,[reversal_ref_no]
           ,[is_active]
           , @modify_by [created_by]
           , CURRENT_TIMESTAMP [created_date]
           , @modify_by [last_modified_by]
           ,CURRENT_TIMESTAMP [last_modified_date]
           ,[installment_proportion]
           ,[excess_payment_date]
           ,-1444[excess_id]
		   ,ISNULL(grace_days,0) grace_days
from
	#temp_loan_interest_details

update  l
set l.is_active = 0,last_modified_date = CURRENT_TIMESTAMP,last_modified_by = @modify_by,excess_id = -141
from
BSGACCOUNTING..loan_repayment_chart l
inner join #temp_loan_interest_details ll
	on l.loan_account_id = ll.loan_account_id
     	and l.id = ll.id

if(@processing_type = 2)
BEGIN

update 	
	lrc

	set lrc.principal_amount += l.diff_amount , lrc.ideal_balance -= l.diff_amount ,last_modified_by =@modify_by,excess_id = -1411
	
	from
	BSGACCOUNTING..loan_repayment_chart lrc
		inner join BSGACCOUNTING..loan_actual_interest_ideal_interest_diff l
			on lrc.loan_account_id =l.loan_account_id
				and lrc.installment_no = l.installment_no
				and lrc.interest_amount = l.actual_interest_amount
					and l.txn_date = @txn_date
where
	lrc.ideal_balance > 0

END

END
