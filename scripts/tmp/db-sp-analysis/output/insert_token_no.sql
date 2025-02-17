CREATE   PROCEDURE [dbo].[insert_token_no] -- [insert_token_no] 6,1,100
(
@brcode int,
@from_token int,
@to_token int
)
AS
BEGIN
while (@from_token <= @to_token)
BEGIN
        insert into bsgaccounting..token_stock_master
        (
                txn_branch,token_no,is_active,remark,txn_nature,created_by,created_date,last_modified_by,
                last_modified_date
        )
        select
                A.*
        from
        (
        select
                bm.branch_code,
                @from_token token_no,
                1 is_active,
                'System entry' remark,
                'D' txn_nature,
                1 created_by,
                GETDATE() created_date,
                1 last_modified_by,
                GETDATE() last_modified_date
        from
                BSGMASTER..branch_master bm
        )A
    where
                A.branch_code = @brcode
        order by
                A.branch_code;
set @from_token = @from_token + 1;
end;
END
