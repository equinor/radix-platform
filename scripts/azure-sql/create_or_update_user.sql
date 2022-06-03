SET XACT_ABORT ON;

IF USER_ID('$(userName)') IS NULL
BEGIN
    CREATE USER [$(userName)] WITH PASSWORD='$(password)';
END
ELSE
BEGIN
    ALTER USER [$(userName)] WITH PASSWORD='$(password)';
END

-- Add/remove user from roles

DECLARE @roleName SYSNAME
DECLARE @cmd NVARCHAR(MAX)

-- Add user to roles defined in $roles
DECLARE add_roles CURSOR FOR SELECT value FROM STRING_SPLIT('$(roles)',',') FOR READ ONLY

OPEN add_roles

FETCH NEXT FROM add_roles INTO @roleName
WHILE @@FETCH_STATUS = 0  
BEGIN
	SET @cmd=N'ALTER ROLE ' + QUOTENAME(@roleName) + N' ADD MEMBER ' + QUOTENAME('$(userName)')
	EXEC sp_executesql @cmd
	FETCH NEXT FROM add_roles INTO @roleName
END

CLOSE add_roles

DEALLOCATE add_roles

-- Remove used from roles not defined in $roles
DECLARE remove_roles CURSOR FOR
SELECT
	p.name
FROM
	sys.database_principals p 
	INNER JOIN sys.database_role_members rm ON p.principal_id=rm.role_principal_id
WHERE
	member_principal_id=USER_ID('$(userName)') 
	AND p.TYPE='R' 
	AND p.name NOT IN (SELECT value FROM STRING_SPLIT('$(roles)',','))
FOR READ ONLY

OPEN remove_roles

FETCH NEXT FROM remove_roles INTO @roleName
WHILE @@FETCH_STATUS = 0  
BEGIN
	SET @cmd=N'ALTER ROLE ' + QUOTENAME(@roleName) + N' DROP MEMBER ' + QUOTENAME('$(userName)')
	EXEC sp_executesql @cmd
	FETCH NEXT FROM remove_roles INTO @roleName
END

CLOSE remove_roles

DEALLOCATE remove_roles