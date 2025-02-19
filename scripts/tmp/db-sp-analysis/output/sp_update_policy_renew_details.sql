



--drop table #TEMP_POLICYRENEW
-- =============================================  
-- Author:  <Author,,Name>  
-- Create date: <Create Date,,>  
-- Description: To get Pm scheme policy renew details for transaction  
-- sp_get_policy_renew_details  759
-- =============================================  
CREATE   PROCEDURE [dbo].[sp_update_policy_renew_details]  
   @fileId INT
AS  
BEGIN  

 Declare @cbsAppDate date = (select app_date from BSGACCOUNTING..cbs_application_date WITH(NOLOCK) where is_active = 1);
 
 create table #TEMP_POLICYRENEW  
(id bigint,policy_no varchar(50),account_no varchar(30), account_id int,account_Status INT,   
 branch_code int, product_id int, total_amount decimal(18,2),is_processed int,available_balance decimal(18,2), lien_amount decimal(18,2),premium_amount decimal(18,2),  
 commission_amount decimal(18,2),txn_date varchar(20), premium_principal_id varchar(20),commission_principal_id varchar(20),file_id Int, premium_account_id bigint, premium_product_id bigint,
 commission_account_id bigint, commission_product_id bigint)  
   

 Insert into #TEMP_POLICYRENEW  
   select ROW_NUMBER() OVER(partition by t2.account_no order by total_amount) Rownum,policy_no,t2.account_no,t2.account_id,account_Status,
		t2.branch_code,
		t3.product_id,
		total_amount,is_processed,
   (select available_balance from BSGACCOUNTING..account_balance with (nolock) where account_id=t2.account_id  and txn_date = (  
		select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=t2.account_id  
   )) available_balance,  
    (select lien_amount from BSGACCOUNTING..account_balance with (nolock) where account_id=t2.account_id  and txn_date = (  
		select max(txn_date) from BSGACCOUNTING..account_balance with (nolock) where account_id=t2.account_id  
   )) lien_amount,
   premium_amount,commission_amount,txn_date,premium_principal_id,commission_principal_id,file_id,
		premium_account_id,premium_product_id,commission_account_id,commission_product_id
  from 
	  BSGACCOUNTING..policy_renewal_details t1  
	  inner join BSGCORE..customer_accounts t2 on t1.account_no = t2.account_no
	  inner join BSGCORE..account_master t3 on t2.account_id = t3.account_id and t3.is_active=1
  where 
	is_processed  = 0 and t1.file_id = @fileId and t2.is_active = 1  and t3.account_status_id in (1,2); 
  --select * from BSGACCOUNTING..policy_renewal_details  where file_id = @fileId
  -- drop table #TEMP_POLICYRENEW
 
 
	update #TEMP_POLICYRENEW set available_balance = (available_balance - lien_amount)  
   
	 update t1   
	 set t1.available_balance -=  ISNULL((  
			  select   
			   SUM(total_amount)  
			  from  
				#TEMP_POLICYRENEW tp  
			  Where  
			   tp.account_id = t1.account_id  
				and tp.id < t1.id  
   
			),0)  
	 from #TEMP_POLICYRENEW t1  
     
	   Where  
		t1.id > 1  

		 --select * from  #TEMP_POLICYRENEW
	 delete from BSGACCOUNTING..policy_renewal_details where policy_no in (select policy_no from #TEMP_POLICYRENEW )  and file_id =  @fileId
	 insert into BSGACCOUNTING..policy_renewal_details 
	 select  txn_date,file_id,policy_no,account_no,account_id,account_Status,product_id,total_amount,premium_amount,
			 commission_amount,available_balance,is_processed,branch_code,premium_principal_id,commission_principal_id,premium_account_id,
			 premium_product_id,commission_account_id,commission_product_id from #TEMP_POLICYRENEW;
   
	Declare @premiumPrincipalId varchar(20);
	Declare @premiumAccountId varchar(20);
	Declare @premiumProductId varchar(20);
	Declare @comissionAccountId varchar(20);
	Declare @comissionProductId varchar(20);
	Declare @premiumCommissionId varchar(20);
	DECLARE @hoBranchCode VARCHAR(20) = (SELECT config_value FROM BSGADMIN..cbs_config WITH(NOLOCK) where config_key = 'HO_BRANCH_ID' and is_active=1)
 
 select top 1 @premiumCommissionId = commission_principal_id, @premiumPrincipalId =premium_principal_id from BSGACCOUNTING..policy_renewal_details where file_id = @fileId
   --set @premiumCommissionId = (select top 1 commission_principal_id from BSGACCOUNTING..policy_renewal_details where file_id = @fileId )
   --set @premiumPrincipalId = (select top 1 premium_principal_id from BSGACCOUNTING..policy_renewal_details where file_id = @fileId )

  
	if (len(@premiumPrincipalId) > 8)
	   begin
		   select @premiumAccountId  =account_id,@premiumProductId =product_id from BSGACCOUNTING..customer_view with(NOLOCK) where account_no = @premiumPrincipalId
		   --set = (select product_id from BSGACCOUNTING..customer_view with(NOLOCK) where account_no = @premiumPrincipalId)
	end

	else if (len(@premiumPrincipalId) <= 8)
	   begin 
		   set @premiumProductId =  (select top 1 internal_product_id from BSGCORE..product_master_internal with(NOLOCK) 
		   where product_code = RIGHT(@premiumPrincipalId,4) and is_active =1 AND branch_code=@hoBranchCode);
		   set @premiumAccountId = '-1'
	end

	   update BSGACCOUNTING..policy_renewal_details set premium_account_id = @premiumAccountId, premium_product_id = @premiumProductId   where  file_id = @fileId
 
	if (len(@premiumCommissionId) > 8)
	   begin
			select @comissionAccountId = account_id,@comissionProductId =product_id from BSGACCOUNTING..customer_view with(NOLOCK) where account_no = @premiumCommissionId
		   --set @comissionAccountId = (select account_id from BSGACCOUNTING..customer_view with(NOLOCK) where account_no = @premiumCommissionId)
		   --set @comissionProductId = (select product_id from BSGACCOUNTING..customer_view with(NOLOCK) where account_no = @premiumCommissionId)
	   end

	  else if (len(@premiumCommissionId) <= 8)
	   begin 
			set @comissionProductId = (select top 1 internal_product_id from BSGCORE..product_master_internal with(NOLOCK) 
			where product_code = RIGHT(@premiumCommissionId,4) and is_active = 1 AND branch_code=@hoBranchCode)
			set @comissionAccountId = '-1'
	   end
	   update BSGACCOUNTING..policy_renewal_details set commission_account_id = @comissionAccountId ,commission_product_id = @comissionProductId where  file_id = @fileId
   
    update prd
	set prd.account_id = am.account_id,prd.account_Status = am.account_status_id
	from BSGACCOUNTING..policy_renewal_details prd
	inner join BSGCORE..customer_accounts ca on prd.account_no = ca.account_no and ca.is_active = 1 
	inner join BSGCORE..account_master am on ca.account_id = am.account_id
	and am.account_status_id not in (1,2) and am.is_active=1 
	where is_processed = 0 and prd.file_id = @fileId;

  exec sp_insert_casa_balances_policy_renew_accounts @cbsAppDate,@fileId;
  
END  


