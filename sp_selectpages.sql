if OBJECT_ID('sp_selectpages') is not null
  BEGIN
    PRINT 'dropping procedure sp_selectpages'
    DROP PROCEDURE sp_selectpages
  END
GO
/*
Original Version: John Huang's

Revised by: Fabiano Neves Amorim
E-Mail: fabiano_amorim@bol.com.br
http://fabianosqlserver.spaces.live.com/
http://www.simple-talk.com/author/fabiano-amorim/

Revised by: Filip De Vos
http://foxtricks.blogspot.com

Usage:

DECLARE @i Int
declare @d int
set @d = db_id('acc_fsdb35_it1')
SET @i = object_id('acc_fsdb35_it1..t_entity')

EXEC dbo.sp_selectpages @object_id = @i, @db_id = @d,  @max_pages = 10000
*/
CREATE PROCEDURE sp_selectpages(@object_id int, @db_id int = NULL,  @max_pages int = 100)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @SQL      nvarchar(MAX),
            @PageFID  smallint, 
            @PagePID  int,
            @rowcount int
            
    IF @db_id IS NULL
      SET @db_id = DB_ID()

    IF object_name(@object_id, @db_id) IS NULL
    BEGIN
      RAISERROR ('The object with id [%d] does not exist in the database with id [%d]', 16, 1, @object_id, @db_id);
      RETURN(-1)
    END

    CREATE TABLE #DBCC_IND(ROWID           integer IDENTITY(1,1) PRIMARY KEY, 
                           PageFID         smallint, 
                           PagePID         integer, 
                           IAMFID          integer, 
                           IAMPID          integer, 
                           ObjectID        integer,
                           IndexID         integer,
                           PartitionNumber bigint,
                           PartitionID     bigint, 
                           Iam_Chain_Type  varchar(80), 
                           PageType        integer,
                           IndexLevel      integer,
                           NexPageFID      integer,
                           NextPagePID     integer,
                           PrevPageFID     integer,
                           PrevPagePID     integer)

    CREATE TABLE #DBCC_Page(ROWID        integer IDENTITY(1, 1) PRIMARY KEY, 
                            ParentObject varchar(500),
                            Object       varchar(500), 
                            Field        varchar(500), 
                            Value        varchar(MAX))

    CREATE TABLE #Results(ROWID     integer PRIMARY KEY, 
                          Page      varchar(100), 
                          Slot      varchar(300), 
                          Object    varchar(300), 
                          FieldName varchar(300), 
                          Value     varchar(6000))

    CREATE TABLE #Columns(ColumnID integer PRIMARY KEY, 
                          Name     varchar(800))

    select @SQL = N'SELECT colid, name
                     FROM ' + QUOTENAME(DB_NAME(@db_id)) + N'..syscolumns
                    WHERE id = @object_id'

    INSERT INTO #Columns
    exec sp_executesql @SQL, N'@object_id int', @object_id
    
    SELECT @rowcount = @@ROWCOUNT
    
    IF @rowcount = 0 
      BEGIN
        RAISERROR('No columns to return for table with id [%d]', 16, 1, @object_id)
        RETURN(-1)
      END

    SELECT @SQL = N'DBCC IND(' + QUOTENAME(DB_NAME(@db_id)) + N', ' + CONVERT(varchar(11), @object_id) + N', 1) WITH NO_INFOMSGS'

    DBCC TRACEON(3604) WITH NO_INFOMSGS

    INSERT INTO #DBCC_IND
    EXEC (@SQL)
    
    DECLARE cCursor CURSOR LOCAL READ_ONLY FOR
    SELECT TOP (@max_pages) PageFID, PagePID 
      FROM #DBCC_IND 
     WHERE PageType = 1

    OPEN cCursor

    FETCH NEXT FROM cCursor INTO @PageFID, @PagePID 

    WHILE @@FETCH_STATUS = 0
    BEGIN
      DELETE #DBCC_Page
      
      SELECT @SQL = N'DBCC PAGE (' + QUOTENAME(DB_NAME(@db_id)) + N',' + CONVERT(varchar(10), @PageFID) + N',' + CONVERT(varchar(10), @PagePID) + N', 3) WITH TABLERESULTS, NO_INFOMSGS '
      
      INSERT INTO #DBCC_Page
      EXEC (@SQL)
      
      DELETE FROM #DBCC_Page 
       WHERE Object NOT LIKE 'Slot %' 
          OR Field = '' 
          OR Field IN ('Record Type', 'Record Attributes') 
          OR ParentObject in ('PAGE HEADER:')
      
      INSERT INTO #Results
      SELECT ROWID, cast(@PageFID as varchar(20)) + ':' + CAST(@PagePID as varchar(20)), ParentObject, Object, Field, Value 
        FROM #DBCC_Page

      FETCH NEXT FROM cCursor INTO @PageFID, @PagePID 
    END
    
    CLOSE cCursor
    DEALLOCATE cCursor

    SELECT @SQL = N' SELECT ' + STUFF(CAST((SELECT N',' + QUOTENAME(Name) + N'' 
                                             FROM #Columns 
                                         ORDER BY ColumnID 
                                              FOR XML PATH('')) AS varchar(MAX)), 1, 1,'') + '
                    FROM (SELECT CONVERT(varchar(20), Page) + CONVERT(varchar(500), Slot) p
                               , FieldName x_FieldName_x
                               , Value x_Value_x 
                            FROM #Results) Tab
                    PIVOT(MAX(Tab.x_Value_x) FOR Tab.x_FieldName_x IN( ' + STUFF((SELECT ',' +  QUOTENAME(Name) + '' 
                                                                                    FROM #Columns 
                                                                                ORDER BY ColumnID 
                                                                                     FOR XML PATH('')), 1, 1,'') + ' )
                    ) AS pvt'

    EXEC (@SQL)
    
    RETURN (0)
END
GO
if OBJECT_ID('sp_selectpages') is null
  PRINT 'Failed to create procedure sp_selectpages...'
ELSE
  PRINT 'Correctly created procedure sp_selectpages...'
GO