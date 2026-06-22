
CREATE PROCEDURE [web].[getInventory]
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(7) = '-1',
    @CategorySubgroupCode NVARCHAR(7) = '-1',
    @AmcosVersionId INT = 202001
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ColumnToSelect VARCHAR(500) = 'Step';

    /* Set the column to select */
    IF (web.PayPlanContainsTag(@PayPlan, 'Active Military') = 1)
       OR (web.PayPlanContainsTag(@PayPlan, 'National Guard') = 1)
       OR (web.PayPlanContainsTag(@PayPlan, 'Reserves') = 1)
    BEGIN
        SET @ColumnToSelect = 'YOS';
    END;

    DECLARE @From NVARCHAR(1000);
    DECLARE @Select NVARCHAR(500);
    DECLARE @PivotValueColumn NVARCHAR(100);
    DECLARE @PivotSortColumn NVARCHAR(100);
    DECLARE @DataColumn NVARCHAR(100);
    DECLARE @GroupBy NVARCHAR(500);
    DECLARE @OrderBy NVARCHAR(500);

    IF (@CategoryGroupCode = '-1')
    BEGIN
        SET @From
            = N'(SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step, YOS, Inventory FROM data.Inventory WHERE PayPlan = '''
              + @PayPlan + N''' AND AmcosVersionId = ' + CAST(@AmcosVersionId AS NVARCHAR(50)) + N') tblInv ';
        SET @Select = @ColumnToSelect;
        SET @PivotValueColumn = N'Grade';
        SET @PivotSortColumn = N'GradeLevel';
        SET @DataColumn = N'Inventory';
        SET @GroupBy = @ColumnToSelect;
        SET @OrderBy = @ColumnToSelect;

        EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                                  @Select = @Select,                     -- nvarchar(500)
                                  @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                                  @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                                  @DataColumn = @DataColumn,             -- nvarchar(100)
                                  @GroupBy = @GroupBy,                   -- nvarchar(500)
                                  @OrderBy = @OrderBy,                   -- nvarchar(500)
                                  @Debug = 1;                            -- bit
        RETURN;
    END;

    IF (@CategorySubgroupCode = '-1')
    BEGIN
        SET @From
            = N'(SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step, YOS, Inventory FROM data.Inventory WHERE PayPlan = '''
              + @PayPlan + N''' AND CategoryGroupCode = ''' + @CategoryGroupCode + N''' AND AmcosVersionId = '
              + CAST(@AmcosVersionId AS NVARCHAR(50)) + N') tblInv ';
        SET @Select = @ColumnToSelect;
        SET @PivotValueColumn = N'Grade';
        SET @PivotSortColumn = N'GradeLevel';
        SET @DataColumn = N'Inventory';
        SET @GroupBy = @ColumnToSelect;
        SET @OrderBy = @ColumnToSelect;

        EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                                  @Select = @Select,                     -- nvarchar(500)
                                  @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                                  @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                                  @DataColumn = @DataColumn,             -- nvarchar(100)
                                  @GroupBy = @GroupBy,                   -- nvarchar(500)
                                  @OrderBy = @OrderBy,                   -- nvarchar(500)
                                  @Debug = 1;                            -- bit
        RETURN;
    END;
    SET @From
        = N'(SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step, YOS, Inventory FROM data.Inventory WHERE PayPlan = '''
          + @PayPlan + N''' AND CategoryGroupCode = ''' + @CategoryGroupCode + N''' AND CategorySubgroupCode = '''
          + @CategorySubgroupCode + N''' AND AmcosVersionId = ' + CAST(@AmcosVersionId AS NVARCHAR(50)) + N') tblInv ';
    SET @Select = @ColumnToSelect;
    SET @PivotValueColumn = N'Grade';
    SET @PivotSortColumn = N'GradeLevel';
    SET @DataColumn = N'Inventory';
    SET @GroupBy = @ColumnToSelect;
    SET @OrderBy = @ColumnToSelect;

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(100)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 1;                            -- bit
    RETURN;
END;