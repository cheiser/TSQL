-- Written by: Mattis Andersson


-- Drop stored procedure if it already exists
IF EXISTS (
  SELECT * 
    FROM INFORMATION_SCHEMA.ROUTINES 
   WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'SPRC_TEST_HANDLE_FOREIGN_KEYS' 
)
   DROP PROCEDURE dbo.SPRC_TEST_HANDLE_FOREIGN_KEYS
GO

CREATE PROCEDURE dbo.SPRC_TEST_HANDLE_FOREIGN_KEYS
AS
	BEGIN TRAN

---------------------------------------------------------------------------------------
---------------------------- TABLES AND VARIABLES -------------------------------------
---------------------------------------------------------------------------------------
		DECLARE @uniqueKeyTable AS NVARCHAR(MAX) = 'uniqueKeyTable'
		,		@keyColumnName	AS NVARCHAR(MAX) = 'uniqueKey'
		,		@tempStr		AS NVARCHAR(MAX) = ''

		CREATE TABLE uniqueKeyTable
		(
			uniqueKey		INT
		,	othercolumn1	INT
		,	othercolumn2	INT
		)

		CREATE TABLE tableThatUsesUniqueKey
		(
			uniqueKey	INT
		,	ocolumn1	INT
		,	ocolumn2	INT
		)

		CREATE TABLE tableThatUsesUniqueKeyWithoutSpecificValue
		(
			uniqueKey	INT
		,	ocolumn1	INT
		,	ocolumn2	INT
		)

		CREATE TABLE tableThatUsesUniqueWithWrongType
		(
			uniqueKey	FLOAT
		,	ocolumn1	INT
		,	ocolumn2	INT
		)

		DECLARE @resultTable TABLE
		(
			columnName		NVARCHAR(MAX) NOT NULL
		,	tableName		NVARCHAR(MAX) NOT NULL
		,	dataType		NVARCHAR(MAX) NOT NULL
		)

		INSERT INTO uniqueKeyTable (uniqueKey, othercolumn1, othercolumn2)
		VALUES (10, 2, 2)

		INSERT INTO tableThatUsesUniqueKey (uniqueKey, ocolumn1, ocolumn2)
		VALUES (10, 25, 2)

		INSERT INTO tableThatUsesUniqueKeyWithoutSpecificValue (uniqueKey, ocolumn1, ocolumn2)
		VALUES (101, 25, 2)

		INSERT INTO tableThatUsesUniqueWithWrongType (uniqueKey, ocolumn1, ocolumn2)
		VALUES (10.0, 25, 2)

---------------------------------------------------------------------------------------
-------------------------------- TEST 1 -----------------------------------------------
---------------------------------------------------------------------------------------
		-- create atleast two tables, one with a unique key and another one that uses that key as a foreign key and then just
		-- make sure the SP returns that other table as a table which references it as a foreign key
		INSERT INTO @resultTable (columnName, tableName, dataType) -- THIS ONLY WORKS IF WE DON'T USE @pSpecificValue
		EXEC SPRC_HANDLE_FOREIGN_KEYS	@pTableName			= @uniqueKeyTable
		,								@pColumnName		= @keyColumnName
		,								@pSpecificValue		= ''
		,								@pTableSchema		= 'dbo'
		,								@pSameType			= 1
		,								@pOnlyActualFK		= 0
		,								@pOnlySpecificValue	= 0
		

		SELECT	1 AS test1, *
		FROM	@resultTable

		IF NOT EXISTS
		(
			SELECT	1
			FROM	@resultTable
			WHERE	tableName IN ('tableThatUsesUniqueKey', 'tableThatUsesUniqueKeyWithoutSpecificValue')
			AND		columnName = @keyColumnName
		)
			RAISERROR('Test 1 - Missing table that uses the specific key', 11, 11)

		IF EXISTS
		(
			SELECT	1
			FROM	@resultTable
			WHERE	columnName = @keyColumnName
			AND		tableName NOT IN ('uniqueKeyTable', 'tableThatUsesUniqueKey', 'tableThatUsesUniqueKeyWithoutSpecificValue')
		)
		BEGIN
			SELECT	@tempStr = (@tempStr + ' ' + tableName)
			FROM	@resultTable
			WHERE	columnName = @keyColumnName
			AND		tableName NOT IN ('uniqueKeyTable', 'tableThatUsesUniqueKey', 'tableThatUsesUniqueKeyWithoutSpecificValue')

			RAISERROR('Test 1 - Got tables which problably should not use the uniquekey: %s', 11, 11, @tempStr)
		END


---------------------------------------------------------------------------------------
-------------------------------- TEST 2 -----------------------------------------------
---------------------------------------------------------------------------------------

		-- Clear table for second test...
		DELETE
		FROM	@resultTable

		-- Test for specific value
		INSERT INTO @resultTable (columnName, tableName, dataType) -- THIS ONLY WORKS IF WE DON'T USE @pSpecificValue
		EXEC SPRC_HANDLE_FOREIGN_KEYS	@pTableName			= @uniqueKeyTable
		,								@pColumnName		= @keyColumnName
		,								@pSpecificValue		= '10'
		,								@pTableSchema		= 'dbo'
		,								@pSameType			= 1
		,								@pOnlyActualFK		= 0
		,								@pOnlySpecificValue	= 1
		
		SELECT	2 AS test2, *
		FROM	@resultTable

		IF NOT EXISTS
		(
			SELECT	1
			FROM	@resultTable
			WHERE	tableName = 'tableThatUsesUniqueKey'
			AND		columnName = @keyColumnName
		)
			RAISERROR('Test 2 - Missing table that uses the specific key/value', 11, 11)

		IF EXISTS
		(
			SELECT	1
			FROM	@resultTable
			WHERE	columnName = @keyColumnName
			AND		tableName NOT IN ('uniqueKeyTable', 'tableThatUsesUniqueKey')
		)
		BEGIN
			SELECT	@tempStr = (@tempStr + ' ' + tableName)
			FROM	@resultTable
			WHERE	columnName = @keyColumnName
			AND		tableName NOT IN ('uniqueKeyTable', 'tableThatUsesUniqueKey')

			RAISERROR('Test 2 - Got tables which problably doesn''t use the uniquekey/value pair: %s', 11, 11, @tempStr)
		END


---------------------------------------------------------------------------------------
-------------------------------- TEST 3 -----------------------------------------------
---------------------------------------------------------------------------------------
		-- Clear table for third test...
		DELETE
		FROM	@resultTable

		-- Test for getting results with other type aswell...
		INSERT INTO @resultTable (columnName, tableName, dataType) -- THIS ONLY WORKS IF WE DON'T USE @pSpecificValue
		EXEC SPRC_HANDLE_FOREIGN_KEYS	@pTableName			= @uniqueKeyTable
		,								@pColumnName		= @keyColumnName
		,								@pSpecificValue		= ''
		,								@pTableSchema		= 'dbo'
		,								@pSameType			= 0
		,								@pOnlyActualFK		= 0
		,								@pOnlySpecificValue	= 0

		

		SELECT	3 AS test3, *
		FROM	@resultTable

		IF NOT EXISTS
		(
			SELECT	1
			FROM	@resultTable
			WHERE	tableName IN
				(
					'tableThatUsesUniqueKey'
				,	'tableThatUsesUniqueKeyWithoutSpecificValue'
				,	'tableThatUsesUniqueWithWrongType'
				)
			AND		columnName = @keyColumnName
		)
			RAISERROR('Test 3 - Missing table that uses the specific key', 11, 11)

		IF EXISTS
		(
			SELECT	1
			FROM	@resultTable
			WHERE	columnName = @keyColumnName
			AND		tableName NOT IN
				(
					'uniqueKeyTable'
				,	'tableThatUsesUniqueKey'
				,	'tableThatUsesUniqueKeyWithoutSpecificValue'
				,	'tableThatUsesUniqueWithWrongType'
				)
		)
		BEGIN
			SELECT	@tempStr = (@tempStr + ' ' + tableName)
			FROM	@resultTable
			WHERE	columnName = @keyColumnName
			AND		tableName NOT IN
				(
					'uniqueKeyTable'
				,	'tableThatUsesUniqueKey'
				,	'tableThatUsesUniqueKeyWithoutSpecificValue'
				,	'tableThatUsesUniqueWithWrongType'
				)

			RAISERROR('Test 3 - Got tables which problably should not use the uniquekey: %s', 11, 11, @tempStr)
		END

	ROLLBACK TRAN
GO


--SELECT	column_name, *
--FROM	INFORMATION_SCHEMA.COLUMNS
--WHERE	TABLE_NAME = 'Customer'

--SELECT	*
--FROM	INFORMATION_SCHEMA.TABLES


---- =============================================
---- Example to execute the stored procedure
---- =============================================
--EXECUTE dbo.SPRC_TEST_HANDLE_FOREIGN_KEYS
--GO
