CREATE   PROCEDURE [dbo].[sp_backup_bod] -- [sp_backup_bod] @backupLocation='G:\bsgturing\turing_backup\'

AS
begin
declare  @databaseName sysname = null
declare  @backupType CHAR(1) = null
declare  @backupLocation nvarchar(400) = null

create table #temp1
(
id int identity,
output nvarchar(max)
)

	--begin try
	--insert into #temp1
	--EXEC XP_CMDSHELL 'Dir J:' 
	--if((select output from #temp1 where id =1) != ' Volume in drive J is Application')
	--begin
	--	EXEC XP_CMDSHELL 'net use J: \\192.168.1.115\db_backup /USER:administrator'
	--	print 'drive map'
	--end
	----select * from #temp1
	--end try
	--begin catch
	--	print 'drive allready map'
	--end catch


set @backupLocation='E:\BACKUP\'
-- set @backupLocation='H:\'
 SET NOCOUNT ON;
 
 DECLARE @DBs TABLE
 (
 ID int IDENTITY PRIMARY KEY,
 DBNAME nvarchar(500),
 dbCreatedate datetime
 )
 
 declare @succes_count int =0,@failure_count int =0
 
 -- Pick out only databases which are online in case ALL databases are chosen to be backed up
 -- If specific database is chosen to be backed up only pick that out from @DBs
 INSERT INTO @DBs (DBNAME,dbCreatedate)
 SELECT name,create_date FROM master.sys.databases
 where state=0 and database_id  > 4
 AND name like '%BSG%'
 
 -- in ( 'BSGACCOUNTING','BSGTURINGREPORTS','BSGPAYMENTGATEWAY','BSGADMIN','BSGCBR','BSGCBSFILES','BSGCORE','BSGCRM','BSGLOAN','BSGLOCKER','BSGMASTER','BSGREMITTANCE','BSGTD','BSGTURING')
-- AND name=@DatabaseName
 --OR @DatabaseName IS NULL
 --ORDER BY Name
 
 -- Filter out databases which do not need to backed up
 --IF @backupType='F'
 --BEGIN
 --DELETE @DBs where DBNAME IN ('tempdb','Northwind','pubs','AdventureWorks')
 --END
 --ELSE IF @backupType='D'
 --BEGIN
 --DELETE @DBs where DBNAME IN ('tempdb','Northwind','pubs','master','AdventureWorks')
 --END
 --ELSE IF @backupType='L'
 --BEGIN
 --DELETE @DBs where DBNAME IN ('tempdb','Northwind','pubs','master','AdventureWorks')
 --END
 --ELSE
 --BEGIN
 --RETURN
 --END
 
 -- Declare variables
 DECLARE @BackupName varchar(200)
 DECLARE @BackupFile varchar(200)
 DECLARE @DBNAME varchar(300)
 DECLARE @sqlCommand NVARCHAR(1000)
 DECLARE @dateTime NVARCHAR(20)
 DECLARE @Loop int
 declare @createdate datetime
 declare @rootlocation nvarchar(400)
 declare @archiveCommand  nvarchar(400)
 declare @deletebak nvarchar(400) = ''
 set @rootlocation = @backupLocation
 declare @mysqldatabase nvarchar(500)
 declare @servername nvarchar(200)
 -- Loop through the databases one by one
 SELECT @Loop = min(ID) FROM @DBs
 
 WHILE @Loop IS NOT NULL
 BEGIN
 BEGIN TRY
-- Database Names have to be in [dbname] formate since some have - or _ in their name
 SET @DBNAME = ''+(SELECT DBNAME FROM @DBs WHERE ID = @Loop)+''
 
  SET @createdate = (SELECT dbCreatedate FROM @DBs WHERE ID = @Loop)


if(datename(dw,GETDATE()) = 'Sunday') --
begin
	set @backupType = 'F'
end
else
begin
	set @backupType = 'D'
end

if CAST(@createdate as date) = cast(GETDATE() as date)
begin
	set @backupType = 'F'
end
set @backupType = 'F'

 --select right(@DBNAME,len(@DBNAME) - CHARINDEX('_',@DBNAME))
 set @backupLocation = @rootlocation + '\'+ replace(cast(GETDATE() as date),'-','_')+'_eod\'+ right(@DBNAME,len(@DBNAME) - CHARINDEX('_',@DBNAME))  
 
--set @backupLocation = @rootlocation + right(@DBNAME,len(@DBNAME) - CHARINDEX('_',@DBNAME)) + '\'+ replace(cast(GETDATE() as date),'-','_')+'\'+
--	case when CHARINDEX('_',@DBNAME) > 0 then left(@DBNAME, CHARINDEX('_',@DBNAME)-1) else @DBNAME end --replace(replace(CONVERT(VARCHAR(19),GETDATE()),' ','_'),':','_')
 
declare @exists table (directory nvarchar(100), depth int)
insert into @exists
EXEC master.sys.xp_dirtree @backupLocation 


if((select COUNT(*) from @exists) = 0)
begin


 set @backupLocation = @backupLocation --+ '\'+ right(@DBNAME,len(@DBNAME) - CHARINDEX('_',@DBNAME))  
	 EXEC master.dbo.xp_create_subdir @backupLocation 	
end
  set @backupLocation += '\'
-- Set the current date and time n yyyyhhmmss format
 SET @dateTime = REPLACE(CONVERT(VARCHAR, GETDATE(),101),'/','') + '_' + REPLACE(CONVERT(VARCHAR, GETDATE(),108),':','')
 
-- Create backup filename in path\filename.extension format for full,diff and log backups
 IF @backupType = 'F'
 SET @BackupFile = @backupLocation+REPLACE(REPLACE(@DBNAME, '[',''),']','')+ '_FULL_'+ @dateTime+ '.BAK'
 ELSE IF @backupType = 'D'
 SET @BackupFile = @backupLocation+REPLACE(REPLACE(@DBNAME, '[',''),']','')+ '_DIFF_'+ @dateTime+ '.BAK'
 ELSE IF @backupType = 'L'
 SET @BackupFile = @backupLocation+REPLACE(REPLACE(@DBNAME, '[',''),']','')+ '_LOG_'+ @dateTime+ '.TRN'
 
-- Provide the backup a name for storing in the media
 IF @backupType = 'F'
 SET @BackupName = REPLACE(REPLACE(@DBNAME,'[',''),']','') +' full backup for '+ @dateTime
 IF @backupType = 'D'
 SET @BackupName = REPLACE(REPLACE(@DBNAME,'[',''),']','') +' differential backup for '+ @dateTime
 IF @backupType = 'L'
 SET @BackupName = REPLACE(REPLACE(@DBNAME,'[',''),']','') +' log backup for '+ @dateTime
 
-- Generate the dynamic SQL command to be executed
 
 IF @backupType = 'F'
 BEGIN
 SET @sqlCommand = 'BACKUP DATABASE ' +@DBNAME+ ' TO DISK = '''+@BackupFile+ ''' WITH INIT, NAME= ''' +@BackupName+''', NOSKIP, NOFORMAT'
 END
 IF @backupType = 'D'
 BEGIN
 SET @sqlCommand = 'BACKUP DATABASE ' +@DBNAME+ ' TO DISK = '''+@BackupFile+ ''' WITH DIFFERENTIAL, INIT, NAME= ''' +@BackupName+''', NOSKIP, NOFORMAT'
 END
 IF @backupType = 'L'
 BEGIN
 SET @sqlCommand = 'BACKUP LOG ' +@DBNAME+ ' TO DISK = '''+@BackupFile+ ''' WITH INIT, NAME= ''' +@BackupName+''', NOSKIP, NOFORMAT'
 END
 
-- Execute the generated SQL command
 
 print @sqlCommand
 EXEC(@sqlCommand)

set @succes_count +=1;
insert into BSGTURING..turing_task_result(task_id,task_ref_id,task_ref_table,response_code,message,created_date,created_by)
values(77,@succes_count,@DBNAME,1,@DBNAME,GETDATE(),1)
-- Goto the next database
SELECT @Loop = min(ID) FROM @DBs where ID>@Loop
 END TRY
 BEGIN CATCH
	SELECT @Loop = min(ID) FROM @DBs where ID>@Loop
 --insert into bsgdeepfreeze..error_deepfreeze(table_name,records_count,errormsg,created_date)
 --select @DBNAME,0 records_count,ERROR_MESSAGE(),getdate() 
 
 END CATCH
END

-- --Delete 10 days back file 
--select @succes_count succes_count,@failure_count failure_count
--set @deletebak  = 'RMDIR '+@rootlocation + '\'+ replace(cast(dateadd(day, -10,GETDATE()) as date),'-','_')+'_eod /s /q'
--exec  xp_cmdshell @deletebak

--declare @writetrgfile nvarchar(400) ='echo 1  >'+ @rootlocation+'\'+replace(cast( GETDATE() as date),'-','_')+'_eod.trg'
--EXECUTE Master.dbo.xp_CmdShell  @writetrgfile

end

