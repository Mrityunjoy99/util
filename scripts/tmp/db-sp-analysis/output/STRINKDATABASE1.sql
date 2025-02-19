
CREATE PROC [dbo].[STRINKDATABASE1]
AS
declare 	@GB AS INT  

 select @GB= sum(Used) from 
 (
 SELECT RTRIM(name) AS [Segment Name], groupid AS [Group Id], filename AS [File Name],
   CAST(size/128.0 AS DECIMAL(10,2)) AS [Allocated Size in MB],
   CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(10,2)) AS [Used]
FROM sysfiles
where groupid =1 
) b

SET @GB = @GB *1024
--IF OBJECT_ID ('tempdb.dbo.#dbcc_extent_info', 'U') IS NOT NULL

--DROP TABLE #dbcc_extent_info

--IF OBJECT_ID ('tempdb.dbo.#object_id', 'U') IS NOT NULL

--DROP TABLE #object_id

--GO

--PRINT 'Capturing allocated extent information. This could take a few minutes.'

--PRINT ''


CREATE TABLE #dbcc_extent_info (file_id int,page_id bigint,pg_alloc tinyint,ext_size tinyint,object_id bigint,index_id int,partition_number int, partition_id bigint,iam_chain_type varchar(30),pfs_bytes varbinary(255))

INSERT INTO #dbcc_extent_info EXEC ( 'DBCC EXTENTINFO' )


SELECT TOP 150 object_id , object_name(object_id) as object_name , file_id , page_id*8, (page_id*8)/1024
FROM #dbcc_extent_info
WHERE index_id = 0
AND page_id*8> @GB
ORDER BY page_id DESC


SELECT DISTINCT A.object_id , object_name(object_id) as object_name
,'alter table '+object_name(object_id)+' rebuild '
FROM
(
SELECT TOP 150 object_id 

FROM #dbcc_extent_info

WHERE index_id = 0
AND page_id*8 > @GB

ORDER BY page_id DESC

) as A 


-- select * from 
-- (
-- SELECT RTRIM(name) AS [Segment Name], groupid AS [Group Id], filename AS [File Name],
--   CAST(size/128.0 AS DECIMAL(10,2)) AS [Allocated Size in MB],
--   CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(10,2)) AS [Space Used in MB],
--   CAST([maxsize]/128.0 AS DECIMAL(10,2)) AS [Max in MB],
--   CAST([maxsize]/128.0-(FILEPROPERTY(name, 'SpaceUsed')/128.0) AS DECIMAL(10,2)) AS [Available Space in MB],
--   CAST((CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(10,2))/CAST([maxsize]/128.0 AS DECIMAL(10,2)))*100 AS DECIMAL(10,2)) AS [Percent Used]
--FROM sysfiles
--where groupid =1 
--) b
 declare @filename as varchar(1000)
declare @sql as varchar(1000)
declare @a as int
declare @Lower as int
declare @i as int
declare @diff as int
declare @database1 as varchar(1000)
declare @database2 as varchar(1000)

select @database1=name 
from sys.database_files
where  file_id=1

select @database2=name 
from sys.database_files
where  file_id!=1
order by file_id  

select @database1,@database2

DECLARE	@query as varchar(max)
DECLARE	@query1 as varchar(max)

DECLARE shrink CURSOR FOR
select   'CREATE CLUSTERED INDEX TempDROP1' + object_name(a.object_id) + ' ON ' + object_name(a.object_id) + ' (' + B.name +  ') '
from (
SELECT distinct object_id 
FROM #dbcc_extent_info
WHERE index_id = 0
AND page_id*8 > @GB
) as A  , SYS.COLUMNS B
where A.OBJECT_ID = B.OBJECT_ID 
and B.column_id = 1 and
b.object_id > 255 and type_name(system_type_id) not in (
'varbinary','binary'
)

OPEN shrink
FETCH NEXT FROM shrink INTO
	@query
WHILE @@FETCH_STATUS = 0 
BEGIN
	begin try
	print @query
	exec(@query)
	end try
	begin catch	
	end catch

FETCH NEXT FROM shrink INTO
	@query
END

CLOSE		shrink
DEALLOCATE	shrink
 select @filename=s,@diff=(a),@Lower = u
 from 
 (
 SELECT RTRIM(name) AS s,
   CAST(size/128.0 AS DECIMAL(10,2)) AS a,
   CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(10,2)) AS u
FROM sysfiles
where groupid =1 
)B 
order by s

set @i =@diff
			while(@i > @Lower)
			begin 
					if @i < @Lower
					begin
						set @i = @Lower
					end 
					set @sql ='DBCC SHRINKFILE ('+@database1+','+str(@i)+')
								DBCC SHRINKFILE ('+@database2+','+str(@i)+')
								'
					set @i =@i-1000
					print @sql
					exec (@sql)
			end
					set @sql ='DBCC SHRINKFILE ('+@database1+','+str(@Lower)+')
								DBCC SHRINKFILE ('+@database2+','+str(@Lower)+')
								'
					set @i =@i-1000
					print @sql
					exec (@sql)



DECLARE shrink1 CURSOR FOR
select 'drop INDEX ' + OBJECT_NAME(object_id) + '.' + name from sys.indexes where name like 'TempDROP1%'
OPEN shrink1
FETCH NEXT FROM shrink1 INTO
	@query1
WHILE @@FETCH_STATUS = 0 
BEGIN
	begin try	
	print @query1
	exec(@query1)
	end try
	begin catch	
	end catch

FETCH NEXT FROM shrink1 INTO
	@query1
END

CLOSE		shrink1
DEALLOCATE	shrink1
