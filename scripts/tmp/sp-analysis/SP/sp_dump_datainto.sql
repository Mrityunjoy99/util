-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[sp_dump_datainto]
AS
BEGIN
declare @cnt numeric(18,0) = 100
	while @cnt < 100001
	begin
		INSERT INTO [test1]
           (text1
           ,text2
           ,text3
           ,text4
           )
		select text1
           ,text2
           ,text3
           ,text4 from [test1]
	select @cnt = count(1) from [test1]
	end
END


