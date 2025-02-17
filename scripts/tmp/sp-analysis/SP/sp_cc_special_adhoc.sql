CREATE   PROCEDURE [dbo].[sp_cc_special_adhoc]  -- sp_cc_special_adhoc '2020-03-31','2020-03-31','2020-04-30'
	@txn_date varchar(500), -- Comma seprated Date for which interest need to calculate
	@balance_date DATE, -- Balance Date
	@adhoc_expire_date Date, -- Adhoc Where Expire
	@adhoc_reason varchar(200) = 'INTEREST ADHOC' -- Adhoc Reason
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @CurrentDate Date = (select app_date from BSGACCOUNTING..cbs_application_date where is_active = 1)

	

	Select 
		*
	INTO 
		#Temp_TransactionDate
	FROM
		BSGTURINGREPORTS.dbo.SplitString(@txn_date,',')


	DECLARE @txnMinDate Date = (select MIN(cast(Item as date)) from #Temp_TransactionDate)

 IF((select count(1) from #Temp_TransactionDate) > 0)
 BEGIN
    insert into bsgloan..loan_limit_adhoc_details
	select 
		account_id,
		@balance_date,
		0,
		DATEDIFF(D,@balance_date,CASE WHEN @adhoc_expire_date < cast(y.limit_expiry_date as date) THEN  @adhoc_expire_date ELSE cast(y.limit_expiry_date as date) END),
		CASE WHEN @adhoc_expire_date < cast(y.limit_expiry_date as date) THEN  @adhoc_expire_date ELSE cast(y.limit_expiry_date as date) END,
		int_amount,
		ISNULL(y.rate_of_interest,0) + ISNULL(y.offset,0) Rate,
		@adhoc_reason,
		 'NA',
		 1,
		 -555,
		 @CurrentDate,
		 -555,
		 @CurrentDate,
		 'A'  
	from
	(select 
		account_id,
		sum(interest_amount)int_amount 
	from 
		BSGACCOUNTING..interest_details 
	where 
		txn_date in (select cast(Item as date) from #Temp_TransactionDate)
		and activity_id=6003 
	group by 
		account_id
	)x
	inner join
	(select 
		* 
	from 
		bsgloan..loan_account_basic 
	where 
		is_active=1
	)y
	on x.account_id=y.loan_account_id
	inner join
	BSGACCOUNTING..account_balance_loan a
	on a.loan_account_id=x.account_id 
		and a.txn_date=@balance_date 
		and a.available_dp>0 
		and a.sanction_limit>0
	inner join bsgloan..loan_account_master c
		on a.loan_account_id=c.loan_account_id 
			and c.is_active=1 
			and c.asset_classification<3
			and c.loan_type = 2
			and a.loan_account_id 
			not in (select 
						loan_account_id 
					from 
						bsgloan..loan_limit_adhoc_details 
					where 
						is_active=1 
						and adhoc_expiry_date> @CurrentDate
					)
			and cast(y.limit_expiry_date as date) > @CurrentDate;

	update a 
	set 
		a.adhoc_amount=ISNULL(a.adhoc_amount,0)+b.int_amount,
		a.available_balance=ISNULL(a.available_balance,0)+b.int_amount,
		a.available_dp=ISNULL(a.available_dp,0)+ISNULL(b.int_amount,0) 
	from
		BSGACCOUNTING..account_balance_loan a

		inner join
		(select account_id,
			ISNULL(sum(interest_amount),0) int_amount 
		from 
			BSGACCOUNTING..interest_details 
		where 
			txn_date in (select cast(Item as date) from #Temp_TransactionDate)
			and activity_id=6003 
		group by 
			account_id 
		)b
	on
	a.loan_account_id=b.account_id 
		and a.txn_date=@balance_date 
		and a.available_dp>0 
		and a.sanction_limit>0
	inner join
	(select 
		* 
	from 
		bsgloan..loan_account_basic 
	where 
		is_active=1
	)y
	on b.account_id=y.loan_account_id
	inner join bsgloan..loan_account_master c
		on a.loan_account_id=c.loan_account_id 
		and c.is_active=1 
		and c.asset_classification<3 
		and c.loan_type = 2
		and a.loan_account_id 
		not in (
				select 
					loan_account_id 
				from 
					bsgloan..loan_limit_adhoc_details 
				where 
					is_active=1 
					and adhoc_expiry_date> @CurrentDate
					and created_by>0
				)
		and cast(y.limit_expiry_date as date) > @CurrentDate;

	update a 
	set a.is_Active=0 
	from
	bsgloan..loan_limit_adhoc_details a
	inner join
	(select 
		loan_account_id,
		max(id)maxid 
	from 
		bsgloan..loan_limit_adhoc_details 
	where 
		is_active=1 
	group by 
		loan_account_id
	)b
	on a.loan_account_id=b.loan_account_id 
		and a.is_active=1 
		and a.id<>b.maxid;

	update 
		bsgloan..loan_authorization_status 
	set 
		is_active=0  
	where 
		table_name='loan_limit_adhoc_details';

	insert into bsgloan..loan_authorization_status
	select 
		loan_account_id,
		'A',
		-1,
		id,
		'loan_adhoc_details',
		'loan_limit_adhoc_details',
		1,
		'A',
		-1,
		CURRENT_TIMESTAMP,
		-1,
		CURRENT_TIMESTAMP,
		1,
		-1 
	from 
		bsgloan..loan_limit_adhoc_details 
	where 
		is_active=1;

	update 
		BSGACCOUNTING..account_balance_loan 
	set 
		available_dp=ISNULL(sanction_limit,0)+ISNULL(adhoc_amount,0),
		available_balance=ISNULL(sanction_limit,0)+ISNULL(adhoc_amount,0)+ISNULL(checker_clear_balance ,0)
	 where 
		txn_date=@balance_date 
		and ISNULL(adhoc_amount,0)>0 
		and ISNULL(available_dp,0)>ISNULL(sanction_limit,0)+ISNULL(adhoc_amount,0);
 END
END
