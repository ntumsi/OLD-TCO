
CREATE PROCEDURE [web].[getCostView_CompareGFEBS]
    @PayPlan NVARCHAR(3),
    @OccupationalSeries NVARCHAR(7),
    @StateCountry NVARCHAR(50),
    @FunctionalAreaCode NVARCHAR(50),
    @CostCenterCode NVARCHAR(50)
AS
BEGIN

    CREATE TABLE #Costs
    (
        APPN NVARCHAR(30) NULL,
        CostElementCategory NVARCHAR(40) NULL,
        CostElementName NVARCHAR(300) NULL,
        CostElementId INT NULL,
        GradeLevel INT NULL,
        Amount FLOAT NULL
    );

    /* Production costs */
    INSERT INTO #Costs
    (
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           GradeLevel,
           Amount
    FROM compare.CostsProduction
    WHERE PayPlan = @PayPlan
          AND
          (
              @OccupationalSeries = '__ALL__'
              OR CategorySubGroupCode = @OccupationalSeries
          )
          AND
          (
              @StateCountry = '__ALL__'
              OR StateCountry = @StateCountry
          )
          AND
          (
              @FunctionalAreaCode = '__ALL__'
              OR FunctionalAreaCode = @FunctionalAreaCode
          )
          AND
          (
              @CostCenterCode = '__ALL__'
              OR CostCenterCode = @CostCenterCode
          );

    DECLARE @From NVARCHAR(4000);
    DECLARE @Select NVARCHAR(500);
    DECLARE @PivotValueColumn NVARCHAR(100);
    DECLARE @PivotSortColumn NVARCHAR(100);
    DECLARE @DataColumn NVARCHAR(500);
    DECLARE @GroupBy NVARCHAR(500);
    DECLARE @OrderBy NVARCHAR(500);


    SET @From
        = N'(SELECT APPN,CostElementCategory,CostElementName,GradeLevel, Avg(Amount) As avgAmount FROM #Costs GROUP BY APPN, CostElementCategory, CostElementName, GradeLevel) as tblCosts ';
    SET @Select = N'APPN,CostElementCategory,CostElementName';
    SET @PivotValueColumn = N'GradeLevel';
    SET @PivotSortColumn = N'GradeLevel';
    SET @DataColumn = N'avgAmount';
    SET @GroupBy = N'APPN,CostElementCategory,CostElementName';
    SET @OrderBy = N'APPN,CostElementCategory,CostElementName';

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit

    /* External Test costs */
    TRUNCATE TABLE #Costs;

    INSERT INTO #Costs
    (
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           GradeLevel,
           Amount
    FROM compare.CostsExternalTest
    WHERE PayPlan = @PayPlan
          AND
          (
              @OccupationalSeries = '__ALL__'
              OR CategorySubGroupCode = @OccupationalSeries
          )
          AND
          (
              @StateCountry = '__ALL__'
              OR StateCountry = @StateCountry
          )
          AND
          (
              @FunctionalAreaCode = '__ALL__'
              OR FunctionalAreaCode = @FunctionalAreaCode
          )
          AND
          (
              @CostCenterCode = '__ALL__'
              OR CostCenterCode = @CostCenterCode
          );

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit

    /* Internal Test costs */
    TRUNCATE TABLE #Costs;

    INSERT INTO #Costs
    (
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        GradeLevel,
        Amount
    )
    SELECT APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           GradeLevel,
           Amount
    FROM data.Costs
    WHERE PayPlan = @PayPlan
          AND
          (
              @OccupationalSeries = '__ALL__'
              OR CategorySubGroupCode = @OccupationalSeries
          )
          AND
          (
              @StateCountry = '__ALL__'
              OR StateCountry = @StateCountry
          )
          AND
          (
              @FunctionalAreaCode = '__ALL__'
              OR FunctionalAreaCode = @FunctionalAreaCode
          )
          AND
          (
              @CostCenterCode = '__ALL__'
              OR CostCenterCode = @CostCenterCode
          );

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit

    DROP TABLE IF EXISTS #Costs;

END;