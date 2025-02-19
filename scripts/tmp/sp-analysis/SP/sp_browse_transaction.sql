-- BSGACCOUNTING..sp_browse_transaction
CREATE   procedure [dbo].[sp_browse_transaction] 
-- sp_browse_transaction '2017-11-13','2017-11-13',@channel='A', @txnRefNo=31017307761,@classificationid=5
--@channel=A'@employeecode=santosh, @classficationid=1 
@fromdate datetime,
@todate datetime,
@employeecode nvarchar(20) = '0',
@brcode int =0 ,
@fromamt decimal(18,2) = 0,
@toamt decimal(18,2) = 0,
@classificationid int = 0,
@productcode int = 0,
@batchCode int = 0, -- 1 then atm 2 then imps
@accountid nvarchar(30) = '0',
@txnType int = 0,
@channel nvarchar(10) = '0',
@pageIndex int = 1,
@pageSize int = 20,
@txnRefNo nvarchar(100) = '0'
as 
begin

Select 0 Sutex



/*
SET NOCOUNT ON;

	declare @accid nvarchar(100) = @accountid
	if(@accountid <> '0')
		set @accountid = (select account_id from bsgcore..customer_accounts where account_no = @accountid and is_active=1)
	
	
	declare @nfs nvarchar(10)= ''
	if(@channel = 'A')
		set @nfs = 'N'
	
	set @employeecode = (select top 1  employee_id from BSGADMIN..employee_master where employee_code = @employeecode and is_active=1)
	--print @employeecode
	if(@classificationid <> 5)
	begin
		
	;With CTEForPagination AS  
    (
		select 
			row_number() over (order by txn_ref_no) RowNum,
			  tm.id,
			  tm.account_id,
			  tm.txn_date,
			  tm.txn_value_date,
			  tm.instr_no,
			  tm.narration,
			  'CustomerTransaction' type,
			  tm.txn_amount,
			  tm.txn_nature,
			  tm.txn_ref_no,
			 -- (select top  1 employee_code from BSGADMIN..employee_master where employee_id =  tm.created_by and is_active=1) created_by,
			  (select top  1 employee_code from BSGADMIN..employee_master where employee_id =  tm.last_modified_by and is_active=1) last_modified_by,
			 -- tm.created_by,
			  cv.account_no + ' - ('+ (select top 1 full_name from BSGCRM..customer_master where customer_id=cv.customer_id and is_active=1)+')' account_no,
			  tm.txn_type,
			  tm.home_branch,
			  tm.txn_branch,
			  tm.batch_code,
			  tm.txn_posting_date,
			  ''principle_type 
			   
		from 
			BSGACCOUNTING..transaction_master tm 
		left join 
		--select * from 
			BSGCORE..customer_accounts cv
			--BSGACCOUNTING..customer_view cv
		on 
			tm.account_id = cv.account_id
		and 
			cv.is_active=1
		where
			tm.is_active=1
		and 
			(@employeecode ='0' or @employeecode is null or tm.created_by = @employeecode or tm.last_modified_by= @employeecode) 
		and 
			(@txnRefNo != '0' or cast(tm.txn_posting_date as date) >= @fromdate )
		and 
			(@txnRefNo != '0' or  cast(tm.txn_posting_date as date) <= @todate )
		and 
			(@fromamt = 0  or tm.txn_amount >= @fromamt )
		and
			(@toamt =0 or tm.txn_amount <= @toamt )
		and 
			(@brcode = 0 or tm.txn_branch = @brcode)
		and 
			(@batchCode = 0 or tm.batch_code=@batchCode)
		and 
			(@classificationid = 0 or cv.classification_id = @classificationid)
		--and 
		--	(@productcode ='0' or cv.product_id = @productcode)
		and 
			(@accountid = 0 or tm.account_id=@accountid)
		and 
			tm.is_active=1
		and 
			(@txnType = 0  or tm.txn_type=@txnType)
		and		
			(@channel = '0' or tm.batch_code in 		
				(select batch_code from BSGACCOUNTING..batch_master where is_active = 1 and  channel in (@nfs,@channel)))
		and 
			(@txnRefNo = '0' or tm.txn_ref_no = @txnRefNo)
	),
		--select * into #temp from CTEForPagination where RowNum BETWEEN 0 AND (@PageIndex * @PageSize)
		
		 CTEForPagination1 AS (
		select row_number() over (order by a.txn_ref_no) RowNum,* from 
		(select
			  0 id,  
			  account_id,
			  txn_date,
			  txn_value_date,
			  instr_no,
			  narration,
			   type,
			  txn_amount,
			  txn_nature,
			  txn_ref_no,
			 -- created_by,
			  last_modified_by,			 			 
			   account_no,
			  txn_type,
			  home_branch,
			  txn_branch,
			  batch_code,
			  txn_posting_date,
			  principle_type  from CTEForPagination 
		union all
		select 
				--row_number() over (order by tmi.txn_ref_no) RowNum,
				tmi.id,
				tmi.principal_id,
				tmi.txn_date,
				tmi.txn_value_date,
				tmi.instr_no,
				tmi.narration,
				'InternalTransaction' type,
				 tmi.txn_amount,
				 tmi.txn_nature,
				 tmi.txn_ref_no,
				-- (select top  1 employee_code from BSGADMIN..employee_master where employee_id =  tmi.created_by and is_active=1) created_by,
				  (select top  1 employee_code from BSGADMIN..employee_master where employee_id =  tmi.last_modified_by and is_active=1) last_modified_by,			
				  case when 
							principal_type = 'IA' 
						then 
							(select 
								top 1 account_no + ' - ('+(select top 1 description from BSGCORE..account_master_internal where internal_account_id = tmi.principal_id and is_active=1)+')'
							from 
								bsgcore..customer_accounts 
							where 
								account_id=tmi.principal_id 
							and 
								is_active=1)
						when
							principal_type = 'IP'
						then 
							 (select 
								top 1 right('0000'+CAST(branch_code as nvarchar),4) + CAST(product_code as nvarchar) +' - ('+description+')'
							  from 
								BSGCORE..product_master_internal 
							  where  
								internal_product_id = tmi.principal_id 
							   and
								is_active=1 ) 
						end,
				  --case when @accountid = '0' then cast(@productcode as nvarchar) else @accid end  account_no,
				  tmi.txn_type,
				  tmi.home_branch,
				  tmi.txn_branch,
				  tmi.batch_code,
				  tmi.txn_posting_date,
				  tmi.principal_type from transaction_master_internal tmi 
			where 
				(txn_ref_no in (select distinct txn_ref_no from CTEForPagination) or txn_ref_no = @txnRefNo)
			and		
				tmi.is_active =1
			and tmi.principal_type in ('IA','IP')
			and (
						
							case when tmi.principal_type = 'IP' and   (select 
								COUNT(1) 
							from 
								transaction_master_internal 
							where  
								txn_ref_no = tmi.txn_ref_no 
							and 
								principal_type='IA'
							and 
								principal_id in 
									 (select 
										internal_account_id 
									from 
										BSGCORE..account_master_internal 
									where  
										internal_product_id = tmi.principal_id 
									and 
										is_active=1)) > 0 then 0 else 1 end  = 1)
				 )a
		
	)
	 select 
		ct.*,bm.branch_name txn_branch_name,
		BSGTURINGREPORTS.dbo.DSP_NumericToRupees(txn_amount) as amtwords,
		(select top  1 employee_code from BSGADMIN..employee_master where employee_id =
		(select top 1 created_by from BSGACCOUNTING..transaction_status where txn_ref_no = ct.txn_ref_no order by id asc))created_by,
		(select 
			count(1)/@pageSize + case when (COUNT(1)% @pageSize) > 0 then 1 else 0 end 
		from 
			CTEForPagination1) nopages 
	from 
		CTEForPagination1  ct
	inner join 
		BSGMASTER..branch_master bm
	on
		ct.txn_branch = bm.branch_code
	and 
		bm.is_active=1
	where 
		RowNum BETWEEN ((@pageIndex - 1) * @PageSize + 1) 
	AND 
		(@PageIndex * @PageSize)
	 order by txn_ref_no,id,txn_nature
	-- drop table #temp
	end		
	else
	begin
	
		
	
	;With CTEForPagination AS  
    (
		select 
			 row_number() over (order by tmi.txn_ref_no) RowNum,
			tmi.principal_id,
			tmi.txn_date,
			tmi.txn_value_date,
			tmi.instr_no,
			tmi.narration,
			'InternalTransaction' type,
			 tmi.txn_amount,
			 tmi.txn_nature,
			 tmi.txn_ref_no,
			-- (select top  1 employee_code from BSGADMIN..employee_master where employee_id =  tmi.created_by and is_active=1) created_by,
			  (select top  1 employee_code from BSGADMIN..employee_master where employee_id =  tmi.last_modified_by and is_active=1) last_modified_by,			
			  --case when @accountid = '0' then cast(@productcode as nvarchar) else @accid end  account_no,
			    case when 
							principal_type = 'IA' 
						then 
							(select 
								top 1 account_no + ' - ('+(select top 1 description from BSGCORE..account_master_internal where internal_account_id = tmi.principal_id and is_active=1)+')'
							from 
								bsgcore..customer_accounts 
							where 
								account_id=tmi.principal_id 
							and 
								is_active=1)
						when
							principal_type = 'IP'
						then 
							 (select 
								top 1 right('0000'+CAST(branch_code as nvarchar),4) + CAST(product_code as nvarchar) +' - ('+description+')'
							  from 
								BSGCORE..product_master_internal 
							  where  
								internal_product_id = tmi.principal_id 
							   and
								is_active=1 ) 
						end account_no,
			  tmi.txn_type,
			  tmi.home_branch,
			  tmi.txn_branch,
			  tmi.batch_code,
			  tmi.txn_posting_date
			  
		from 
			--select * from 
			BSGACCOUNTING..transaction_master_internal tmi 
		left join 
			-- select * from 
			BSGACCOUNTING..transaction_pending tp
		on 
			tmi.principal_id = case when tp.internal_product_id = -1 then tp.account_id else  tp.internal_product_id end
		and 
			tmi.principal_type = case when tp.internal_product_id = -1 then 'IA' else 'IP' end
		and 
			tmi.txn_ref_no = tp.txn_ref_no
		and 
			tp.is_active=1			 
		--inner join 
		----select * from 
		--	bsgcore..product_master_internal pmi
		--on 
		--	tmi.principal_id = pmi.internal_product_id
		--and 
		--	pmi.is_active=1
		where
			(@employeecode ='0' or @employeecode is null or  tmi.created_by = @employeecode or tmi.last_modified_by= @employeecode) 
		and 
			(@txnRefNo != '0' or cast(tmi.txn_posting_date as date) >= @fromdate )
		and 
			(@txnRefNo != '0' or cast(tmi.txn_posting_date as date) <= @todate)
		and 
			(@fromamt = 0  or tmi.txn_amount >= @fromamt )
	    and
			(@toamt =0 or tmi.txn_amount <= @toamt )
		and 
			(@brcode = 0 or tmi.txn_branch = @brcode)
		and 
			(@batchCode = 0 or tmi.batch_code=@batchCode)
		and 
			(@productcode =0 or 
			         tmi.principal_id in (select 
												principal_id 
										   from 
												bsgcore..product_master_internal 
											where 
												product_code = @productcode 
											and 
												is_active=1 ))
		and 
			tmi.principal_type = case when @accountid	=0  then 'IP' else 'IA'end
		and 
			(@accountid = 0 or tmi.principal_id = @accountid)				
		and 
			tmi.is_active=1				
		and 
			(@txnType = 0  or tmi.txn_type=@txnType)
		and		
			(@channel = '0' or tmi.batch_code in 
				(select batch_code from BSGACCOUNTING..batch_master where is_active = 1 and  channel in (@nfs,@channel))
		and 
			(@txnRefNo = '0' or tmi.txn_ref_no = @txnRefNo)		
		)
	)
	--select count(1)/@pageSize from CTEForPagination
	select *,(select top  1 employee_code from BSGADMIN..employee_master where employee_id =
		(select top 1 created_by from BSGACCOUNTING..transaction_status where txn_ref_no = ct.txn_ref_no order by id asc))created_by,
		(select count(1)/@pageSize + case when (COUNT(1)% @pageSize) > 0 then 1 else 0 end from CTEForPagination) nopages from CTEForPagination ct where  RowNum BETWEEN ((@pageIndex - 1) * @PageSize + 1) AND (@PageIndex * @PageSize)
	end	
	
	*/
		
end


