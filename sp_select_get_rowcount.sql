IF OBJECT_ID('sp_select_get_rowcount') is not null
  BEGIN
    PRINT 'Dropping procedure sp_select_get_rowcount...'
    DROP PROCEDURE sp_select_get_rowcount
  END
 GO
/*
Created by: Filip De Vos
http://foxtricks.com

Usage:
    create table #myTempTable (id int, value varchar(100))
    insert into #myTempTable values (10, 'hihi'), (11, 'haha')

    Keep the connection open where the temptable is created and run the following query from any connection you want.

    exec sp_select_get_rowcount 'tempdb..#myTempTable'

    Also "normal" tables can be inspected.

    exec sp_select_get_rowcount 'msdb.dbo.MSdbms'

    If you suspect incorrect data on normal tables you can run.
    DBCC UPDATEUSAGE (myDbName, "mySchema.myTable");


*/
CREATE PROCEDURE dbo.sp_select_get_rowcount(@table_name sysname, @spid int = NULL)
AS
  SET NOCOUNT ON
  
  DECLARE @status int
        , @object_id int
        , @db_id int
        , @nsql nvarchar(1000)

  EXEC @status = sp_select_get_object_id @table_name = @table_name
                                       , @spid = @spid 
                                       , @object_id = @object_id output

  IF @object_id is null
    BEGIN
        RAISERROR('The table %s does not exist.', 16, 1, @table_name) 
        RETURN (-1)
    END 

  select @nsql = N'USE ' + PARSENAME(@table_name, 3) + '
    SELECT rows = SUM(st.row_count)
      FROM tempdb.sys.dm_db_partition_stats st
     WHERE index_id < 2
       AND object_id = @object_id'

  exec @status = sp_executesql @nsql, N'@object_id int', @object_id

  RETURN (@status)
GO
if OBJECT_ID('sp_select_get_rowcount') is null
  PRINT 'Failed to create procedure sp_select_get_rowcount...'
ELSE
  PRINT 'Correctly created procedure sp_select_get_rowcount...'
GO


