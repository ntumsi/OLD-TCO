

/*  
Description:	Provide the costs to AMCOS Lite screen
Author:			Roger, Gary, Greg
Create Date:	?
Param:			
Return:			Average cost for cost element by grade
				Army Cost Element Structure Names (For weapon system manpower cost summary)
Modified Date:  
Modification:   
*/
CREATE PROCEDURE [web].[GetAmcosLiteCosts]
    @PayPlan NVARCHAR(3),
    @CostSummaryName NVARCHAR(50) = 'Default',
    @CategoryGroupCode NVARCHAR(4) = '-1',
    @CategorySubgroupCode NVARCHAR(5) = '-1',
    @CareerProgramNumber NCHAR(2) = '-1',
    @LocationId INTEGER = -1,
    @STRL NVARCHAR(20) = '-1',
    @DependentStatus NVARCHAR(25) = '-1',
    @NumberOfDependents INTEGER = -1,
    @InflationConversion NVARCHAR(25),
    @InflationYear NVARCHAR(4),
    @AmcosVersionId INTEGER = 202001,
    @IncludeVisualizationData BIT = 1,
    @Debug BIT = 0
AS
BEGIN
    --SET NOCOUNT ON;
    IF @PayPlan IN
       (
           SELECT PayPlan FROM analysis.GetPayPlans('Military')
       )
       AND @CategorySubgroupCode = '-1'
       AND @LocationId <> -1
    BEGIN
        --as of 12/2019 location specific costs are only generated at the subgroup level so queries above that level with a location are invalid
        --if we didn't have this then costs would be returned but they would be wrong and misleading since they would be missing BAH and Overseas costs
        RAISERROR('No military cost data exists for group or payplan level aggregation', 18, 1);
        RETURN;
    END;

    IF @CostSummaryName IS NOT NULL
        DECLARE @CostSummaryId INTEGER = web.GetCostSummaryId(@PayPlan, @CostSummaryName, @AmcosVersionId);

    CREATE TABLE #AmcosLite
    (
        appnGroup NVARCHAR(50) NULL,
        APPN NVARCHAR(50) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        CostElementName NVARCHAR(250) NULL,
        Description NVARCHAR(3000) NULL,
        CostElementId INTEGER NULL,
        ShowOrder INTEGER NULL,
        ApplyInflation BIT NULL,
        GradeLevel TINYINT NULL,
        Grade NVARCHAR(5) NULL,
        WeaponSystemId INTEGER NULL,
        WeaponSystemName NVARCHAR(50) NULL,
        Amount FLOAT NULL,
        ArmyCesTitle NVARCHAR(250) NULL,
        OsdCapeCesTitle NVARCHAR(250) NULL,
        AmcosVersionId INT NOT NULL
    ) ON [PRIMARY];

    /* Costs for each cost element by grade */
    INSERT INTO #AmcosLite
    (
        appnGroup,
        APPN,
        CostElementCategory,
        CostElementName,
        Description,
        CostElementId,
        ShowOrder,
        ApplyInflation,
        GradeLevel,
        Grade,
        WeaponSystemId,
        WeaponSystemName,
        Amount,
        ArmyCesTitle,
        OsdCapeCesTitle,
        AmcosVersionId
    )
    SELECT AppropriationGroup,
           APPN,
           CostElementCategory,
           CostElementName,
           Description,
           CostElementId,
           ShowOrder,
           ApplyInflation,
           GradeLevel,
           Grade,
           WeaponSystemId,
           WeaponSystemName,
           Amount,
           ArmyCesTitle,
           OsdCapeCesTitle,
           AmcosVersionId
    FROM web.GetCosts(
                         @PayPlan,
                         @CostSummaryName,
                         @CategoryGroupCode,
                         @CategorySubgroupCode,
                         @CareerProgramNumber,
                         @LocationId,
                         @STRL,
                         @DependentStatus,
                         @NumberOfDependents,
                         @AmcosVersionId
                     );

    IF (@IncludeVisualizationData = 1)
       AND (@CostSummaryName = 'Default')
    BEGIN
        /* Inventory */
        SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               SUM(ISNULL(Inventory, 0)) AS Inventory
        FROM web.Inventory
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode = @CategoryGroupCode
              AND CategorySubgroupCode = @CategorySubgroupCode
              AND CareerProgramNumber = @CareerProgramNumber
              AND LocationId = @LocationId
              AND Strl = @STRL
        GROUP BY GradeLevel,
                 CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2))
        ORDER BY GradeLevel;

        /* Min and Max Pay */
        SELECT MinMaxPay.Grade,
               MinMaxPay.GradeLevel,
               MinMaxPay.MinimumPay * JicInflationRates.Amount MinimumPay,
               MinMaxPay.MaximumPay * JicInflationRates.Amount MaximumPay
        FROM web.GetMinMaxPay(
                                 @PayPlan,
                                 @CategoryGroupCode,
                                 @CategorySubgroupCode,
                                 @CareerProgramNumber,
                                 @LocationId,
                                 @STRL,
                                 @AmcosVersionId
                             ) MinMaxPay
            INNER JOIN lookup.JicInflationRates JicInflationRates
                ON @InflationConversion = JicInflationRates.ConversionType
                   AND @InflationYear = JicInflationRates.Year
                   AND MinMaxPay.Appropriation = JicInflationRates.Appropriation
                   AND @AmcosVersionId = JicInflationRates.AmcosVersionId
        ORDER BY MinMaxPay.GradeLevel;
    END;

    /* Apply inflation */
    UPDATE #AmcosLite
    SET Amount = JicInflationRates.Amount * AmcosLite.Amount
    FROM #AmcosLite AmcosLite
        INNER JOIN lookup.JicInflationRates JicInflationRates
            ON @InflationConversion = JicInflationRates.ConversionType
               AND @InflationYear = JicInflationRates.Year
               AND AmcosLite.APPN = JicInflationRates.Appropriation
               AND AmcosLite.AmcosVersionId = JicInflationRates.AmcosVersionId
    WHERE AmcosLite.ApplyInflation = 1;

    /* Include Weapon System Name instead of Id */
    UPDATE #AmcosLite
    SET WeaponSystemName = w.WeaponSystemName
    FROM #AmcosLite A
        INNER JOIN lookup.WeaponSystem w
            ON w.WeaponSystemId = A.WeaponSystemId
               AND (A.AmcosVersionId
               BETWEEN w.AmcosVersionIdStart AND w.AmcosVersionIdEnd
                   )
    WHERE w.WeaponSystemName <> 'Not Applicable';

    /* Pivot results on grade level */
    DECLARE @From NVARCHAR(1000);
    IF (@CostSummaryName = 'Detailed')
       OR (@CostSummaryName = 'Training')
       OR (@CostSummaryName = 'Ancillary')
        SET @From
            = N'(SELECT appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade,Amount = CASE WHEN CostElementName = ''Avg Cost of Weapon Specific Training'' THEN SUM(Amount) WHEN CostElementName LIKE ''Actual Cost%'' THEN SUM(Amount) ELSE AVG(Amount) END FROM #AmcosLite GROUP BY appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade) as Costs ';
    ELSE
        SET @From
            = N'(SELECT appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade,Avg(Amount) AS Amount FROM #AmcosLite GROUP BY appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder,GradeLevel,Grade) as Costs ';

    DECLARE @Select NVARCHAR(500)
        = N'appnGroup,APPN,CostElementCategory AS [Cost Element Category],CostElementName AS [Cost Element Name],Description,ShowOrder';
    DECLARE @PivotValueColumn NVARCHAR(100) = N'Grade';
    DECLARE @PivotSortColumn NVARCHAR(100) = N'GradeLevel';
    DECLARE @DataColumn NVARCHAR(100) = N'Amount';
    DECLARE @GroupBy NVARCHAR(500) = N'appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder';
    DECLARE @OrderBy NVARCHAR(500) = N'appnGroup,APPN,CostElementCategory,CostElementName,Description,ShowOrder';

    IF @CostSummaryName = 'Weapon System Manpower'
    BEGIN
        SET @From = REPLACE(@From, 'CostElementName', 'ArmyCesTitle,OsdCapeCesTitle,WeaponSystemName,CostElementName');
        SET @GroupBy
            = REPLACE(@GroupBy, 'CostElementName', 'ArmyCesTitle,OsdCapeCesTitle,WeaponSystemName,CostElementName');
        SET @OrderBy
            = REPLACE(@OrderBy, 'CostElementName', 'ArmyCesTitle,OsdCapeCesTitle,WeaponSystemName,CostElementName');
        SET @Select
            = REPLACE(
                         @Select,
                         'CostElementName AS [Cost Element Name]',
                         'ArmyCesTitle AS [Army CES Title],OsdCapeCesTitle AS [OSD CAPE CES Title],WeaponSystemName AS [Weapon System Name],CostElementName AS [Cost Element Name]'
                     );
    END;

    EXEC web.spCrossTabGrades @From = @From,                         -- nvarchar(4000)
                              @Select = @Select,                     -- nvarchar(500)
                              @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                              @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                              @DataColumn = @DataColumn,             -- nvarchar(100)
                              @GroupBy = @GroupBy,                   -- nvarchar(500)
                              @OrderBy = @OrderBy,                   -- nvarchar(500)
                              @Debug = @Debug;                       -- bit

    IF (@IncludeVisualizationData = 1)
       AND (@CostSummaryName = 'Default')
    BEGIN;
        WITH AmcosLiteChart_CTE (appnGroup, APPN, CostElementCategory, CostElementName, ShowOrder, Grade, GradeLevel,
                                 Amount, AmcosVersionId
                                )
        AS (SELECT appnGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   ShowOrder,
                   Grade,
                   GradeLevel,
                   Amount,
                   AmcosVersionId
            FROM #AmcosLite
            GROUP BY appnGroup,
                     APPN,
                     CostElementCategory,
                     CostElementName,
                     ShowOrder,
                     Grade,
                     GradeLevel,
                     Amount,
                     AmcosVersionId)
        SELECT AmcosLiteChart_CTE.Grade,
               AmcosLiteChart_CTE.GradeLevel,
               AmcosLiteChart_CTE.CostElementCategory,
               MIN(AmcosLiteChart_CTE.ShowOrder) AS ShowOrder,
               SUM(Amount) AS Amount
        FROM AmcosLiteChart_CTE
        GROUP BY AmcosLiteChart_CTE.Grade,
                 AmcosLiteChart_CTE.GradeLevel,
                 AmcosLiteChart_CTE.CostElementCategory
        ORDER BY AmcosLiteChart_CTE.GradeLevel,
                 MIN(AmcosLiteChart_CTE.ShowOrder);
    END;

    IF (@IncludeVisualizationData = 1)
       AND (@CostSummaryName = 'Default')
    BEGIN
        SELECT Grade,
               GradeLevel,
               AVG(Amount) AS AveragePay
        FROM #AmcosLite
        WHERE CostElementName LIKE '%base pay%'
              AND CostElementName NOT LIKE '%base pay 2%'
        GROUP BY Grade,
                 GradeLevel
        ORDER BY GradeLevel;
    END;
END;