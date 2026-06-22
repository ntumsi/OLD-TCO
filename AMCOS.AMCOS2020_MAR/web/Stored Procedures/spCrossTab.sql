

CREATE PROCEDURE [web].[spCrossTab]
    @From NVARCHAR(4000),
    @Select NVARCHAR(500),
    @PivotValueColumn NVARCHAR(100),
    @PivotSortColumn NVARCHAR(100),
    @DataColumn NVARCHAR(100),
    @GroupBy NVARCHAR(500),
    @OrderBy NVARCHAR(500),
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sqlSelect NVARCHAR(4000);
    DECLARE @sqlCase NVARCHAR(4000);
    DECLARE @sqlEnd NVARCHAR(4000);

    SET @sqlSelect = N'SELECT ' + @Select;

    DROP TABLE IF EXISTS #PivotConfiguration;
    CREATE TABLE #PivotConfiguration
    (
        PivotValue NVARCHAR(100) NOT NULL,
        PivotSort INT NOT NULL
    );
    DECLARE @InsertPivotConfigurationSQL AS NVARCHAR(3000);
    SET @InsertPivotConfigurationSQL
        = N'INSERT INTO #PivotConfiguration (PivotValue,PivotSort) ' + N'SELECT DISTINCT CAST(' + @PivotValueColumn
          + N' AS NVARCHAR(100)), CAST(' + @PivotSortColumn + N' AS INT) FROM ' + @From + N' ';
    EXEC (@InsertPivotConfigurationSQL);

    DECLARE @KeyValue AS NVARCHAR(100);
    SET @sqlCase = N'';

    DECLARE PivotConfiguration_Cursor CURSOR FOR
    SELECT PivotValue
    FROM #PivotConfiguration
    ORDER BY PivotSort;
    OPEN PivotConfiguration_Cursor;
    FETCH NEXT FROM PivotConfiguration_Cursor
    INTO @KeyValue;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sqlCase
            = @sqlCase + N',' + N'SUM(CASE CAST(' + @PivotValueColumn + N' AS NVARCHAR(100))' + N' WHEN ''' + @KeyValue
              + N'''' + N' THEN ' + CASE
                                        WHEN @DataColumn IS NULL THEN
                                            '1'
                                        ELSE
                                            @DataColumn
                                    END + N' ELSE 0' + N' END) AS ''' + @KeyValue + N'''';
        FETCH NEXT FROM PivotConfiguration_Cursor
        INTO @KeyValue;
    END;
    CLOSE PivotConfiguration_Cursor;
    DEALLOCATE PivotConfiguration_Cursor;

    SET @sqlEnd = N' FROM ' + @From + N' GROUP BY ' + @GroupBy + N' ORDER BY ' + @OrderBy;

    IF @Debug = 1
        PRINT @sqlSelect + @sqlCase + @sqlEnd;

    EXEC (@sqlSelect + @sqlCase + @sqlEnd);
END;