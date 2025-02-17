CREATE   PROCEDURE [dbo].[sp_balance_mismatch]   --sp_balance_mismatch 1,'2018-02-20'
@classification_id INT,
@txn_posting_date DATETIME
AS
begin

declare @temp table(Id int identity,ProductCode varchar(10))

insert into @temp
select distinct product_code from BSGCORE.dbo.product_master where is_active=1 AND classification_id=@classification_id


declare @min int=(select min(Id) from @temp)
declare @max int=(select max(Id) from @temp)
declare @selectedproduct varchar(10)

declare @output table
(branch_code int,	product_id varchar(20),	product_code varchar(20),	product_description varchar(100),
	BALDATE datetime,	checker_clear_balance decimal(18,2)
)

while(@min<=@max)
begin
set @selectedproduct=(select ProductCode from @temp where Id=@min)

insert into @output
select A.*,CBL.checker_clear_balance from
(select PM.branch_code,PM.product_id,PM.product_code,PM.product_description,max(PB.txn_date) BALDATE from BSGCORE.dbo.product_master PM 
left outer join
BSGACCOUNTING.dbo.product_balance PB
on
PM.product_id=PB.product_id and PB.txn_date<=@txn_posting_date
where PM.product_code=@selectedproduct and PM.is_active=1
group by PM.branch_code,PM.product_id,PM.product_code,PM.product_description)A
left outer join
BSGACCOUNTING.dbo.product_balance CBL
on
A.product_id=CBL.product_id and A.BALDATE=CBL.txn_date 
where CBL.is_active=1 

set @min=@min+1
end





declare @valuestable table (Id bigint identity,ProductCode varchar(10),ProductName varchar(60),
[br_1] decimal(18,2),[br_1_Acc] decimal(18,2),[br_1_diff] decimal(18,2),
[br_1000] decimal(18,2),[br_1000_Acc] decimal(18,2),[br_1000_diff] decimal(18,2),
[br_1001] decimal(18,2),[br_1001_Acc] decimal(18,2),[br_1001_diff] decimal(18,2),
[br_1002] decimal(18,2),[br_1002_Acc] decimal(18,2),[br_1002_diff] decimal(18,2),
[br_1003] decimal(18,2),[br_1003_Acc] decimal(18,2),[br_1003_diff] decimal(18,2),
[br_1004] decimal(18,2),[br_1004_Acc] decimal(18,2),[br_1004_diff] decimal(18,2),
[br_1005] decimal(18,2),[br_1005_Acc] decimal(18,2),[br_1005_diff] decimal(18,2),
[br_1006] decimal(18,2),[br_1006_Acc] decimal(18,2),[br_1006_diff] decimal(18,2))




insert into @valuestable(ProductCode)
select distinct product_code from @output

update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1000 and product_code=ProductCode )
update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1001 and product_code=ProductCode )
where ProductName is null

update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1002 and product_code=ProductCode )
where ProductName is null

update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1003 and product_code=ProductCode )
where ProductName is null

update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1004 and product_code=ProductCode )
where ProductName is null

update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1005 and product_code=ProductCode )
where ProductName is null

update @valuestable set ProductName = (select top 1 product_description from @output where branch_code=1006 and product_code=ProductCode )
where ProductName is null


update @valuestable set [br_1] = (select isnull(checker_clear_balance,0) from @output where branch_code=1 and product_code=ProductCode  )
update @valuestable set [br_1000]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1000 and product_code=ProductCode  )
update @valuestable set [br_1001]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1001 and product_code=ProductCode  )
update @valuestable set [br_1002]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1002 and product_code=ProductCode  )
update @valuestable set [br_1003]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1003 and product_code=ProductCode  )
update @valuestable set [br_1004]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1004 and product_code=ProductCode  )
update @valuestable set [br_1005]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1005 and product_code=ProductCode  )
update @valuestable set [br_1006]  = (select isnull(checker_clear_balance,0) from @output where branch_code=1006 and product_code=ProductCode  )



-------------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------------


update @valuestable set [br_1_Acc]	=   (select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1','YES',	'No','Account No','NO'))--(select isnull(checker_clear_balance,0) from @output where branch_code=1 and product_code=ProductCode  ))
update @valuestable set [br_1000_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1000','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1000 and product_code=ProductCode  )
update @valuestable set [br_1001_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1001','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1001 and product_code=ProductCode  )
update @valuestable set [br_1002_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1002','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1002 and product_code=ProductCode  )
update @valuestable set [br_1003_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1003','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1003 and product_code=ProductCode  )
update @valuestable set [br_1004_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1004','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1004 and product_code=ProductCode  )
update @valuestable set [br_1005_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1005','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1005 and product_code=ProductCode  )
update @valuestable set [br_1006_Acc]  =(select dbo.fn_GetBalancefromBalanceBook(@txn_posting_date,ProductCode,'1006','YES','No','Account No','NO')) --(select isnull(checker_clear_balance,0) from @output where branch_code=1005 and product_code=ProductCode  )

update @valuestable set [br_1_diff]=isnull([br_1],0)-isnull([br_1_Acc],0),
[br_1000_diff]=isnull([br_1000],0)-isnull([br_1000_Acc],0),
[br_1001_diff]=isnull(br_1001,0)-isnull([br_1001_Acc],0),
[br_1002_diff]=isnull(br_1002,0)-isnull([br_1002_Acc],0),
[br_1003_diff]=isnull(br_1003,0)-isnull([br_1003_Acc],0),
[br_1004_diff]=isnull(br_1004,0)-isnull([br_1004_Acc],0),
[br_1005_diff]=isnull(br_1005,0)-isnull([br_1005_Acc],0),
[br_1006_diff]=isnull(br_1006,0)-isnull([br_1006_Acc],0)

SELECT CASE WHEN SUM(Br1+Br2+Br3+Br4+Br5+Br6+Br7+Br8) >= 1 THEN 1 ELSE 0 END mismatch_count
FROM
(
SELECT
	CASE WHEN br_1_diff <> 0 THEN 1 ELSE 0 END    Br1,
	CASE WHEN br_1000_diff <> 0 THEN 1 ELSE 0 END Br2,
	CASE WHEN br_1001_diff <> 0 THEN 1 ELSE 0 END Br3,
	CASE WHEN br_1002_diff <> 0 THEN 1 ELSE 0 END Br4,
	CASE WHEN br_1003_diff <> 0 THEN 1 ELSE 0 END Br5,
	CASE WHEN br_1004_diff <> 0 THEN 1 ELSE 0 END Br6,
	CASE WHEN br_1005_diff <> 0 THEN 1 ELSE 0 END Br7,
	CASE WHEN br_1006_diff <> 0 THEN 1 ELSE 0 END Br8
FROM 
	@valuestable
) K

end


