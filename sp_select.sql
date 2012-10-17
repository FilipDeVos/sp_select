if OBJECT_ID('sp_select') is not null
  begin
    print 'Dropping procedure sp_select...'
    drop procedure sp_select
  end
 GO
/*
Created by: Filip De Vos
http://foxtricks.blogspot.com

Based on the post by Jonathan Kehayias
http://sqlblog.com/blogs/jonathan_kehayias/archive/2009/09/29/what-session-created-that-object-in-tempdb.aspx

Usage:
    create table #myTempTable (id int, value varchar(100))
    insert into #myTempTable values (10, 'hihi'), (11, 'haha')

    Keep the connection open where the temptable is created and run the following query from any connection you want.

    exec sp_select 'tempdb..#myTempTable'

    Also "normal" tables can be inspected.

    exec sp_select 'msdb.dbo.MSdbms'
*/
CREATE PROCEDURE dbo.sp_select(@table_name sysname, @spid int = NULL, @max_pages int = 1000)
AS
  SET NOCOUNT ON
  
  DECLARE @object_id int
        , @table     sysname
        , @db_name   sysname
        , @db_id     int
        , @file_name nvarchar(MAX)  
        , @status    int
        , @rowcount  int
  
  IF PARSENAME(@table_name, 3) = N'tempdb'
    begin
      SET @table = PARSENAME(@table_name, 1)
      
      IF (SELECT COUNT(*) from tempdb.sys.tables where name like @table + N'[_][_]%') > 1
        BEGIN
            -- determine the default trace file
            SELECT @file_name = SUBSTRING(path, 0, LEN(path) - CHARINDEX(N'\', REVERSE(path)) + 1) + N'\Log.trc'  
            FROM sys.traces   
            WHERE is_default = 1;  

            CREATE TABLE #objects (ObjectId sysname primary key)
            
            -- Match the spid with db_id and object_id via the default trace file
            insert into #objects
            SELECT o.object_id
            FROM sys.fn_trace_gettable(@file_name, DEFAULT) AS gt  
            JOIN tempdb.sys.objects AS o   
                 ON gt.ObjectID = o.object_id  
            LEFT JOIN (SELECT distinct spid, dbid 
                         FROM master..sysprocesses 
                        WHERE spid = @spid or @spid is null) dr
              ON dr.spid = gt.SPID
            WHERE gt.DatabaseID = 2 
              AND gt.EventClass = 46 -- (Object:Created Event from sys.trace_events)  
              AND o.create_date >= DATEADD(ms, -100, gt.StartTime)   
              AND o.create_date <= DATEADD(ms, 100, gt.StartTime)
              AND o.name like @table + N'[_][_]%'
              AND (gt.SPID = @spid or (@spid is null and dr.dbid = DB_ID()))
              
            SET @rowcount = @@ROWCOUNT
            
            IF @rowcount = 0 
              BEGIN
                RAISERROR('Unable to figure out which temp table with name [%s] to select, please run the procedure on a specific database, or specify a @spid to filter on.', 16,1, @table_name)
                RETURN(-1)
              END
            
            IF @rowcount > 1 and @spid is null
              BEGIN
                RAISERROR('There are %d temp tables with the name [%s] active in your database. Please specify the @spid you wish to find it for.', 16, 1, @rowcount, @table_name)
                RETURN(-1)
              END   
            
            IF @rowcount > 1
              BEGIN
                RAISERROR('There are %d temp tables with the name [%s] active on the spid %d. There must be something wrong in this procedure. Showing the first one', 16, 1, @rowcount, @table_name, @spid)
                -- We'll continue with the first match.
              END

            SELECT TOP 1 @object_id = ObjectId 
              FROM #objects
             ORDER BY ObjectId
        END
      ELSE
        BEGIN
          SELECT @object_id = object_id FROM tempdb.sys.tables WHERE name LIKE @table + N'[_][_]%'
        END
    END
  ELSE 
    SET @object_id = OBJECT_ID(@table_name)
  
  IF @object_id IS NULL
    BEGIN 
      RAISERROR('The table [%s] does not exist', 16, 1, @table_name)
      RETURN (-1)
    END
  
  SET @db_id = DB_ID(PARSENAME(@table_name, 3))
    
  EXEC @status = sp_selectpages @object_id = @object_id, @db_id = @db_id, @max_pages = @max_pages
  
  RETURN (@status)
GO
if OBJECT_ID('sp_select') is null
  PRINT 'Failed to create procedure sp_select...'
ELSE
  PRINT 'Correctly created procedure sp_select...'
GO
