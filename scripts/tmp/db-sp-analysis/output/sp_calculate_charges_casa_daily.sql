--select * from BSGMASTER..branch_holiday_master  where calendar_date = '2017-11-05' and branch_code=1
-- =============================================
-- Author:      <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
--eligible_checker_unclear_balance = sum(debit_amount)>checker_unclear_balance ?  checker_unclear_balance  :  sum(debit_amount)
CREATE   PROCEDURE [dbo].[sp_calculate_charges_casa_daily] 
--[sp_calculate_charges_casa_daily] @sgstchargepercent=9,@cgstchargepercent=9,@runDate='2019-06-24',@istxt=0,@branch=0
@sgstchargepercent decimal(4,2),
@cgstchargepercent decimal(4,2),
@runDate datetime,
@istxt int =0 ,
@branch int
AS
BEGIN
set @sgstchargepercent = 0;
set @cgstchargepercent = 0;
declare @againstclgpercent  decimal(4,2) = 0
 set @againstclgpercent = 19;--(select top 1 charge_value from BSGREMITTANCE.dbo.external_product_charges  where charge_type in (12) and is_active=1)
declare @todpercent decimal(4,2) = 19;

select  
case when (checker_unclear_balance >  abs(checker_clear_balance)) then abs(checker_clear_balance)  
		else checker_unclear_balance end
		
		againstchargesbalance,
	case when (checker_unclear_balance <  abs(checker_clear_balance)) then abs(checker_clear_balance)  - checker_unclear_balance 
		else 0  end todchargesbalance,
	am.account_name,
	a.account_no,
	a.account_id,
	am.product_code,
	ab.txn_date
	into #temp
from BSGACCOUNTING..account_balance  ab with  (nolock) 
inner join 
	(select ca.account_no,ab.account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance ab with  (nolock) 
	inner join 
		bsgcore..customer_accounts  ca
	on 
		ab.account_id = ca.account_id
	and 
		ca.is_active =1
	and  
		ca.classification_id =1
	 group  by ca.account_no,ab.account_id)a
on 
	ab.account_id = a.account_id
and 
	ab.txn_date = a.txn_date
inner join 
	bsgcore..account_master am
on 
	ab.account_id = am.account_id
and 
	am.is_active=1
where checker_clear_balance < 0

-- select replace(convert(varchar ,getdate(),106),' ','-')  

 --SELECT *, 
 --                    (tod*
	--					@todpercent*
	--				datediff(day,txn_date,
	--				case when nexttxndate < nextaccountbalancedate then nexttxndate else nextaccountbalancedate end)/36500) todcharges, 
 --                    datediff(day,txn_date,case when nexttxndate < nextaccountbalancedate then nexttxndate else nextaccountbalancedate end) noofdays, 
 --                    cast((od_against_clg*
	--				 @againstclgpercent*
	--				 datediff(day,txn_date,case when nexttxndate < nextaccountbalancedate then nexttxndate else nextaccountbalancedate end))/36500 AS decimal(18,2)) od_against_clgcharges into #temp 
 --             FROM   ( 
 --                           SELECT *, 
 --                                  CASE  
 --                                         WHEN cast(a.eligible_checker_unclear_balance AS decimal(18,2)) >= abs(cast(a.checker_clear_balance AS decimal(18,2))) THEN abs(cast(a.checker_clear_balance AS decimal(18,2)))
 --                                         WHEN cast(a.eligible_checker_unclear_balance AS decimal(18,2)) < abs(cast(a.checker_clear_balance AS decimal(18,2))) THEN cast(a.eligible_checker_unclear_balance AS decimal(18,2))
 --                                         ELSE 0.00 
 --                                  END od_against_clg, 
 --                                  CASE 
 --                                         WHEN cast(a.eligible_checker_unclear_balance AS decimal(18,2)) >= abs(cast(a.checker_clear_balance AS decimal(18,2))) THEN 0.00
 --                                         ELSE abs(cast(a.checker_clear_balance AS decimal(18,2))) - cast(a.eligible_checker_unclear_balance AS decimal(18,2))
 --                                  END tod, 
                                   
 --                                  isnull((select  min(txn_date) from BSGACCOUNTING..transaction_master 
 --                                         where account_id = a.account_id 
 --                                               and txn_Date >=( 
 --                                         SELECT min(txn_date) 
 --                                         FROM   bsgaccounting..account_balance 
 --                                         WHERE  txn_date > a.txn_date 
 --                                         AND    account_id = a.account_id)),GETDATE()) nexttxndate,
 --                                   isnull((select case when MIN(txn_date) > @rundate then @rundate else  MIN(txn_date) end  from BSGACCOUNTING..account_balance where account_id = a.account_id and txn_date > a.txn_date and checker_clear_balance > 0),@rundate) nextaccountbalancedate      
                                          
 --                           FROM   ( 
 --                                         SELECT *, 
 --                                                CASE   when debittxnamount =0 then checker_unclear_balance
 --                                                       WHEN debittxnamount > checker_unclear_balance THEN checker_unclear_balance
 --                                                       ELSE debittxnamount 
 --                                                END eligible_checker_unclear_balance 
 --                                         FROM   ( 
 --                                                           SELECT     ab.account_id, 
 --                                                                      ca.account_no,
 --                                                                      ca.full_name,
 --                                                                      ab.txn_date, 
 --                                                                      ab.checker_clear_balance,
 --                                                                      ab.checker_unclear_balance,
 --                                                                      isnull(( 
 --                                                                             SELECT sum(txn_amount)
 --                                                                             FROM   bsgaccounting..transaction_master
 --                                                                             WHERE  txn_posting_date = ab.txn_date
 --                                                                             AND    account_id = ca.account_id
 --                                                                             AND    txn_nature = 'D'
 --                                                                             AND    is_active=1),0)debittxnamount,
 --                                                                     isnull(( 
 --                                                                             SELECT top 1 txn_ref_no
 --                                                                             FROM   bsgaccounting..transaction_master
 --                                                                             WHERE  txn_posting_date = ab.txn_date
 --                                                                             AND    account_id = ca.account_id
 --                                                                             AND    txn_nature = 'D'
 --                                                                             AND    is_active=1 order by id desc),
                                                                              
 --                                                                             (SELECT top 1 txn_ref_no
 --                                                                             FROM   bsgaccounting..transaction_master
 --                                                                             WHERE  txn_posting_date < ab.txn_date
 --                                                                             AND    account_id = ca.account_id
 --                                                                             AND    txn_nature = 'D'
 --                                                                             AND    is_active=1 order by id desc)
 --                                                                             )txn_ref_no
 --                                                           FROM       BSGACCOUNTING..customer_view ca                                                              
 --                                                           INNER JOIN bsgaccounting..account_balance ab
 --                                                           ON         ca.account_id = ab.account_id
 --                                                            inner join 
 --                                                               (select account_id,MAX(txn_date) txn_date from BSGACCOUNTING..account_balance where txn_date < @runDate group by account_id) a
 --                                                           on 
 --                                                               ab.account_id = a.account_id
 --                                                           and 
 --                                                               ab.txn_date = a.txn_date
 --                                                           WHERE      ca.classification_id = 1         
 --                                                           and (@branch=0 or ca.branch_code = @branch)
 --                                                          -- AND        txn_date >= @fromdate 
 --                                                           -- AND        txn_date <= @todate 
 --                                                           AND        checker_clear_balance < 0
 --                                                           -- and     Exists(select 1 from BSGACCOUNTING..transaction_master where account_id = ca.account_id and txn_posting_date = ab.txn_date)
 --                                                           --AND        ca.account_id = 201524
 --                                                            )a)a )a --)a
                                                            
-- if(@istxt = 0)                                                     
  select * from (SELECT @rundate rundate, todchargesbalance chargesbalance,-1 txn_ref_no,-1 chg_ref_no ,account_id,account_no, '11047' activityId,
  isnull(todchargesbalance *19.00/100,0)/365  charges_amount,
  0 cgst_amount,0 sgst_amount,11 charge_type,product_code, 0 status,'EP' principal_type ,
  'TOD INT '+replace(convert(varchar ,txn_date,106),' ','-')  remarks ,1 is_active ,
  0 created_by ,GETDATE() created_date
  -- isnull(againstchargesbalance*19.00/100,0)/365 od_against_clgcharges,
 
  from #temp where todchargesbalance > 0
  union all

  SELECT @rundate,againstchargesbalance ,-1 txn_ref_no,-1 chg_ref_no ,account_id,account_no, '11049' activityId,
  isnull(againstchargesbalance *19.00/100,0)/365  od_against_clgcharges,
  0 cgst_amount,0 sgst_amount,12 charge_type,product_code, 0 status,'EP' principal_type ,
  'AGST CLG INT '+replace(convert(varchar ,txn_date,106),' ','-')  remarks ,1 is_active ,
  0 created_by ,GETDATE() created_date
 
  from #temp where againstchargesbalance > 0


  union all 
  
  select @rundate,od_clg_amount,od.txn_ref_no,-1 chg_ref_no ,od.account_id,account_no,'11049' activityId,
  isnull(od.od_clg_amount*19.00/100,0)/365 od_against_clgcharges,
  0 cgst_amount,0 sgst_amount,12 charge_type,product_code, 0 status,'EP' principal_type ,
   'AGST CLG INT\SD '+replace(convert(varchar ,@runDate,106),' ','-')   remarks ,1 is_active ,
  0 created_by ,GETDATE() created_date
  from 
	BSGACCOUNTING..od_details od with  (nolock) 
	inner join 
		BSGACCOUNTING..account_balance ab with  (nolock) 
	on 
		od.account_id = ab.account_id
	inner join 
		(select account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance with  (nolock)  group by account_id)a
	on 
		od.account_id = a.account_id
	and 
		ab.txn_date = a.txn_date
	inner join 
		BSGCORE..account_master am
	on 
		od.account_id = am.account_id
	and 
		am.is_active=1
  inner join 
	bsgcore..customer_accounts ca with  (nolock) 
	on 
		od.account_id = ca.account_id
	and 
		ca.is_active=1
	and 
		ca.classification_id=1
	inner join 
		BSGCRM..customer_master cm with  (nolock) 
	on 
		ca.customer_id = cm.customer_id
	and 
		cm.is_active=1

	where 
		od.is_active=1 --and od.available_balance < 0 --and od.response_code=1
	and 
		od.od_clg_amount <> 0 and cast(od.created_date  as date) = @runDate
	and 
		ab.checker_clear_balance >= 0

	union all  -- if same day funding happend and account got against clearing then it will come in list
	select @rundate,od_clg_amount,od.txn_ref_no,-1 chg_ref_no ,od.account_id,account_no,'11049' activityId,
  isnull(od.od_clg_amount*19.00/100,0)/365 od_against_clgcharges,
  0 cgst_amount,0 sgst_amount,12 charge_type,loan_product_code, 0 status,'EP' principal_type ,
  'AGST CLG INT\SD '+replace(convert(varchar ,@runDate,106),' ','-')  remarks ,1 is_active ,
  0 created_by ,GETDATE() created_date
  from 
	BSGACCOUNTING..od_details od with  (nolock) 
	inner join 
		BSGACCOUNTING..account_balance_loan ab with  (nolock) 
	on 
		od.account_id = ab.loan_account_id
	inner join 
		(select loan_account_id,max(txn_date) txn_date from BSGACCOUNTING..account_balance_loan with  (nolock)  group by loan_account_id)a
	on 
		od.account_id = a.loan_account_id
	and 
		ab.txn_date = a.txn_date
	inner join 
		bsgloan..loan_account_master  lam with  (nolock) 
	on 
		od.account_id = lam.loan_account_id
	and 
		lam.is_active=1
  inner join 
	bsgcore..customer_accounts ca with  (nolock) 
	on 
		od.account_id = ca.account_id
	and 
		ca.is_active=1
	and 
		ca.classification_id=6
	inner join 
		BSGCRM..customer_master cm with  (nolock) 
	on 
		ca.customer_id = cm.customer_id
	and 
		cm.is_active=1

	where 
		od.is_active=1 -- and od.available_balance < 0 --and od.response_code=1
	and 
		od.od_clg_amount <> 0 and cast(od.created_date  as date) = @runDate
	and 
		ab.available_balance >= 0)a  order by a.account_id

  --else 
  --begin
  --select @rundate,txn_ref_no,-1 chg_ref_no  ,account_id,account_no,'11047' activityId  , todcharges charges_amount,
  --Isnull(Cast((todcharges * @cgstchargepercent)/100 AS DECIMAL(18,2)),0.00) cgst_amount,
  --Isnull(Cast((todcharges * @sgstchargepercent)/100 AS DECIMAL(18,2)),0.00)sgst_amount
  --,11 charge_type,
  --right(LEFT(account_no,8),4) product_code,0 status,'EP' principal_type ,'TOD chg '+CAST(convert(varchar(5),txn_date,105) as nvarchar) +' Rs '+cast(tod as nvarchar) remarks ,1 is_active 
  --,0 created_by ,GETDATE() created_date
  --from #temp where todcharges  > 0
  --union all
  
  -- select @rundate,txn_ref_no,-1 chg_ref_no ,account_id,account_no,'11049' activityId  , od_against_clgcharges charges_amount,
  --Isnull(Cast((od_against_clgcharges * @cgstchargepercent)/100 AS DECIMAL(18,2)),0.00) cgst_amount,
  --Isnull(Cast((od_against_clgcharges * @sgstchargepercent)/100 AS DECIMAL(18,2)),0.00)sgst_amount
  --,12 charge_type,
  --right(LEFT(account_no,8),4) product_code,0 status,'EP' principal_type ,'Agst clg chg '+CAST(convert(varchar(5),txn_date,105) as nvarchar) +' Rs '+cast(od_against_clg as nvarchar) remarks 
  --,1 is_active 
  --,0 created_by ,GETDATE() created_date
  --from #temp where od_against_clgcharges  > 0
  
  /*
  select cast(account_no as nvarchar)+'|'+ 'D' +'|'+ 'TOD/'+CAST(noofdays as nvarchar)+'Days DT:'+CAST(txn_date as nvarchar)+'|'+'000000'+'|'+cast(todcharges + Isnull(Cast((todcharges * @sgstchargepercent)/100 AS DECIMAL(18,2)),0.00) + Isnull(Cast((todcharges * @cgstchargepercent)/100 AS DECIMAL(18,2)),0.00) as nvarchar)from #temp where todcharges  > 0
  union all 
  select left(account_no,4)+'7311' +'|'+ 'C'+'|'+account_no +'/SGST/TOD/'+'|'+'000000'+'|'+cast(Isnull(Cast((todcharges * @sgstchargepercent)/100 AS DECIMAL(18,2)),0.00) as nvarchar) from #temp where todcharges  > 0
  union all
  select left(account_no,4)+'7312'+'|'+'C'+'|'+account_no+'/CGST/TOD/ '+'|'+'000000'+'|'+CAST( Isnull(Cast((todcharges * @cgstchargepercent)/100 AS DECIMAL(18,2)),0.00) as nvarchar)from #temp where todcharges  > 0     
  union all 
  select account_no+'|'+'D'+'|'+'Against clg/'+CAST(noofdays as nvarchar)+' DT:'+CAST(txn_date as nvarchar)+'|'+'000000'+'|'+cast(od_against_clgcharges + Isnull(Cast((od_against_clgcharges * @sgstchargepercent)/100 AS DECIMAL(18,2)),0.00) + Isnull(Cast((od_against_clgcharges * @cgstchargepercent)/100 AS DECIMAL(18,2)),0.00) as nvarchar)from #temp where od_against_clgcharges  > 0
  union all 
  select left(account_no,4)+'7311'+'|'+'C'+'|'+account_no+'/SGST/Against clg'+'|'+'000000'+'|'+cast(Isnull(Cast((od_against_clgcharges * @sgstchargepercent)/100 AS DECIMAL(18,2)),0.00) as nvarchar) from #temp where od_against_clgcharges  > 0
  union all 
  select left(account_no,4)+'7312'+'|'+'C'+'|'+account_no+'/CGST/Against clg'+'|'+'000000'+'|'+cast(Isnull(Cast((od_against_clgcharges * @cgstchargepercent)/100 AS DECIMAL(18,2)),0.00)as nvarchar) from #temp where od_against_clgcharges  > 0
  
   union all
  select left(account_no,4)+'90001001601'+'|'+'C'+'|'+'TOD/OD against clg- 2017/2018'+'|'+'000000'+'|'+
CAST(sum(Isnull(Cast((od_against_clgcharges) AS DECIMAL(18,2)),0.00)+ Isnull(Cast((todcharges) AS DECIMAL(18,2)),0.00)) as nvarchar) from #temp where (isnull(todcharges,0) + isnull(od_against_clgcharges,0)) > 0    
  group by left(account_no,4)
  */
  
  -- end



END
