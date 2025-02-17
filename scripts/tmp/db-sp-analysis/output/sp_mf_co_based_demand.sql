-- =============================================
-- Author:		<Author,Akhil Chandran>
-- Create date: <Create Date,2022-12-12>
-- Description:	<Description,MF-CO-BASED-DEMAND-DETAILS>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_mf_co_based_demand]  -- sp_mf_co_based_demand 
@branchCode int = 0 ,
@summaryOrDetail int = 0, -- 0 = summary , 1 - detailed , -1 -- insertinDemandtable
@page int = 1,
@size int = 50
AS
BEGIN
	SET NOCOUNT ON;
declare @demandDate date =  (select dateadd(day,-1,cast(app_date as date)) from BSGACCOUNTING..cbs_application_date where is_active = 1)

	declare @fromrnum int = case when @page = 1 then 1 else (@page-1)*@size end
	declare @tornum int = case when @page = 1 then @size else @size * @page end
		
		if(@summaryOrDetail = 0) -- summary
		begin
			DROP TABLE if exists #finalMFAccountData;
			select account_id loan_account_id,0 installmentno,sum(collection_amt) collection_amt,ROW_NUMBER()over(order by account_id) rnum
			into #finalMFAccountData
			from BSGLOAN..co_based_demand_details
			where status = 1 and is_active = 1 and cast(app_date as date) = cast(@demandDate as date)
			group by account_id

			select a.*,b.ref_id,c.co_id,d.co_name,c.village_id,e.village_name,c.center_id,f.center_name,c.group_id,g.group_name,
			collection_day,collection_week
			from #finalMFAccountData a
			inner join bsgloan..loan_account_master lam
			on
				a.loan_account_id = lam.loan_account_id
			inner join bsgloan..loan_micro_finance_master b
			on	
				a.loan_account_id = b.loan_account_id
			inner join bsgloan..co_group_mapping c
			on
				b.ref_id = c.ref_id
			left outer join bsgloan..collection_officer_master d
			on	
				c.co_id = d.co_id
			and
				d.is_active = 1
			left outer join bsgloan..village_master e
			on
				c.village_id = e.village_id
			and
				e.is_active = 1
			left outer join bsgloan..center_master f
			on
				c.center_id = f.center_id
			and
				f.is_active = 1
			left outer join bsgloan..loan_group_master g
			on
				c.group_id = g.group_id
			and
				g.is_active = 1	
			where 
				b.is_active = 1 and c.is_active = 1  and c.status = 1 and lam.is_active = 1
				and rnum > @fromrnum and rnum <= @tornum
		end
		else if(@summaryOrDetail = 1) -- @summaryOrDetail = 1 -- detailed
		begin
		
			select account_id loan_account_id,0 installmentno
			from BSGLOAN..co_based_demand_details cbdd
			inner join bsgloan..loan_account_master lam
			on
				cbdd.account_id = lam.loan_account_id
			inner join bsgaccounting..loan_repayment_chart lrc
			on
				cbdd.account_id = lrc.loan_account_id
			and
				cbdd.installment_no = lrc.installment_no 		
			and
				lrc.id = (select max(id) from BSGACCOUNTING..loan_repayment_chart a where a.loan_account_id = cbdd.account_id and
				a.installment_no = lrc.installment_no ) 
			where 
				cbdd.status = 1 
			and 
				cbdd.is_active = 1 
			and 
				cast(cbdd.app_date as date) = cast(@demandDate as date)
			and
				lam.is_active = 1
			and
				lrc.is_active = 1

		end
		else if(@summaryOrDetail = -1) -- @summaryOrDetail = 1 -- insert activity
		begin
		
			declare @hoBranchCode varchar(10) = (select config_value from BSGADMIN..cbs_config where config_key = 'HO_BRANCH_ID');

			set @branchCode = case 
				when cast(@hoBranchCode as int) = @branchCode then null 
				else @branchCode end;
			
			set @demandDate = case 
				when  @demandDate is null then (select app_date from BSGACCOUNTING..cbs_application_date where is_active = 1) 
				else @demandDate end;

			declare @microFinanceProduct varchar(20) = null;
			set @microFinanceProduct = (select config_value from BSGADMIN..cbs_config where config_key = 'MICROFINANCE_PRODUCT');
		
			IF OBJECT_ID(N'tempdb..#tempMFProduct') IS NOT NULL
				DROP TABLE #tempMFProduct; 
		
			create table #tempMFProduct(
			productCode int,
			productDescription varchar(100)
			)
			insert into #tempMFProduct
			select productcode,product_description
			from (
			SELECT t.c.value('.', 'VARCHAR(100)') productcode
			                    FROM (
			                            SELECT x = CAST('<t>' + 
			                                REPLACE(@microFinanceProduct , ',', '</t><t>') + '</t>' AS XML)
			                         ) a
			                    CROSS APPLY x.nodes('/t') t(c) 
			) a
			inner join bsgcore..product_master pam
			on
				a.productcode = pam.product_code
			and
				pam.classification_id in (3)
			and
				pam.is_active = 1
			and
				pam.branch_code  = @hoBranchCode
			
			--select * from #tempMFProduct
			
			IF OBJECT_ID('tempdb..#tempMFAccounts') IS NOT NULL
			  DROP TABLE #tempMFAccounts; 
			
			select a.loan_account_no,lrc.loan_account_id,account_name,lrc.installment_no,lrc.installment_amount,
				isnull(lrc.principal_amount,0) principal_amount,isnull(lrc.principal_received,0) principal_rec,
				isnull(lrc.interest_amount,0) interest_amount,isnull(lrc.interest_received,0) interest_received,
				isnull(lrc.od_int_accrual,0) od_int_accrual,isnull(lrc.penal_int_accrual,0) penal_int_accrual,isnull(lrc.overdue_amount,0) overdue_amount,
				isnull(lrc.overdue_days_count,0) overdue_days_count
			into #tempMFAccounts 
			from BSGACCOUNTING..loan_repayment_chart lrc
			inner join (select a.loan_account_id , a.installment_no , max(a.id) id from BSGACCOUNTING..loan_repayment_chart a where a.is_active = 1 and
				a.due_date <= @demandDate group by a.loan_account_id,a.installment_no) lrc1
			on	
				lrc.loan_account_id = lrc1.loan_account_id
			and
				lrc.installment_no = lrc1.installment_no
			inner join bsgloan..loan_account_master a
			on
				lrc.loan_account_id = a.loan_account_id
			inner join #tempMFProduct tmp
			on
				a.loan_product_code = tmp.productCode
			
			where
				lrc.is_active = 1 
			and
				lrc.full_installment_received = 0
			and
				(@branchCode is null or a.branch_code = @branchCode)
			and
				a.loan_account_status <> 2
			
			end
		
END
