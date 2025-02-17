-- =============================================
-- Author:        <Author,,pankaj yadav>
-- Create date: <Create Date,,31/10/2022>
-- Description:    <Description,,Get old account number list>
-- =============================================
create PROCEDURE [dbo].[sp_get_old_account_list] --[sp_get_old_account_list]    
AS
BEGIN
select old_account_no account_number from BSGCORE..account_number_mapping where is_active = 1
END
