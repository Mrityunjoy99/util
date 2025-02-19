create    PROCEDURE [dbo].[sp_test] 
as begin
drop table if exists #t1

create table #t1
(
id int identity(1,1),
loan_account_id	 varchar(100),
installmentno	 varchar(100),
collection_amt	 varchar(100),
rnum	 varchar(100),
ref_id	 varchar(100),
co_id	 varchar(100),
co_name	 varchar(100),
village_id	 varchar(100),
village_name varchar(100),	
center_id	 varchar(100),
center_name	 varchar(100),
group_id	 varchar(100),
group_name	 varchar(100),
collection_day	 varchar(100),
collection_week varchar(100),
product_description varchar(100)
)

insert into #t1 (loan_account_id,center_name,group_id,product_description)
values ('123','C1','G1','Prod1'), ('123','C1','G1','Prod1'), ('123','C1','G1','Prod2'), ('123','C1','G1','Prod3'), ('123','C1','G1','Prod3') ,('123','C1','G1','Prod3'),
 ('123','C2','G1','Prod1'), ('123','C3','G1','Prod1'), ('123','C3','G1','Prod2'), ('123','C3','G1','Prod3'), ('123','C4','G1','Prod3') ,('123','C1','G4','Prod3');

 update #t1 set rnum = id;
 select * from #t1;
 end
