


create    PROCEDURE [dbo].[sp_get_account_info]-- [sp_get_account_info] 4,-1,25754,-1,1,0,1,0
@classificationId int=0,
@accountId bigint=0,
@customerId bigint=0,
@branchCode int = 0,
@skipAccountFilter int = 0,
@skipCustomerFilter int = 0,
@skipBranchFilter int = 0,
@interestApplication int = 0,
@isVerify int = 0
AS BEGIN
    if(@interestApplication = 0)
	BEGIN
		if(@classificationId in (1, 2))
		BEGIN
			if(@skipAccountFilter = 0)
			begin 
				select ca.classification_id, ca.account_no, am.account_id, cm.customer_id, am.account_status_id,
					isnull(case when cm.custome_type_code =1 then  
				(select top 1 aadhar_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)  
				else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then 
				(select top 1 pan_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)
				  else  (select top 1 pan_no  from bsgcrm..customer_corp_info  where customer_id=cm.customer_id and is_active=1) end,'' )pan_no,
				cm.registered_mobile_no,
				(select available_balance from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id  and txn_date = (
				select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id
				)) available_balance,
				 (select lien_amount from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id  and txn_date = (
				select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id
				)) lien_amount,cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				 and ca.account_id = @accountId				
				inner join 
				bsgcore..account_master am WITH(NOLOCK)
				on  ca.account_id = am.account_id and am.is_active=1
				where ca.account_id = @accountId
			end 
			else if(@skipCustomerFilter = 0)
			begin 
				select ca.classification_id, ca.account_no, am.account_id, cm.customer_id, am.account_status_id,
					isnull(case when cm.custome_type_code =1 then  
				(select top 1 aadhar_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)  
				else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then 
				(select top 1 pan_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)
				  else  (select top 1 pan_no  from bsgcrm..customer_corp_info  where customer_id=cm.customer_id and is_active=1) end,'' )pan_no,
				cm.registered_mobile_no,
				(select available_balance from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id  and txn_date = (
				select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id
				)) available_balance,
				 (select lien_amount from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id  and txn_date = (
				select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id
				)) lien_amount,cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				 and ca.customer_id = @customerId				
				inner join 
				bsgcore..account_master am WITH(NOLOCK)
				on  ca.account_id = am.account_id and am.is_active=1
				and am.account_status_id <> 4
				where ca.customer_id = @customerId
			end 
			else if(@skipBranchFilter = 0)
			begin 
				select ca.classification_id, ca.account_no, am.account_id, cm.customer_id, am.account_status_id,
					isnull(case when cm.custome_type_code =1 then  
				(select top 1 aadhar_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)  
				else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then 
				(select top 1 pan_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)
				  else  (select top 1 pan_no  from bsgcrm..customer_corp_info  where customer_id=cm.customer_id and is_active=1) end,'' )pan_no,
				cm.registered_mobile_no,
				(select available_balance from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id  and txn_date = (
				select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id
				)) available_balance,
				 (select lien_amount from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id  and txn_date = (
				select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=ca.account_id
				)) lien_amount,cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				 and ca.branch_code = @branchCode				
				inner join 
				bsgcore..account_master am WITH(NOLOCK)
				on  ca.account_id = am.account_id and am.is_active=1
				where ca.branch_code = @branchCode
			end 
			 

		END
		ELSE IF(@classificationId in (3, 6))
		BEGIN
			if(@skipAccountFilter = 0)
			begin 
				select ca.classification_id, ca.account_no, 
					isnull(case when cm.custome_type_code =1 then  
				(select top 1 aadhar_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)  
				else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then 
				(select top 1 pan_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)
				  else  (select top 1 pan_no  from bsgcrm..customer_corp_info  where customer_id=cm.customer_id and is_active=1) end,'' )pan_no,
				cm.registered_mobile_no,
				am.loan_account_id account_id, am.customer_no customer_id, am.loan_account_Status account_status_id, 
				ad.rate_of_interest,
				ad.offset,
				ad.loan_amount,		
				ab.checker_clear_balance,
				ab.available_dp,
				ab.available_balance,	
				ab.sanction_limit,
				ab.margin_amount,
				ab.margin_realised_amount,
				ab.disbursement_amount,
				ab.earmarked_amount,
				cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				and ca.account_id = @accountId 
				 
				inner join 
				bsgloan..loan_account_master am WITH(NOLOCK)
				on  ca.account_id = am.loan_account_id and am.is_active=1
				inner join BSGLOAN..loan_account_basic ad WITH(NOLOCK)
				on am.loan_account_id = ad.loan_account_id and ad.is_active = 1
				--left outer join 
				--bsgcrm..customer_ind_info cii WITH(NOLOCK)
				--on  cm.customer_id = cii.customer_id and cii.is_active=1
				--left outer join 
				--BSGCRM..customer_corp_info cci WITH(NOLOCK)
				--on cm.customer_id = cci.customer_id and cci.is_active=1
				left join (select ab.* from BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK)
				inner join 
					(SELECT loan_account_id,MAX(txn_date)  txn_date
					FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK)
					where loan_account_id = @accountId
					group by loan_account_id
					)a
				on 
					ab.loan_account_id = a.loan_account_id
				and 
					ab.txn_date = a.txn_date
				)ab 
				on am.loan_account_id = ab.loan_account_id
				
				where   ca.account_id = @accountId 
			end
			else if(@skipCustomerFilter = 0)
			begin 
				select ca.classification_id, ca.account_no, 
					isnull(case when cm.custome_type_code =1 then  
				(select top 1 aadhar_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)  
				else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then 
				(select top 1 pan_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)
				  else  (select top 1 pan_no  from bsgcrm..customer_corp_info  where customer_id=cm.customer_id and is_active=1) end,'' )pan_no,
				cm.registered_mobile_no,
				am.loan_account_id account_id, am.customer_no customer_id, am.loan_account_Status account_status_id, 
				ad.rate_of_interest,
				ad.offset,
				ad.loan_amount,		
				ab.checker_clear_balance,
				ab.available_dp,
				ab.available_balance,	
				ab.sanction_limit,
				ab.margin_amount,
				ab.margin_realised_amount,
				ab.disbursement_amount,
				ab.earmarked_amount,
				cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				and ca.customer_id = @customerId
				inner join 
				bsgloan..loan_account_master am WITH(NOLOCK)
				on  ca.account_id = am.loan_account_id and am.is_active=1
				and am.loan_account_Status <> 2
				inner join BSGLOAN..loan_account_basic ad WITH(NOLOCK)
				on am.loan_account_id = ad.loan_account_id and ad.is_active = 1
				 
				left join BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK)
				on am.loan_account_id = ab.loan_account_id
				and ab.txn_date = (SELECT MAX(txn_date) 
					FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK) 
					WHERE loan_account_id = am.loan_account_id and is_active = 1)
				where   ca.customer_id = @customerId
			end
			else if(@skipBranchFilter = 0)
			begin 
				select ca.classification_id, ca.account_no, 
					isnull(case when cm.custome_type_code =1 then  
				(select top 1 aadhar_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)  
				else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then 
				(select top 1 pan_no  from bsgcrm..customer_ind_info  where customer_id=cm.customer_id and is_active=1)
				  else  (select top 1 pan_no  from bsgcrm..customer_corp_info  where customer_id=cm.customer_id and is_active=1) end,'' )pan_no,
				cm.registered_mobile_no,
				am.loan_account_id account_id, am.customer_no customer_id, am.loan_account_Status account_status_id, 
				ad.rate_of_interest,
				ad.offset,
				ad.loan_amount,		
				ab.checker_clear_balance,
				ab.available_dp,
				ab.available_balance,	
				ab.sanction_limit,
				ab.margin_amount,
				ab.margin_realised_amount,
				ab.disbursement_amount,
				ab.earmarked_amount,
				cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				and ca.branch_code = @branchCode
				inner join 
				bsgloan..loan_account_master am WITH(NOLOCK)
				on  ca.account_id = am.loan_account_id and am.is_active=1

				inner join BSGLOAN..loan_account_basic ad WITH(NOLOCK)
				on am.loan_account_id = ad.loan_account_id and ad.is_active = 1
				 
				left join BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK)
				on am.loan_account_id = ab.loan_account_id
				and ab.txn_date = (SELECT MAX(txn_date) 
					FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK) 
					WHERE loan_account_id = am.loan_account_id and is_active = 1)
				where   ca.branch_code = @branchCode
			end
		END
		ELSE IF(@classificationId in (4))
		BEGIN
			if(@skipAccountFilter = 0)
			begin
				select ca.classification_id, ca.account_no, tam.td_account_id account_id, cm.customer_id, tam.account_status_id,
			isnull(case when cm.custome_type_code =1 then  cii.aadhar_no else 'N/A' end ,'') aadhar_no, 
			isnull(case when cm.custome_type_code =1 then  cii.pan_no else cci.pan_no end,'' )pan_no,
			cm.registered_mobile_no, tam.td_amount tam_td_amount, tam.maturity_amount, 
			tadd.td_amount tadd_td_amount, tadd.computed_amount, tadd.maturity_date, 
			abt.checker_clear_balance, abt.available_balance, abt.interest_provided, 
			abt.interest_paid, abt.interest_payable, abt.previous_td_interest_payable, 
			isnull(tip.payment_mode, -1) payment_mode, isnull(tip.transfer_branch, -1) transfer_branch, 
			isnull(tip.transfer_account_id, -1) transfer_account_id, isnull(tip.beneficiary_ifsc, 'N/A') beneficiary_ifsc, 
			isnull(tip.beneficiary_account_no, 'N/A') beneficiary_account_no, isnull(tip.dd_po_payee_name, 'N/A') dd_po_payee_name, 
			cm.custome_type_code
			from bsgcrm..customer_master cm WITH(NOLOCK)
			inner join 
			bsgcore..customer_accounts ca WITH(NOLOCK)
			on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
			 and ca.account_id = @accountId
			   
			inner join 
			bsgtd..td_account_master tam WITH(NOLOCK)
			on  ca.account_id = tam.td_account_id and tam.is_active=1
			inner join 
			BSGTD..td_account_deposit_details tadd WITH(NOLOCK)
			ON tam.td_account_id = tadd.td_account_id AND tadd.is_active = 1 
			left join 
			BSGTD..td_interest_payment tip WITH(NOLOCK)
			ON tam.td_account_id = tip.td_account_id AND tip.is_active = 1
			left outer join 
			bsgcrm..customer_ind_info  cii WITH(NOLOCK)
			on  cm.customer_id =  cii.customer_id and cii.is_active=1
			left outer join 
			BSGCRM..customer_corp_info cci WITH(NOLOCK)
			on cm.customer_id = cci.customer_id and cci.is_active=1
			left join
			BSGACCOUNTING..account_balance_td abt WITH(NOLOCK)
			on tam.td_account_id = abt.td_account_id
			and abt.id = (SELECT MAX(id)
			FROM BSGACCOUNTING.dbo.account_balance_td WITH(NOLOCK)
			WHERE td_account_id = tam.td_account_id)
			where   ca.account_id = @accountId;
			end 
			else if(@skipCustomerFilter = 0)
			begin
					select ca.classification_id, ca.account_no, tam.td_account_id account_id, cm.customer_id, tam.account_status_id,
				isnull(case when cm.custome_type_code =1 then  cii.aadhar_no else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then  cii.pan_no else cci.pan_no end,'' )pan_no,
				cm.registered_mobile_no, tam.td_amount tam_td_amount, tam.maturity_amount, 
				tadd.td_amount tadd_td_amount, tadd.computed_amount, tadd.maturity_date, 
				abt.checker_clear_balance, abt.available_balance, abt.interest_provided, 
				abt.interest_paid, abt.interest_payable, abt.previous_td_interest_payable, 
				isnull(tip.payment_mode, -1) payment_mode, isnull(tip.transfer_branch, -1) transfer_branch, 
				isnull(tip.transfer_account_id, -1) transfer_account_id, isnull(tip.beneficiary_ifsc, 'N/A') beneficiary_ifsc, 
				isnull(tip.beneficiary_account_no, 'N/A') beneficiary_account_no, isnull(tip.dd_po_payee_name, 'N/A') dd_po_payee_name, 
				cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				 and  ca.customer_id = @customerId
				inner join 
				bsgtd..td_account_master tam WITH(NOLOCK)
				on  ca.account_id = tam.td_account_id and tam.is_active=1
				and tam.account_status_id<> 5
				inner join 
				BSGTD..td_account_deposit_details tadd WITH(NOLOCK)
				ON tam.td_account_id = tadd.td_account_id AND tadd.is_active = 1 
				left join 
				BSGTD..td_interest_payment tip WITH(NOLOCK)
				ON tam.td_account_id = tip.td_account_id AND tip.is_active = 1
				left outer join 
				bsgcrm..customer_ind_info  cii WITH(NOLOCK)
				on  cm.customer_id =  cii.customer_id and cii.is_active=1
				left outer join 
				BSGCRM..customer_corp_info cci WITH(NOLOCK)
				on cm.customer_id = cci.customer_id and cci.is_active=1
				left join
				BSGACCOUNTING..account_balance_td abt WITH(NOLOCK)
				on tam.td_account_id = abt.td_account_id
				and abt.id = (SELECT MAX(id)
				FROM BSGACCOUNTING.dbo.account_balance_td WITH(NOLOCK)
				WHERE td_account_id = tam.td_account_id)
				where   cm.customer_id = @customerId;
			end 
			else if(@skipBranchFilter = 0)
			begin
					select ca.classification_id, ca.account_no, tam.td_account_id account_id, cm.customer_id, tam.account_status_id,
				isnull(case when cm.custome_type_code =1 then  cii.aadhar_no else 'N/A' end ,'') aadhar_no, 
				isnull(case when cm.custome_type_code =1 then  cii.pan_no else cci.pan_no end,'' )pan_no,
				cm.registered_mobile_no, tam.td_amount tam_td_amount, tam.maturity_amount, 
				tadd.td_amount tadd_td_amount, tadd.computed_amount, tadd.maturity_date, 
				abt.checker_clear_balance, abt.available_balance, abt.interest_provided, 
				abt.interest_paid, abt.interest_payable, abt.previous_td_interest_payable, 
				isnull(tip.payment_mode, -1) payment_mode, isnull(tip.transfer_branch, -1) transfer_branch, 
				isnull(tip.transfer_account_id, -1) transfer_account_id, isnull(tip.beneficiary_ifsc, 'N/A') beneficiary_ifsc, 
				isnull(tip.beneficiary_account_no, 'N/A') beneficiary_account_no, isnull(tip.dd_po_payee_name, 'N/A') dd_po_payee_name, 
				cm.custome_type_code
				from bsgcrm..customer_master cm WITH(NOLOCK)
				inner join 
				bsgcore..customer_accounts ca WITH(NOLOCK)
				on  cm.customer_id = ca.customer_id  and cm.is_active =1 and ca.is_active=1
				 and  ca.branch_code = @branchCode
				inner join 
				bsgtd..td_account_master tam WITH(NOLOCK)
				on  ca.account_id = tam.td_account_id and tam.is_active=1
				inner join 
				BSGTD..td_account_deposit_details tadd WITH(NOLOCK)
				ON tam.td_account_id = tadd.td_account_id AND tadd.is_active = 1 
				left join 
				BSGTD..td_interest_payment tip WITH(NOLOCK)
				ON tam.td_account_id = tip.td_account_id AND tip.is_active = 1
				left outer join 
				bsgcrm..customer_ind_info  cii WITH(NOLOCK)
				on  cm.customer_id =  cii.customer_id and cii.is_active=1
				left outer join 
				BSGCRM..customer_corp_info cci WITH(NOLOCK)
				on cm.customer_id = cci.customer_id and cci.is_active=1
				left join
				BSGACCOUNTING..account_balance_td abt WITH(NOLOCK)
				on tam.td_account_id = abt.td_account_id
				and abt.id = (SELECT MAX(id)
				FROM BSGACCOUNTING.dbo.account_balance_td WITH(NOLOCK)
				WHERE td_account_id = tam.td_account_id)
				where   ca.branch_code = @branchCode;
			end 
			 
		END
	END
    ELSE IF(@interestApplication=1)
    BEGIN
		if(@classificationId in (1, 2))
		BEGIN
			select DISTINCT 
			ca.classification_id, ca.account_no, am.account_id, cm.customer_id, am.account_status_id,
			isnull(case when cm.custome_type_code =1 then  cii.aadhar_no else 'N/A' end ,'') aadhar_no, 
			isnull(case when cm.custome_type_code =1 then  cii.pan_no else cci.pan_no end,'') pan_no,
			cm.registered_mobile_no, ab.available_balance,
			ab.lien_amount,cm.custome_type_code
			from BSGACCOUNTING..td_interest_application tia WITH(NOLOCK)
			inner join bsgcore..customer_accounts ca WITH(NOLOCK)
			on tia.transfer_account_id = ca.account_id and tia.current_interest> 0 and ca.is_active =1
			inner join bsgcrm..customer_master cm WITH(NOLOCK)
			on cm.customer_id = ca.customer_id   and cm.is_active=1  
			inner join bsgcore..account_master am WITH(NOLOCK)
			on  ca.account_id = am.account_id and am.is_active=1
			left outer join 
			bsgcrm..customer_ind_info cii WITH(NOLOCK)
			on  cm.customer_id =  cii.customer_id and cii.is_active=1
			left outer join 
			BSGCRM..customer_corp_info cci WITH(NOLOCK)
			on cm.customer_id = cci.customer_id and cci.is_active=1
			left join
			BSGACCOUNTING..account_balance ab WITH(NOLOCK)
			on am.account_id = ab.account_id
			and ab.txn_date = (SELECT MAX(txn_date)
			FROM BSGACCOUNTING.dbo.account_balance WITH(NOLOCK)
			WHERE account_id = am.account_id and is_active = 1)

		END
		ELSE IF(@classificationId in (3, 6))
		BEGIN
			select DISTINCT 
			ca.classification_id, ca.account_no, 
			isnull(case when cm.custome_type_code =1 then  cii.aadhar_no else 'N/A' end ,'') aadhar_no, 
			isnull(case when cm.custome_type_code =1 then  cii.pan_no else cci.pan_no end,'') pan_no,			
			cm.registered_mobile_no,
			am.loan_account_id account_id, am.customer_no customer_id, am.loan_account_Status account_status_id, 
			ad.rate_of_interest,
			ad.offset,
			ad.loan_amount,		
			ab.checker_clear_balance,
			ab.available_dp,
			ab.available_balance,	
			ab.sanction_limit,
			ab.margin_amount,
			ab.margin_realised_amount,
			ab.disbursement_amount,
			ab.earmarked_amount,
			cm.custome_type_code
			from BSGACCOUNTING..td_interest_application tia WITH(NOLOCK)
			inner join bsgcore..customer_accounts ca WITH(NOLOCK)
			on tia.transfer_account_id = ca.account_id and tia.current_interest> 0 and ca.is_active =1
			inner join bsgcrm..customer_master cm WITH(NOLOCK)
			on cm.customer_id = ca.customer_id   and cm.is_active=1  
			inner join bsgloan..loan_account_master am WITH(NOLOCK)
			on  ca.account_id = am.loan_account_id and am.is_active=1
			inner join BSGLOAN..loan_account_basic ad WITH(NOLOCK)
			on am.loan_account_id = ad.loan_account_id and ad.is_active = 1
			left outer join 
			bsgcrm..customer_ind_info cii WITH(NOLOCK)
			on  cm.customer_id =  cii.customer_id and cii.is_active=1
			left outer join 
			BSGCRM..customer_corp_info cci WITH(NOLOCK)
			on cm.customer_id = cci.customer_id and cci.is_active=1
			left join
			BSGACCOUNTING..account_balance_loan ab WITH(NOLOCK)
			on am.loan_account_id = ab.loan_account_id
			and ab.txn_date = (SELECT MAX(txn_date)
			FROM BSGACCOUNTING.dbo.account_balance_loan WITH(NOLOCK) 
			WHERE loan_account_id = am.loan_account_id and is_active = 1)	
		END
		ELSE IF(@classificationId in (4))
		BEGIN
			select ca.classification_id, ca.account_no, tam.td_account_id account_id, cm.customer_id, tam.account_status_id,
			isnull(case when cm.custome_type_code =1 then  cii.aadhar_no else 'N/A' end ,'') aadhar_no, 
			isnull(case when cm.custome_type_code =1 then  cii.pan_no else cci.pan_no end,'' )pan_no,
			cm.registered_mobile_no, tam.td_amount tam_td_amount, tam.maturity_amount, 
			tadd.td_amount tadd_td_amount, tadd.computed_amount, tadd.maturity_date, 
			abt.checker_clear_balance, abt.available_balance, abt.interest_provided, 
			abt.interest_paid, abt.interest_payable, abt.previous_td_interest_payable, 
			isnull(tip.payment_mode, -1) payment_mode, isnull(tip.transfer_branch, -1) transfer_branch, 
			isnull(tip.transfer_account_id, -1) transfer_account_id, isnull(tip.beneficiary_ifsc, 'N/A') beneficiary_ifsc, 
			isnull(tip.beneficiary_account_no, 'N/A') beneficiary_account_no, isnull(tip.dd_po_payee_name, 'N/A') dd_po_payee_name, 
			cm.custome_type_code
			from BSGACCOUNTING..td_interest_application tia WITH(NOLOCK)
			inner join bsgcore..customer_accounts ca WITH(NOLOCK)
			on tia.td_account_id = ca.account_id 
			and (@skipBranchFilter = 1 or tia.branch_code = @branchCode) 
			and (tia.current_interest > 0 or tia.current_interest = -1 or (tia.interest_date = (SELECT app_date FROM BSGACCOUNTING..cbs_application_date WHERE is_active = 1) AND tia.current_interest = 0)) 
			and (((tia.payment_mode <> -2 OR tia.payment_mode IS NULL) AND @isVerify = 0) OR (@isVerify = 1 AND tia.payment_mode > 0)) 
			and ca.is_active = 1
			inner join bsgcrm..customer_master cm WITH(NOLOCK)
			on cm.customer_id = ca.customer_id   and cm.is_active=1  
			inner join 
			bsgtd..td_account_master tam WITH(NOLOCK)
			on  ca.account_id = tam.td_account_id and tam.is_active=1
			inner join 
			BSGTD..td_account_deposit_details tadd WITH(NOLOCK)
			ON tam.td_account_id = tadd.td_account_id AND tadd.is_active = 1 
			left join 
			BSGTD..td_interest_payment tip WITH(NOLOCK)
			ON tam.td_account_id = tip.td_account_id AND tip.is_active = 1
			left outer join 
			bsgcrm..customer_ind_info  cii WITH(NOLOCK)
			on  cm.customer_id =  cii.customer_id and cii.is_active=1
			left outer join 
			BSGCRM..customer_corp_info cci WITH(NOLOCK)
			on cm.customer_id = cci.customer_id and cci.is_active=1
			left join
			BSGACCOUNTING..account_balance_td abt WITH(NOLOCK)
			on tam.td_account_id = abt.td_account_id
			and abt.id = (SELECT MAX(id)
			FROM BSGACCOUNTING.dbo.account_balance_td WITH(NOLOCK)
			WHERE td_account_id = tam.td_account_id);
		END
    END
END

