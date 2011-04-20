sp_select
=========
A very hard to crack issue when debugging TSQL Stored procedures on SQL Server 2005 or 2008(r2) is the fact that you can not see the contents of temp tables outside the session where they are created. This problem is now solved thanks the procedures `sp_select` and `sp_selectpages`. 
This code would not have been possible without the blog posts from [Fabiano Neves][1] and [Jonathan Kehayias][2].

How to use these procedures
===========================
The procedures can be deployed on the master database with the included rakefile (or just manually open them in SQL Server Management Studio and run them on master)

Once they are deployed you can call the procedure `sp_select` from any database. 
`sp_select` accepts the following parameters:

 - @table_name: This is the fully qualified table name to display the contents from. (for example `msdb.dbo.MSdbms`)
 - @spid: this optional parameter can be used to specify a spid on which the temp table is created. (useful on busy servers)
 - @max_pages: this optional parameter is used to limit the amount of data returned. (default 1000)

Examples
========
Run the following code in one query window:

        CREATE TABLE #temp (id int, name varchar(200))
        INSERT INTO #temp VALUES (1, 'Filip')
        INSERT INTO #temp VALUES (2, 'Sam')
 
Now open a second query and run the following statement:

        exec sp_select 'tempdb..#temp'
  
The result will be

id | name
---|----------:
1  | Filip
2  | Sam

How does it work
================
The procedure `sp_select` will try to pinpoint the `object_id` of the table you are trying to get the data from. When specifying a permanent table this is quite easy the function `object_id()` will return the correct value.
When the target is a temp table this is quite difficult as SQL Server does not store a link between the temp table in tempdb and the session in an easily accessible way. There are 3 scenarios implemented in the procedures

 - There is only 1 temp table with the name you are looking for. ==> get the object_id from `tempdb.sys.tables`
 - There are more than 1 temp table with the name you are looking for and you did not specify a `@spid`. ==> find the first temp table matching the database name of the database you are running the procedure on
 - There are more than 1 temp table with the name you are looking for and you did specify a `@spid` ==> match the temp table with the spid by mining the default trace file `log.trc`. 

Once the `object_id` is determined the procedure sp_selectpages will be used to return the content.

 - Use `DBCC IND` to return the list of pages to look at with `DBCC PAGE`
 - Loop over all the pages and store the page content with `DBCC PAGE`
 - use the PIVOT statement to pivot the key/value results to the original table layout

Note: All the fields in the resultset will have the type `VARCHAR(6000)`

[1]: http://mcflyamorim.wordpress.com/2010/05/31/fabiano-vs-dbcc-page/
[2]: http://sqlblog.com/blogs/jonathan_kehayias/archive/2009/09/29/what-session-created-that-object-in-tempdb.aspx
