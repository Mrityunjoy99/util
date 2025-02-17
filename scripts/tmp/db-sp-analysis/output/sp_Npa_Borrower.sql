-- =============================================
-- Author:		<Abhishek,>
-- Create date: <23-01-2020, 23-01-2020>
-- Description:	<NPA BORROWER, GIVE LIST WHICH GET ACCOUNT ID SHOULD BE MARK AS NPA>
-- =============================================

create    PROCEDURE [dbo].[sp_Npa_Borrower] -- sp_Npa_Borrower '2020-01-03',-99
(
	@cbsDate Date,
	@employeeId bigint
)
AS
BEGIN

-- Final Return Table
CREATE TABLE #Npa_Borrower
(
	loanAccountId bigint,
	npaReason varchar(500)
)

-- Take Those Account Which Are Already NPA
Select 
	distinct ca.customer_id
INTO 
	#distinctCustomerId
FROM
	BSGLOAN..loan_account_master LAM WITH(NOLOCK)
	INNER JOIN (
				select	
					ABL.loan_account_id ,
					MAX(txn_date) txn_date
				FROM
					BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
				Where	
					ABL.is_active = 1
					and txn_date <= @cbsDate
				Group by 
					ABL.loan_account_id
				)AB
			ON AB.loan_account_id = LAM.loan_account_id
	INNER JOIN BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
		ON ABL.loan_account_id = AB.loan_account_id	
			and ABL.txn_date = AB.txn_date
				and ABL.is_active = 1
	INNER JOIN BSGCORE..customer_accounts CA WITH(NOLOCK)
		ON CA.account_id = LAM.loan_account_id
			and CA.is_active = 1 
	INNER JOIN BSGLOAN..loan_product_master LPM  WITH(NOLOCK)
		ON LAM.loan_product_id = LPM.loan_product_id
			and LPM.is_active = 1
Where
	LAM.is_active = 1
	and LAM.loan_account_status <> 2
	and LAM.asset_classification in (3,4,5,6,7) 
	AND ABL.checker_clear_balance  < 0
	and LPM.npa_applicable = 1

-- Take Those Account Which Are Should Be NPA
/*INSERT INTO #distinctCustomerId
Select 
	distinct ca.customer_id
FROM
	BSGACCOUNTING..loan_npa_details LNP WITH(NOLOCK)
	INNER JOIN BSGCORE..customer_accounts CA WITH(NOLOCK)
		ON CA.account_id = LNP.loan_account_id
			and CA.is_active = 1
Where
	CA.customer_id not in (select customer_id from #distinctCustomerId)
*/
Select 
	distinct 
		CM.customer_group_id
INTO 
	#distinctCustomerGroupId
FROM
	BSGCRM..customer_master CM WITH(NOLOCK)
	INNER JOIN #distinctCustomerId dci
		on CM.customer_id = dci.customer_id		
Where
	CM.is_active = 1
	
Select 
	distinct 
		CM.customer_id
INTO 
	#distinctCustomerIdForLoanCCAccounts
FROM
	BSGCRM..customer_master CM WITH(NOLOCK)
	INNER JOIN #distinctCustomerGroupId dci
		on CM.customer_group_id = dci.customer_group_id
Where
	CM.is_active = 1

INSERT INTO #Npa_Borrower
Select 
	LAM.loan_account_id ,
	'BORROWER WISE NPA' 
FROM
	BSGLOAN..loan_account_master LAM WITH(NOLOCK)
	INNER JOIN (
				select	
					ABL.loan_account_id ,
					MAX(txn_date) txn_date
				FROM
					BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
				Where	
					ABL.is_active = 1
					and txn_date <= @cbsDate
				Group by 
					ABL.loan_account_id
				)AB
			ON AB.loan_account_id = LAM.loan_account_id
	INNER JOIN BSGACCOUNTING..account_balance_loan ABL WITH(NOLOCK)
		ON ABL.loan_account_id = AB.loan_account_id	
			and ABL.txn_date = AB.txn_date
				and ABL.is_active = 1
	INNER JOIN BSGCORE..customer_accounts CA WITH(NOLOCK)
		ON CA.account_id = LAM.loan_account_id
			and CA.is_active = 1
	INNER JOIN BSGLOAN..loan_product_master LPM  WITH(NOLOCK)
		ON LAM.loan_product_id = LPM.loan_product_id
			and LPM.is_active = 1
	INNER JOIN  #distinctCustomerIdForLoanCCAccounts DC
		ON DC.customer_id =  CA.customer_id
Where
	LAM.is_active = 1
	and LAM.loan_account_status <> 2
	and LAM.asset_classification not in (3,4,5,6,7) 
	AND ABL.checker_clear_balance  < 0
	and LPM.npa_applicable = 1

-- final Selection 
Select 
	loanAccountId,
	npaReason
FROM
	#Npa_Borrower

END
