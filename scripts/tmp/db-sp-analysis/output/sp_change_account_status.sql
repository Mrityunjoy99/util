CREATE   PROCEDURE [dbo].[sp_change_account_status] --  sp_change_account_status 1,24,7 
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
			ca.classification_id=@p_classification_id 
		and 
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
			ca.classification_id=@p_classification_id 
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

		--select * from #temp
		--return 

		       
--update bsgdeepfreeze..transaction_master_df
--set activity_id = 1003
--where @p_period > 24 
--        and  id in (
-- SELECT
--    max(tm.id) txn_date
--FROM
--    bsgdeepfreeze..transaction_master_df tm
--where 
-- tm.account_id  in (select t.account_id from #temp t)
--and  tm.narration like 'Interest Credit%'
--group by tm.account_id
-- );

		update BSGCORE..account_master
		set is_active=0
		where account_id in (select account_id from #temp)
		and 
			is_Active=1	

		insert into BSGCORE..account_master( branch_code
		,product_code
		,product_id
		,product_currency
		,account_id
		,customer_id
		,customer_category_id
		,account_name
		,account_type_id
		,operating_instruction_id
		,mode_of_operation_id
		,group_account_id
		,account_status_id
		,minor_flag
		,account_open_date
		,interest_tax_percentage
		,transaction_freeze_type_id
		,member_type_id
		,member_no
		,membership_reason
		,date_of_birth
		,date_of_establishment
		,relation_with_director_flag
		,director_id
		,director_relationship_id
		,operating_instruction_corp
		,sprinkle
		,is_active
		,created_by
		,created_date
		,last_modified_by
		,last_modified_date
		,authorization_status
		,capitalization_date
		,operating_mode
		,account_closure_date
		,is_staff
		,account_status_remarks)
		select branch_code
		,product_code
		,product_id
		,product_currency
		,account_id
		,customer_id
		,customer_category_id
		,account_name
		,account_type_id
		,operating_instruction_id
		,mode_of_operation_id
		,group_account_id
		,account_status_id
		,minor_flag
		,account_open_date
		,interest_tax_percentage
		,transaction_freeze_type_id
		,member_type_id
		,member_no
		,membership_reason
		,date_of_birth
		,date_of_establishment
		,relation_with_director_flag
		,director_id
		,director_relationship_id
		,operating_instruction_corp
		,sprinkle
		,is_active
		,-1 created_by
		,getdate() created_date
		,-1 last_modified_by
		,getdate() last_modified_date
		,authorization_status
		,capitalization_date
		,operating_mode
		,account_closure_date
		,is_staff
		,account_status_remarks from #temp
	

	--update  BSGCORE..casa_authorization_status
	--set is_active=0
	-- where table_name='account_master' and tab_name='basic_details' and principal_id in 
	--(select account_id from #temp) and is_active=1

	
update cas set cas.is_active=0 from BSGCORE..casa_authorization_status cas 
inner join #temp t
on cas.principal_id = t.account_id and cas.new_id=t.id
where cas.is_active=1 and cas.table_name='account_master' and cas.tab_name='basic_details'

	insert into BSGCORE..casa_authorization_status(principal_id
		,principal_type
		,original_id
		,new_id
		,tab_name
		,table_name
		,auth_status
		,created_by
		,created_date
		,last_modified_by
		,last_modified_date
		,is_active
		,branch_code)
	select  t.account_id,'A',t.id,am.id,'basic_details','account_master',1, -1 created_by,
	getdate(),-1 last_modified_by,getdate() last_modified_date,
	1,am.branch_code
	 from #temp t inner join 
		BSGCORE..account_master am 
		on 
			t.account_id = am.account_id
		and 
			am.is_active=1
	
	end
	else if (@p_classification_id = 4)
	begin
	;with cte as (select 
			ca.account_id,tm.maturity_date  txn_date
		from 
			bsgcore..customer_accounts ca with (nolock)
		inner join
			BSGTD..td_account_master am
		on 
			ca.account_id = am.td_account_id
		inner join 
			BSGTD..td_account_deposit_details tm with (nolock)
		on	
			ca.account_id = tm.td_account_id
		where 
			ca.classification_id=@p_classification_id 
		and 
			ca.is_active=1		
		and
			am.is_active=1
		and 			
			am.account_status_id not in ( 5,8)
		and 
			tm.is_active=1
		and 
			tm.maturity_date <= DATEADD(month,-1*@p_period,getdate())
		-- and 
			-- case when @p_period <= 24 then 1 else 0 end  = 1				
		)

		select distinct am.id
			,am.product_id
			,@p_status account_status_id
			,am.product_code
			,am.branch_code
			,am.td_account_id
			,am.customer_id
			,am.customer_name
			,am.customer_type
			,am.td_currency_code
			,am.td_amount
			,am.td_tenure_days
			,am.td_tenure_months
			,am.td_tenure_years
			,am.customer_profile
			,am.operating_instruction
			,am.age_group
			,am.account_open_date
			,am.maturity_amount
			,am.account_class
			,am.sprinkle
			,am.is_active
			,am.created_by
			,am.created_date
			,am.last_modified_by
			,am.last_modified_date
			,am.authorization_status
			,am.lien
			,am.lien_mark_date
			,am.lien_unmark_date
			,am.lien_remark
			,am.lien_loan_account_id
			,am.account_closure_date
			,am.staff_or_related
			,am.moved_to_maturity_gl
			--,am.temp_renewal_date
			,am.renew_count into #temp_td from cte c inner join 
			BSGTD..td_account_master am with (nolock)
			on 
				c.account_id = am.td_account_id
		where am.is_active=1 order by id desc; 

		update BSGTD..td_account_master
		set is_active=0
		where td_account_id in (select td_account_id from #temp_td)
		and 
			is_Active=1	


	insert into BSGTD..td_account_master(
		product_id
		,account_status_id
		,product_code
		,branch_code
		,td_account_id
		,customer_id
		,customer_name
		,customer_type
		,td_currency_code
		,td_amount
		,td_tenure_days
		,td_tenure_months
		,td_tenure_years
		,customer_profile
		,operating_instruction
		,age_group
		,account_open_date
		,maturity_amount
		,account_class
		,sprinkle
		,is_active
		,created_by
		,created_date
		,last_modified_by
		,last_modified_date
		,authorization_status
		,lien
		,lien_mark_date
		,lien_unmark_date
		,lien_remark
		,lien_loan_account_id
		,account_closure_date
		,staff_or_related
		,moved_to_maturity_gl
		--,temp_renewal_date
		,renew_count
	)
select product_id
		,account_status_id
		,product_code
		,branch_code
		,td_account_id
		,customer_id
		,customer_name
		,customer_type
		,td_currency_code
		,td_amount
		,td_tenure_days
		,td_tenure_months
		,td_tenure_years
		,customer_profile
		,operating_instruction
		,age_group
		,account_open_date
		,maturity_amount
		,account_class
		,sprinkle
		,is_active
		,-1 created_by
		,getdate() created_date
		,-1 last_modified_by
		,getdate() last_modified_date
		,authorization_status
		,lien
		,lien_mark_date
		,lien_unmark_date
		,lien_remark
		,lien_loan_account_id
		,account_closure_date
		,staff_or_related
		,moved_to_maturity_gl
		--,temp_renewal_date
		,renew_count 
	from
		 #temp_td
	
	update cas set cas.is_active=0 from BSGTD..td_authorization_status cas 
		inner join #temp_td t
		on cas.principal_id = t.td_account_id and cas.new_id=t.id
		where cas.is_active=1 and cas.table_name='td_account_master' and cas.tab_name='primary_applicant_details'
	
	insert into BSGTD..td_authorization_status(principal_id
		,principal_type
		,original_id
		,new_id
		,tab_name
		,table_name
		,auth_status
		,created_by
		,created_date
		,last_modified_by
		,last_modified_date
		,is_active
		,branch_code)
	select  t.td_account_id,'A',t.id,am.id,'primary_applicant_details','td_account_master',1,-1 created_by,
	getdate(),-1 last_modified_by,getdate() last_modified_date,
	1,am.branch_code
	 from #temp_td t inner join 
		BSGTD..td_account_master am 
		on 
			t.td_account_id = am.td_account_id
		and 
			am.is_active=1
	
	end
	
END



