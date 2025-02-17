
CREATE   procedure [dbo].[sp_cash_charges_not_authorized_legs] -- sp_cash_charges_not_authorized_legs 3,'2019-07-26'
( 
@txnBranch bigint,
@txnDate varchar(20)
)

AS
BEGIN


 select 
	tknMap.token_id, count(tknMap.txn_ref_no) txnRefNo into #countRef
	--tknMap.txn_ref_no txnRefNo
from
	txn_ref_token_mapping tknMap
inner join
	txn_ref_token_mapping tknMap1
	on 
		tknMap.token_id = tknMap1.token_id
	and
		tknMap1.is_active=1
	--and 
	--	tknMap1.txn_branch = @branchCode
inner join 
	transaction_status ts
	on 
		tknMap.txn_ref_no = ts.txn_ref_no
	and
		ts.txn_type = 1 
	and
		ts.is_active = 1
where 
	tknMap1.txn_ref_no 
in
	(select 
		ac.txn_ref_no 
	from 
		account_charges ac 
	where 
		ac.account_id < -1 and
		ac.post_date = @txnDate
	)
and
	tknMap.is_active = 1
	group by tknMap.token_id having count(tknMap.txn_ref_no) = 3;

select * from #countRef;

select 
	tknMap.token_id, tknMap.txn_ref_no txnRefNo,ts.txn_state,0 pass into #temp
	--tknMap.txn_ref_no txnRefNo
from
	txn_ref_token_mapping tknMap
--inner join
--	txn_ref_token_mapping tknMap1
--	on 
--		tknMap.token_id = tknMap1.token_id
--	and
--		tknMap1.is_active=1
	--and 
	--	tknMap1.txn_branch = @branchCode
inner join 
	transaction_status ts
	on 
		tknMap.txn_ref_no = ts.txn_ref_no
	and
		ts.txn_type = 1 
	and
		ts.is_active = 1
where 
	tknMap.is_active = 1 and tknMap.token_id in 
	(select distinct token_id from #countRef);

	update t
	set t.pass = 1 
	from #temp t
	where token_id in (select token_id from #temp where t.txn_state = 'C' group by token_id,txn_state having count(1) = 3);

	--update t
	--set t.pass = 1 
	--from #temp t
	--where token_id in (select token_id from #temp);

	--update t
	--set t.pass = 1
	--from #temp t
	--where t.token_id in 
	--	  (select token_id, ROW_NUMBER() over (order by [RS_NOM]) as ROWNUM
	--	  from #temp where txn_state = 'C' group by token_id having ROW_NUMBER() > 1)

	select txnRefNo from #temp where pass = 0;


END;
