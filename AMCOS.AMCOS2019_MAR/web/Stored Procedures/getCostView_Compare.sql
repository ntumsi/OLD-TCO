
CREATE PROCEDURE [web].[getCostView_Compare]
(
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(10),
    @CategorySubGroupCode NVARCHAR(10)
)
AS
BEGIN

    DECLARE @DefaultSummary TABLE
    (
        CostElementId INT NOT NULL
    );
    INSERT @DefaultSummary
    SELECT CostSummaryElement.CostElementId
    FROM lookup.CostSummary CostSummary
        INNER JOIN lookup.CostSummaryElement CostSummaryElement
            ON CostSummaryElement.SummaryId = CostSummary.SummaryId
    WHERE CostSummary.PayPlan = @PayPlan
          AND CostSummary.Name = 'Default';

    CREATE TABLE #tblCosts
    (
        [APPN] [NVARCHAR](25) NOT NULL,
        [CostElementCategory] [NVARCHAR](50) NOT NULL,
        [CostElementName] [NVARCHAR](250) NOT NULL,
        [CostElementId] [INT] NOT NULL,
        [GradeLevel] [INT] NULL,
        [Amount] [FLOAT] NULL
    );

    /* Get PROD cost view */
    IF @CategoryGroupCode = '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsProduction Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan;
    END;

    -- Display a cost factor for a Group
    IF @CategorySubGroupCode = '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsProduction Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND Costs.CategoryGroupCode = @CategoryGroupCode;
    END;

    --Display for a SubGroup
    IF @CategoryGroupCode <> '__ALL__'
       AND @CategorySubGroupCode <> '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsProduction Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND Costs.CategoryGroupCode = @CategoryGroupCode
              AND Costs.CategorySubGroupCode = @CategorySubGroupCode;
    END;

    DECLARE @From VARCHAR(1000);
    DECLARE @Select NVARCHAR(500);
    DECLARE @PivotValueColumn NVARCHAR(100);
    DECLARE @PivotSortColumn NVARCHAR(100);
    DECLARE @DataColumn NVARCHAR(50);
    DECLARE @GroupBy NVARCHAR(500);
    DECLARE @OrderBy NVARCHAR(500);

    SET @From
        = '(SELECT APPN,CostElementCategory,CostElementName, GradeLevel, Avg(Amount) As avgAmount FROM #tblCosts GROUP BY APPN, CostElementCategory, CostElementName, GradeLevel) as tblCosts ';
    SET @Select = N'APPN,CostElementCategory,CostElementName';
    SET @PivotValueColumn = N'GradeLevel';
    SET @PivotSortColumn = N'GradeLevel';
    SET @DataColumn = N'avgAmount';
    SET @GroupBy = N'APPN,CostElementCategory,CostElementName';
    SET @OrderBy = N'APPN,CostElementCategory,CostElementName';
    -- Totals

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit

    --Get TEST cost view
    TRUNCATE TABLE #tblCosts;

    IF @CategoryGroupCode = '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsExternalTest Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan;
    END;

    -- Display a cost factor for a Group
    IF @CategorySubGroupCode = '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsExternalTest Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND Costs.CategoryGroupCode = @CategoryGroupCode;
    END;

    --Display for a SubGroup
    IF @CategoryGroupCode <> '__ALL__'
       AND @CategorySubGroupCode <> '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM compare.CostsExternalTest Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND Costs.CategoryGroupCode = @CategoryGroupCode
              AND Costs.CategorySubGroupCode = @CategorySubGroupCode;
    END;

    SET @From
        = '(SELECT APPN, CostElementCategory, CostElementName, GradeLevel, Avg(Amount) As avgAmount FROM #tblCosts GROUP BY APPN, CostElementCategory, CostElementName, GradeLevel) as tblCosts ';
    EXEC web.spCrossTabGrades @From = N'',                           -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit

    --Get DEV cost view
    TRUNCATE TABLE #tblCosts;

    IF @CategoryGroupCode = '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM data.Costs Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan;
    END;

    -- Display a cost factor for a Group
    IF @CategorySubGroupCode = '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM data.Costs Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND Costs.CategoryGroupCode = @CategoryGroupCode;
    END;

    --Display for a SubGroup
    IF @CategoryGroupCode <> '__ALL__'
       AND @CategorySubGroupCode <> '__ALL__'
    BEGIN
        INSERT INTO #tblCosts
        (
            APPN,
            CostElementCategory,
            CostElementName,
            CostElementId,
            GradeLevel,
            Amount
        )
        SELECT Costs.APPN,
               Costs.CostElementCategory,
               Costs.CostElementName,
               Costs.CostElementId,
               Costs.GradeLevel,
               Costs.Amount
        FROM data.Costs Costs
            INNER JOIN @DefaultSummary DefaultSummary
                ON Costs.CostElementId = DefaultSummary.CostElementId
        WHERE Costs.PayPlan = @PayPlan
              AND Costs.CategoryGroupCode = @CategoryGroupCode
              AND Costs.CategorySubGroupCode = @CategorySubGroupCode;
    END;

    SET @From
        = '(SELECT APPN,CostElementCategory,CostElementName, GradeLevel, Avg(Amount) As avgAmount FROM #tblCosts GROUP BY APPN, CostElementCategory, CostElementName, GradeLevel) as tblCosts ';

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit

    DROP TABLE #tblCosts;

END;