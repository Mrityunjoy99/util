-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_pending_charges]
AS
BEGIN
	select 
		ac.*
	from 
		account_charges ac
	inner join
		account_balance ab
	on 
		ac.account_id = ab.account_id
	inner join  (select account_id,max(txn_date) txn_date from  account_balance ab
	where account_id in (select account_id from account_charges where status = 0  and  is_active=1)
	 group by account_id )a
	on 
		ac.account_id = a.account_id
	and	
		ab.txn_date = a.txn_date		
	where 
		status = 0 
	and 
		ac.is_active=1
	and 
		ac.charges_amount + cgst_amount+ sgst_amount<= available_balance
	and ac.charges_amount  >0
union all
select 
		ac.*
	from 
		account_charges ac
	inner join
		account_balance_loan ab
	on 
		ac.account_id = ab.loan_account_id
	inner join  (select loan_account_id,max(txn_date) txn_date from  account_balance_loan ab
	where loan_account_id in (select account_id from account_charges where status = 0  and  is_active=1)
	 group by loan_account_id )a
	on 
		ac.account_id = a.loan_account_id
	and	
		ab.txn_date = a.txn_date		
	where 
		status = 0 
	and 
		ac.is_active=1
	and 
		ac.charges_amount + cgst_amount+ sgst_amount <= available_balance
	
	and ac.charges_amount  >0
END
