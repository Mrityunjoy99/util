
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
create   PROCEDURE [dbo].[sp_td_interest_application_2022_04_05]  -- exec sp_td_interest_application '2019-09-27','2019-04-01','2020-03-31'
@cbs_app_date date,
@fin_year_start_date date,
@fin_year_end_date date
AS
BEGIN


--  lastInterestDate, interestStartDate,maturityDate,rate

DECLARE @no_pan_rate decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_NO_PAN_RATE' AND is_active = 1)
DECLARE @ind_customer_rate decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_INDIVIDUAL_CUSTOMER' AND is_active = 1)
DECLARE @corp_customer_rate decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_CORPORATE_CUSTOMER' AND is_active = 1)
DECLARE @regular_tds_threshold decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_THRESHOLD' AND is_active = 1)
DECLARE @senior_tds_threshold decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_SENIOR_CITIZEN_THRESHOLD' AND is_active = 1)

INSERT INTO BSGACCOUNTING..td_interest_application 
select 
	master_data.customer_group_id ,
	master_data.customer_id ,
	master_data.td_account_id ,
	(SELECT account_no FROM bsgcore..customer_accounts WHERE account_id=master_data.td_account_id) as td_account_no ,
	master_data.branch_code ,
	case when (master_data.account_status=1 and master_data.next_interest_date = @cbs_app_date 
				AND (CASE WHEN master_data.accrual_date IS NULL 
								THEN master_data.interest_start_date 
						  ELSE master_data.accrual_date END) 
				<master_data.next_interest_date AND master_data.deposite_type IN (1,2)) 
					then (SELECT interest FROM BSGACCOUNTING..td_datewise_interest WHERE td_account_id=master_data.td_account_id AND interest_date=master_data.next_interest_date AND is_active=1)
		WHEN (master_data.account_status=1 and master_data.next_interest_date = @cbs_app_date AND master_data.deposite_type=3) 
					THEN (CASE WHEN master_data.maturity_date<=@cbs_app_date
								THEN (CASE WHEN (SELECT count(td_account_id) FROM bsgtd..rd_installment_master WHERE td_account_id = master_data.td_account_id AND received_date IS NULL)>0
												THEN (CASE WHEN ROUND(master_data.interest_accrual, 0)> (master_data.maturity_amount-(master_data.checker_clear_balance+master_data.interest_payable+master_data.interest_paid))
																THEN (master_data.maturity_amount-(master_data.checker_clear_balance+master_data.interest_payable+master_data.interest_paid))
															ELSE ROUND(master_data.interest_accrual, 0) end)
											ELSE (CASE WHEN (master_data.maturity_amount-(master_data.checker_clear_balance+master_data.interest_payable+master_data.interest_paid))>0
															THEN (master_data.maturity_amount-(master_data.checker_clear_balance+master_data.interest_payable+master_data.interest_paid))
														ELSE 0 END) END)
								ELSE ROUND(master_data.interest_accrual, 0) END )
		ELSE 0 end current_interest,
	(CASE WHEN master_data.projected_interest IS NULL THEN 0 ELSE master_data.projected_interest END) AS projected_interest,
	(CASE WHEN master_data.custome_type_code=1 THEN master_data.age_group ELSE -1 END) as age_group,
	(CASE WHEN master_data.previous_interest IS NULL THEN 0 ELSE master_data.previous_interest END) AS previous_interest,
	(CASE WHEN master_data.previous_tds IS NULL THEN 0 ELSE master_data.previous_tds END) AS previous_tds,
	(case WHEN (SELECT is_applicable FROM BSGCRM..customer_tds 
				WHERE customer_id=master_data.customer_group_id 
					AND is_active=1 and master_data.next_interest_date>=applicable_date
				AND master_data.next_interest_date<=expiry_date 
					AND master_data.projected_interest<( CASE WHEN form15h=1
																THEN (SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TD_15H_UPPER_LIMIT' AND is_active = 1) 
															  ELSE (SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TD_15G_UPPER_LIMIT' AND is_active = 1) END) )=0
					THEN 0
		  WHEN tds_eligible=0
					THEN 0
		  when (select percentage from bsgcrm..customer_tds ct where ct.customer_id= master_data.customer_group_id and master_data.next_interest_date>=applicable_date
				AND master_data.next_interest_date<=expiry_date AND ct.form15g=0 AND ct.form15h=0 AND ct.is_active=1 ) is not null
				then (select percentage from bsgcrm..customer_tds ct where ct.customer_id=master_data.customer_group_id and master_data.next_interest_date>=applicable_date
						AND master_data.next_interest_date<=expiry_date AND ct.form15g=0 AND ct.form15h=0 AND ct.is_active=1)       
		  WHEN master_data.custome_type_code=1  
				then isnull((select @ind_customer_rate from BSGCRM..customer_ind_info cii  
								where is_active=1 and  cii.pan_no like '[A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z]' AND cii.customer_id=master_data.customer_group_id),@no_pan_rate)
		  else isnull((select @corp_customer_rate from BSGCRM..customer_corp_info cci 
						where is_active=1 and cci.pan_no like '[A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z]' AND cci.customer_id=master_data.customer_group_id),@no_pan_rate)
		end ) as tds_rate,tds_eligible,
	master_data.tds_receivable,
	(ROUND(((master_data.tds_receivable*master_data.base_rate*DATEDIFF(D,master_data.tds_receivable_date,master_data.next_interest_date))/36500),0)) as interest_on_tds_receivable ,
	master_data.tds_receivable_date,
	master_data.interest_payable,
	master_data.next_interest_date,
	master_data.interest_start_date,
	master_data.maturity_date,
	master_data.accrual_date,
	master_data.base_rate,
	master_data.account_status,
	0 as current_tds,
	master_data.deposite_type,
	tpm.interest_frequency,
	tpm.is_open_deposit,
	tpm.quarter_calculation,
	master_data.payment_mode,
	master_data.transfer_branch,
	(CASE WHEN master_data.transfer_activity_type=1002
		THEN ISNULL((SELECT account_id FROM bsgcore..account_master WHERE account_id=master_data.transfer_account_id AND is_active=1 AND account_status_id NOT IN (4,5,2)),-1)
	 ELSE master_data.transfer_account_id END) as transfer_account_id,
	(SELECT account_no FROM bsgcore..customer_accounts WHERE account_id=master_data.transfer_account_id) as transfer_account_no,
	(CASE WHEN master_data.transfer_activity_type=1002 
		THEN ISNULL((SELECT product_id FROM bsgcore..account_master WHERE account_id=master_data.transfer_account_id AND is_active=1 AND account_status_id NOT IN (4,5,2)),-1)
	 ELSE -1 END) as transfer_product_id,
	master_data.transfer_activity_type,
	master_data.beneficiary_bank_code,
	master_data.beneficiary_branch_code,
	master_data.beneficiary_ifsc,
	master_data.beneficiary_account_name,
	master_data.beneficiary_account_no,
	master_data.beneficiary_address,
	master_data.beneficiary_bank,
	master_data.beneficiary_branch,
	master_data.beneficiary_remarks,
	master_data.dd_po_payee_name,
	tpm.pl_account_id,
	(SELECT internal_product_id FROM bsgcore..account_master_internal WHERE internal_account_id=tpm.pl_account_id AND is_active=1) as pl_product_id,
	master_data.product_id,
	(SELECT internal_product_id FROM BSGCORE..product_master_internal WHERE product_code=( SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='INTEREST_PAYABLE' AND is_active = 1) AND branch_code=master_data.branch_code AND is_active=1) as interest_payable_product_id,
	(SELECT internal_product_id FROM BSGCORE..product_master_internal WHERE product_code=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_PRODUCT' AND is_active = 1) AND branch_code=master_data.branch_code AND is_active=1) as tds_product_id,
	(SELECT internal_product_id FROM BSGCORE..product_master_internal WHERE product_code=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_RECEIVABLE_PRODUCT' AND is_active = 1) AND branch_code=master_data.branch_code AND is_active=1) as tds_receivable_product_id,
	@cbs_app_date as txn_date,
	getdate() as created_date,
	-1 as created_by,
	0 as is_applied,
	master_data.next_paid_date
FROM
	(select inner_atla_data.accrual_date,int_data.*,customer_int_tds.previous_interest,customer_int_tds.previous_tds
	from 
		(SELECT tpi.*,bal_data.* 
		FROM
			(select cm.*,projected_data.projected_interest, (CASE WHEN cm.age_group IN (2,3) AND projected_data.projected_interest>@senior_tds_threshold 
																	THEN 1
																  WHEN cm.age_group IN (1,4,-1) AND projected_data.projected_interest>@regular_tds_threshold 
																	THEN 1
															 ELSE 0 END) as tds_eligible 
			from
				(select account_details.*,
					inner_group_cm.customer_group_id,
					(SELECT custome_type_code FROM BSGCRM..customer_master WHERE is_active=1 AND customer_id=inner_group_cm.customer_group_id) AS custome_type_code,
					(SELECT age_group FROM BSGCRM..customer_master WHERE is_active=1 AND customer_id=inner_group_cm.customer_group_id)AS age_group 
				from 
					(select inner_tam.*,
						inner_tdd.base_rate,
						inner_tdd.next_interest_date,
						inner_tdd.deposite_type,
						inner_tdd.interest_start_date,
						inner_tdd.maturity_date,
						inner_tdd.next_paid_date,
						inner_tip.* 
					from
						(select td_account_id,
							customer_id,
							account_status_id account_status,
							branch_code,
							product_id,
							maturity_amount
						from bsgtd..td_account_master 
						where is_active=1 and
							(account_closure_date is null or account_closure_date>=@fin_year_start_date)
						)inner_tam
					inner join
						(select td_account_id,base_rate,next_interest_date,deposite_type,interest_start_date,maturity_date,next_paid_date
						 FROM bsgtd..td_account_deposit_details where is_active=1
						 )inner_tdd
						on inner_tam.td_account_id=inner_tdd.td_account_id
					left outer join
						(select td_account_id as tip_td_account_id,
							payment_mode,
							transfer_branch,
							transfer_account_id,
							transfer_activity_type,
							beneficiary_bank_code,
							beneficiary_branch_code,beneficiary_ifsc,beneficiary_account_name,beneficiary_account_no,beneficiary_address,
							beneficiary_bank,beneficiary_branch,beneficiary_remarks,dd_po_payee_name 
						from bsgtd..td_interest_payment 
						where is_active=1
						)inner_tip
						on inner_tam.td_account_id=inner_tip.tip_td_account_id)account_details
					LEFT OUTER JOIN 
						(SELECT customer_id,customer_group_id
						 FROM BSGCRM..customer_master 
						 WHERE is_active=1
						) inner_group_cm
						ON inner_group_cm.customer_id=account_details.customer_id)cm
					LEFT OUTER JOIN
						( SELECT inner_projection.customer_group_id,
							SUM(inner_projection.projected_interest) as projected_interest 
						FROM ( select cm.customer_group_id,
									ROUND(sum(projected_interest),0)projected_interest 
								from bsgtd..td_projected_interest tip,bsgtd..td_account_master tam,bsgcrm..customer_master cm
								where to_date>=@fin_year_start_date and to_date<=@fin_year_end_date
										AND tip.td_account_id=tam.td_account_id AND tam.is_active=1 AND tam.account_status_id IN (1,2)
								AND tam.customer_id=cm.customer_id AND cm.is_active=1 GROUP BY cm.customer_group_id

UNION ALL

select cm.customer_group_id,ROUND(sum(interest)-sum(interest_reversal),0)projected_interest 
from bsgtd..td_customer_interest_tds tcit,bsgtd..td_account_master tam,bsgcrm..customer_master cm
where tcit.txn_date>=@fin_year_start_date and tcit.txn_date<=@fin_year_end_date
AND tcit.td_account_id=tam.td_account_id AND tam.is_active=1 AND tam.account_status_id=5
AND tam.account_closure_date>=@fin_year_start_date
AND tam.customer_id=cm.customer_id AND cm.is_active=1 AND tcit.is_active=1 GROUP BY cm.customer_group_id
)inner_projection GROUP BY inner_projection.customer_group_id )projected_data
on cm.customer_group_id=projected_data.customer_group_id
)tpi
left outer join
(SELECT td_account_id as bal_account_id,tds_receivable,tds_receivable_date,interest_payable,interest_paid,interest_accrual ,checker_clear_balance
FROM BSGACCOUNTING..account_balance_td abt WHERE id=(
SELECT MAX(id) FROM BSGACCOUNTING..account_balance_td WHERE td_account_id=abt.td_account_id))bal_data
ON bal_data.bal_account_id=tpi.td_account_id
) int_data
left outer join
(SELECT td_account_id as atla_td_account_id,accrual_date 
FROM BSGACCOUNTING..account_td_last_accrual)inner_atla_data
ON inner_atla_data.atla_td_account_id=int_data.td_account_id
left outer join
(select tcit.td_account_id,tcit.customer_id,(SUM(interest)-SUM(interest_reversal)) as previous_interest,
					 (SUM(tds)-SUM(tds_reversal)) as previous_tds from bsgtd..td_customer_interest_tds tcit 
					 INNER JOIN bsgtd..td_account_master tm
					 on
					 tm.td_account_id=tcit.td_account_id and tm.customer_id=tcit.customer_id and tm.is_active=1 
					 LEFT OUTER JOIN bsgcrm..customer_tds ct ON					
					  tcit.customer_id=ct.customer_id AND ct.is_active=1 
					  WHERE tcit.txn_date>=(CASE WHEN ct.applicable_date IS NULL OR (form15g=1 OR form15h=1) THEN @fin_year_start_date ELSE 
					  (CASE WHEN @cbs_app_date>=ct.applicable_date AND @cbs_app_date<=ct.expiry_date THEN ct.applicable_date 
					  WHEN @cbs_app_date>ct.expiry_date THEN DATEADD(D,1,ct.expiry_date) ELSE @fin_year_start_date END)END)  
					  AND tcit.txn_date<=(CASE WHEN ct.expiry_date IS NULL OR (form15g=1 OR form15h=1) THEN @fin_year_end_date ELSE 
					  (CASE WHEN @cbs_app_date>=ct.applicable_date AND @cbs_app_date<=ct.expiry_date THEN ct.expiry_date
					  ELSE @fin_year_end_date END)END) AND  tcit.is_active=1  					  
					  group by tcit.td_account_id,tcit.customer_id) customer_int_tds
on
inner_atla_data.atla_td_account_id=customer_int_tds.td_account_id
--LEFT OUTER JOIN
--(SELECT 0 AS previous_interest,0 AS previous_tds) customer_int_tds ON 1=1 
)master_data
inner join
(select product_id,pl_account_id,interest_frequency,quarter_calculation,is_open_deposit from bsgtd..td_product_master where is_active=1) tpm
on
master_data.product_id=tpm.product_id;

UPDATE BSGACCOUNTING..td_interest_application SET is_applied = 1 WHERE interest_date = @cbs_app_date AND current_interest = 0;

UPDATE tia SET tia.current_interest = -1, is_applied = 1 
FROM BSGACCOUNTING..td_interest_application tia 
INNER JOIN 
(SELECT tia.td_account_id, tia.current_interest, tadd.td_amount, tadd.computed_amount, abt.interest_provided 
FROM BSGACCOUNTING..td_interest_application tia 
INNER JOIN BSGACCOUNTING..account_balance_td abt 
ON abt.td_account_id = tia.td_account_id AND abt.id = (SELECT MAX(id) FROM BSGACCOUNTING..account_balance_td WHERE td_account_id = tia.td_account_id) 
INNER JOIN BSGTD..td_account_deposit_details tadd 
ON tadd.td_account_id = tia.td_account_id AND tadd.deposite_type IN (1, 2) AND tadd.is_active = 1 
WHERE tia.current_interest > 0 
GROUP BY tia.td_account_id, tia.current_interest, tadd.td_amount, tadd.computed_amount, abt.interest_provided 
HAVING tia.current_interest + abt.interest_provided + tadd.td_amount > tadd.computed_amount) a 
ON a.td_account_id = tia.td_account_id;

IF OBJECT_ID('tempdb..#customer_wise_tds') 
IS NOT NULL DROP TABLE #customer_wise_tds

SELECT customer_group_id,(SUM(current_interest)+SUM(previous_interest)) as total_int,
CEILING(((SUM(current_interest)+SUM(previous_interest))*tds_rate)/100) as total_tds,
SUM(previous_tds) as previous_tds,SUM(current_interest) as current_total_interest
,(CEILING(((SUM(current_interest)+SUM(previous_interest))*tds_rate)/100)-SUM(previous_tds)) as current_total_tds
INTO #customer_wise_tds
FROM BSGACCOUNTING..td_interest_application 
WHERE tds_rate>0 GROUP BY customer_group_id,tds_rate

UPDATE tia SET 
tia.current_tds=CEILING((tia.current_interest*cwt.current_total_tds)/cwt.current_total_interest)
FROM BSGACCOUNTING..td_interest_application tia
INNER JOIN #customer_wise_tds cwt
ON tia.customer_group_id=cwt.customer_group_id AND cwt.current_total_tds>0 AND cwt.current_total_interest>0
WHERE tia.tds_rate>0 AND tia.current_interest>0


IF OBJECT_ID('tempdb..#customer_wise_tds') 
IS NOT NULL DROP TABLE #customer_wise_tds

END
