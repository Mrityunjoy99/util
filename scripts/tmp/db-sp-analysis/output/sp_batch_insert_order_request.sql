CREATE   PROCEDURE dbo.sp_batch_insert_order_request
    @CreateOrderRequestList dbo.orderRequestTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
   
    -- Time variables
    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @EndTime DATETIME2;
    DECLARE @DurationInMilliseconds BIGINT;

    -- Temporary table to store only id and order_id
    DECLARE @InsertedDetails TABLE (
        id BIGINT,
        order_no VARCHAR(100)
    );

    -- Insert into the target table and capture id and order_id
    INSERT INTO dbo.order_request (
       txn_ref_no, status, account_id, ref_id, created_by, created_date,
       last_modified_by, last_modified_date, channel_type, order_no, metadata
    )
    OUTPUT inserted.id, inserted.order_no
    INTO @InsertedDetails
    SELECT 
        txn_ref_no, status, account_id, ref_id, created_by, created_date,
       last_modified_by, last_modified_date, channel_type, order_no, metadata
    FROM @CreateOrderRequestList;
   
    -- End time and duration
    SET @EndTime = SYSUTCDATETIME();
    SET @DurationInMilliseconds = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

    -- Return id and order_no of all inserted rows
    SELECT id, order_no FROM @InsertedDetails;
   
    -- Return duration as a separate result set
    SELECT @DurationInMilliseconds AS DurationInMilliseconds;
END;