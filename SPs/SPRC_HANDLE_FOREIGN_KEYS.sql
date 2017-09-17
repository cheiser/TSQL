-- Written by: Mattis Andersson


-- Drop stored procedure if it already exists
IF EXISTS (
	SELECT	1 
    FROM	INFORMATION_SCHEMA.ROUTINES 
	WHERE	SPECIFIC_SCHEMA = N'dbo'
    AND		SPECIFIC_NAME = N'SPRC_HANDLE_FOREIGN_KEYS' 
)
   DROP PROCEDURE dbo.SPRC_HANDLE_FOREIGN_KEYS
GO

CREATE PROCEDURE dbo.SPRC_HANDLE_FOREIGN_KEYS
	@pTableName			NVARCHAR(MAX), 
	@pColumnName		NVARCHAR(MAX) = 'comp_id',
	@pSpecificValue		NVARCHAR(MAX) = '', -- Should be defined if we want to find all tables "referencing" the specific 
	-- column/value pair. This value will be cast into the correct type based on what the tablename/column type is.
	-- For strings, this would need to be on the format '''string'''
	@pTableSchema		NVARCHAR(MAX) = 'dbo', -- This will most of the time not be used.
	@pSameType			BIT = 1, -- If this is true we only return tables of the same type
	@pOnlyActualFK		BIT = 0, -- If this is true then we only return tables with "real" foreign key contraints
	@pOnlySpecificValue	BIT = 0 -- If this is true then we only return the table which holds information regarding @pSpecificValue
AS
----------------------------------------------------------------------------------------------
-- If @pSpecificValue is specified, then we return two tables, the second table contains the name of all tables referencing
-- that value for that column, the other table will contain all tables that has that column as foreign key.
-- If @pSpecificValue is not specified, only the first table is returned.
----------------------------------------------------------------------------------------------
	DECLARE @dSQL			AS NVARCHAR(MAX)
	,		@paramDef		AS NVARCHAR(MAX) -- Holds information regarding the parameter definitions
	,		@tType			AS NVARCHAR(MAX) -- Holds information regarding the target tables type
	,		@tcColumnName	AS NVARCHAR(MAX) -- tableCursor COLUMN_NAME...
	,		@tcTableName	AS NVARCHAR(MAX)
	,		@tcDataType		AS NVARCHAR(MAX)
	,		@resultParamDef AS NVARCHAR(MAX) = N'@pOutputBit BIT OUTPUT'
	,		@outputBit		AS BIT

	DECLARE @tfkTable TABLE
	(
		columnName		NVARCHAR(MAX) NOT NULL
	,	tableName		NVARCHAR(MAX) NOT NULL
	,	dataType		NVARCHAR(MAX) NOT NULL
	--,	PRIMARY KEY (columnName, tableName, dataType)
	)

	DECLARE @tRefValueTable TABLE
	(
		columnName		NVARCHAR(MAX) NOT NULL
	,	tableName		NVARCHAR(MAX) NOT NULL
	,	value			NVARCHAR(MAX) NOT NULL
	--,	PRIMARY KEY (columnName, tableName, value)
	)


	SELECT	@tType = DATA_TYPE -- Find datatype of target table/column
	FROM	INFORMATION_SCHEMA.COLUMNS
	WHERE	TABLE_NAME = @pTableName
	AND		COLUMN_NAME = @pColumnName


	-- Insert all the found tables with the given column name
	INSERT INTO @tfkTable (columnName, tableName, dataType)
	SELECT	DISTINCT COLUMN_NAME, TABLE_NAME, DATA_TYPE
	FROM	INFORMATION_SCHEMA.COLUMNS
	WHERE	COLUMN_NAME = @pColumnName
	AND		TABLE_SCHEMA = @pTableSchema
	--AND		TABLE_NAME <> @pTableName -- Uncomment this to exclude the "target" table...
	AND		(DATA_TYPE = @tType
	OR		@pSameType = 0) -- If we have specified that the datatype should match, then we check it
	AND		@pOnlyActualFK = 0

	IF (@pOnlySpecificValue = 0)
		SELECT	*
		FROM	@tfkTable -- 

	---- =================== OLD CURSOR SOLUTION NOT NEEDED =========================
	--DECLARE tableCursor CURSOR FAST_FORWARD
	--FOR	SELECT TOP 10 COLUMN_NAME, TABLE_NAME, DATA_TYPE
	--FROM	INFORMATION_SCHEMA.COLUMNS
	--WHERE	COLUMN_NAME = @pColumnName
	--AND		TABLE_SCHEMA = @pTableSchema
	----AND	TABLE_NAME <> @pTableName -- Don't get the target table aswell...

	---- Open the cursor
	--OPEN tableCursor

	---- Fetch the cursor results
	--FETCH NEXT FROM tableCursor
	--INTO	@tcColumnName
	--,		@tcTableName
	--,		@tcDataType

	---- Loop over results
	--WHILE (@@fetch_status = 0)
	--BEGIN
	--	-- Add results to result table

	--	-- Fetch the next results if they exists
	--	FETCH NEXT FROM tableCursor
	--	INTO	@tcColumnName
	--	,		@tcTableName
	--	,		@tcDataType
	--END

	-- Table/columnname return...

	-- Cursor och loopa över alla tabeller returnerade och kolla om dem innehåller den specifika kolumnen och om
	-- dem gör det så läggs det tabell och kolumnnamnet till i en lista som sedan används med dynamisk SQL för att få fram
	-- datan i tabellen och kollar om värdet ligger där?
	---- ================= END OLD CURSOR SOLUTION NOT NEEDED =======================

	-- EXEC sp_fkeys @pktable_qualifier = N'Customer'; -- @pTableName


	
	IF @pSpecificValue <> ''
	BEGIN
		PRINT 'SPECIFIC VALUE'
		-- Set parameter definitions
		SET	@paramDef = N''
		-- code to display names of all tables referencing the value here
		DECLARE tableCursor CURSOR FAST_FORWARD
		FOR	SELECT columnName, tableName, dataType
		FROM	@tfkTable

		-- Open the cursor
		OPEN tableCursor

		-- Fetch the cursor results
		FETCH NEXT FROM tableCursor
		INTO	@tcColumnName
		,		@tcTableName
		,		@tcDataType

		-- Loop over results
		WHILE (@@fetch_status = 0)
		BEGIN
			-- Add results to result table
			SELECT	@dSQL = N'SELECT	@pOutputBit = CASE WHEN EXISTS
							(
								SELECT 1
								FROM	' + @tcTableName + ' a
								WHERE	' + @tcColumnName + ' = ' + @pSpecificValue + '
							) THEN 1 ELSE 0 END'


			EXEC sp_executesql @dSQL, @resultParamDef, @pOutputBit = @outputBit OUTPUT

			IF (@outputBit = 1)
			BEGIN
				-- Add the given table/column name to the result table.....
				INSERT INTO @tRefValueTable (columnName, tableName, value)
				VALUES (@tcColumnName, @tcTableName, @pSpecificValue)
			END

			-- Fetch the next results if they exists
			FETCH NEXT FROM tableCursor
			INTO	@tcColumnName
			,		@tcTableName
			,		@tcDataType
		END

		SELECT	*
		FROM	@tRefValueTable
	END
GO


--SELECT	column_name, *
--FROM	INFORMATION_SCHEMA.COLUMNS
--WHERE	TABLE_NAME = 'Customer'

--SELECT	*
--FROM	INFORMATION_SCHEMA.TABLES

-- EXEC sp_fkeys @pTableName -- THIS GETS THE ACTUAL FOREIGN KEYS!!!
GO
