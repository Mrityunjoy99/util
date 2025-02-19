
CREATE    PROCEDURE [dbo].[getActiveAccountsByMobileNo] -- getActiveAccountsByMobileNo '8730847627'  
(  
 @mobileNo VARCHAR(12)  
)  
AS  
BEGIN  

select  
 @mobileNo mobileNumber,  
 
  ca.account_no accountNumber,  
 cm.full_name accountName,  
 CASE WHEN ca.classification_id = 1 THEN 'CA'  
   when ca.classification_id =2  then 'SB'  
   when  classification_id=6 and (select is_secured from BSGLOAN..loan_product_master lpm with(nolock) where lpm.loan_product_id=isnull(am.product_id, 
                        lam.loan_product_id) and lpm.is_active=1) =1 then 'SOD'  
   when  classification_id=6 and (select is_secured from BSGLOAN..loan_product_master lpm with(nolock) where lpm.loan_product_id=isnull(am.product_id, 
                        lam.loan_product_id) and lpm.is_active=1 ) <>1 then 'UOD'  
   END accountType,  
 (select bm.ifsc_code from BSGMASTER..branch_master bm with(nolock) where bm.branch_code=ca.branch_code and is_active=1)   accountIfsc,  
 ISNULL((select replace(aadhar_no,',','') from BSGCRM..customer_ind_info cii with(nolock)  where cii.customer_id = ca.customer_id and cii.is_active=1) ,'') 
 accountAadhar,
--(select top 1 customer_id from #temp_customerId)   
(select top 1  customer_id  from BSGCRM..customer_master with(nolock)  where registered_mobile_no=@mobileNo and is_active=1) 
 customerId, -- onbank mail  
isnull((SELECT top 1 mmid from bsgcore..account_mmid with(nolock) WHERE account_id=ca.account_id and is_active = 1),'9773001') mmid  
 from   
 bsgcrm..customer_master cm  with (nolock)  
  inner join bsgcore..customer_accounts ca with (nolock)
        ON cm.customer_id = ca.customer_id
            AND cm.is_active = 1
			and ca.is_active=1
        left JOIN bsgcore..account_master am with (nolock)  ON ca.account_id = am.account_id
            AND am.is_active = 1
        left JOIN bsgloan..loan_account_master lam with (nolock)  ON ca.account_id = lam.loan_account_id
		-- and classification_id = 6
            AND lam.is_active = 1
  where   
  cm.registered_mobile_no = @mobileNo 
  --and 
  --exists  (select customer_id  from BSGCRM..customer_master a with(nolock)  
  --where registered_mobile_no=@mobileNo and a.customer_id=cm.customer_id and is_active=1)  
and   
 isnull(isnull(am.account_status_id,                                
                        lam.loan_account_status),
                1)=1   
and   
 ca.classification_id in (1,2,6)  

END  
