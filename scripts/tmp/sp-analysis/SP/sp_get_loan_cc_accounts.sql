

CREATE PROCEDURE [dbo].[sp_get_loan_cc_accounts]  --[sp_get_loan_cc_accounts] @processing_type = 2 
@processing_type int = 1
as
BEGIN
SET NOCOUNT ON;
DECLARE @cbsDate Date =  (select app_date from BSGACCOUNTING..cbs_application_date where is_active = 1)

DECLARE @cnt bigint = (select count(1) from BSGACCOUNTING..loan_interest_details)

if(@cnt > 0)
BEGIN
BEGIN TRY
 THROW 50001, 'Loan Pre Processing Table should be empty', 1;
END TRY
BEGIN CATCH
	THROW; -- throw original error
END CATCH
END


if(@processing_type=1) -- Calender Quarter
BEGIN

insert into BSGACCOUNTING..loan_interest_details
select isnull(ca.customer_id,-1) customer_id, lam.loan_account_id,
ca.account_no,
lam.loan_type,
case when asset_classification >= 3 then 1 else 0 end,
lam.branch_code,
lam.loan_product_code,
lam.loan_product_id,
0,0,0,
interestpl.internal_product_id,
interestpl.internal_account_id,
penalinterestpl.internal_account_id,
penalinterestpl.internal_product_id,
0
from bsgloan..loan_account_master  lam 
inner join 
bsgloan..loan_product_master lpm 
on lam.loan_product_id = lpm.loan_product_id 
inner join bsgcore..account_master_internal penalinterestpl 
on penalinterestpl.internal_account_id = lpm.penal_interest_pl_account_id 
inner join bsgcore..account_master_internal interestpl 
on interestpl.internal_account_id = lpm.interest_income_pl_code 
inner join bsgcore..customer_accounts ca
on ca.account_id = lam.loan_account_id
where lam.is_active=1 and lpm.is_active=1 and penalinterestpl.is_active=1 and interestpl.is_active=1 
and lam.loan_account_status!=2 AND lam.is_bddr <> 1 and ca.is_active=1 
and (lpm.regular_interest_quarter_type =  1 or lam.loan_type = 2) -- calenderQuarter Loan Accounts and Cc Accounts
and lpm.interest_frequency <= CASE MONTH(@cbsDate) WHEN 3 THEN 4 
												   WHEN 9 THEN 3								   
												   WHEN 6 THEN 2
												   WHEN 12 THEN 2
												   ELSE 1 END;

END
ELSE if(@processing_type=2) -- Anniversary Quarter
BEGIN

declare @hoBranchCode varchar(10) = (select config_value from BSGADMIN..cbs_config where config_key = 'HO_BRANCH_ID');

declare @microFinanceProduct varchar(1000) = null;
set @microFinanceProduct = (select config_value from BSGADMIN..cbs_config where config_key = 'MICROFINANCE_PRODUCT');

IF OBJECT_ID(N'tempdb..#tempMFProduct') IS NOT NULL
	DROP TABLE #tempMFProduct; 

create table #tempMFProduct(
productCode int,
productDescription varchar(1000)
)
insert into #tempMFProduct
select productcode,product_description
from (
SELECT t.c.value('.', 'VARCHAR(1000)') productcode
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


DROP TABLE IF EXISTS #temp_anniversary_date
select isnull(ca.customer_id,-1) customer_id, lam.loan_account_id,
ca.account_no,
lam.loan_type,
case when asset_classification >= 3 then 1 else 0 end npa_flag,
lam.branch_code,
lam.loan_product_code,
lam.loan_product_id,
0 account_balance,
0 interest_amount,
0 penal_interest_amount,
interestpl.internal_product_id,
interestpl.internal_account_id,
penalinterestpl.internal_account_id penal_pl_account_id,
penalinterestpl.internal_product_id penal_pl_product_id,
0 is_processed
INTO #temp_anniversary_date
from bsgloan..loan_account_master  lam 
inner join 
bsgloan..loan_product_master lpm 
on lam.loan_product_id = lpm.loan_product_id 
inner join bsgcore..account_master_internal penalinterestpl 
on penalinterestpl.internal_account_id = lpm.penal_interest_pl_account_id 
inner join bsgcore..account_master_internal interestpl 
on interestpl.internal_account_id = lpm.interest_income_pl_code 
inner join bsgcore..customer_accounts ca
on ca.account_id = lam.loan_account_id
inner join (
select 
	lrc.loan_account_id,lrc.due_date,lrc.installment_no 
from
(
select
    loan_account_id,
    installment_no,
    MAX(id) id
from
    BSGACCOUNTING..loan_repayment_chart with(nolock)
group by
    loan_account_id,
   installment_no
)a
inner join BSGACCOUNTING..loan_repayment_chart lrc with(nolock)
    on lrc.loan_account_id = a.loan_account_id
        and lrc.installment_no = a.installment_no
            and lrc.id = a.id
where 
	lrc.due_date = @cbsDate
) lrc on lrc.loan_account_id = lam.loan_account_id
	and lrc.due_date = @cbsDate
inner join #tempMFProduct tmp
on
	lpm.loan_product_code = tmp.productCode
where lam.is_active=1 and lpm.is_active=1 and penalinterestpl.is_active=1 and interestpl.is_active=1 
and lam.loan_account_status!=2 AND lam.is_bddr <> 1 and ca.is_active=1 
and lpm.regular_interest_quarter_type = 2 -- Anniversary Date
and lam.loan_type = 1



DROP TABLE IF EXISTS #temp_limit_expired_accounts
SELECT ca.customer_id,lab.loan_account_id, ca.account_no, 
lam.loan_type,
case when lam.asset_classification >= 3 then 1 else 0 end npa_flag,
lam.branch_code,
lam.loan_product_code,
lam.loan_product_id,
0 account_balance,
0 interest_amount,
0 penal_interest_amount,
interestpl.internal_product_id,
interestpl.internal_account_id,
penalinterestpl.internal_account_id penal_pl_account_id,
penalinterestpl.internal_product_id penal_pl_product_id,
0 is_processed
INTO #temp_limit_expired_accounts
FROM BSGLOAN..loan_account_basic lab
INNER JOIN BSGLOAN..loan_account_master lam 
ON lab.loan_account_id = lam.loan_account_id 
INNER JOIN 
bsgloan..loan_product_master lpm 
ON lam.loan_product_id = lpm.loan_product_id 
INNER JOIN BSGCORE..customer_accounts ca
ON  ca.account_id = lam.loan_account_id
INNER JOIN bsgcore..account_master_internal interestpl 
ON interestpl.internal_account_id = lpm.interest_income_pl_code 
INNER JOIN bsgcore..account_master_internal penalinterestpl 
ON penalinterestpl.internal_account_id = lpm.penal_interest_pl_account_id 
WHERE CAST(lab.limit_expiry_date as date) < @cbsDate AND lam.loan_account_status != 2 
AND lab.is_active = 1 AND lam.is_active = 1 AND lam.loan_type = 1  AND lam.is_bddr <> 1
AND lpm.is_active = 1 AND lpm.repayment_mode = 1 AND lpm.regular_interest_quarter_type = 2
AND ca.is_active = 1 AND interestpl.is_active = 1 AND penalinterestpl.is_active = 1
AND (SELECT MAX(due_date) FROM BSGACCOUNTING..loan_repayment_chart lrc 
WHERE loan_account_id = lab.loan_account_id AND is_active = 1) < @cbsDate 


DROP TABLE IF EXISTS #templimitexpiredacrualdate
SELECT * ,ROW_NUMBER()OVER(partition by loan_account_id ORDER BY loan_account_id,acrrualdate) rnum
INTO #templimitexpiredacrualdate
FROM (
SELECT a.*,dateadd(d,-1,isnull(duedate,installmentStartdate)) txndate,isnull(lrc.duedate,a.installmentStartdate) startdatepart,
--CASE 
--     WHEN 
--         DATEADD(m,number,txndate) = eomonth(DATEADD(m,number,txndate) ) and isnull(lrc.duedate,a.installmentStartdate)= EOMONTH(isnull(lrc.duedate,a.installmentStartdate))
--     THEN 
--         eomonth(DATEADD(m,number,txndate)) 
--     ELSE 
--         CASE WHEN month(DATEADD(m,number,txndate)) = 1 and day(isnull(lrc.duedate,a.installmentStartdate)) >= 28 THEN eomonth(DATEADD(m,number,txndate)) 
--         ELSE    dateadd(dd,day(isnull(lrc.duedate,a.installmentStartdate)) - day(DATEADD(m,number,txndate))
--         ,DATEADD(month,1,cast(cast(year(DATEADD(m,number,txndate)) AS varchar) + '-' + cast(month(DATEADD(m,number,txndate)) AS varchar) +'-'+ 
--         cast(day(DATEADD(m,number,txndate)) AS varchar) AS date))) END END
DATEADD(d,number,isnull(duedate,installmentStartdate)) acrrualdate
--select *
FROM (
SELECT lam.loan_account_no,lam.loan_account_id
,lab.installment_start_date installmentStartdate
FROM bsgloan..loan_account_master lam
inner join #tempMFProduct tmp
on
	lam.loan_product_code = tmp.productCode
INNER JOIN bsgloan..loan_account_basic lab
ON
    lam.loan_account_id = lab.loan_account_id
INNER JOIN #temp_limit_expired_accounts tlea
ON tlea.loan_account_id = lab.loan_account_id
AND
    lam.is_active = 1 AND lab.is_active = 1 AND lam.loan_account_id = tlea.loan_account_id
) a
--LEFT JOIN (SELECT MAX(txn_date) txndate,account_id FROM BSGACCOUNTING..interest_details WHERE activity_id = 3004 and is_active = 1 GROUP BY account_id) b
--ON
--    a.loan_account_id = b.account_id
LEFT JOIN (SELECT MAX(due_Date) duedate,loan_account_id FROM  BSGACCOUNTING..loan_repayment_chart WHERE is_active = 1 GROUP BY loan_account_id) lrc
ON
    a.loan_account_id = lrc.loan_account_id
INNER JOIN master..spt_values spt
ON
    spt.type = 'P'
AND
    DATEADD(d,number,isnull(duedate,installmentStartdate)) <= @cbsDate AND spt.number > 0 and spt.number % 14 = 0) a WHERE a.acrrualdate = @cbsDate 


INSERT INTO BSGACCOUNTING..loan_interest_details
SELECT  customer_id, 
loan_account_id,
account_no,
loan_type,
npa_flag ,
branch_code,
loan_product_code,
loan_product_id,
account_balance,
interest_amount,
penal_interest_amount,
internal_product_id,
internal_account_id,
penal_pl_account_id,
penal_pl_product_id,
is_processed
FROM #temp_anniversary_date 
UNION ALL
SELECT tlea.customer_id,
tlea.loan_account_id, 
tlea.account_no, 
tlea.loan_type,
tlea.npa_flag,
tlea.branch_code,
tlea.loan_product_code,
tlea.loan_product_id,
tlea.account_balance,
tlea.interest_amount,
tlea.penal_interest_amount,
tlea.internal_product_id,
tlea.internal_account_id,
tlea.penal_pl_account_id,
tlea.penal_pl_product_id,
tlea.is_processed
FROM #temp_limit_expired_accounts tlea
INNER JOIN #templimitexpiredacrualdate tmp
ON tmp.loan_account_id = tlea.loan_account_id



END

-- CREATE INDEX id_loan_interest_index ON loan_interest_details(account_id,branch_code);


update  lid 
set lid.interest_amount = cast(isnull(ab.interest_accrual,0) as decimal(18,0)),
lid.penal_interest_amount = cast(isnull(ab.penal_interest_accrual,0) as decimal(18,0)),
lid.account_balance = isnull(ab.available_balance,0) 
from bsgaccounting..loan_interest_details lid
inner join 
bsgaccounting..account_balance_loan ab 
on 
	lid.account_id = ab.loan_account_id 
inner join 
	(select loan_account_id,max(txn_date) txn_date from bsgaccounting..account_balance_loan
	 where is_Active=1 group by loan_account_id 
	 ) a 
on  
	ab.loan_account_id = a.loan_account_id 
and  
	ab.txn_date = a.txn_date ;



UPDATE bsgaccounting..loan_interest_details SET interest_amount = 0 WHERE interest_amount < 0;
UPDATE bsgaccounting..loan_interest_details SET penal_interest_amount = 0 WHERE penal_interest_amount < 0;




END;
