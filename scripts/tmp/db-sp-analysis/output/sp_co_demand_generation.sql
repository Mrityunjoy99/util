-- =============================================
-- Author:		<Author,Akhil Chandran>
-- Create date: <Create Date,2022-11-25>
-- Description:	<Description,CO BASED COLLECTION DETAILS>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_co_demand_generation] --[sp_co_demand_generation] 96,'2022-04-27'
@branchCode bigint = null,
@duedate date = null
AS
BEGIN
	SET NOCOUNT ON;
	declare @cbsAppDate datetime = cast((select app_date from BSGACCOUNTING..cbs_application_date where is_active = 1) as datetime);
	set @cbsAppDate = @duedate;
	declare @microFinanceProduct varchar(50) = (select config_value from BSGADMIN..cbs_config where config_key = 'MICROFINANCE_PRODUCT' and is_active = 1)

    drop table if exists #productlistforMicroFinance
    select * 
    into #productlistforMicroFinance
    from (
        SELECT t.c.value('.', 'VARCHAR(100)') productcode
                    FROM (
                            SELECT x = CAST('<t>' + 
                                REPLACE(@microFinanceProduct , ',', '</t><t>') + '</t>' AS XML)
                         ) a
                    CROSS APPLY x.nodes('/t') t(c) 
    ) a

	--select * 
	--from #productlistforMicroFinance


	selecT lrc.*,lam.branch_code,lam.loan_account_no,lam.loan_product_code
	into #templrc
	from BSGACCOUNTING..loan_repayment_chart lrc
	inner join (Select loan_Account_id,installment_no,max(id) id 
		from BSGACCOUNTING..loan_repayment_chart lrc where is_active = 1 and due_date <= @cbsAppDate 
	group by loan_account_id,installment_no) lrc1
	on
		lrc.loan_account_id= lrc1.loan_account_id
	and
		lrc.installment_no = lrc1.installment_no
	and
		lrc.id = lrc1.id
	inner join bsgloan..loan_account_master lam
	on
		lrc.loan_account_id = lam.loan_account_id
	and
		lam.loan_account_status <> 2
	and
		lam.is_active = 1
	inner join #productlistforMicroFinance prd
	on
		lam.loan_product_code = prd.productcode
	where full_installment_received <> 1 and lrc.is_active = 1 


	
	
	drop table if exists #tempCoGroupMapping
	select a.id,a.co_id,a.center_id,a.group_id,a.branch_code,a.collection_day,a.collection_week, 
		a.status,a.is_active,a.created_by,a.created_date,a.last_modified_by,a.last_modified_date,a.authorization_status,a.ref_id
		,a.village_id,cm.center_name,vm.village_name,co.co_name,gm.group_name 
	into #tempCoGroupMapping
	from bsgloan..co_group_mapping a with(nolock)  
	inner join bsgloan..center_master cm with(nolock) 
	on  
		a.village_id = cm.village_id  
	and  
		a.center_id = cm.center_id  
	and  
		a.co_id = cm.co_id  
	and  
		a.status = 1 and cm.status = 1  
	inner join bsgloan..village_master vm with(nolock)  
	on  
		a.village_id = vm.village_id  
	and  
		a.branch_code = vm.branch_code  
	and  
		vm.status = 1  
	inner join bsgloan..collection_officer_master co  
	on  
		a.co_id = co.co_id  
	and  
		co.status = 1  
	inner join bsgloan..loan_group_master gm  
	on  
		a.group_id = gm.group_id  
	and  
		gm.status = 1  
	where cm.is_active = 1 and vm.is_active = 1 and co.is_active = 1 and gm.is_active = 1 
	
	--select * from bsgloan..co_based_demand_details


	update bsgloan..co_based_demand_details set status = 0 where status = 1 and is_active = 1
	--select * 
	--from bsgloan..co_based_demand_details
	insert into bsgloan..co_based_demand_details
	select 
	lrc.loan_account_id account_id,
	@cbsAppDate app_date,
	due_date due_date,
	installment_no installment_no,
	((principal_amount - principal_received) + (interest_amount - interest_received) + (od_int_accrual) + (penal_int_accrual)) collectionamt,
	tmp.ref_id group_mapping_ref_id,
	1 status,
	1 is_active,
	-190 created_by,
	getdate() created_date,
	-190 last_modified_by,
	getdate() last_modified_date,
	'A' authorization_status
	from #templrc lrc
	inner join bsgloan..loan_micro_finance_master lmf
	on
		lrc.loan_account_id = lmf.loan_account_id
	and
		lmf.is_active = 1
	inner join #tempCoGroupMapping tmp
	on
		lmf.co_id = tmp.co_id
	and
		lmf.center_id = tmp.center_id
	and
		lmf.group_id = tmp.group_id
	and
		lmf.village_id = tmp.village_id
	where (@branchCode is null or lrc.branch_code = @branchCode)

	select * 
	from bsgloan..co_based_demand_details
	where status = 1 and is_active = 1

END
