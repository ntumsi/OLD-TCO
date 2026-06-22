
CREATE PROCEDURE [web].[GetAmcosLiteCostsGSSpecialPayPlusLocality]
    @CategoryGroupCode NVARCHAR(7),
    @CategorySubgroupCode NVARCHAR(7),
    @CostSummaryId INTEGER,
    @LocalityId INTEGER,
    @SpecialRateTableNumber NVARCHAR(4),
    @InflationConversion NVARCHAR(25),
    @InflationYear NVARCHAR(4)
AS
BEGIN

    IF @CostSummaryId IS NOT NULL
        DECLARE @CostSummaryName NVARCHAR(50) = web.GetCostSummaryName(@CostSummaryId);

    DECLARE @LocalityRate FLOAT = web.GetLocalityRate(@LocalityId);

    DECLARE @CostSummaryIdGSS INTEGER;
    IF @CostSummaryId = 16
        SET @CostSummaryIdGSS = 46;

    CREATE TABLE #AmcosLite
    (
        appnGroup NVARCHAR(50) NULL,
        APPN NVARCHAR(25) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        CostElementName NVARCHAR(250) NULL,
        Description NVARCHAR(3000) NULL,
        CostElementId INTEGER NOT NULL,
        ShowOrder INTEGER NULL,
        Locality BIT NULL,
        SpecialRateTableNumber NVARCHAR(4) NULL,
        GradeLevel TINYINT NULL,
        Grade NVARCHAR(5) NULL,
        Amount FLOAT NULL
    );

    INSERT INTO #AmcosLite
    (
        appnGroup,
        APPN,
        CostElementCategory,
        CostElementName,
        Description,
        CostElementId,
        ShowOrder,
        Locality,
        SpecialRateTableNumber,
        GradeLevel,
        Grade,
        Amount
    )
    SELECT Costs.AppropriationGroup,
           Costs.APPN,
           Costs.CostElementCategory,
           Costs.CostElementName,
           Costs.Description,
           Costs.CostElementId,
           Costs.showOrder,
           Costs.Locality,
           Costs.SpecialRateTableNumber,
           Costs.GradeLevel,
           CAST('GS' AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2)) AS Grade,
           Costs.Amount
    FROM data.Costs Costs
        INNER JOIN lookup.CostSummaryElement CSE
            ON CSE.CostElementId = Costs.CostElementId
    WHERE Costs.PayPlan = 'GSS'
          AND Costs.CategoryGroupCode = @CategoryGroupCode
          AND Costs.CategorySubGroupCode = @CategorySubgroupCode
          AND CSE.SummaryId = @CostSummaryIdGSS
          AND Costs.SpecialRateTableNumber = @SpecialRateTableNumber;

    IF @CostSummaryName = 'Default'
    BEGIN
        /* Inventory */
        SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               SUM(Inventory) AS Inventory
        FROM data.Inventory
        WHERE PayPlan = 'GS'
        GROUP BY GradeLevel,
                 CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2));

        /* Min and Max Pay */
        SELECT Grade,
               GradeLevel,
               MinimumPay,
               MaximumPay
        FROM web.GetMinMaxPay('GSS', @CategoryGroupCode, @CategorySubgroupCode, @LocalityId, @SpecialRateTableNumber);
    END;

    /* All Costs Summary */
    IF (@CostSummaryId = 0)
    BEGIN
        INSERT INTO #AmcosLite
        (
            appnGroup,
            APPN,
            CostElementCategory,
            CostElementName,
            Description,
            CostElementId,
            GradeLevel,
            Grade,
            Amount
        )
        SELECT AppropriationGroup,
               APPN,
               CostElementCategory,
               CostElementName,
               Description,
               CostElementId,
               GradeLevel,
               CAST('GS' AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2)) AS Grade,
               Amount
        FROM data.Costs
        WHERE PayPlan = 'GSS'
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubGroupCode = @CategorySubgroupCode
              AND SpecialRateTableNumber = @SpecialRateTableNumber;
    END;

    /* Remove Grade Levels that are not in the Inventory */
    DECLARE @GradeLevelsWithInventory TABLE
    (
        GradeLevel INTEGER NOT NULL
    );

    IF (@CostSummaryId <> 0)
        INSERT INTO @GradeLevelsWithInventory
        SELECT DISTINCT
               tblCosts.GradeLevel
        FROM
        (
            SELECT PayPlan,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   SpecialRateTableNumber,
                   CostElementId,
                   GradeType,
                   GradeLevel,
                   Amount
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategoryGroupCode = @CategoryGroupCode
                  AND CategorySubGroupCode = @CategorySubgroupCode
        ) tblCosts
            INNER JOIN
            (
                SELECT PayPlan,
                       APPN,
                       CostElementCategory,
                       CostElementName,
                       Amort,
                       Model
                FROM lookup.CostSummariesByPayPlan
                WHERE SummaryId = @CostSummaryId
                      AND PayPlan = 'GS'
            ) tblSum
                ON tblCosts.APPN = tblSum.APPN
                   AND tblCosts.CostElementCategory = tblSum.CostElementCategory
                   AND tblCosts.CostElementName = tblSum.CostElementName
            INNER JOIN lookup.CostElement tblElement
                ON tblElement.CostElementId = tblCosts.CostElementId;
    ELSE
        INSERT INTO @GradeLevelsWithInventory
        SELECT DISTINCT
               GradeLevel
        FROM data.Costs
        WHERE Costs.PayPlan = 'GS'
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubGroupCode = @CategorySubgroupCode;

    DELETE FROM #AmcosLite
    WHERE GradeLevel NOT IN
          (
              SELECT GradeLevel FROM @GradeLevelsWithInventory
          );

    /* Include Locality Pay */
    UPDATE #AmcosLite
    SET Amount = Amount * @LocalityRate
    WHERE Locality = 1;

    UPDATE #AmcosLite
    SET Amount = i.Amount * a.Amount
    FROM #AmcosLite a
        INNER JOIN lookup.JicInflationRates i
            ON @InflationConversion = i.ConversionType
               AND @InflationYear = i.Year
               AND a.APPN = i.Appropriation;

    DECLARE @From NVARCHAR(1000)
        = N'(SELECT appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade,Avg(Amount) As Amount FROM #AmcosLite GROUP BY appnGroup, APPN, CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade) as tblCosts ';
    DECLARE @Select NVARCHAR(500)
        = N'appnGroup,APPN,CostElementCategory AS [Cost Element Category],CostElementName AS [Cost Element Name],Description,ShowOrder';
    DECLARE @PivotValueColumn NVARCHAR(100) = N'Grade';
    DECLARE @PivotSortColumn NVARCHAR(100) = N'GradeLevel';
    DECLARE @DataColumn NVARCHAR(50) = N'Amount';
    DECLARE @GroupBy NVARCHAR(500) = N'appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder';
    DECLARE @OrderBy NVARCHAR(500) = N'appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder';

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(500)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = 0;                            -- bit   

    IF @CostSummaryName = 'Default'
    BEGIN;
        WITH AmcosLiteChart_CTE (appnGroup, APPN, CostElementCategory, ShowOrder, Grade, GradeLevel, Amount)
        AS (SELECT appnGroup,
                   APPN,
                   CostElementCategory,
                   ShowOrder,
                   Grade,
                   GradeLevel,
                   AVG(Amount) AS Amount
            FROM #AmcosLite
            GROUP BY appnGroup,
                     APPN,
                     CostElementCategory,
                     ShowOrder,
                     Grade,
                     GradeLevel)
        SELECT AmcosLiteChart_CTE.Grade,
               AmcosLiteChart_CTE.GradeLevel,
               AmcosLiteChart_CTE.CostElementCategory,
               MIN(AmcosLiteChart_CTE.ShowOrder) AS ShowOrder,
               SUM(AmcosLiteChart_CTE.Amount) AS Amount
        FROM AmcosLiteChart_CTE
        GROUP BY AmcosLiteChart_CTE.Grade,
                 AmcosLiteChart_CTE.GradeLevel,
                 AmcosLiteChart_CTE.CostElementCategory
        ORDER BY MIN(AmcosLiteChart_CTE.ShowOrder);
    END;

    IF @CostSummaryName = 'Default'
    BEGIN
        SELECT Grade,
               GradeLevel,
               AVG(Amount) AS AveragePay
        FROM #AmcosLite
        WHERE CostElementName LIKE '%base pay%'
        GROUP BY Grade,
                 GradeLevel;
    END;

END;