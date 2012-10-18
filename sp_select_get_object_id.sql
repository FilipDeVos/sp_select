IF OBJECT_ID('sp_select_get_object_id') is not null
  BEGIN
    PRINT 'dropping procedure sp_select_get_object_id'
    DROP PROCEDURE sp_select_get_object_id
  END
GO
/*
declare @object_id int
exec sp_select_get_object_id 'tempdb..#t', default, @object_id output
select @object_id
*/
CREATE PROCEDURE sp_select_get_object_id(@table_name sysname, @spid int = null, @object_id int output)
As
  DECLARE @table     sysname
        , @db_name   sysname
        , @db_id     int
        , @file_name nvarchar(MAX)  
        , @status    int
        , @rowcount  int

  IF PARSENAME(@table_name, 3) = N'tempdb'
    BEGIN
      SET @table = PARSENAME(@table_name, 1)
      
      IF (SELECT COUNT(*) from tempdb.sys.tables where name like @table + N'[_][_]%') > 1
        BEGIN
            -- determine the default trace file
            SELECT @file_name = SUBSTRING(path, 0, LEN(path) - CHARINDEX(N'\', REVERSE(path)) + 1) + N'\Log.trc'  
            FROM sys.traces   
            WHERE is_default = 1;  

            CREATE TABLE #objects (ObjectId sysname primary key)
            
            -- Match the spid with db_id and object_id via the default trace file
            INSERT INTO #objects
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
  
RETURN (0)
GO
if OBJECT_ID('sp_select_get_object_id') is null
  PRINT 'Failed to create procedure sp_select_get_object_id...'
ELSE
  PRINT 'Correctly created procedure sp_select_get_object_id...'
GO