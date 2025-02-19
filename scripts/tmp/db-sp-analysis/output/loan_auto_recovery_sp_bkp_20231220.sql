-- =============================================
-- Author:		<Author,,Shubham Bhalerao>
-- Create date: <Create Date,,30/06/2022>
-- Description:	<Description,,loan_auto_recovery_sp>
-- =============================================
CREATE PROCEDURE [dbo].[loan_auto_recovery_sp] -- [loan_auto_recovery_sp] -- loan_auto_recovery_sp 3 ,'2023-06-05'
	@recoveryType int,
	@date datetime,
	@executionType int = 1
AS
BEGIN

 -- return 1

DECLARE @overdueWithNpa int =	ISNULL((select config_value from BSGADMIN..cbs_config where config_key ='LOAN_OVERDUE_WITH_NPA_INTEREST' and is_active = 1),0)


CREATE TABLE #auto_recovery_temptable
(
	debit_account_no varchar(50),
	loan_account_id bigint,
	debit_account_id bigint,
	recovery_type int,
	loan_account_no varchar(50),
	classification_id int,
	due_amount decimal(18,2)
)
 
  IF (@recoveryType = 1)   -- moratorium
  BEGIN
  if(@executionType = 1)
		BEGIN
     -- DROP TABLE IF EXISTS #auto_recovery_temptable
	 INSERT INTO #auto_recovery_temptable    
	select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		due_amount
	from
	( select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		case when due_amount < balance then due_amount else  balance end
		due_amount
	 from
	 (

	  SELECT 
		ca.account_no AS debit_account_no ,
		lar.loan_account_id,
		lar.debit_account_id, 
		lar.recovery_type,
		lam.loan_account_no, 
		ca.classification_id, 
		bb.due_amount AS due_amount ,
		case 
			when ca.classification_id = 6 
			then acbl.available_balance - acbl.earmarked_amount 
			else acb.available_balance - acb.lien_amount
		end  balance
	--  INTO #auto_recovery_temptable
      FROM 
		BSGLOAN..loan_auto_recovery lar with(nolock)
		INNER JOIN BSGLOAN..loan_account_master lam  with(nolock)
			ON lar.loan_account_id = lam.loan_account_id 
				and lam.is_active = 1
				and lam.loan_account_status <> 2
		INNER JOIN BSGCORE..customer_accounts ca  with(nolock)
			ON lar.debit_account_id = ca.account_id 
					AND ca.is_active = 1
		INNER JOIN BSGLOAN..loan_account_basic lab with(nolock)
			ON lar.loan_account_id = lab.loan_account_id
				and lab.is_active =1
		LEFT JOIN (
					SELECT 
						account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance with(nolock)
					WHERE 
						txn_date <= @date 
						--AND is_active = 1 
					GROUP BY account_id
					) ab
			ON lar.debit_account_id = ab.account_id
		LEFT JOIN BSGACCOUNTING..account_balance acb with(nolock)
			ON ab.account_id = acb.account_id AND ab.txn_date = acb.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl
				ON lar.debit_account_id = abl.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl with(nolock)
				ON abl.loan_account_id = acbl.loan_account_id 
				AND abl.txn_date = acbl.txn_date
		LEFT OUTER JOIN (
			
			select 
				lrc.loan_account_id,	
				SUM(ISNULL(lrc.interest_amount,0) 
				- ISNULL(lrc.interest_received,0) + 
				ISNULL(lrc.od_int_accrual,0)
				- ISNULL(lrc.od_int_received,0) + 
				ISNULL(lrc.penal_int_accrual,0) 
				- ISNULL(lrc.penal_int_received,0)) due_amount
			from
			(select 
					loan_account_id,installment_no,MAX(id) id
				from	
					BSGACCOUNTING..loan_repayment_chart with(nolock)
				where
					due_date <= @date
				 GROUP BY loan_account_id, installment_no
			)a inner join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)
				on lrc.loan_account_id = a.loan_account_id
				and lrc.installment_no = a.installment_no
					and lrc.id = a.id
					and is_active =1
					and full_installment_received = 0
			group by lrc.loan_account_id
		)bb on bb.loan_account_id = lam.loan_account_id
		WHERE 
			lar.recovery_type = @recoveryType
				and lar.is_active = 1
			AND cast(installment_start_date as date) <  @date 
			and case 
				when ca.classification_id = 6 
				then acbl.available_balance - acbl.earmarked_amount 
				else acb.available_balance - acb.lien_amount
				end > 0 --- Debit Account should have balance
		) a
			)b where due_amount > 0
			
	 END

  END
 

--IF @recoveryType = 2 -- Interest as and when 
--   BEGIN

   
			

--	END
  
 
IF  @recoveryType = 3 -- Overdue
  BEGIN 
    insert into #auto_recovery_temptable
	select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		due_amount
	from
	( select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		case when 
			(case when total_oustanding < due_amount 
			 then total_oustanding else due_amount end 
			)
		< balance then (case when total_oustanding < due_amount
		then total_oustanding else due_amount end) 
			else  balance end
		due_amount
	 from
	 (

	  SELECT 
		ca.account_no AS debit_account_no ,
		lar.loan_account_id,
		lar.debit_account_id, 
		lar.recovery_type,
		lam.loan_account_no, 
		ca.classification_id, 
		ISNULL(case when acbl1.checker_clear_balance > 0 then 0 else
			(acbl1.checker_clear_balance) *-1 end,0) + 
			ISNULL(acbl1.npa_interest_amount,0)
			+ISNULL(acbl1.npa_penal_interest_amount,0)
			+ISNULL(acbl1.npa_charges_amount,0) total_oustanding,
		ISNULL(due_amount,0) +
		ISNULL(acbl1.charges_applied-acbl1.charges_paid,0) + ISNULL(acbl1.npa_charges_amount,0)
		AS due_amount ,
		case 
			when ca.classification_id = 6 
			then acbl.available_balance - acbl.earmarked_amount 
			else acb.available_balance - acb.lien_amount
		end  balance
	--  INTO #auto_recovery_temptable
      FROM 
		BSGLOAN..loan_auto_recovery lar with(nolock)
		INNER JOIN BSGLOAN..loan_account_master lam  with(nolock)
			ON lar.loan_account_id = lam.loan_account_id 
				and lam.is_active = 1
				and lam.loan_account_status <> 2
		inner join BSGLOAN..loan_product_master lpm with(nolock)
			on lpm.loan_product_id = lam.loan_product_id
				and lpm.is_active = 1
		INNER JOIN BSGCORE..customer_accounts ca  with(nolock)
			ON lar.debit_account_id = ca.account_id 
					AND ca.is_active = 1
		INNER JOIN BSGLOAN..loan_account_basic lab with(nolock)
			ON lar.loan_account_id = lab.loan_account_id
				and lab.is_active =1
		LEFT JOIN (
					SELECT 
						account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance with(nolock)
					WHERE 
						txn_date <= @date 
						--AND is_active = 1 
					GROUP BY account_id
					) ab
			ON lar.debit_account_id = ab.account_id
		LEFT JOIN BSGACCOUNTING..account_balance acb with(nolock)
			ON ab.account_id = acb.account_id AND ab.txn_date = acb.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl
				ON lar.debit_account_id = abl.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl with(nolock)
				ON abl.loan_account_id = acbl.loan_account_id 
				AND abl.txn_date = acbl.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl1
				ON lar.loan_account_id = abl1.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl1 with(nolock)
				ON abl1.loan_account_id = acbl1.loan_account_id 
				AND abl1.txn_date = acbl1.txn_date
		LEFT OUTER JOIN (
			
		select 
				lrc.loan_account_id,	
		SUM(ISNULL(lrc.principal_amount,0) 
		- ISNULL(lrc.principal_received,0) +
		ISNULL(lrc.interest_amount,0) 
		- ISNULL(lrc.interest_received,0) + 
		ISNULL(lrc.od_int_accrual,0)
		- ISNULL(lrc.od_int_received,0) + 
		ISNULL(lrc.penal_int_accrual,0) 
		- ISNULL(lrc.penal_int_received,0)) due_amount
			from
			(select 
					loan_account_id,installment_no,MAX(id) id
				from	
					BSGACCOUNTING..loan_repayment_chart with(nolock)
				where
					due_date <= @date
					 GROUP BY loan_account_id, installment_no
			)a inner join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)
				on lrc.loan_account_id = a.loan_account_id
				and lrc.installment_no = a.installment_no
					and lrc.id = a.id
					and is_active =1
					and full_installment_received = 0
			group by lrc.loan_account_id
		)bb on bb.loan_account_id = lam.loan_account_id
		WHERE 
			lar.recovery_type = @recoveryType
			and lar.is_active = 1
			and lpm.repayment_mode = 1
			and case 
				when ca.classification_id = 6 
				then acbl.available_balance - acbl.earmarked_amount 
				else acb.available_balance - acb.lien_amount
				end > 0 --- Debit Account should have balance
		) a
			)b where due_amount > 0

		if(@executionType = 1)
		BEGIN
		insert into #auto_recovery_temptable
		select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		due_amount
	from
	(select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		case when due_amount < balance then due_amount else  balance end
		due_amount
	 from
	 (

	  SELECT 
		ca.account_no AS debit_account_no ,
		lar.loan_account_id,
		lar.debit_account_id, 
		lar.recovery_type,
		lam.loan_account_no, 
		ca.classification_id, 
		acbl1.overdue_amount + case when @overdueWithNpa = 1  then 0 else ISNULL(acbl1.npa_interest_amount,0) 
	+ ISNULL(acbl1.npa_penal_interest_amount,0) +  ISNULL(acbl1.npa_charges_amount ,0)  end
		 due_amount ,
		case 
			when ca.classification_id = 6 
			then acbl.available_balance - acbl.earmarked_amount 
			else acb.available_balance - acb.lien_amount
		end  balance
	--  INTO #auto_recovery_temptable
      FROM 
		BSGLOAN..loan_auto_recovery lar with(nolock)
		INNER JOIN BSGLOAN..loan_account_master lam  with(nolock)
			ON lar.loan_account_id = lam.loan_account_id 
				and lam.is_active = 1
				and lam.loan_account_status <> 2
		inner join BSGLOAN..loan_product_master lpm
			on lpm.loan_product_id = lam.loan_product_id
				and lpm.is_active = 1
		INNER JOIN BSGCORE..customer_accounts ca  with(nolock)
			ON lar.debit_account_id = ca.account_id 
					AND ca.is_active = 1
		INNER JOIN BSGLOAN..loan_account_basic lab with(nolock)
			ON lar.loan_account_id = lab.loan_account_id
				and lab.is_active =1
		LEFT JOIN (
					SELECT 
						account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance with(nolock)
					WHERE 
						txn_date <= @date 
						--AND is_active = 1 
					GROUP BY account_id
					) ab
			ON lar.debit_account_id = ab.account_id
		LEFT JOIN BSGACCOUNTING..account_balance acb with(nolock)
			ON ab.account_id = acb.account_id AND ab.txn_date = acb.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl
				ON lar.debit_account_id = abl.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl with(nolock)
				ON abl.loan_account_id = acbl.loan_account_id 
				AND abl.txn_date = acbl.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl1
				ON lar.loan_account_id = abl1.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl1 with(nolock)
				ON abl1.loan_account_id = acbl1.loan_account_id 
				AND abl1.txn_date = acbl1.txn_date
		WHERE 
			lar.recovery_type = @recoveryType
			and lar.is_active = 1
			and lpm.repayment_mode <> 1
			and case 
				when ca.classification_id = 6 
				then acbl.available_balance - acbl.earmarked_amount 
				else acb.available_balance - acb.lien_amount
				end > 0 --- Debit Account should have balance
		) a
			)b where due_amount > 0


		END
	


  END
  
  
IF(@recoveryType = 4) -- Interest Recovery
  BEGIN
 if(@executionType = 1)
		BEGIN
    insert into #auto_recovery_temptable
	select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		due_amount
	from
	( select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		case when due_amount < balance then due_amount else  balance end
		due_amount
	 from
	 (

	  SELECT 
		ca.account_no AS debit_account_no ,
		lar.loan_account_id,
		lar.debit_account_id, 
		lar.recovery_type,
		lam.loan_account_no, 
		ca.classification_id, 
		due_amount + 
		ISNULL(acbl1.charges_applied-acbl1.charges_paid,0) + ISNULL(acbl1.npa_charges_amount,0)
		AS due_amount ,
		case 
			when ca.classification_id = 6 
			then acbl.available_balance - acbl.earmarked_amount 
			else acb.available_balance - acb.lien_amount
		end  balance
	--  INTO #auto_recovery_temptable
      FROM 
		BSGLOAN..loan_auto_recovery lar with(nolock)
		INNER JOIN BSGLOAN..loan_account_master lam  with(nolock)
			ON lar.loan_account_id = lam.loan_account_id 
				and lam.is_active = 1
				and lam.loan_account_status <> 2
		inner join BSGLOAN..loan_product_master lpm with(nolock)
			on lpm.loan_product_id = lam.loan_product_id
				and lpm.is_active = 1
		INNER JOIN BSGCORE..customer_accounts ca  with(nolock)
			ON lar.debit_account_id = ca.account_id 
					AND ca.is_active = 1
		INNER JOIN BSGLOAN..loan_account_basic lab with(nolock)
			ON lar.loan_account_id = lab.loan_account_id
				and lab.is_active =1
		LEFT JOIN (
					SELECT 
						account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance with(nolock)
					WHERE 
						txn_date <= @date 
						--AND is_active = 1 
					GROUP BY account_id
					) ab
			ON lar.debit_account_id = ab.account_id
		LEFT JOIN BSGACCOUNTING..account_balance acb with(nolock)
			ON ab.account_id = acb.account_id AND ab.txn_date = acb.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date  
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl
				ON lar.debit_account_id = abl.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl with(nolock)
				ON abl.loan_account_id = acbl.loan_account_id 
				AND abl.txn_date = acbl.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl1
				ON lar.loan_account_id = abl1.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl1 with(nolock)
				ON abl1.loan_account_id = acbl1.loan_account_id 
				AND abl1.txn_date = acbl1.txn_date
		LEFT OUTER JOIN (
			
		select 
				lrc.loan_account_id,	
		SUM(ISNULL(lrc.interest_amount,0) 
		- ISNULL(lrc.interest_received,0) + 
		ISNULL(lrc.od_int_accrual,0)
		- ISNULL(lrc.od_int_received,0) + 
		ISNULL(lrc.penal_int_accrual,0) 
		- ISNULL(lrc.penal_int_received,0)) due_amount
			from
			(select 
					loan_account_id,installment_no,MAX(id) id
				from	
					BSGACCOUNTING..loan_repayment_chart with(nolock)
				where
					due_date <= @date
					 GROUP BY loan_account_id, installment_no
			)a inner join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)
				on lrc.loan_account_id = a.loan_account_id
				and lrc.installment_no = a.installment_no
					and lrc.id = a.id
					and is_active =1
					and full_installment_received = 0
			group by lrc.loan_account_id
		)bb on bb.loan_account_id = lam.loan_account_id
		WHERE 
			lar.recovery_type = @recoveryType
				and lar.is_active = 1
			and lpm.repayment_mode = 1
			and case 
				when ca.classification_id = 6 
				then acbl.available_balance - acbl.earmarked_amount 
				else acb.available_balance - acb.lien_amount
				end > 0 --- Debit Account should have balance
		) a
			)b where due_amount > 0


		insert into #auto_recovery_temptable
	select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		due_amount
	from
	(
	select 
		debit_account_no,
		loan_account_id,
		debit_account_id,
		recovery_type,
		loan_account_no,
		classification_id,
		case when due_amount < balance then due_amount else  balance end
		due_amount
	 from
	 (

	  SELECT 
		ca.account_no AS debit_account_no ,
		lar.loan_account_id,
		lar.debit_account_id, 
		lar.recovery_type,
		lam.loan_account_no, 
		ca.classification_id, 
	ISNULL(acbl1.interest_applied-acbl1.interest_paid,0) + ISNULL(acbl1.penal_interest_applied-acbl1.penal_interest_paid,0) + ISNULL(acbl1.charges_applied-acbl1.charges_paid,0) + ISNULL(acbl1.npa_charges_amount,0)	+ ISNULL(acbl1.npa_interest_amount,0) 
	+ ISNULL(acbl1.npa_penal_interest_amount,0) +  ISNULL(acbl1.npa_charges_amount ,0)  
		 due_amount ,
		case 
			when ca.classification_id = 6 
			then acbl.available_balance - acbl.earmarked_amount 
			else acb.available_balance - acb.lien_amount
		end  balance
	--  INTO #auto_recovery_temptable
      FROM 
		BSGLOAN..loan_auto_recovery lar with(nolock)
		INNER JOIN BSGLOAN..loan_account_master lam  with(nolock)
			ON lar.loan_account_id = lam.loan_account_id 
				and lam.is_active = 1
				and lam.loan_account_status <> 2
		inner join BSGLOAN..loan_product_master lpm with(nolock)
			on lpm.loan_product_id = lam.loan_product_id
				and lpm.is_active = 1
		INNER JOIN BSGCORE..customer_accounts ca  with(nolock)
			ON lar.debit_account_id = ca.account_id 
					AND ca.is_active = 1
		INNER JOIN BSGLOAN..loan_account_basic lab with(nolock)
			ON lar.loan_account_id = lab.loan_account_id
		LEFT JOIN (
					SELECT 
						account_id,
						MAX(txn_date)txn_date 
					FROM  
						BSGACCOUNTING..account_balance with(nolock)
					WHERE 
						txn_date <= @date 
						--AND is_active = 1 
					GROUP BY account_id
					) ab
			ON lar.debit_account_id = ab.account_id
		LEFT JOIN BSGACCOUNTING..account_balance acb with(nolock)
			ON ab.account_id = acb.account_id AND ab.txn_date = acb.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl
				ON lar.debit_account_id = abl.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl with(nolock)
				ON abl.loan_account_id = acbl.loan_account_id 
				AND abl.txn_date = acbl.txn_date
		LEFT JOIN (
					SELECT 
						loan_account_id,
						MAX(txn_date)txn_date 
					FROM 
						BSGACCOUNTING..account_balance_loan with(nolock)
					WHERE 
						txn_date <= @date 
					GROUP BY loan_account_id
				) abl1
				ON lar.loan_account_id = abl1.loan_account_id 
		LEFT JOIN BSGACCOUNTING..account_balance_loan acbl1 with(nolock)
				ON abl1.loan_account_id = acbl1.loan_account_id 
				AND abl1.txn_date = acbl1.txn_date
		WHERE 
			lar.recovery_type = @recoveryType
				and lar.is_active = 1
			
			and case 
				when ca.classification_id = 6 
				then acbl.available_balance - acbl.earmarked_amount 
				else acb.available_balance - acb.lien_amount
				end > 0 --- Debit Account should have balance
		) a

		)b where due_amount > 0

		
	
	END





  END
  
  SELECT debit_account_no ,loan_account_id, debit_account_id, recovery_type, loan_account_no, classification_id, 
  due_amount FROM #auto_recovery_temptable 
  
END
