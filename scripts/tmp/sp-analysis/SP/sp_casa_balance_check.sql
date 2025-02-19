
CREATE   PROCEDURE [dbo].[sp_casa_balance_check]
as  
BEGIN
  declare @v_application_date  datetime = (SELECT
        app_date
    
    FROM
        bsgaccounting..cbs_application_date
    WHERE
        is_active = 1)
  declare  @action_type  VARCHAR(10) ='UPDATE'; --'SELECT';
  declare  @maxnoofrecoredupdate   INT = 10;
    -- EXECUTE IMMEDIATE 'truncate table #tempcasabalcheck';
    

   set @v_application_date = @v_application_date-1;--to_date('2019-04-21','yyyy-mm-dd');
   --  INSERT INTO #tempcasabalcheck
        SELECT
            * into #tempcasabalcheck
        FROM
            (
                SELECT
					ROW_NUMBER() over (order by tm.account_id) rownum,
                    tm.account_id,
                    @v_application_date txn_date,
                    tm.credit,
                    tm.debit,
                    ( ab.checker_clear_balance + ab.checker_unclear_balance ) + tm.credit - debit workingbal,
                    abcur.checker_clear_balance + abcur.checker_unclear_balance abcurbal
                FROM
                    (
                        SELECT
                            tm.account_id,
                            SUM(
                                CASE
                                    WHEN tm.txn_nature = 'C' THEN
                                        tm.txn_amount
                                    ELSE
                                        0
                                END
                            ) credit,
                            SUM(
                                CASE
                                    WHEN tm.txn_nature = 'D' THEN
                                        tm.txn_amount
                                    ELSE
                                        0
                                END
                            ) debit
                        FROM
                            bsgaccounting..transaction_master tm
                        WHERE tm.is_active=1 and 
           -- tm.account_id = 6715060
           -- AND 
                            tm.txn_posting_date =cast(@v_application_date as date)
                        GROUP BY
                            tm.account_id
                    ) tm
                    INNER JOIN bsgaccounting..account_balance   abcur ON tm.account_id = abcur.account_id
                    INNER JOIN (
                        SELECT
                            account_id,
                            MAX(txn_date) txn_date
                        FROM
                            bsgaccounting..account_balance ab
                        WHERE
                            txn_date <= cast(@v_application_date as date)
                        GROUP BY
                            account_id
                    ) abmaxcur ON tm.account_id = abmaxcur.account_id
                                  AND abcur.txn_date = abmaxcur.txn_date
                    LEFT JOIN (
                        SELECT
                            account_id,
                            MAX(txn_date) txn_date
                        FROM
                            bsgaccounting..account_balance ab
                        WHERE
                            txn_date <= cast(@v_application_date  -1 as date) 
                        GROUP BY
                            account_id
                    ) abmax ON tm.account_id = abmax.account_id
                    LEFT JOIN bsgaccounting..account_balance   ab ON abmax.account_id = ab.account_id
                                                                  AND abmax.txn_date = ab.txn_date
                WHERE
                    ( ab.checker_clear_balance + ab.checker_unclear_balance ) + tm.credit - debit <> abcur.checker_clear_balance +
                    abcur.checker_unclear_balance
            ) a
        WHERE
            ROWNUM <= @maxnoofrecoredupdate;

    IF ( @action_type = 'UPDATE' ) 
	begin
        MERGE INTO bsgaccounting..account_balance ab USING #tempcasabalcheck a ON ( ab.account_id = a.account_id
                                                                                  AND ab.txn_date = a.txn_date )
        WHEN MATCHED THEN UPDATE SET ab.checker_clear_balance = workingbal - ab.checker_unclear_balance,
                                     ab.maker_clear_balance = workingbal - ab.checker_unclear_balance,
                                     ab.available_balance = workingbal - ab.checker_unclear_balance;

        INSERT INTO bsgturing..turing_task_result (
            task_id,
            task_ref_id,
            task_ref_table,
            response_code,
            message,
            created_date,
            created_by
        )
            SELECT
                8,
                account_id,
                'account_balance',
                1,
                'previous bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar),
                getdate(),
                - 1
            FROM
                #tempcasabalcheck;

        SELECT
                               COUNT(1) successcount,
                               0 failurecount
                           FROM
                               #tempcasabalcheck;
	end 
    ELSE
    begin   
        INSERT INTO bsgturing..turing_task_result (
            task_id,
            task_ref_id,
            task_ref_table,
            response_code,
            message,
            created_date,
            created_by
        )
            SELECT
                8,
                account_id,
                'account_balance',
                1,
                'previous bal :'
                + abcurbal
                + ',working bal :'
                + workingbal,
                getdate(),
                - 1
            FROM
                #tempcasabalcheck;

         SELECT
                               COUNT(1) successcount,
                               0 failurecount
                           FROM
                               #tempcasabalcheck;




    END  ;
    
    
    
    
update bsgaccounting..account_balance
set maker_clear_balance = checker_clear_balance,
last_modified_by  = 786,
last_modified_date = getdate()
where txn_date  = @v_application_date 
and  maker_clear_balance <> checker_clear_balance;

/*
create global TEMPORARY table #tempcasabalcheck
(account_id number(18,0),txn_date date,credit decimal(18,2),debit decimal(18,2),workingbal decimal(18,2), abcurbal decimal(18,2) )
on commit preserve rows
*/

END;

