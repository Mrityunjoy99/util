CREATE  procedure [dbo].[sp_getAccountDetails_UPI] --sp_getAccountDetails_UPI @accountNo='001001005016645',@panNo='N/A'
@accountNo nvarchar(50),
@panNo nvarchar(12)
as 
begin
set @panNo = 'N/A'
declare @classification_id int 
declare @account_id bigint
select *,
 case when   exists (select 1 from BSGCRM..customer_ind_info cii with(nolock)
 where  cii.customer_id = a.customer_id and cii.is_active=1 --and cii.pan_no = @panNo
 ) then 'PRIMARY' 
 else 'SECONDARY' end accountHolder
 from (
select
ca.customer_id,
 @accountNo --ca.account_no
 accountNumber,
 cm.full_name accountName,
 CASE WHEN ca.classification_id = 1 THEN 'CA'
	  when ca.classification_id =2  then 'SB'
	  when  classification_id=6 and (select is_secured from BSGLOAN..loan_product_master lpm with(nolock) where lpm.loan_product_id=lam.loan_product_id and lpm.is_active=1 ) =1 then 'SOD'
	  when  classification_id=6 and (select is_secured from BSGLOAN..loan_product_master lpm with(nolock) where lpm.loan_product_id=lam.loan_product_id and lpm.is_active=1 ) <>1 then 'UOD'
	  END accountType,
bm.ifsc_code accountIfsc, 
 case when classification_id in (1,2) and exists (select  1 from BSGCORE..account_jointmaster aj with(nolock)  where  aj.account_id = ca.account_id and is_active=1 ) then 'JOINT'
	  when 	classification_id in (6) and exists (select  1 from BSGLOAN..loan_account_jointmaster aj with(nolock)  where  aj.loan_account_id = ca.account_id and is_active=1 ) then 'JOINT'
	  else 'SINGLE' end  accountNature
,cm.registered_mobile_no

 , --@panNo 
 (select pan_no from BSGCRM..customer_ind_info cii with(nolock)
 where  cii.customer_id = cm.customer_id and cii.is_active=1 )panNo
 ,
 case when ca.classification_id in (1,2) and am.account_status_id in (1) then 'A'
		when ca.classification_id in (1,2) and am.account_status_id in (4) then 'C'
      when ca.classification_id in (6) and loan_account_status in (1) then 'A'
	 when ca.classification_id in (6) and loan_account_status in (2) then 'C'
	 else 'B' end accountStatus

 from BSGCRM..customer_master cm with(nolock)
inner join
	bsgcore..customer_accounts ca with(nolock)
on
	cm.customer_id = ca.customer_id
and
	cm.is_active=1
and
	ca.is_active=1
inner join
	BSGMASTER..branch_master bm with(nolock)
on
	ca.branch_code = bm.branch_code
and
	bm.is_active=1
 
left outer join
	bsgcore..account_master am with(nolock)
on
	ca.account_id = am.account_id
and
	ca.customer_id=am.customer_id
and
	am.is_active=1
left outer join
	BSGLOAN..loan_account_master lam with(nolock)
on
	ca.account_id = lam.loan_account_id
and
	ca.customer_id = lam.customer_no
and
	lam.is_active=1
where ca.account_no = cast(@accountNo as bigint)
and
	ca.classification_id in (1,2,6)
 )a
 where case when accountNature = 'SINGLE' and not exists (select 1 from BSGCRM..customer_ind_info cii  with(nolock)
 where  cii.customer_id = a.customer_id and cii.is_active=1 
 --and cii.pan_no = @panNo
 ) then 0 else 1 end = 1
end 

--select * from bsgcore..customer_accounts  where customer_id=510572 and classification_id in (1,2,6)

---- 1002005002718	1510
--select * from bsgcrm..customer_ind_info  where pan_no = 'AAZPN9193N'

---- AAZPN9193N

--sp_getAccountDetails_UPI '1005037000097','AAZPN9193N'

--select 2668,AHCPP9924D