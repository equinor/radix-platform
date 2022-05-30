SET XACT_ABORT ON;

IF USER_ID('$(userName)') IS NULL
BEGIN
    CREATE USER [$(userName)] WITH PASSWORD='$(password)';
END
ELSE
BEGIN
    ALTER USER [$(userName)] WITH PASSWORD='$(password)';
END

DECLARE role_names CURSOR FOR SELECT value FROM STRING_SPLIT('$(roles)',',') FOR READ ONLY

OPEN role_names
DECLARE @roleName SYSNAME
FETCH NEXT FROM role_names INTO @roleName
WHILE @@FETCH_STATUS = 0  
BEGIN
	DECLARE @cmd NVARCHAR(MAX)=N'ALTER ROLE ' + QUOTENAME(@roleName) + N' ADD MEMBER ' + QUOTENAME('$(userName)')
	EXEC sp_executesql @cmd
	FETCH NEXT FROM role_names INTO @roleName
END

CLOSE role_names

DEALLOCATE role_names