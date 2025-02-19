-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
create    PROCEDURE [dbo].[sp_get_interest_recovery_amount] -- sp_get_interest_recovery_amount 10489958

@accountId bigint
AS
BEGIN

	DECLARE @cbsApplicationDate datetime = (select app_date from BSGACCOUNTING..cbs_application_date where is_active=1);
	DECLARE @modifiedby int = -1;
	DECLARE @accountOpenDate datetime = (select TOP 1 disbursement_date from bsgloan..loan_account_basic where is_Active=1 and loan_account_id=@accountId order by id desc); 
	DECLARE @minMonth int = 2;
	 

	print @cbsApplicationDate;
	print @accountOpenDate;
	print @minMonth;
	
	DECLARE @commitmentCharge decimal(18,2) = 
	(select case when round(isnull(lab.loan_amount*(lab.rate_of_interest+lab.offset)*@minMonth/1200,0),0)-
	isnull(sum(interest_amount),0) < 0 then 0
	else  round(isnull(lab.loan_amount*(lab.rate_of_interest+lab.offset)*@minMonth/1200,0),0)-
	isnull(sum(interest_amount),0) end
	from
	bsgloan..loan_account_master lam
inner join
	bsgloan..loan_account_basic lab
on	lam.loan_account_id=lab.loan_account_id and lam.is_active=1 and lab.is_active=1
	and lam.loan_account_id=@accountId
	and loan_product_code in (6026, 6100)
left join
	BSGACCOUNTING..interest_details id
on	lam.loan_account_id=id.account_id and id.is_active=1 and id.txn_date>=@accountOpenDate
	and activity_id in (6003,6005)
	group by lab.loan_amount,lab.rate_of_interest,lab.offset)

	SET @commitmentCharge = (select isnull(@commitmentCharge,0));
	SET @commitmentCharge = (select case when @commitmentCharge<0 then 0 else @commitmentCharge end); 
	PRINT @commitmentCharge;
	SELECT @commitmentCharge as interest_amount;

END

