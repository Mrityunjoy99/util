-- =============================================
-- Author:		<Author,,Shubham Bhalerao>
-- Create date: <Create Date,,31/10/2022>
-- Description:	<Description,,Get product id based on product code>
-- =============================================
CREATE    PROCEDURE [dbo].[sp_get_bsbda_product_id]
	
AS
BEGIN
SELECT DISTINCT pm.product_id from BSGCORE..product_master pm
INNER JOIN BSGCORE..bsbda_rule_config brc
ON pm.product_code = brc.product_code
WHERE pm.is_active = 1 AND brc.is_active = 1
END
