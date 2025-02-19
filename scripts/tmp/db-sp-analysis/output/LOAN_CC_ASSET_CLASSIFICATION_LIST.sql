-- =============================================
-- Author:		<Abhishek,>
-- Create date: <2023-04-29, 2023-04-29>
-- Description:	<Loan Asset Classification Updation task, Business Logic for NPA Asset classification change >
-- =============================================

CREATE PROCEDURE [dbo].[LOAN_CC_ASSET_CLASSIFICATION_LIST] -- LOAN_CC_ASSET_CLASSIFICATION_LIST '2023-05-04',1
(
	@taskDate date,
	@modifyBy int
)
AS 
BEGIN
DECLARE @doubtfull1AssetMonths int = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'NPA_DOUBTFUL_ASSET_PERIOD_MONTHS' and is_active = 1 ),12)
DECLARE @doubtfull2AssetMonths int = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'NPA_DOUBTFUL_TWO_ASSET_PERIOD_MONTHS' and is_active = 1 ),24)
DECLARE @doubtfull3AssetMonths int = ISNULL((select config_value from BSGADMIN..cbs_config where config_key = 'NPA_DOUBTFUL_THREE_ASSET_PERIOD_MONTHS' and is_active = 1 ),48)

CREATE TABLE #temp_account_new_asset_classification
(
	loan_account_id bigint,
	old_asset_classification int,
	new_asset_classfication int
)


CREATE TABLE #temp_asset_classification_details
(
	loan_account_id bigint,
	customer_no bigint,
	customer_group_id bigint,
	asset_classification int,
	npa_mark_date date
)
INSERT INTO #temp_asset_classification_details
select 
	lam.loan_account_id,
	cm.customer_id,
	cm.customer_group_id,
	lam.asset_classification,
	abl.npa_marked_date
from
	BSGLOAN..loan_account_master lam with(nolock)
		inner join BSGCRM..customer_master cm with(nolock)
			on cm.customer_id = lam.customer_no
				and cm.is_active = 1
	    left outer join  (
							select 
								loan_account_id,
								MAX(txn_date)txn_date
							from
								BSGACCOUNTING..account_balance_loan abl with(nolock)
							where
								txn_date <= @taskDate
							group by 
								loan_account_id
						) ab
					on ab.loan_account_id = lam.loan_account_id
		 left outer join BSGACCOUNTING..account_balance_loan abl with(nolock)
			on abl.loan_account_id = ab.loan_account_id
				and abl.txn_date = ab.txn_date
where
	lam.is_active = 1
	and lam.loan_account_status <> 2
	and lam.asset_classification >= 3 -- Sub-Standard and greater asset-classification
			

select 
	cm.customer_group_id,	
	MAX(lam.is_suitfile) is_suitfile,
	MIN(lab.limit_expiry_date) limit_expiry_date,
	ISNULL(SUM(overdue_amount),0) overdue_amount,
	ISNULL(SUM(npa_interest_amount),0) npa_interest_amount,
	ISNULL(SUM(npa_penal_interest_amount),0) npa_penal_interest_amount,
	ISNULL(SUM(npa_charges_amount),0) npa_charges_amount
INTO
	#temp_customer_group_id_details
from
	#temp_asset_classification_details t
		inner join BSGCRM..customer_master cm with(nolock)
			on	cm.customer_group_id = t.customer_group_id
				and cm.is_active = 1
		 inner join BSGLOAN..loan_account_master lam with(nolock)
			on lam.customer_no = cm.customer_id
				and lam.is_active = 1
		left join BSGLOAN..loan_account_basic lab with(nolock)
			on lab.loan_account_id = lam.loan_account_id
				and lab.is_active =1 
		LEFT OUTER JOIN  (
							select 
								loan_account_id,
								MAX(txn_date)txn_date
							from
								BSGACCOUNTING..account_balance_loan abl with(nolock)
							where	
								txn_date <= @taskDate
							group by 
								loan_account_id
						) ab
					on ab.loan_account_id = lam.loan_account_id
		LEFT OUTER JOIN BSGACCOUNTING..account_balance_loan abl with(nolock)
			on abl.loan_account_id = ab.loan_account_id
				and abl.txn_date = ab.txn_date
where
	lam.is_active = 1
	and lam.loan_account_status <> 2
group by cm.customer_group_id

/* New asset classification standard list */
insert into #temp_account_new_asset_classification
select 
	loan_account_id,
	asset_classification,
	1 new_asset_classfication -- make account standard as all recovery come

from	
	#temp_asset_classification_details
where
	customer_group_id
	in (
	
	select 
		customer_group_id
	from 
		#temp_customer_group_id_details
	where
		is_suitfile = 0  
		and limit_expiry_date > @taskDate
		and overdue_amount = 0	
		and npa_interest_amount = 0
		and npa_penal_interest_amount = 0
		and npa_charges_amount = 0
	)
	--and asset_classification = 3 -- only substandard account we can unmark to standard
	AND asset_classification IN (3,4,5,6) -- ALL NPA accounts marks as Standard on Full recovery



/* New asset classification d1 list */
INSERT INTO #temp_account_new_asset_classification
select 
	t.loan_account_id,
	asset_classification,
	4 new_asset_classification -- new_asset_classification is doubtfull -1
from
	#temp_asset_classification_details t
		left join #temp_account_new_asset_classification tt
			on t.loan_account_id = tt.loan_account_id
where
	asset_classification = 3 -- substandard-account where npa_doubtfull_asset_months_passed should be mark as doubtfull 1
	and dbo.FullMonthsSeparation(npa_mark_date,@taskDate) >= @doubtfull1AssetMonths
	and tt.loan_account_id is null



/* New asset classification d2 list */
INSERT INTO #temp_account_new_asset_classification
select 
	t.loan_account_id,
	asset_classification,
	5 new_asset_classification -- new_asset_classification is doubtfull -2
from
	#temp_asset_classification_details t
		left join #temp_account_new_asset_classification tt
			on t.loan_account_id = tt.loan_account_id
where
	asset_classification = 4 -- doubtful -1 -account where npa_doubtfull_asset_months_passed should be mark as doubtfull 2
	and dbo.FullMonthsSeparation(npa_mark_date,@taskDate) >= @doubtfull2AssetMonths
	and tt.loan_account_id is null


/* New asset classification d3 list */
INSERT INTO #temp_account_new_asset_classification
select 
	t.loan_account_id,
	asset_classification,
	6 new_asset_classification -- new_asset_classification is doubtfull -1
from
	#temp_asset_classification_details t
		left join #temp_account_new_asset_classification tt
			on t.loan_account_id = tt.loan_account_id
where
	asset_classification = 5 -- doubtful -2 -account where npa_doubtfull_asset_months_passed should be mark as doubtfull 3
	and dbo.FullMonthsSeparation(npa_mark_date,@taskDate) >= @doubtfull3AssetMonths
	and tt.loan_account_id is null
	 




select 
	loan_account_id loanAccountId, 
	old_asset_classification,  
	new_asset_classfication 
from 
	#temp_account_new_asset_classification
order by loan_account_id

END