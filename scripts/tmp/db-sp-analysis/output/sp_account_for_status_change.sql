


-- =============================================
-- Author:		<Author,,gourav>
-- Create date: <Create Date,,2018-10-03>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_account_for_status_change] --  sp_account_for_change__status 1,24,1 
@p_classification_id int,
@p_period int, -- month
@p_status int
AS
BEGIN
if(@p_classification_id  in (1, 2))
	begin

		select 
			ca.account_id,max(txn_date)  txn_date into #temp_tr
		from 
			bsgcore..customer_accounts ca with (nolock)
		inner join
			BSGCORE..account_master am
		on 
			ca.account_id = am.account_id
		left join 
			BSGACCOUNTING..transaction_master tm with (nolock)
		on	
			ca.account_id = tm.account_id
		and 
			activity_id not in (11081,11067,11069,11065,11063,11071,11073,11113,1003,1004)
		and
			tm.narration not like '%int%'
		and
			tm.narration not like '%charge%'
		and
			tm.narration not like '%CHRGS%'
		where 
			ca.is_active=1

		and 
			am.account_open_date < DATEADD(month,-1*@p_period,getdate())
		
		and
			am.is_active=1
		and 
			case when @p_period <= 24 and 
				  am.account_status_id not in (3,5,4,7,8)
				then 1 
				when @p_period > 24 and am.account_status_id = 7
				then 1 end  = 1 		 
		group by ca.account_id
		having (max(txn_date) is null or max(txn_date) < DATEADD(month,-1*@p_period,getdate()))


		select 
			ca.account_id,max(tm.txn_date)  txn_date into #temp_df
		from 
			#temp_tr ca
		inner join 
			bsgdeepfreeze..transaction_master_df tm with (nolock)
		on	
			ca.account_id = tm.account_id		
		where 			
			activity_id not in (11081,11067,11069,11065,11063,11071,11073,11113,1003,1004)		
		and
			tm.narration not like '%int%'
		and
			tm.narration not like '%charge%'
		and
			tm.narration not like '%CHRGS%'
		group by ca.account_id
		having ( max(tm.txn_date) >= DATEADD(month,-1*@p_period,getdate()))

		--select * into #tempdftr from #temp_tr where account_id not in (select account_id from #temp_df)

		delete #temp_tr where account_id in (select account_id from #temp_df)

		select 
			ca.account_id,alt.LastTranDate  txn_date into #temp_acclast
		from 
			bsgcore..customer_accounts ca with (nolock)
		inner join
			#temp_tr am
		on 
			ca.account_id = am.account_id
		left join 
			BSGTURINGREPORTS..accountlasttransaction alt
		on 
			ca.account_no = alt.AccountNo
		where 
			am.txn_date is null
		and 
			ca.is_active=1		 		
		and 
			alt.LastTranDate >=  DATEADD(month,-1*@p_period,getdate())
		and 
			case when @p_period > 24 then 1 else 0 end  = 1


		;with cte as (
		select * from #temp_tr
		where  
			account_id not in (
			select tr.account_id from #temp_acclast tr		 	
			)
		
			
		)


		
		select distinct  --top 5
				 am.id,am.branch_code
				,am.product_code
				,am.product_id
				,am.product_currency
				,am.account_id
				,am.customer_id
				,am.customer_category_id
				,am.account_name
				,am.account_type_id
				,am.operating_instruction_id
				,am.mode_of_operation_id
				,am.group_account_id
				,@p_status account_status_id
				,am.minor_flag
				,am.account_open_date
				,am.interest_tax_percentage
				,am.transaction_freeze_type_id
				,am.member_type_id
				,am.member_no
				,am.membership_reason
				,am.date_of_birth
				,am.date_of_establishment
				,am.relation_with_director_flag
				,am.director_id
				,am.director_relationship_id
				,am.operating_instruction_corp
				,am.sprinkle
				,am.is_active
				,am.created_by
				,am.created_date
				,am.last_modified_by
				,am.last_modified_date
				,am.authorization_status
				,am.capitalization_date
				,am.operating_mode
				,am.account_closure_date
				,am.is_staff
				,am.account_status_remarks into #temp from cte c inner join 
			BSGCORE..account_master am with (nolock)
			on 
				c.account_id = am.account_id
		where am.is_active=1 order by id desc; 

		select * from #temp
		
end

	
END



