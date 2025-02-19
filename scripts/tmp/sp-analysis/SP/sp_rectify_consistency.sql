
CREATE     procedure [dbo].[sp_rectify_consistency] -- [sp_rectify_consistency]
as

begin
declare @v_application_date     datetime = (
 SELECT
        app_date     
    FROM
        bsgaccounting..cbs_application_date
    WHERE
        is_active = 1
)
declare  @action_type            VARCHAR(10) = 'UPDATE'-- 'SELECT' --
declare  @maxnoofrecoredupdate   INT = 25

 --EXECUTE IMMEDIATE 'truncate table #temp_internaltransactionwoorking'
 --EXECUTE IMMEDIATE 'truncate table #tempcasabalcheck'
   

   
create  table #tempcasabalcheck
(rownum int ,account_id numeric(18,0),txn_date date,credit decimal(18,2),debit decimal(18,2),workingbal decimal(18,2), abcurbal decimal(18,2) )

 

    create  table #temp_internaltransactionwoorking
    (
		principle_type VARCHAR(10),
		principal_id numeric(18,0),
		camount numeric(18,2),
		damount numeric(18,2)
	)


  set @v_application_date = @v_application_date-1--to_date('2019-04-21','yyyy-mm-dd')

    INSERT INTO #temp_internaltransactionwoorking
    SELECT
        tmi.principal_type principle_type,
        tmi.principal_id,
        SUM(
            CASE
                WHEN txn_nature = 'C' THEN
                    txn_amount
                ELSE
                    0
            END
        ) camount,
        SUM(
            CASE
                WHEN txn_nature = 'D' THEN
                    txn_amount
                ELSE
                    0
            END
        ) damount 
    FROM
        bsgaccounting..transaction_master_internal tmi
    WHERE
        txn_posting_date = cast(@v_application_date as date)
    and 
        is_active=1
    and 
        tmi.is_reconciled in (1,2)
    GROUP BY
        tmi.principal_type,
        tmi.principal_id


/*EP */
 INSERT INTO #tempcasabalcheck
    SELECT
        * 
    FROM
        (
            SELECT
				row_number() over (order by  tit.principal_id) ROWNUM,
                tit.principal_id account_id,
                @v_application_date txn_date,
                tit.camount,
                tit.damount,
                isnull(pbpr.checker_clear_balance, 0) + tit.camount - tit.damount workingbal,
                pb.checker_clear_balance 
   --  isnull(pbpr.checker_clear_balance, 0),
            FROM
                #temp_internaltransactionwoorking   tit
                INNER JOIN bsgaccounting..product_balance      pb
                ON tit.principal_id = pb.product_id
                AND tit.principle_type = 'EP'
                INNER JOIN (
                    SELECT
                        product_id,
                        MAX(txn_date) txn_date
                    FROM
                        bsgaccounting..product_balance
                    WHERE
                        txn_date <= cast(@v_application_date as date)
                    GROUP BY
                        product_id
                ) a ON pb.product_id = a.product_id
                       AND pb.txn_date = a.txn_date
                LEFT OUTER JOIN bsgaccounting..product_balance      pbpr
                ON tit.principal_id = pbpr.product_id
                INNER JOIN (
                    SELECT
                        product_id,
                        MAX(txn_date) txn_date
                    FROM
                        bsgaccounting..product_balance
                    WHERE
                        txn_date <= cast(@v_application_date -1 as date)
                    GROUP BY
                        product_id
                ) b ON pbpr.product_id = b.product_id
                       AND pbpr.txn_date = b.txn_date
            WHERE
            tit.principle_type = 'EP' and 
                isnull(pbpr.checker_clear_balance, 0) + tit.camount - tit.damount <> pb.checker_clear_balance
        ) a
    WHERE
        ROWNUM <= @maxnoofrecoredupdate

if(@action_type = 'UPDATE')
begin 

     MERGE INTO bsgaccounting..product_balance pb USING #tempcasabalcheck a ON ( pb.product_id = a.account_id
                                                                                  AND pb.txn_date = a.txn_date )
        WHEN MATCHED THEN UPDATE SET pb.checker_clear_balance = workingbal ;

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
                80,
                account_id,
                'product_balance',
                1,
                'CBS_DATE'+cast(@v_application_date as nvarchar)+',cur bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar) +', credit sum '+ cast(credit as nvarchar)
                +', debit sum '+cast( debit as nvarchar),

                getdate(),
                - 1
            FROM
                #tempcasabalcheck

              SELECT
                               COUNT(1) successcount,
                               0 failurecount
from
                                 #tempcasabalcheck
end
else 
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
                80,
                account_id,
                'product_balance',
                1,
                 'CBS_DATE'+cast(@v_application_date as nvarchar)+',cur bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar) +', credit sum '+ cast(credit as nvarchar)
                +', debit sum '+cast( debit as nvarchar),


                getdate(),
                - 1
            FROM
                #tempcasabalcheck

 SELECT
                               COUNT(1) successcount,
                               0 failurecount
from
                                 #tempcasabalcheck
end


/*IP*/
truncate table #tempcasabalcheck

 INSERT INTO #tempcasabalcheck
    SELECT
        *
    FROM
        (
            SELECT
				ROW_NUMBER() over (order by tit.principal_id) rownum,
                tit.principal_id,
                @v_application_date txn_date,
                tit.camount,
                tit.damount,
                isnull(pbpr.checker_clear_balance, 0) + tit.camount - tit.damount workingbal,
                pb.checker_clear_balance
   --  isnull(pbpr.checker_clear_balance, 0),
            FROM
                #temp_internaltransactionwoorking   tit
                INNER JOIN bsgaccounting..product_balance_internal      pb 
                ON tit.principal_id = pb.internal_product_id
                AND tit.principle_type = 'IP'
                INNER JOIN (
                    SELECT
                        internal_product_id,
                        MAX(txn_date) txn_date
                    FROM
                        bsgaccounting..product_balance_internal
                    WHERE
                        txn_date <= cast(@v_application_date as date)
                    GROUP BY
                        internal_product_id
                ) a ON pb.internal_product_id = a.internal_product_id
                       AND pb.txn_date = a.txn_date
                LEFT OUTER JOIN bsgaccounting..product_balance_internal      pbpr 
                ON tit.principal_id = pbpr.internal_product_id
                INNER JOIN (
                    SELECT
                        internal_product_id,
                        MAX(txn_date) txn_date
                    FROM
                        bsgaccounting..product_balance_internal
                    WHERE
                        txn_date <= cast(@v_application_date -1 as date)
                    GROUP BY
                        internal_product_id
                ) b ON pbpr.internal_product_id = b.internal_product_id
                       AND pbpr.txn_date = b.txn_date
            WHERE
            tit.principle_type = 'IP' and 
                isnull(pbpr.checker_clear_balance, 0) + tit.camount - tit.damount <> pb.checker_clear_balance
        ) a
    WHERE
        ROWNUM <= @maxnoofrecoredupdate

if(@action_type = 'UPDATE')
begin 
     MERGE INTO bsgaccounting..product_balance_internal pb USING #tempcasabalcheck a 
     ON ( pb.internal_product_id = a.account_id
                                                                                  AND pb.txn_date = a.txn_date )
        WHEN MATCHED THEN UPDATE SET pb.checker_clear_balance = workingbal ;

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
                80,
                account_id,
                'product_balance_internal',
                1,
                 'CBS_DATE'+cast(@v_application_date as nvarchar)+',cur bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar) +', credit sum '+ cast(credit as nvarchar)
                +', debit sum '+cast( debit as nvarchar),


                getdate(),
                - 1
            FROM
                #tempcasabalcheck
               SELECT
                               COUNT(1) successcount,
                               0 failurecount
                           FROM
                               #tempcasabalcheck
end 
else 
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
                80,
                account_id,
                'product_balance_internal',
                1,
                'CBS_DATE'+cast(@v_application_date as nvarchar)+',cur bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar) +', credit sum '+ cast(credit as nvarchar)
                +', debit sum '+cast( debit as nvarchar),


                getdate(),
                - 1
            FROM
                #tempcasabalcheck

        SELECT
                               COUNT(1) successcount,
                               0 failurecount
from
                                 #tempcasabalcheck
end



/*IA*/
truncate table #tempcasabalcheck
INSERT INTO #tempcasabalcheck
    SELECT
        *
    FROM
        (
            SELECT
				ROW_NUMBER() over (order by tit.principal_id) rownum,
                tit.principal_id,
                @v_application_date txn_date,
                tit.camount,
                tit.damount,
                isnull(pbpr.checker_clear_balance, 0) + tit.camount - tit.damount workingbal,
                pb.checker_clear_balance
   --  isnull(pbpr.checker_clear_balance, 0),
            FROM
                #temp_internaltransactionwoorking   tit
                INNER JOIN bsgaccounting..account_balance_internal      pb ON tit.principal_id = pb.ACCOUNT_ID
                                                               AND tit.principle_type = 'IA'
                INNER JOIN (
                    SELECT
                        ACCOUNT_ID,
                        MAX(txn_date) txn_date
                    FROM
                        bsgaccounting..account_balance_internal
                    WHERE
                        txn_date <= cast(@v_application_date as date)
                    GROUP BY
                        ACCOUNT_ID
                ) a ON pb.ACCOUNT_ID = a.ACCOUNT_ID
                       AND pb.txn_date = a.txn_date
                LEFT OUTER JOIN bsgaccounting..account_balance_internal      pbpr ON tit.principal_id = pbpr.ACCOUNT_ID
                INNER JOIN (
                    SELECT
                        ACCOUNT_ID,
                        MAX(txn_date) txn_date
                    FROM
                        bsgaccounting..account_balance_internal
                    WHERE
                        txn_date <= cast(@v_application_date -1 as date)
                    GROUP BY
                        ACCOUNT_ID
                ) b ON pbpr.ACCOUNT_ID = b.ACCOUNT_ID
                       AND pbpr.txn_date = b.txn_date
            WHERE
            tit.principle_type = 'IA' and 
                isnull(pbpr.checker_clear_balance, 0) + tit.camount - tit.damount <> pb.checker_clear_balance
        ) a
    WHERE
        ROWNUM <= @maxnoofrecoredupdate

if(@action_type = 'UPDATE')
begin 

     MERGE INTO bsgaccounting..account_balance_internal pb USING #tempcasabalcheck a ON ( pb.ACCOUNT_ID = a.account_id
                                                                                  AND pb.txn_date = a.txn_date )
        WHEN MATCHED THEN UPDATE SET pb.checker_clear_balance = workingbal ;

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
                80,
                account_id,
                'account_balance_internal',
                1,
                  'CBS_DATE'+cast(@v_application_date as nvarchar)+',cur bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar) +', credit sum '+ cast(credit as nvarchar)
                +', debit sum '+cast( debit as nvarchar),


                getdate(),
                - 1
            FROM
                #tempcasabalcheck
            SELECT
                               COUNT(1) successcount,
                               0 failurecount
                           FROM
                               #tempcasabalcheck
	end
else 
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
                80,
                account_id,
                'account_balance_internal',
                1,
                  'CBS_DATE'+cast(@v_application_date as nvarchar)+',cur bal :'
                + cast(abcurbal as nvarchar)
                + ',working bal :'
                + cast(workingbal as nvarchar) +', credit sum '+ cast(credit as nvarchar)
                +', debit sum '+cast( debit as nvarchar),


                getdate(),
                - 1
            FROM
                #tempcasabalcheck

       SELECT
                               COUNT(1) successcount,
                               0 failurecount
                           FROM
                               #tempcasabalcheck
	end

end
       

/*

    create global temporary table #temp_internaltransactionwoorking
    (
    principle_type VARCHAR(10),
    principal_id number(18,0),
    camount number(18,2),
    damount number(18,2)
    ) on commit preserve rows
*/

-- truncate  table #temp_internaltransactionwoorking

   --select * from bsgaccounting..account_balance_internal
