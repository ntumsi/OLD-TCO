
CREATE PROCEDURE [dbo].[spCrossTabNumber]
    @table AS VARCHAR(8000),              -- Table to crosstab
    @onrows AS VARCHAR(2000),             -- Grouping key values (on rows)
    @onrowsalias AS VARCHAR(2000) = NULL, -- Alias for grouping column
    @oncols AS VARCHAR(2000),             -- Destination columns (on columns)
    @sumcol AS VARCHAR(2000) = NULL       -- Data cells
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sqlSelect AS VARCHAR(8000),
            @sqlCase AS VARCHAR(8000),
            @sqlEnd AS VARCHAR(8000),
            @NEWLINE AS CHAR(1),
            @rows AS NVARCHAR(2000),
            @rowAlias AS NVARCHAR(2000),
            @idxRows AS SMALLINT,
            @idxAlias AS SMALLINT;
    SET @NEWLINE = CHAR(10);
    -- Step 1: beginning of SQL string
    SET @sqlSelect = 'SELECT ';
    SET @rows = REPLACE(@onrows, ' ', '');
    SET @rowAlias = REPLACE(@onrowsalias, ' ', '');
    SET @idxRows = 1;
    SET @idxAlias = 1;

    WHILE (@idxRows <> 0)
    BEGIN
        SET @idxRows = CHARINDEX(',', @rows, @idxRows);
        SET @idxAlias = CHARINDEX(',', @rowAlias, @idxAlias);
        IF (@idxRows = 0) -- If only one row name or last row name
        BEGIN
            SET @sqlSelect = @sqlSelect + @rows + CASE
                                                      WHEN @rowAlias IS NOT NULL THEN
                                                          ' AS ' + @rowAlias
                                                      ELSE
                                                          ''
                                                  END;
            BREAK;
        END;
        ELSE
        BEGIN
            PRINT @rows;
            SET @sqlSelect
                = @sqlSelect + LEFT(@rows, @idxRows - 1) + CASE
                                                               WHEN
                                                               (
                                                                   (@rowAlias IS NOT NULL)
                                                                   AND (@idxAlias <> 0)
                                                               ) THEN
                                                                   ' AS ' + LEFT(@onrowsalias, @idxAlias - 1) + ', '
                                                               ELSE
                                                                   ', '
                                                           END;
            --Remove first row column name and alias
            SET @rows = SUBSTRING(@rows, @idxRows + 1, LEN(@rows));
            SET @rowAlias = SUBSTRING(@rowAlias, @idxAlias + 1, LEN(@rowAlias));
        END;
    END;


    --LISTING 5: Step 2 of the sp_CrossTab Stored Procedure: Storing Keys in a Temp Table
    CREATE TABLE #keys
    (
        keyvalue INT NOT NULL
    );
    DECLARE @keyssql AS VARCHAR(8000);
    SET @keyssql
        = 'INSERT INTO #keys ' + 'SELECT DISTINCT CAST(' + @oncols + ' AS nvarchar(1000))  ' + 'FROM (' + @table
          + ') tblTemp ';

    PRINT @keyssql;

    EXEC (@keyssql);

    --LISTING 6: Step 3 of the sp_CrossTab Stored procedure: Middle Part of SQL String
    DECLARE @key AS VARCHAR(8000);
    SELECT @key = MIN(keyvalue)
    FROM #keys;
    SET @sqlCase = '';
    WHILE @key IS NOT NULL
    BEGIN
        SET @sqlCase
            = @sqlCase + ',' + 'SUM(CASE CAST(' + @oncols + ' AS char(5))' + ' WHEN ''' + @key + '''' + ' THEN '
              + CASE
                    WHEN @sumcol IS NULL THEN
                        '1'
                    ELSE
                        @sumcol
                END + ' ELSE 0' + ' END) AS ''' + @key + '''';
        SELECT @key = MIN(keyvalue)
        FROM #keys
        WHERE keyvalue > @key;
    END;


    --LISTING 7: Step 4 of the sp_CrossTab Stored Procedure: End of SQL String
    SET @sqlEnd
        = ' ' + @NEWLINE + 'FROM ( ' + @table + ' ) tblTemp ' + @NEWLINE + 'GROUP BY ' + @onrows + ' ' + @NEWLINE
          + 'ORDER BY ' + @onrows;
    PRINT @sqlSelect + @NEWLINE;
    PRINT @sqlCase + @NEWLINE;
    PRINT @sqlEnd; -- For debug
    EXEC (@sqlSelect + @sqlCase + @sqlEnd);
END;