

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[sp_td_interest_application]  -- exec sp_td_interest_application '2023-04-24','2023-04-01','2024-03-31'
@cbs_app_date date,
@fin_year_start_date date,
@fin_year_end_date date
AS
BEGIN

--TRUNCATE TABLE BSGACCOUNTING..td_interest_application

--  lastInterestDate, interestStartDate,maturityDate,rate

DECLARE @no_pan_rate decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_NO_PAN_RATE' AND is_active = 1)
DECLARE @ind_customer_rate decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_INDIVIDUAL_CUSTOMER' AND is_active = 1)
DECLARE @corp_customer_rate decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_CORPORATE_CUSTOMER' AND is_active = 1)
DECLARE @regular_tds_threshold decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_THRESHOLD' AND is_active = 1)
DECLARE @senior_tds_threshold decimal(18,2)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TDS_SENIOR_CITIZEN_THRESHOLD' AND is_active = 1)
Declare @NRO_TDS_PERCENTAGE decimal(18,2) =(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='NRO_TDS_PERCENTAGE' AND is_active = 1)
Declare @NRE_TDS_PERCENTAGE decimal(18,2) =(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='NRE_TDS_PERCENTAGE' AND is_active = 1)
Declare @TD_NRE_PRODUCTS nvarchar(500)=(SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TD_NRE_PRODUCTS' AND is_active = 1)



select 
	master_data.customer_group_id ,
	master_data.customer_id ,
	master_data.td_account_id ,
	(SELECT account_no FROM bsgcore..customer_accounts WHERE account_id=master_data.td_account_id AND is_active = 1) as td_account_no ,
	master_data.branch_code ,
	case when (master_data.account_status=1 and master_data.next_interest_date = @cbs_app_date 
				AND (CASE WHEN master_data.accrual_date IS NULL 
								THEN master_data.interest_start_date 
						  ELSE master_data.accrual_date END) 
				<master_data.next_interest_date AND master_data.deposite_type IN (1,2)) 
					then (select top 1 interest_accrual from BSGACCOUNTING..account_balance_td where td_account_id = (SELECT td_account_id FROM BSGACCOUNTING..td_datewise_interest WHERE td_account_id=master_data.td_account_id AND interest_date=master_data.next_interest_date AND is_active=1
					) order by txn_date desc)
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
		THEN ISNULL((SELECT account_id FROM bsgcore..account_master WHERE account_id=master_data.transfer_account_id AND is_active=1 AND account_status_id NOT IN (4,8) and freeze_status_id not in (2,5)),-1)
	 ELSE master_data.transfer_account_id END) as transfer_account_id,
	(SELECT account_no FROM bsgcore..customer_accounts WHERE account_id=master_data.transfer_account_id and is_active=1) as transfer_account_no,
	(CASE WHEN master_data.transfer_activity_type=1002 
		THEN ISNULL((SELECT product_id FROM bsgcore..account_master WHERE account_id=master_data.transfer_account_id AND is_active=1 AND account_status_id NOT IN (4,8) and freeze_status_id not in (2,5)),-1)
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
	master_data.next_paid_date,
	master_data.interest_accrual,
	master_data.custome_type_code,
	master_data.maturity_amount,
	master_data.checker_clear_balance,
	master_data.interest_paid,
	master_data.NRO_FLAG
INTO 
	#temp_interest_application
FROM
	(select inner_atla_data.accrual_date,int_data.*,customer_int_tds.previous_interest,customer_int_tds.previous_tds
	from 
		(SELECT tpi.*,bal_data.* 
		FROM
			(select cm.*,projected_data.projected_interest 
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
							maturity_amount,
							NRO_FLAG
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
from BSGTD..td_customer_interest_tds tcit,bsgtd..td_account_master tam,bsgcrm..customer_master cm
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
					 (SUM(tds)-SUM(tds_reversal)) as previous_tds from BSGTD..td_customer_interest_tds tcit 
					 INNER JOIN bsgtd..td_account_master tm
					 on
					 tm.td_account_id=tcit.td_account_id and tm.customer_id=tcit.customer_id and tm.is_active=1 
					  WHERE 
														  
					  tcit.txn_date>=@fin_year_start_date	  
																																																  
																																																  
					  AND tcit.txn_date<=@fin_year_end_date 
																										 
					  AND  tcit.is_active=1  					  
					  group by tcit.td_account_id,tcit.customer_id) customer_int_tds
on
int_data.td_account_id=customer_int_tds.td_account_id
--LEFT OUTER JOIN
--(SELECT 0 AS previous_interest,0 AS previous_tds) customer_int_tds ON 1=1 
)master_data
inner join
(select product_id,pl_account_id,interest_frequency,quarter_calculation,is_open_deposit from bsgtd..td_product_master where is_active=1) tpm
on
master_data.product_id=tpm.product_id




INSERT INTO BSGACCOUNTING..td_interest_application
select 
	tds_rate_cal.customer_group_id ,
	tds_rate_cal.customer_id ,
	tds_rate_cal.td_account_id ,
	tds_rate_cal.td_account_no,
	tds_rate_cal.branch_code,
	tds_rate_cal.current_interest,
	tds_rate_cal.projected_interest,
	tds_rate_cal.age_group,
	tds_rate_cal.previous_interest,
	tds_rate_cal.previous_tds,
	(case
	WHEN tds_rate_cal.NRO_FLAG=1 then @NRO_TDS_PERCENTAGE
	when tds_rate_cal.product_id in (SELECT product_id FROM BSGACCOUNTING.dbo.SplitString(@TD_NRE_PRODUCTS,',') t 
									 INNER JOIN BSGTD..td_product_master p
									 ON t.Item=p.product_code and p.is_active=1) then @NRE_TDS_PERCENTAGE
	WHEN (SELECT is_applicable FROM BSGCRM..customer_tds 
				WHERE customer_id=tds_rate_cal.customer_group_id 
					AND is_active=1 and tds_rate_cal.next_interest_date>=applicable_date
				AND tds_rate_cal.next_interest_date<=expiry_date 
					AND tds_rate_cal.tds_applicable_interest<( CASE WHEN form15h=1
																THEN (SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TD_15H_UPPER_LIMIT' AND is_active = 1) 
															  ELSE (SELECT config_value FROM BSGADMIN..cbs_config WHERE config_key='TD_15G_UPPER_LIMIT' AND is_active = 1) END) )=0
					THEN 0
		  WHEN tds_eligible=0
					THEN 0
		  when (select percentage from bsgcrm..customer_tds ct where ct.customer_id= tds_rate_cal.customer_group_id and tds_rate_cal.next_interest_date>=applicable_date
				AND tds_rate_cal.next_interest_date<=expiry_date AND ct.form15g=0 AND ct.form15h=0 AND ct.is_active=1 ) is not null
				then (select percentage from bsgcrm..customer_tds ct where ct.customer_id=tds_rate_cal.customer_group_id and tds_rate_cal.next_interest_date>=applicable_date
						AND tds_rate_cal.next_interest_date<=expiry_date AND ct.form15g=0 AND ct.form15h=0 AND ct.is_active=1)       
		  WHEN tds_rate_cal.custome_type_code=1  
				then isnull((select @ind_customer_rate from BSGCRM..customer_ind_info cii  
								where is_active=1 and  cii.pan_no like '[A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z]' AND cii.customer_id=tds_rate_cal.customer_group_id),@no_pan_rate)
		  else isnull((select @corp_customer_rate from BSGCRM..customer_corp_info cci 
						where is_active=1 and cci.pan_no like '[A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z]' AND cci.customer_id=tds_rate_cal.customer_group_id),@no_pan_rate)
		end ) as tds_rate,tds_eligible,
	tds_rate_cal.tds_receivable,
	tds_rate_cal.interest_on_tds_receivable ,
	tds_rate_cal.tds_receivable_date,
	tds_rate_cal.interest_payable,
	tds_rate_cal.next_interest_date,
	tds_rate_cal.interest_start_date,
	tds_rate_cal.maturity_date,
	tds_rate_cal.accrual_date,
	tds_rate_cal.base_rate,
	tds_rate_cal.account_status,
	tds_rate_cal.current_tds,
	tds_rate_cal.deposite_type,
	tds_rate_cal.interest_frequency,
	tds_rate_cal.is_open_deposit,
	tds_rate_cal.quarter_calculation,
	tds_rate_cal.payment_mode,
	tds_rate_cal.transfer_branch,
	tds_rate_cal.transfer_account_id,
	tds_rate_cal.transfer_account_no,
	tds_rate_cal.transfer_product_id,
	tds_rate_cal.transfer_activity_type,
	tds_rate_cal.beneficiary_bank_code,
	tds_rate_cal.beneficiary_branch_code,
	tds_rate_cal.beneficiary_ifsc,
	tds_rate_cal.beneficiary_account_name,
	tds_rate_cal.beneficiary_account_no,
	tds_rate_cal.beneficiary_address,
	tds_rate_cal.beneficiary_bank,
	tds_rate_cal.beneficiary_branch,
	tds_rate_cal.beneficiary_remarks,
	tds_rate_cal.dd_po_payee_name,
	tds_rate_cal.pl_account_id,
	tds_rate_cal.pl_product_id,
	tds_rate_cal.product_id,
	tds_rate_cal.interest_payable_product_id,
	tds_rate_cal.tds_product_id,
	tds_rate_cal.tds_receivable_product_id,
	tds_rate_cal.txn_date,
	tds_rate_cal.created_date,
	tds_rate_cal.created_by,
	tds_rate_cal.is_applied,
	tds_rate_cal.next_paid_date
from
(

select 
	master_td_int_data.customer_group_id ,
	master_td_int_data.customer_id ,
	master_td_int_data.td_account_id ,
	master_td_int_data.td_account_no,
	master_td_int_data.branch_code,
	master_td_int_data.current_interest,
	master_td_int_data.projected_interest,
	master_td_int_data.age_group,
	master_td_int_data.previous_interest,
	master_td_int_data.previous_tds,
	master_td_int_data.tds_receivable,
	master_td_int_data.interest_on_tds_receivable ,
	master_td_int_data.tds_receivable_date,
	master_td_int_data.interest_payable,
	master_td_int_data.next_interest_date,
	master_td_int_data.interest_start_date,
	master_td_int_data.maturity_date,
	master_td_int_data.accrual_date,
	master_td_int_data.base_rate,
	master_td_int_data.account_status,
	master_td_int_data.current_tds,
	master_td_int_data.deposite_type,
	master_td_int_data.interest_frequency,
	master_td_int_data.is_open_deposit,
	master_td_int_data.quarter_calculation,
	master_td_int_data.payment_mode,
	master_td_int_data.transfer_branch,
	master_td_int_data.transfer_account_id,
	master_td_int_data.transfer_account_no,
	master_td_int_data.transfer_product_id,
	master_td_int_data.transfer_activity_type,
	master_td_int_data.beneficiary_bank_code,
	master_td_int_data.beneficiary_branch_code,
	master_td_int_data.beneficiary_ifsc,
	master_td_int_data.beneficiary_account_name,
	master_td_int_data.beneficiary_account_no,
	master_td_int_data.beneficiary_address,
	master_td_int_data.beneficiary_bank,
	master_td_int_data.beneficiary_branch,
	master_td_int_data.beneficiary_remarks,
	master_td_int_data.dd_po_payee_name,
	master_td_int_data.pl_account_id,
	master_td_int_data.pl_product_id,
	master_td_int_data.product_id,
	master_td_int_data.interest_payable_product_id,
	master_td_int_data.tds_product_id,
	master_td_int_data.tds_receivable_product_id,
	master_td_int_data.txn_date,
	master_td_int_data.created_date,
	master_td_int_data.created_by,
	master_td_int_data.is_applied,
	master_td_int_data.next_paid_date,
	master_td_int_data.tds_applicable_interest,
	(CASE WHEN master_td_int_data.age_group IN (2,3) 
	AND master_td_int_data.tds_applicable_interest>@senior_tds_threshold 
	THEN 1
	WHEN master_td_int_data.age_group IN (1,4,-1) AND master_td_int_data.tds_applicable_interest>@regular_tds_threshold 
	THEN 1
	ELSE 0 END
	) tds_eligible,
	master_td_int_data.custome_type_code,
	master_td_int_data.NRO_FLAG
from
(

select 
	td_int_data.customer_group_id ,
	td_int_data.customer_id ,
	td_int_data.td_account_id ,
	td_int_data.td_account_no,
	td_int_data.branch_code,
	td_int_data.current_interest,
	td_int_data.projected_interest,
	td_int_data.age_group,
	td_int_data.previous_interest,
	td_int_data.previous_tds,
	td_int_data.tds_receivable,
	td_int_data.interest_on_tds_receivable ,
	td_int_data.tds_receivable_date,
	td_int_data.interest_payable,
	td_int_data.next_interest_date,
	td_int_data.interest_start_date,
	td_int_data.maturity_date,
	td_int_data.accrual_date,
	td_int_data.base_rate,
	td_int_data.account_status,
	td_int_data.current_tds,
	td_int_data.deposite_type,
	td_int_data.interest_frequency,
	td_int_data.is_open_deposit,
	td_int_data.quarter_calculation,
	td_int_data.payment_mode,
	td_int_data.transfer_branch,
	td_int_data.transfer_account_id,
	td_int_data.transfer_account_no,
	td_int_data.transfer_product_id,
	td_int_data.transfer_activity_type,
	td_int_data.beneficiary_bank_code,
	td_int_data.beneficiary_branch_code,
	td_int_data.beneficiary_ifsc,
	td_int_data.beneficiary_account_name,
	td_int_data.beneficiary_account_no,
	td_int_data.beneficiary_address,
	td_int_data.beneficiary_bank,
	td_int_data.beneficiary_branch,
	td_int_data.beneficiary_remarks,
	td_int_data.dd_po_payee_name,
	td_int_data.pl_account_id,
	td_int_data.pl_product_id,
	td_int_data.product_id,
	td_int_data.interest_payable_product_id,
	td_int_data.tds_product_id,
	td_int_data.tds_receivable_product_id,
	td_int_data.txn_date,
	td_int_data.created_date,
	td_int_data.created_by,
	td_int_data.is_applied,
	td_int_data.next_paid_date,
	case when td_int_data.projected_interest > actual_interest
		then td_int_data.projected_interest
		else actual_interest
	end tds_applicable_interest,
	td_int_data.custome_type_code,
	td_int_data.NRO_FLAG
	--td_int_data.age_group
from	(

select 
	t.* ,
	actual_interest
from
	#temp_interest_application t
	left outer join (
		select customer_group_id,sum(current_interest+previous_interest) actual_interest from #temp_interest_application
		group by  customer_group_id
	) tt
		on t.customer_group_id = tt.customer_group_id
)td_int_data

) master_td_int_data
) tds_rate_cal;


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




select 
	a.customer_group_id,
	a.tds_rate,
	a.upto_amount,
	a.applicable_date,
	a.expiry_date,
	ISNULL(case when isCurrentInterestInPeriod = 1 then 
	current_interest + applied_period_interest else 
	applied_period_interest end,0) applied_period_interest,
	applied_period_tds,
	current_interest,
	previous_interest,
	previous_tds,
	tds_rate_without_slab
INTO
	#temp_form15AA_details
from
(
Select 
	tt.customer_id customer_group_id,percentage tds_rate,isnull(upto_amount,0) upto_amount,applicable_date,expiry_date,
	ISNULL(previouInterestTdsDetails.previous_interest,0) applied_period_interest,
	ISNULL(previouInterestTdsDetails.previous_tds,0) applied_period_tds,
	ISNULL(current_interest,0) current_interest, 
	ISNULL(tdCurrentInterestDetails.previous_interest,0)previous_interest,
	ISNULL(tdCurrentInterestDetails.previous_tds,0) previous_tds,
	ISNULL(tdCurrentInterestDetails.tds_rate_without_slab,0) tds_rate_without_slab,
	case when @cbs_app_date >= cast(applicable_date as date) 
	and @cbs_app_date <= CAST(expiry_date as date) then  1 else 0 end  isCurrentInterestInPeriod 

from
	BSGCRM..customer_tds tt
	LEFT join (
			select 
				cm.customer_group_id,
				(SUM(interest)-SUM(interest_reversal)) as previous_interest,
				(SUM(tds)-SUM(tds_reversal)) as previous_tds 
			from BSGTD..td_customer_interest_tds tcit 
					INNER JOIN bsgtd..td_account_master tm
					on tm.td_account_id=tcit.td_account_id 
					and tm.customer_id=tcit.customer_id 
						and tm.is_active=1 
					left outer join BSGCRM..customer_master cm
						on cm.customer_id = tm.customer_id
							and cm.is_active = 1
					left outer join BSGCRM..customer_tds c
							on c.customer_id = cm.customer_group_id
								and c.is_active = 1
			WHERE 
					tcit.txn_date>=cast(c.applicable_date as date)  
					AND tcit.txn_date<=cast(c.expiry_date as date)
					AND  tcit.is_active=1  					  
			group by cm.customer_group_id
		) previouInterestTdsDetails
			on  tt.customer_id = previouInterestTdsDetails.customer_group_id
		left outer join (
							select 
								t.customer_group_id,
								ISNULL(SUM(t.current_interest),0) current_interest,
								ISNULL(SUM(t.previous_interest),0) previous_interest,
								ISNULL(SUM(t.previous_tds),0) previous_tds,
								case when tt.custome_type_code = 1
								THEN  isnull((select @ind_customer_rate from BSGCRM..customer_ind_info cii  
								where is_active=1 and  cii.pan_no like '[A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z]' AND cii.customer_id=t.customer_group_id),@no_pan_rate)
								ELSE isnull((select @corp_customer_rate from BSGCRM..customer_corp_info cci 
						where is_active=1 and cci.pan_no like '[A-Z][A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][A-Z]' AND cci.customer_id=t.customer_group_id),@no_pan_rate)
								END tds_rate_without_slab
							from
								BSGACCOUNTING..td_interest_application t
									left outer join #temp_interest_application tt
											on tt.td_account_id = t.td_account_id
												
										  
							Where
								tds_applicable = 1
							Group by t.customer_group_id,tt.custome_type_code
						 ) tdCurrentInterestDetails
						  ON tdCurrentInterestDetails.customer_group_id = tt.customer_id
where
	cast(applicable_date as date) >= @fin_year_start_date
	and cast(expiry_date as date) <= @fin_year_end_date
	and is_applicable = 1 -- Form 15 AA Submitted
	and form15g = 0 -- Form 15 G should not be submitted
	and form15g = 0 -- Form 15 H should not be submitted
	and is_active = 1 
)a


	update tia set tia.tds_rate = ISNULL(t15a.tds_rate,0)
	from BSGACCOUNTING..td_interest_application tia
		inner join #temp_form15AA_details t15a
			on tia.customer_group_id = t15a.customer_group_id
		left outer join BSGTD..td_product_master tpm
			on tpm.product_id = tia.td_product_id
				and tpm.is_active = 1
		Where
			tia.tds_applicable = 1
			and tpm.tds_applicable = 1
select 
	customer_group_id,
	total_int,
	total_tds,
	previous_tds,
	current_interest current_total_interest,
	CEILING(total_tds - previous_tds) current_total_tds
INTO 
	#temp_15AACustomerWiseDetails
from
	(
select	
	customer_group_id,
	total_int,	
	case when total_int  - applied_period_interest > 0 then 
	CEILING((total_int  - applied_period_interest) * tds_rate_without_slab / 100.00)
	ELSE 0 END + ISNULL(slabTdsCalculated,0) total_tds,
	previous_tds,
	current_interest,
	tds_rate_without_slab,
	applied_period_interest
from
(
select 
	customer_group_id,
	total_int,
	(case when (applied_period_interest - tdsCalulcatedAmount) > 0 then 
		CEILING(((applied_period_interest - tdsCalulcatedAmount) * tds_rate_without_slab)/100.00) 
		else 0 end)+
		CEILING((tdsCalulcatedAmount * tds_rate)/100.00) slabTdsCalculated,
	previous_tds,
	current_interest,
	tds_rate_without_slab,
	applied_period_interest
from
(

SELECT 
	customer_group_id,
	(current_interest)+(previous_interest) as total_int,
	case when (applied_period_interest) > upto_amount
	then upto_amount
	else applied_period_interest end tdsCalulcatedAmount,
	applied_period_interest,
	applied_period_tds,
	previous_tds,
	tds_rate,
	tds_rate_without_slab,
	current_interest
FROM 
	#temp_form15AA_details
--where 
--	tds_rate > 0
)A
)B
)C
--GROUP BY customer_group_id,tds_rate,tds_rate_without_slab


IF OBJECT_ID('tempdb..#customer_wise_tds') 
IS NOT NULL DROP TABLE #customer_wise_tds

SELECT customer_group_id,(SUM(current_interest)+SUM(previous_interest)) as total_int,
CEILING(((SUM(current_interest)+SUM(previous_interest))*tds_rate)/100) as total_tds,
SUM(previous_tds) as previous_tds,SUM(current_interest) as current_total_interest
,(CEILING(((SUM(current_interest)+SUM(previous_interest))*tds_rate)/100)-SUM(previous_tds)) as current_total_tds
INTO #customer_wise_tds
FROM BSGACCOUNTING..td_interest_application
WHERE tds_rate>0  and customer_group_id not in (
select distinct customer_group_id from #temp_15AACustomerWiseDetails
)
GROUP BY customer_group_id,tds_rate

INSERT INTO #customer_wise_tds
select 
	customer_group_id,
	total_int,
	total_tds,
	previous_tds,
	current_total_interest,
	current_total_tds
from
	#temp_15AACustomerWiseDetails


UPDATE tia SET 
tia.current_tds=CEILING((tia.current_interest*cwt.current_total_tds)/cwt.current_total_interest)
FROM BSGACCOUNTING..td_interest_application tia
INNER JOIN #customer_wise_tds cwt
ON tia.customer_group_id=cwt.customer_group_id AND cwt.current_total_tds>0 AND cwt.current_total_interest>0
WHERE tia.tds_rate>0 AND tia.current_interest>0


IF OBJECT_ID('tempdb..#customer_wise_tds') 
IS NOT NULL DROP TABLE #customer_wise_tds

END
  
