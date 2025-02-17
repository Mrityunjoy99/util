-- =============================================
-- Author:		<Author,,Shubham Bhalerao>
-- Create date: <Create Date,,14/10/2022>
-- Description:	<Description,, Get BSBDA Rule Config>
-- =============================================
create    PROCEDURE [dbo].[sp_get_bsbda_rule_config]  -- [sp_get_bsbda_rule_config] 2501, 1
    @productCode bigint,
	@status int = null
AS
BEGIN

	SELECT id, product_code, rule_id, rule_value, frequency, transaction_nature, authorization_status, created_by, created_date,
	last_modified_by, last_modified_date, is_active FROM BSGCORE..bsbda_rule_config WHERE product_code =  @productCode
	AND is_active = 1


END
