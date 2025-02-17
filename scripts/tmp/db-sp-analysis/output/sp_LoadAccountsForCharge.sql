create    PROCEDURE [dbo].[sp_LoadAccountsForCharge]  --  sp_LoadAccountsForCharge 'sp_test',1
    @sp_name VARCHAR(100),
    @charge_id INT
AS
BEGIN
    DECLARE @SQL VARCHAR(MAX) = 'EXEC ' + @sp_name + ';'
    EXEC(@SQL)
END
