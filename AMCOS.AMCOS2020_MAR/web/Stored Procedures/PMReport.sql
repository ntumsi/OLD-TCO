CREATE PROCEDURE [web].[PMReport]
(
    @ProjectId INT,
    @AmcosVersionId INT
)
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #Costs
    (
        PMCategoryName NVARCHAR(50) NULL,
        Uic NVARCHAR(6) NULL,
        PayPlan NVARCHAR(3) NOT NULL,
        CategoryGroupCode NVARCHAR(10) NOT NULL,
        CategoryGroupDescription NVARCHAR(250) NULL,
        CategorySubgroupCode NVARCHAR(10) NOT NULL,
        CategorySubgroupDescription NVARCHAR(255) NULL,
        CareerProgramNumber NCHAR(2) NOT NULL,
        LocationId INT NOT NULL,
        LocationText NVARCHAR(150) NOT NULL,
        STRL NVARCHAR(20) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        Grade NVARCHAR(10) NOT NULL,
        DependentStatus NVARCHAR(25) NOT NULL,
        NumberOfDependents INT NOT NULL,
        ActiveDutyDays SMALLINT NULL,
        OverheadPercent FLOAT NULL,
        CostSummaryName NVARCHAR(50) NULL,
        APPN NVARCHAR(100) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        CostElementName NVARCHAR(250) NULL,
        CostElementId INT NULL,
        ApplyInflation BIT NULL,
        ShowOrder INT NULL,
        Year INTEGER NOT NULL,
        Inventory INT NULL,
        Cost FLOAT NULL,
        ExceedsSalaryLimit BIT NULL
    );

    /* Insert costs for all pay plans except CCE */
    INSERT INTO #Costs
    (
        PMCategoryName,
        Uic,
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubgroupDescription,
        CareerProgramNumber,
        LocationId,
        LocationText,
        STRL,
        GradeLevel,
        Grade,
        DependentStatus,
        NumberOfDependents,
        ActiveDutyDays,
        OverheadPercent,
        CostSummaryName,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        ApplyInflation,
        ShowOrder,
        Year,
        Inventory,
        Cost,
        ExceedsSalaryLimit
    )
    SELECT PMCategoryName,
           Uic,
           PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           CategorySubgroupCode,
           NULL AS CategorySubgroupDescription,
           CareerProgramNumber,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           Grade,
           DependentStatus,
           NumberOfDependents,
           ActiveDutyDays,
           OverheadPercent,
           CostSummaryName,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           ApplyInflation,
           ShowOrder,
           Year,
           Inventory,
           Cost,
           0
    FROM web.PMCostsByPayPlan(@ProjectId, @AmcosVersionId);

    /* Insert costs for reserve component pay plans */
    INSERT INTO #Costs
    (
        PMCategoryName,
        Uic,
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubgroupDescription,
        CareerProgramNumber,
        LocationId,
        LocationText,
        STRL,
        GradeLevel,
        Grade,
        DependentStatus,
        NumberOfDependents,
        ActiveDutyDays,
        OverheadPercent,
        CostSummaryName,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        ApplyInflation,
        ShowOrder,
        Year,
        Inventory,
        Cost,
        ExceedsSalaryLimit
    )
    SELECT PMCategoryName,
           Uic,
           PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           CategorySubgroupCode,
           NULL AS CategorySubgroupDescription,
           CareerProgramNumber,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           Grade,
           DependentStatus,
           NumberOfDependents,
           ActiveDutyDays,
           OverheadPercent,
           CostSummaryName,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           ApplyInflation,
           ShowOrder,
           Year,
           Inventory,
           Cost,
           0
    FROM web.PMCostsByPayPlanReserveComponents(@ProjectId, @AmcosVersionId);

    /* Temper the social security amount by the max allowed */
    DECLARE @Max_Wage_SSW NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);

    UPDATE #Costs
    SET Cost = CASE
                   WHEN Cost > @Max_Wage_SSW THEN
                       @Max_Wage_SSW
                   ELSE
                       Cost
               END
    WHERE CostElementId IN ( 290, 360, 414, 454, 524, 578 );

    /* Insert costs for CCE */
    INSERT INTO #Costs
    (
        PMCategoryName,
        Uic,
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubgroupDescription,
        CareerProgramNumber,
        LocationId,
        LocationText,
        STRL,
        GradeLevel,
        Grade,
        DependentStatus,
        NumberOfDependents,
        ActiveDutyDays,
        OverheadPercent,
        CostSummaryName,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        ApplyInflation,
        ShowOrder,
        Year,
        Inventory,
        Cost,
        ExceedsSalaryLimit
    )
    SELECT PMCategoryName,
           Uic,
           PayPlan,
           CategoryGroupCode,
           NULL,
           CategorySubgroupCode,
           NULL,
           CareerProgramNumber,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           Grade,
           DependentStatus,
           NumberOfDependents,
           ActiveDutyDays,
           OverheadPercent,
           CostSummaryName,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           ApplyInflation,
           ShowOrder,
           Year,
           Inventory,
           Cost,
           ExceedsSalaryLimit
    FROM web.PMCostsByPayPlanCCE(@ProjectId, @AmcosVersionId);

    /* Apply inflation */
    BEGIN
        UPDATE #Costs
        SET Cost = costs.Cost * JicInflationRates.Amount
        FROM #Costs Costs
            INNER JOIN lookup.JicInflationRates JicInflationRates
                ON Costs.APPN = JicInflationRates.Appropriation
                   AND Costs.Year = JicInflationRates.Year
        WHERE JicInflationRates.ConversionType = 'ThenToThen'
              AND Costs.ApplyInflation = 1
              AND JicInflationRates.AmcosVersionId = @AmcosVersionId;
    END;

    /* 3/2/2013 Gary temp replace this particular APPN value for proper sorting purpose.  'MMPA' will be replaced to 'PA' in ASP.Net code */
    UPDATE #Costs
    SET APPN = REPLACE(APPN, ' PA', ' MMPA')
    WHERE APPN LIKE '% PA%';

    UPDATE #Costs
    SET CostElementName = 'CCE_1Avg Cost of Salary'
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Salary';

    UPDATE #Costs
    SET CostElementName = 'CCE_2Avg Cost of Benefits'
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Benefits';

    UPDATE #Costs
    SET CostElementName = 'CCE_3Avg Cost of Overhead'
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Overhead';

    UPDATE #Costs
    SET CategoryGroupDescription = 'All'
    WHERE CategoryGroupCode = '-1';

    UPDATE #Costs
    SET CategorySubgroupDescription = 'All'
    WHERE CategorySubgroupCode = '-1';

    UPDATE #Costs
    SET CategoryGroupDescription = a.CategoryGroupCode + ':' + CategoryGroup.CategoryGroupDescription
    FROM #Costs a
        JOIN data.CategoryGroup CategoryGroup
            ON a.PayPlan = CategoryGroup.PayPlan
               AND a.CategoryGroupCode = CategoryGroup.CategoryGroupCode;

    UPDATE #Costs
    SET CategoryGroupDescription = a.CategoryGroupCode + ':' + CategorySubgroup.CategoryGroupDescription,
        CategorySubgroupDescription = a.CategorySubgroupCode + ':' + CategorySubgroup.CategorySubgroupDescription
    FROM #Costs a
        JOIN data.CategorySubgroup CategorySubgroup
            ON a.PayPlan = CategorySubgroup.PayPlan
               AND a.CategorySubgroupCode = CategorySubgroup.CategorySubgroupCode;

    UPDATE #Costs
    SET CategorySubgroupDescription = '0602 : Medical Officer Series'
    WHERE CategorySubgroupCode = '0602';

    UPDATE #Costs
    SET CategorySubgroupDescription = '0680 : Dental Officer Series'
    WHERE CategorySubgroupCode = '0680';

    SELECT PMCategoryName,
           Uic,
           PayPlan,
           CategoryGroupCode,
           CategoryGroupDescription,
           CategorySubgroupCode,
           CategorySubgroupDescription,
           CareerProgramNumber,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           Grade,
           DependentStatus,
           ActiveDutyDays,
           OverheadPercent,
           CostSummaryName,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           ShowOrder,
           Year,
           Inventory,
           Cost,
           ExceedsSalaryLimit
    INTO #CostDefault
    FROM #Costs
    WHERE CostSummaryName = 'Default';

    SELECT PMCategoryName,
           Uic,
           PayPlan,
           CategoryGroupCode,
           CategoryGroupDescription,
           CategorySubgroupCode,
           CategorySubgroupDescription,
           CareerProgramNumber,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           Grade,
           DependentStatus,
           ActiveDutyDays,
           OverheadPercent,
           CostSummaryName,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           ShowOrder,
           Year,
           Inventory,
           Cost,
           ExceedsSalaryLimit
    INTO #CostOsdCapeDodi
    FROM #Costs
    WHERE CostSummaryName <> 'Default';

    DECLARE @DefaultSummaryFrom NVARCHAR(1000) = N'#CostDefault';
    DECLARE @OsdCapeDodiSummaryFrom NVARCHAR(1000) = N'#CostOsdCapeDodi';
    DECLARE @Select NVARCHAR(500)
        = N'PMCategoryName [Sub-Project Name], UIC, PayPlan, CategoryGroupDescription [Category Group], CategorySubgroupDescription [Category Subgroup], LocationText [Location], GradeLevel, Grade, ActiveDutyDays [Active Duty Days], ExceedsSalaryLimit, APPN, CostElementCategory [Category], CostElementName [Cost Element], ShowOrder';
    DECLARE @PivotValueColumn NVARCHAR(100) = N'[Year]';
    DECLARE @PivotSortColumn NVARCHAR(100) = N'[Year]';
    DECLARE @DataColumn NVARCHAR(100) = N'ROUND(ISNULL(Cost,0),2)';
    DECLARE @GroupBy NVARCHAR(500)
        = N'PMCategoryName, UIC, PayPlan, CategoryGroupDescription, CategorySubgroupDescription, LocationText, GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory, CostElementName, ShowOrder';
    DECLARE @OrderBy NVARCHAR(500)
        = N'PMCategoryName, UIC, PayPlan, CategoryGroupDescription, CategorySubgroupDescription, LocationText, GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory, CostElementName, ShowOrder';

    EXEC web.spCrossTab @From = @DefaultSummaryFrom,           -- nvarchar(4000)
                        @Select = @Select,                     -- nvarchar(500)
                        @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                        @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                        @DataColumn = @DataColumn,             -- nvarchar(100)
                        @GroupBy = @GroupBy,                   -- nvarchar(500)
                        @OrderBy = @OrderBy,                   -- nvarchar(500)
                        @Debug = 1;                            -- bit

    EXEC web.spCrossTab @From = @OsdCapeDodiSummaryFrom,       -- nvarchar(4000)
                        @Select = @Select,                     -- nvarchar(500)
                        @PivotValueColumn = @PivotValueColumn, -- nvarchar(100)
                        @PivotSortColumn = @PivotSortColumn,   -- nvarchar(100)
                        @DataColumn = @DataColumn,             -- nvarchar(100)
                        @GroupBy = @GroupBy,                   -- nvarchar(500)
                        @OrderBy = @OrderBy,                   -- nvarchar(500)
                        @Debug = 1;                            -- bit

    DECLARE @BenefitRatio NUMERIC(18, 4) = crunch.GetSingleValue('CCE', 'Benefits_All', @AmcosVersionId);
    DECLARE @MaxPayFootnote MONEY = crunch.GetSingleValue('CCE', 'MaxPayFootnote', @AmcosVersionId);
    SELECT @MaxPayFootnote,
           @BenefitRatio,
           ISNULL(
           (
               SELECT MIN(PMCategorySkill.OverheadPercent)
               FROM webuser.PMCategorySkill PMCategorySkill
                   INNER JOIN webuser.PMCategory PMCategory
                       ON PMCategory.CategoryId = PMCategorySkill.CategoryId
               WHERE PMCategory.ProjectId = @ProjectId
                     AND PMCategorySkill.PayPlan = 'CCE'
           ),
           0
                 ) AS minOverheadPct,
           (
               SELECT COUNT(*) FROM #Costs WHERE PayPlan = 'CCE' AND Cost < 0
           ) AS CountOfOverLimitRows;

    DROP TABLE IF EXISTS #CostDefault;
    DROP TABLE IF EXISTS #CostOsdCapeDodi;
    DROP TABLE IF EXISTS #Costs;

END;