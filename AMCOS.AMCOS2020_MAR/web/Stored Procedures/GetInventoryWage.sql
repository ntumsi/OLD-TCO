
CREATE PROCEDURE [web].[GetInventoryWage]
    @PayPlan NVARCHAR(3),
    @LocationId INT = -1,
    @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @From NVARCHAR(1000);
    DECLARE @Select NVARCHAR(500);
    DECLARE @PivotValueColumn NVARCHAR(100);
    DECLARE @PivotSortColumn NVARCHAR(100);
    DECLARE @DataColumn NVARCHAR(100);
    DECLARE @GroupBy NVARCHAR(500);
    DECLARE @OrderBy NVARCHAR(500);

    IF (@LocationId = -1)
    BEGIN
        SET @From
            = N'(SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step, YOS, Inventory FROM data.Inventory WHERE PayPlan = '''
              + @PayPlan + N''' AND AmcosVersionId = ' + CAST(@AmcosVersionId AS NVARCHAR(50)) + N') tblInv ';
        SET @Select = N'Step';
        SET @PivotValueColumn = N'Grade';
        SET @PivotSortColumn = N'GradeLevel';
        SET @DataColumn = N'Inventory';
        SET @GroupBy = N'Step';
        SET @OrderBy = N'Step';

        EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                                  @Select = @Select,                     -- nvarchar(500)
                                  @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                                  @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                                  @DataColumn = @DataColumn,             -- nvarchar(100)
                                  @GroupBy = @GroupBy,                   -- nvarchar(500)
                                  @OrderBy = @OrderBy,                   -- nvarchar(500)
                                  @Debug = 0;                            -- bit
        RETURN;
    END;

    SET @From
        = N'(SELECT GradeType + CAST(GradeLevel AS varchar(2)) As Grade, GradeLevel, Step, YOS, Inventory FROM data.Inventory WHERE PayPlan = '''
          + @PayPlan + N''' AND LocationId = ' + CAST(@LocationId AS NVARCHAR(50)) + N' AND AmcosVersionId = '
          + CAST(@AmcosVersionId AS NVARCHAR(50)) + N') tblInv ';
    SET @Select = N'Step';
    SET @PivotValueColumn = N'Grade';
    SET @PivotSortColumn = N'GradeLevel';
    SET @DataColumn = N'Inventory';
    SET @GroupBy = N'Step';
    SET @OrderBy = N'Step';

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(100)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit
    RETURN;
END;