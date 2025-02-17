
create    PROCEDURE [dbo].[getSMSList] -- [getSMSList] 13 
(@smsTypeId INT) 
AS 
  BEGIN 
      DECLARE @cbsAppDate DATETIME; 

      CREATE TABLE #tempsms 
        ( 
           mobileno   VARCHAR(20), 
           smscontent VARCHAR(1000) 
        ); 

      SET @cbsAppDate = (SELECT app_date 
                         FROM   bsgaccounting..cbs_application_date WITH (nolock 
                                ) 
                         WHERE  is_active = 1); 
      SET @cbsAppDate = CAST(DATEADD(DAY, -1, @cbsAppDate) AS DATE); 

      IF ( @smsTypeId = 1 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END, 
                   sm.sms_template 
            --A.accountId, 
            --ca.account_no, 
            --ca.classification_id 
            FROM   (SELECT account_id AS accountId 
                    FROM   bsgcore..account_master WITH (nolock) 
                    WHERE  Cast(account_open_date AS DATE) = @cbsAppDate 
                           AND account_status_id = 1 
                           AND is_active = 1 
                    UNION ALL 
                    SELECT td_account_id AS accountId 
                    FROM   bsgtd..td_account_master WITH (nolock) 
                    WHERE  Cast(account_open_date AS DATE) = @cbsAppDate 
                           AND account_status_id = 1 
                           AND is_active = 1 
                    UNION ALL 
                    SELECT loan_account_id AS accountId 
                    FROM   bsgloan..loan_account_master WITH (nolock) 
                    WHERE  Cast(date_of_account_opening AS DATE) = @cbsAppDate 
                           AND loan_account_status = 1 
                           AND is_active = 1) A 
                   INNER JOIN bsgcore..customer_accounts ca WITH (nolock) 
                           ON ca.account_id = A.accountid 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = ca.customer_id 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = ca.customer_id 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = @smsTypeId; 
        END; 

      IF ( @smsTypeId = 2 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END                                            AS mobileNo, 
                   Replace(Replace(sm.sms_template, 'FD_MATURITY_DATE', 
                           Replace( 
                                   CONVERT(NVARCHAR, maturity_date, 106), ' ', 
                           '-') 
                           ), 
                   'ACCOUNT', 
                   Concat('XXXXXXXXXX', RIGHT(ca.account_no, 4))) AS smsContent 
            FROM   bsgtd..td_account_master tam WITH (nolock), 
                   bsgtd..td_account_deposit_details tdd WITH (nolock) 
                   INNER JOIN bsgcore..customer_accounts ca WITH (nolock) 
                           ON ca.account_id = tdd.td_account_id 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = ca.customer_id 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = ca.customer_id 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = 2 
            WHERE  tam.td_account_id = tdd.td_account_id 
                   AND tam.account_status_id IN ( 1 ) 
                   AND Cast(tdd.maturity_date AS DATE) = Cast( 
                       Dateadd(day, sm.number_of_days, @cbsAppDate) AS DATE) 
                   AND tam.is_active = 1 
                   AND tdd.is_active = 1 
                   AND auto_renewal = 0; 
        END; 

      IF ( @smsTypeId = 3 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END         AS mobileNo, 
                   Replace(Replace(Replace(sm.sms_template, 
                                   'RD_INSTALLMENT_DUE_DATE', 
                                   Replace( 
                                                   CONVERT(NVARCHAR, due_date, 
                                                   106 
                                                   ), 
                                   ' ' 
                                   , 
                                   '-')), 
                           'ACCOUNT', 
                                   Concat('XXXXXXXXXX', RIGHT(ca.account_no, 4)) 
                           ), 
                   'AMOUNT', 
                   rim.amount) AS smsContent 
            FROM   bsgtd..td_account_master tam WITH (nolock), 
                   bsgtd..rd_installment_master rim WITH (nolock) 
                   INNER JOIN bsgcore..customer_accounts ca WITH (nolock) 
                           ON ca.account_id = rim.td_account_id 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = ca.customer_id 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = ca.customer_id 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = 3 
            WHERE  tam.td_account_id = rim.td_account_id 
                   AND tam.account_status_id IN ( 1 ) 
                   AND Cast(rim.due_date AS DATE) = Cast( 
                       Dateadd(day, sm.number_of_days, @cbsAppDate) 
                       AS DATE) 
                   AND tam.is_active = 1 
                   AND rim.received_date IS NULL; 
        END; 

      IF ( @smsTypeId = 4 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END 
                   AS 
                   mobileNo, 
                   Replace(Replace(Replace(sm.sms_template, 'ACCOUNT', 
                                           Concat('XXXXXXXXXX', 
                                           RIGHT(ca.account_no, 4 
                                           ) 
                                                   )), 'AMOUNT', 
                   lsi.debit_amount), 
                   'SI_DATE', 
                   Replace(CONVERT(NVARCHAR, lsi.next_si_date, 106), ' ', '-')) 
                   AS 
                   smsContent 
            FROM   bsgloan..loan_si_instruction lsi WITH (nolock) 
                   INNER JOIN bsgcore..customer_accounts ca WITH (nolock) 
                           ON ca.account_id = lsi.debit_account_id 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = ca.customer_id 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = ca.customer_id 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = @smsTypeId 
            WHERE  lsi.next_si_date = Cast(Dateadd(day, sm.number_of_days, 
                                           @cbsAppDate 
                                           ) 
                                           AS 
                                           DATE) 
                   AND cancel <> 1 
                   AND lsi.is_active = 1; 
        END; 

      IF ( @smsTypeId = 5 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT h.mobileno, 
                   Replace(Replace(h.sms_template, 'AMOUNT', h.overdue_amount), 
                   'ACCOUNT', 
                   Concat( 
                   'XXXXXXXXXX', RIGHT(h.account_no, 4))) AS smsContent 
            FROM   (SELECT lam.loan_account_no account_no, 
                           a.overdue_amount    overdue_amount, 
                           CASE 
                             WHEN ccm.mobile_no IS NULL THEN 
                             cm.registered_mobile_no 
                             ELSE ccm.mobile_no 
                           END                 AS mobileNo, 
                           sm.sms_template 
                    FROM   bsgloan..loan_account_master lam 
                           INNER JOIN bsgaccounting..account_balance_loan a 
                                   ON lam.loan_account_id = a.loan_account_id 
                                      AND lam.loan_account_status = 1 
                                      AND lam.is_active = 1 
                           INNER JOIN (SELECT loan_account_id, 
                                              Max(txn_date) date 
                                       FROM 
                           bsgaccounting..account_balance_loan 
                                       GROUP  BY loan_account_id) c 
                                   ON a.loan_account_id = c.loan_account_id 
                                      AND a.txn_date = c.date 
                                      AND overdue_amount >= (SELECT config_value 
                                                             FROM 
                                          bsgadmin..cbs_config 
                                                             WHERE 
                                          config_key = 'LOAN_OVERDUE_THRESHOLD') 
                                      AND overdue_days_count = 1 
                           LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH ( 
                                     nolock) 
                                  ON ccm.customer_id = lam.customer_no 
                                     AND ccm.channel = 'SMS' 
                                     AND ccm.is_active = 1 
                           LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                                  ON cm.customer_id = lam.customer_no 
                                     AND cm.is_active = 1 
                                     AND cm.customer_status_code = 1 
                           INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                                   ON sm.sms_type_id = @smsTypeId 
                                      AND sm.is_active = 1) h; 
        END; 

      IF ( @smsTypeId = 6 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END                                    AS mobileNo, 
                   Replace(sm.sms_template, 'ACCOUNT', 
                   Concat('XXXXXXXXXX', RIGHT(ca.account_no, 4) 
                   )) AS smsContent 
            FROM   bsgcore..account_master am WITH (nolock) 
                   INNER JOIN bsgcore..customer_accounts ca WITH (nolock) 
                           ON ca.account_id = am.account_id 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = ca.customer_id 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = ca.customer_id 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = 6 
                              AND sm.is_active = 1 
            WHERE  am.account_status_id = 7 
                   AND Cast(am.created_date AS DATE) = @cbsAppDate 
                   AND am.is_active = 1; 
        END; 

      IF ( @smsTypeId = 7 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT cm.registered_mobile_no, 
                   sm.sms_template -- cm.customer_id, cid.date_of_birth 
            FROM   bsgcrm..customer_master cm WITH (nolock) 
                   INNER JOIN bsgcrm..customer_ind_info cid WITH (nolock) 
                           ON cm.customer_id = cid.customer_id 
                              AND Month(cid.date_of_birth) = Month(Getdate()) 
                              AND Day(cid.date_of_birth) = Day(Getdate()) 
                              AND Year(cid.date_of_birth) > 1900 
                              AND cid.is_active = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = @smsTypeId 
                              AND sm.is_active = 1 
            WHERE  cm.is_active = 1; 
        END; 

      IF ( @smsTypeId = 8 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END 
                   AS 
                   mobileNo, 
                   Replace(Replace(sm.sms_template, 'LIMIT_EXPIRY_DATE', 
                           Replace( 
                                   CONVERT(NVARCHAR, lab.limit_expiry_date, 106) 
                           , 
                           ' ', 
                           '-' 
                           )) 
                   , 
                   'ACCOUNT', Concat('XXXXXXXXXX', RIGHT(lam.loan_account_no, 4) 
                              )) 
                   AS 
                   smsContent 
            FROM   bsgloan..loan_account_basic lab WITH (nolock) 
                   INNER JOIN bsgloan..loan_account_master lam WITH (nolock) 
                           ON lam.loan_account_id = lab.loan_account_id 
                              AND lam.loan_account_status <> 2 
                              AND lam.loan_type = 2 
                              AND lam.is_active = 1 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = lam.customer_no 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = lam.customer_no 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = @smsTypeId 
                              AND sm.is_active = 1 
            WHERE  Cast(lab.limit_expiry_date AS DATE) = Cast( 
                          Dateadd(day, sm.number_of_days, @cbsAppDate) AS DATE) 
                   AND lab.is_active = 1; 
        END; 

      IF ( @smsTypeId = 9 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT DISTINCT CASE 
                              WHEN ccm.mobile_no IS NULL THEN 
                              cm.registered_mobile_no 
                              ELSE ccm.mobile_no 
                            END 
                            AS mobileNo, 
                            Replace(Replace(Replace(Replace(sm.sms_template,'AMOUNT',lie.insurance_amount), 
                                            'CLASSIFICATION', 
                                            CASE 
                                                    WHEN lam.loan_type = 1 THEN 
                                                    'LOAN' 
                                                    ELSE 'CC' 
                                            END), 
                                    'INSURANCE_EXPIRY_DATE' 
                                    , Replace(CONVERT(NVARCHAR, 
                                              lie.insurance_expiry_date, 
                                              106), ' ', '-')), 
                            'ACCOUNT', Concat('XXXXXXXXXX', 
                                       RIGHT(lam.loan_account_no, 
                                       4 
                                       ))) 
                            AS smsContent 
            FROM   bsgloan..loan_insurance_entry lie WITH (nolock) 
                   INNER JOIN bsgloan..loan_account_master lam WITH (nolock) 
                           ON lam.loan_account_id = lie.loan_account_id 
                              AND lam.loan_account_status <> 2 
                              AND lam.is_active = 1 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = lam.customer_no 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = lam.customer_no 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = 9 
                              AND sm.is_active = 1 
            WHERE  lie.insurance_expiry_date = Cast( 
                       Dateadd(day, sm.number_of_days, @cbsAppDate 
                       ) AS 
                       DATE) 
                   AND lie.is_active = 1; 
        END; 



      IF ( @smsTypeId = 10 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT DISTINCT
			 CASE 
				 WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
				 ELSE ccm.mobile_no 
			END 
				AS mobileNo,
			Replace(Replace(sm.sms_template, 'DP_EXPIRY_DATE', 
								   Replace( 
										   CONVERT(NVARCHAR, A.expriy_date, 106) 
								   , 
								   ' ', 
								   '-' 
								   )) 
						   , 
						   'ACCOUNT', Concat('XXXXXXXXXX', RIGHT(A.loan_account_no, 4) 
									  )) 
						   AS 
						   smsContent 
		FROM
			(SELECT 
				lbd.loan_account_id, 
				lam.customer_no,
				lam.loan_account_no,
				CASE 
					WHEN 
						(lbd.dp_expiry_date > lab.limit_expiry_date) 
						THEN lab.limit_expiry_date 
					ELSE
						lbd.dp_expiry_date 
				END AS expriy_date
			FROM
				BSGLOAN..loan_stock_bd_details lbd WITH (NOLOCK) 
					INNER JOIN 
				BSGLOAN..loan_account_master lam WITH (NOLOCK) 
					ON 
						lam.loan_account_id = lbd.loan_account_id AND 
						lam.loan_account_status <> 2 AND 
						lam.loan_type = 2 AND 
						lam.is_active = 1 
					INNER JOIN
				BSGLOAN..loan_account_basic lab WITH (NOLOCK) 
					ON
						lab.loan_account_id = lbd.loan_account_id AND 
						lab.is_active=1
			WHERE
				lbd.is_active = 1)A
				LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (NOLOCK) 
								  ON ccm.customer_id = A.customer_no 
									 AND ccm.channel = 'SMS' 
									 AND ccm.is_active = 1 
						   LEFT JOIN bsgcrm..customer_master cm WITH (NOLOCK) 
								  ON cm.customer_id = A.customer_no 
									 AND cm.is_active = 1 
									 AND cm.customer_status_code = 1 
						   INNER JOIN bsgaccounting..sms_master sm WITH (NOLOCK) 
								   ON sm.sms_type_id = @smsTypeId 
									  AND sm.is_active = 1 

		WHERE CAST(A.expriy_date AS DATE) = CAST(DATEADD(DAY, sm.number_of_days, @cbsAppDate) AS DATE);
        END; 


      IF ( @smsTypeId = 11 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
          
SELECT DISTINCT
			 CASE 
				 WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
				 ELSE ccm.mobile_no 
			END 
				AS mobileNo,
			Replace(Replace(Replace(sm.sms_template,'AMOUNT',h.installment_amount), 'LOAN_EMI_DUE_DATE', 
								   Replace( 
										   CONVERT(NVARCHAR, CAST(h.installment_date AS DATE), 106) 
								   , 
								   ' ', 
								   '-' 
								   )) 
						   , 
						   'ACCOUNT', Concat('XXXXXXXXXX', RIGHT(h.loan_account_no, 4) 
									  )) 
						   AS 
						   smsContent 
		FROM
			(select 
				a.loan_account_no,
				concat(year(@cbsAppDate),'-',month(@cbsAppDate),'-',day(installment_start_date)) installment_date,
				installment_amount,
				a.customer_no,
				b.installment_frequency,
				b.installment_start_date
				from
			bsgloan..loan_account_master a
			inner join
			bsgloan..loan_account_basic b
			on
			a.loan_account_id=b.loan_account_id
			and a.is_active=1
			and b.is_active=1
			and loan_account_status<>2
			and repayment_mode=1
			and installment_start_date<=@cbsAppDate
			and limit_expiry_date>=@cbsAppDate)h
		    LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH ( 
					 nolock) 
				  ON ccm.customer_id = h.customer_no 
					 AND ccm.channel = 'SMS' 
					 AND ccm.is_active = 1 
		    LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
				  ON cm.customer_id = h.customer_no 
					 AND cm.is_active = 1 
					 AND cm.customer_status_code = 1 
		    INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
				   ON sm.sms_type_id = @smsTypeId 
					  AND sm.is_active = 1
			WHERE (
						day(@cbsAppDate)  + sm.number_of_days = day(installment_start_date)
						or
			(EOMONTH(@cbsAppDate)=dateadd(day,sm.number_of_days,@cbsAppDate ) and day(installment_start_date)>=day(@cbsAppDate)  + sm.number_of_days)
					)
			and (
					installment_frequency=1 or
					(installment_frequency=2 and abs(month(@cbsAppDate)-month(installment_start_date))%3=0) or
					(installment_frequency=3 and abs(month(@cbsAppDate)-month(installment_start_date))%6=0) or
					(installment_frequency=4 and abs(month(@cbsAppDate)-month(installment_start_date))=0)
				);
        END; 

		IF ( @smsTypeId = 12 ) 
        BEGIN 
            INSERT INTO #tempsms 
                        (mobileno, 
                         smscontent) 
            SELECT CASE 
                     WHEN ccm.mobile_no IS NULL THEN cm.registered_mobile_no 
                     ELSE ccm.mobile_no 
                   END                                            AS mobileNo, 
                   Replace(Replace(sm.sms_template, 'FD_MATURITY_DATE', 
                           Replace( 
                                   CONVERT(NVARCHAR, maturity_date, 106), ' ', 
                           '-') 
                           ), 
                   'ACCOUNT', 
                   Concat('XXXXXXXXXX', RIGHT(ca.account_no, 4))) AS smsContent 
            FROM   bsgtd..td_account_master tam WITH (nolock), 
                   bsgtd..td_account_deposit_details tdd WITH (nolock) 
                   INNER JOIN bsgcore..customer_accounts ca WITH (nolock) 
                           ON ca.account_id = tdd.td_account_id 
                   LEFT JOIN bsgcrm..customer_channel_mobile ccm WITH (nolock) 
                          ON ccm.customer_id = ca.customer_id 
                             AND ccm.channel = 'SMS' 
                             AND ccm.is_active = 1 
                   LEFT JOIN bsgcrm..customer_master cm WITH (nolock) 
                          ON cm.customer_id = ca.customer_id 
                             AND cm.is_active = 1 
                             AND cm.customer_status_code = 1 
                   INNER JOIN bsgaccounting..sms_master sm WITH (nolock) 
                           ON sm.sms_type_id = 2 
            WHERE  tam.td_account_id = tdd.td_account_id 
                   AND tam.account_status_id IN ( 1 ) 
                   AND Cast(tdd.maturity_date AS DATE) = Cast( 
                       Dateadd(day, sm.number_of_days, @cbsAppDate) AS DATE) 
                   AND tam.is_active = 1 
                   AND tdd.is_active = 1 
                   AND auto_renewal = 1; 
        END; 
      SELECT mobileno, 
             smscontent 
      FROM   #tempsms; 

      DROP TABLE #tempsms 


	  IF ( @smsTypeId = 13 ) 
	  BEGIN

		select 
			ca.account_id,max(txn_date)  txn_date into #temp_tr 
		from 
			bsgcore..customer_accounts ca with (nolock)
		inner join
			BSGCORE..account_master am
		on 
			ca.account_id = am.account_id
		and 
			am.product_code <> 2004
		left join 
			BSGACCOUNTING..transaction_master tm with (nolock)
		on	
			ca.account_id = tm.account_id
		and 
			activity_id not in (11081,11067,11069,11065,11063,11071,11073,11113,1003,1004)
		and 
			tm.narration not like 'Interest Credit%'
		and 
			tm.narration not like '%Charg%' 
		and 
			tm.narration not like '%CGST%' 
		and 
			tm.narration not like '%SGST%'
		where 
			ca.is_active=1

		and 
			am.account_open_date < DATEADD(month,-1*23,getdate())
		
		and
			am.is_active=1
		and 
			
				  am.account_status_id not in (3,5,4,7,8)
						 
		group by ca.account_id
		having (max(txn_date) is null or max(txn_date) < DATEADD(month,-1*23,getdate()))


		select 
			ca.account_id,max(tm.txn_date)  txn_date into #temp_df
		from 
			#temp_tr ca
		inner join 
			bsgdeepfreeze..transaction_master_df tm with (nolock)
		on	
			ca.account_id = tm.account_id
		and 
			tm.narration not like 'Interest Credit%'
		and 
			tm.narration not like '%Charg%' 
		and 
			tm.narration not like '%CGST%' 
		and 
			tm.narration not like '%SGST%'
		where 			
			activity_id not in (11081,11067,11069,11065,11063,11071,11073,11113,1003,1004)			 
		group by ca.account_id
		having ( max(tm.txn_date) = DATEADD(month,-1*23,getdate()))

		--select * into #tempdftr from #temp_tr where account_id not in (select account_id from #temp_df)

		delete #temp_tr where account_id in (select account_id from #temp_df)

			select 
			ca.account_id,max(tm.txn_date)  txn_date into #temp_history
		from 
			#temp_tr ca
		inner join 
			bsgdeepfreeze..transaction_master_history tm with (nolock)
		on	
			ca.account_id = tm.account_id
		where 			
			activity_id not in (11081,11067,11069,11065,11063,11071,11073,11113,1003,1004)			 
		group by ca.account_id
		having ( max(tm.txn_date) = DATEADD(month,-1*23,getdate()))

		--select * into #tempdftr from #temp_tr where account_id not in (select account_id from #temp_df)

		delete #temp_tr where account_id in (select account_id from #temp_history)



		select 
			ca.account_id,alt.LastTranDate  txn_date into #temp_acclast
		from 
			bsgcore..customer_accounts ca with (nolock)
		inner join
			#temp_tr am
		on 
			ca.account_id = am.account_id
		left join 
			BSGTURINGREPORTS..accountlasttransaction alt
		on 
			ca.account_no = alt.AccountNo
		where 
			am.txn_date is null
		and 
			ca.is_active=1		 		
		and 
			alt.LastTranDate =  DATEADD(month,-1*23,getdate())
		--and 
			--case when 23 > 24 then 1 else 0 end  = 1


		;with cte as (
		select * from #temp_tr
		where  
			account_id not in (
			select tr.account_id from #temp_acclast tr		 	
			)
		
			
		)

	select distinct am.account_id  from cte c inner join 
			BSGCORE..account_master am with (nolock)
			on 
				c.account_id = am.account_id
		where am.is_active=1 order by am.account_id;

		--return 

		 END


	
END


 




