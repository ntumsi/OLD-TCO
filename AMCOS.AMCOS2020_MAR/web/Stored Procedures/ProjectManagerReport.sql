-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [web].[ProjectManagerReport]
    @ProjectId INT,
    @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #Costs
    (
        PMCategoryName NVARCHAR(50) NULL,
        PayPlan NVARCHAR(3) NOT NULL,
        CategoryGroupCode NVARCHAR(10) NOT NULL,
        CategoryGroupDescription NVARCHAR(250) NULL,
        CategorySubgroupCode NVARCHAR(10) NOT NULL,
        CategorySubgroupDescription NVARCHAR(255) NULL,
        CareerProgramNumber NCHAR(2) NOT NULL,
        LocationId INTEGER NOT NULL,
        LocationText NVARCHAR(105) NOT NULL,
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

    CREATE TABLE #DefaultCostSummaryElements
    (
        PayPlan NVARCHAR(3) NOT NULL,
        CostElementId INT NOT NULL
    );
    INSERT INTO #DefaultCostSummaryElements
    (
        PayPlan,
        CostElementId
    )
    SELECT CostSummary.PayPlan,
           CostSummaryElement.CostElementId
    FROM lookup.CostSummaryElement AS CostSummaryElement
        INNER JOIN lookup.CostSummary AS CostSummary
            ON CostSummaryElement.SummaryId = CostSummary.SummaryId
               AND CostSummary.Name = 'Default'
               AND @AmcosVersionId
               BETWEEN CostSummaryElement.AmcosVersionIdStart AND CostSummaryElement.AmcosVersionIdEnd
               AND @AmcosVersionId
               BETWEEN CostSummary.AmcosVersionIdStart AND CostSummary.AmcosVersionIdEnd;

    /* Insert costs for reserve component pay plans */
    INSERT INTO #Costs
    (
        PMCategoryName,
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
    SELECT PMCategorySkillInventory.CategoryName PMCategoryName,
           PMCategorySkillInventory.PayPlan,
           PMCategorySkillInventory.CategoryGroupCode,
           'TODO' AS CategoryGroupDescription,
           PMCategorySkillInventory.CategorySubgroupCode,
           'TODO' AS CategorySubgroupDescription,
           PMCategorySkillInventory.CareerProgramNumber,
           PMCategorySkillInventory.LocationId,
           PMCategorySkillInventory.LocationText,
           PMCategorySkillInventory.STRL,
           PMCategorySkillInventory.GradeLevel,
           web.FormatGradeLevel(PMCategorySkillInventory.PayPlan, PMCategorySkillInventory.GradeLevel) Grade,
           PMCategorySkillInventory.DependentStatus,
           PMCategorySkillInventory.NumberOfDependents,
           PMCategorySkillInventory.ActiveDutyDays,
           PMCategorySkillInventory.OverheadPercent,
           DefaultSummaryCostElements.CostSummaryName,
           DefaultSummaryCostElements.APPN,
           DefaultSummaryCostElements.CostElementCategory,
           DefaultSummaryCostElements.CostElementName,
           DefaultSummaryCostElements.CostElementId,
           DefaultSummaryCostElements.ApplyInflation,
           DefaultSummaryCostElements.ShowOrder,
           PMCategorySkillInventory.Year,
           PMCategorySkillInventory.Amount Inventory,
           (Costs.Amount + Costs1ActiveDay.Amount) * PMCategorySkillInventory.ActiveDutyDays
           * PMCategorySkillInventory.Amount Cost,
           0 AS ExceedsSalaryLimit
    FROM data.Costs Costs
        INNER JOIN crunch.Costs_1ActiveDay Costs1ActiveDay
            ON Costs.CostElementId = Costs1ActiveDay.CostElementId
               AND Costs.AmcosVersionId = Costs1ActiveDay.AmcosVersionId
               AND Costs.PayPlan = Costs1ActiveDay.PayPlan
               AND Costs.CategoryGroupCode = Costs1ActiveDay.CategoryGroupCode
               AND Costs.CategorySubgroupCode = Costs1ActiveDay.CategorySubgroupCode
               AND Costs.GradeLevel = Costs1ActiveDay.GradeLevel
               AND Costs.WeaponSystemId = Costs1ActiveDay.WeaponSystemId
        INNER JOIN data.CurrentDefaultSummaryCostElements DefaultSummaryCostElements
            ON Costs.CostElementId = DefaultSummaryCostElements.CostElementId
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.PayPlan = Costs.PayPlan
               AND PMCategorySkillInventory.CategoryGroupCode = Costs.CategoryGroupCode
               AND PMCategorySkillInventory.CategorySubgroupCode = Costs.CategorySubgroupCode
               AND PMCategorySkillInventory.GradeLevel = Costs.GradeLevel
        INNER JOIN webuser.PMReport PMReport
            ON PMReport.CategoryId = PMCategorySkillInventory.CategoryId
               AND PMReport.PayPlan = PMCategorySkillInventory.PayPlan
    WHERE Costs.AmcosVersionId = @AmcosVersionId
          AND PMCategorySkillInventory.ProjectId = @ProjectId;

    /* Insert costs for CCE */
    INSERT INTO #Costs
    (
        PMCategoryName,
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

    /* Insert costs for all pay plans except CCE */
    INSERT INTO #Costs
    (
        PMCategoryName,
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

    CREATE CLUSTERED INDEX ix_tempCosts
    ON #Costs (
                  PayPlan,
                  CategoryGroupCode,
                  CategorySubgroupCode,
                  CareerProgramNumber,
                  LocationId,
                  CostElementId,
                  GradeLevel
              );

    /* Apply inflation */
    BEGIN
        UPDATE #Costs
        SET Cost = Costs.Cost * JicInflationRates.Amount
        FROM #Costs Costs
            INNER JOIN lookup.JicInflationRates JicInflationRates
                ON Costs.APPN = JicInflationRates.Appropriation
                   AND Costs.Year = JicInflationRates.Year
        WHERE JicInflationRates.ConversionType = 'ThenToThen'
              AND Costs.ApplyInflation = 1
              AND JicInflationRates.AmcosVersionId = @AmcosVersionId;
    END;

    SELECT PMCategoryName,
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
    FROM #Costs;

END;