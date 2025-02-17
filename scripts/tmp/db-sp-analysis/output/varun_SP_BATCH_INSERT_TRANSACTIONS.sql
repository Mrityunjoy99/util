CREATE PROCEDURE dbo.varun_SP_BATCH_INSERT_TRANSACTIONS
    @TransactionList dbo.varun_TransactionTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
   
    -- Time variables
    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @EndTime DATETIME2;
    DECLARE @DurationInMilliseconds BIGINT;

    -- Temporary table to store the required columns
    DECLARE @InsertedDetails TABLE (
        id BIGINT,
        txn_ref_no BIGINT,
        account_id BIGINT,
        scroll_no BIGINT,
        set_no BIGINT,
        txn_amount DECIMAL(18,2),
        txn_nature CHAR(1),
        txn_date DATE,
        txn_type INT,
        activity_id INT
    );

    -- Insert into the target table and capture the required columns
    INSERT INTO dbo.transaction_master (
        txn_ref_no, txn_sub_ref_no, txn_branch, home_branch,
        txn_date, txn_time, txn_type, txn_posting_date,
        txn_value_date, account_id, batch_code, scroll_no,
        set_no, txn_amount, txn_nature, instr_no, instr_date,
        activity_id, activity_sub_type_id, narration, sprinkle,
        is_active, created_by, created_date, last_modified_by,
        last_modified_date, fund_ext_date, fund_date, order_id
    )
    OUTPUT 
        inserted.id,
        inserted.txn_ref_no,
        inserted.account_id,
        inserted.scroll_no,
        inserted.set_no,
        inserted.txn_amount,
        inserted.txn_nature,
        inserted.txn_date,
        inserted.txn_type,
        inserted.activity_id -- Added activity_id
    INTO @InsertedDetails
    SELECT 
        txn_ref_no, txn_sub_ref_no, txn_branch, home_branch,
        txn_date, txn_time, txn_type, txn_posting_date,
        txn_value_date, account_id, batch_code, scroll_no,
        set_no, txn_amount, txn_nature, instr_no, instr_date,
        activity_id, activity_sub_type_id, narration, sprinkle,
        is_active, created_by, created_date, last_modified_by,
        last_modified_date, fund_ext_date, fund_date, order_id
    FROM @TransactionList;
   
    -- End time and duration
    SET @EndTime = SYSUTCDATETIME();
    SET @DurationInMilliseconds = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

    -- Return the captured columns
    SELECT 
        id,
        txn_ref_no,
        account_id,
        scroll_no,
        set_no,
        txn_amount,
        txn_nature,
        txn_date,
        txn_type,
        activity_id -- Added activity_id
    FROM @InsertedDetails;
   
    -- Return duration as a separate result set
    SELECT @DurationInMilliseconds AS DurationInMilliseconds;
END;