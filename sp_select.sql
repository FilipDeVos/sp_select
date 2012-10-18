IF OBJECT_ID('sp_select') is not null
  BEGIN
    PRINT 'Dropping procedure sp_select...'
    DROP PROCEDURE sp_select
  END
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
  
  DECLARE @status int
        , @object_id int
        , @db_id int

  EXEC @status = sp_select_get_object_id @table_name = @table_name
                                       , @spid = @spid 
                                       , @object_id = @object_id output
  
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
