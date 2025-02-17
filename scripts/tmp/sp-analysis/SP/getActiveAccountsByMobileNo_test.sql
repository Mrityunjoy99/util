
CREATE    PROCEDURE [dbo].[getActiveAccountsByMobileNo_test] -- [getActiveAccountsByMobileNo_test] '7896701174'  
(  
 @mobileNo VARCHAR(12)  
)  
AS  
BEGIN  

-- select customer_id into #temp_customerId from BSGCRM..customer_master with(nolock)  where registered_mobile_no=@mobileNo and is_active=1
  
--select * from (  
select  
 @mobileNo mobileNumber,  
 --right('0000'+cv.account_no,15) 
  cv.account_no accountNumber,  
 cv.full_name accountName,  
 --CASE WHEN cv.classification_id = 1 THEN 'CA'  
 --  when cv.classification_id =2  then 'SB'  
 --  when  classification_id=6 and (select is_secured from BSGLOAN..loan_product_master lpm with(nolock) where lpm.loan_product_id=cv.product_id and lpm.is_active=1 ) =1 then 'SOD'  
 --  when  classification_id=6 and (select is_secured from BSGLOAN..loan_product_master lpm with(nolock) where lpm.loan_product_id=cv.product_id and lpm.is_active=1 ) <>1 then 'UOD'  
 --  END accountType,  
-- (select bm.ifsc_code from BSGMASTER..branch_master bm with(nolock) where bm.branch_code=cv.branch_code and is_active=1)   accountIfsc,  
-- ISNULL((select replace(aadhar_no,',','') from BSGCRM..customer_ind_info cii with(nolock)  where cii.customer_id = cv.customer_id and cii.is_active=1) ,'') 
'' accountAadhar
--(select top 1 customer_id from #temp_customerId)   
--(select top 1  customer_id  from BSGCRM..customer_master with(nolock)  where registered_mobile_no=@mobileNo and is_active=1) 
--customerId, -- onbank mail  
--(SELECT top 1 mmid from bsgcore..account_mmid with(nolock) WHERE account_id=cv.account_id and is_active = 1) mmid  
 from   
 bsgaccounting..[customer_view] cv  
  where   
 cv.customer_id in  (181000378878)  
and   
 cv.account_status_id=1   
and   
 cv.classification_id in (1,2,6)  
END  
