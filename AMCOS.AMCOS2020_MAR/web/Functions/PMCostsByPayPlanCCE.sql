

-- =============================================
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMCostsByPayPlanCCE]
(
    @ProjectId INT,
    @AmcosVersionId INT
)
RETURNS @Costs TABLE
(
    PMCategoryName NVARCHAR(50) NULL,
    Uic NVARCHAR(6) NULL,
    PayPlan NVARCHAR(3) NOT NULL,
    CategoryGroupCode NVARCHAR(10) NOT NULL,
    CategorySubgroupCode NVARCHAR(10) NOT NULL,
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
)
AS
BEGIN

    DECLARE @CostSummaryName NVARCHAR(200) = N'Default';
    DECLARE @AvgCostOfSalaryAPPN NVARCHAR(100);
    DECLARE @AvgCostOfSalaryCostElementCategory NVARCHAR(50);
    DECLARE @AvgCostOfSalaryCostElementName NVARCHAR(250);
    DECLARE @AvgCostOfSalaryCostElementId INT;
    DECLARE @AvgCostOfSalaryApplyInflation BIT;
    DECLARE @AvgCostOfSalaryShowOrder INT;

    DECLARE @AvgCostOfBenefitsAPPN NVARCHAR(100);
    DECLARE @AvgCostOfBenefitsCostElementCategory NVARCHAR(50);
    DECLARE @AvgCostOfBenefitsCostElementName NVARCHAR(250);
    DECLARE @AvgCostOfBenefitsCostElementId INT;
    DECLARE @AvgCostOfBenefitsApplyInflation BIT;
    DECLARE @AvgCostOfBenefitsShowOrder INT;

    DECLARE @AvgCostOfOverheadAPPN NVARCHAR(100);
    DECLARE @AvgCostOfOverheadCostElementCategory NVARCHAR(50);
    DECLARE @AvgCostOfOverheadCostElementName NVARCHAR(250);
    DECLARE @AvgCostOfOverheadCostElementId INT;
    DECLARE @AvgCostOfOverheadApplyInflation BIT;
    DECLARE @AvgCostOfOverheadShowOrder INT;
    DECLARE @BenefitRatio NUMERIC(18, 4);

    DECLARE @MaxPayFootnote MONEY = crunch.GetSingleValue('CCE', 'MaxPayFootnote', @AmcosVersionId);
    SELECT @BenefitRatio = crunch.GetSingleValue('CCE', 'Benefits_All', @AmcosVersionId);

    SELECT @AvgCostOfSalaryCostElementId = CostElementId,
           @AvgCostOfSalaryAPPN = APPN,
           @AvgCostOfSalaryCostElementCategory = CostElementCategory,
           @AvgCostOfSalaryCostElementName = CostElementName,
           @AvgCostOfSalaryApplyInflation = ApplyInflation,
           @AvgCostOfSalaryShowOrder = ShowOrder
    FROM lookup.CostElement
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Salary';

    SELECT @AvgCostOfBenefitsCostElementId = CostElementId,
           @AvgCostOfBenefitsAPPN = APPN,
           @AvgCostOfBenefitsCostElementCategory = CostElementCategory,
           @AvgCostOfBenefitsCostElementName = CostElementName,
           @AvgCostOfBenefitsApplyInflation = ApplyInflation,
           @AvgCostOfBenefitsShowOrder = ShowOrder
    FROM lookup.CostElement
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Benefits';

    SELECT @AvgCostOfOverheadCostElementId = CostElementId,
           @AvgCostOfOverheadAPPN = APPN,
           @AvgCostOfOverheadCostElementCategory = CostElementCategory,
           @AvgCostOfOverheadCostElementName = CostElementName,
           @AvgCostOfOverheadApplyInflation = ApplyInflation,
           @AvgCostOfOverheadShowOrder = ShowOrder
    FROM lookup.CostElement
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Overhead';

    INSERT INTO @Costs
    (
        PMCategoryName,
        Uic,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
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
    SELECT DISTINCT
           PMCategorySkillInventory.CategoryName,
           PMCategorySkillInventory.Uic,
           PMCategorySkillInventory.PayPlan,
           PMCategorySkillInventory.CategoryGroupCode,
           PMCategorySkillInventory.CategorySubgroupCode,
           PMCategorySkillInventory.CareerProgramNumber,
           PMCategorySkillInventory.LocationId,
           PMCategorySkillInventory.LocationText,
           PMCategorySkillInventory.STRL,
           1,
           'A_PCT10',
           PMCategorySkillInventory.DependentStatus,
           PMCategorySkillInventory.NumberOfDependents,
           PMCategorySkillInventory.ActiveDutyDays,
           PMCategorySkillInventory.OverheadPercent,
           @CostSummaryName,
           @AvgCostOfSalaryAPPN,
           @AvgCostOfSalaryCostElementCategory,
           @AvgCostOfSalaryCostElementName,
           @AvgCostOfSalaryCostElementId,
           @AvgCostOfSalaryApplyInflation,
           @AvgCostOfSalaryShowOrder,
           PMCategorySkillInventory.Year,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT10 = 9999999 THEN
                    @MaxPayFootnote * PMCategorySkillInventory.Amount
                ELSE
                    Costs.A_PCT10 * PMCategorySkillInventory.Amount
            END
           ) AS Cost,
           (CASE
                WHEN Costs.A_PCT10 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM data.CostsCCE AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubgroupCode = Costs.SOC
               AND PMCategorySkillInventory.LocationId = Costs.LocationId
    WHERE PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.GradeLevel = 1
          AND Costs.AmcosVersionId = @AmcosVersionId
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CategoryName,
           PMCategorySkillInventory.Uic,
           PMCategorySkillInventory.PayPlan,
           PMCategorySkillInventory.CategoryGroupCode,
           PMCategorySkillInventory.CategorySubgroupCode,
           PMCategorySkillInventory.CareerProgramNumber,
           PMCategorySkillInventory.LocationId,
           PMCategorySkillInventory.LocationText,
           PMCategorySkillInventory.STRL,
           2,
           'A_PCT25',
           PMCategorySkillInventory.DependentStatus,
           PMCategorySkillInventory.NumberOfDependents,
           PMCategorySkillInventory.ActiveDutyDays,
           PMCategorySkillInventory.OverheadPercent,
           @CostSummaryName,
           @AvgCostOfSalaryAPPN,
           @AvgCostOfSalaryCostElementCategory,
           @AvgCostOfSalaryCostElementName,
           @AvgCostOfSalaryCostElementId,
           @AvgCostOfSalaryApplyInflation,
           @AvgCostOfSalaryShowOrder,
           PMCategorySkillInventory.Year,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT25 = 9999999 THEN
                    @MaxPayFootnote * PMCategorySkillInventory.Amount
                ELSE
                    Costs.A_PCT25 * PMCategorySkillInventory.Amount
            END
           ) AS Cost,
           (CASE
                WHEN Costs.A_PCT25 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM data.CostsCCE AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubgroupCode = Costs.SOC
               AND PMCategorySkillInventory.LocationId = Costs.LocationId
    WHERE PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.GradeLevel = 2
          AND Costs.AmcosVersionId = @AmcosVersionId
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CategoryName,
           PMCategorySkillInventory.Uic,
           PMCategorySkillInventory.PayPlan,
           PMCategorySkillInventory.CategoryGroupCode,
           PMCategorySkillInventory.CategorySubgroupCode,
           PMCategorySkillInventory.CareerProgramNumber,
           PMCategorySkillInventory.LocationId,
           PMCategorySkillInventory.LocationText,
           PMCategorySkillInventory.STRL,
           3,
           'A_MEDIAN',
           PMCategorySkillInventory.DependentStatus,
           PMCategorySkillInventory.NumberOfDependents,
           PMCategorySkillInventory.ActiveDutyDays,
           PMCategorySkillInventory.OverheadPercent,
           @CostSummaryName,
           @AvgCostOfSalaryAPPN,
           @AvgCostOfSalaryCostElementCategory,
           @AvgCostOfSalaryCostElementName,
           @AvgCostOfSalaryCostElementId,
           @AvgCostOfSalaryApplyInflation,
           @AvgCostOfSalaryShowOrder,
           PMCategorySkillInventory.Year,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_MEDIAN = 9999999 THEN
                    @MaxPayFootnote * PMCategorySkillInventory.Amount
                ELSE
                    Costs.A_MEDIAN * PMCategorySkillInventory.Amount
            END
           ) AS Cost,
           (CASE
                WHEN Costs.A_MEDIAN = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM data.CostsCCE AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubgroupCode = Costs.SOC
               AND PMCategorySkillInventory.LocationId = Costs.LocationId
    WHERE PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.GradeLevel = 3
          AND Costs.AmcosVersionId = @AmcosVersionId
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CategoryName,
           PMCategorySkillInventory.Uic,
           PMCategorySkillInventory.PayPlan,
           PMCategorySkillInventory.CategoryGroupCode,
           PMCategorySkillInventory.CategorySubgroupCode,
           PMCategorySkillInventory.CareerProgramNumber,
           PMCategorySkillInventory.LocationId,
           PMCategorySkillInventory.LocationText,
           PMCategorySkillInventory.STRL,
           4,
           'A_PCT75',
           PMCategorySkillInventory.DependentStatus,
           PMCategorySkillInventory.NumberOfDependents,
           PMCategorySkillInventory.ActiveDutyDays,
           PMCategorySkillInventory.OverheadPercent,
           @CostSummaryName,
           @AvgCostOfSalaryAPPN,
           @AvgCostOfSalaryCostElementCategory,
           @AvgCostOfSalaryCostElementName,
           @AvgCostOfSalaryCostElementId,
           @AvgCostOfSalaryApplyInflation,
           @AvgCostOfSalaryShowOrder,
           PMCategorySkillInventory.Year,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT75 = 9999999 THEN
                    @MaxPayFootnote * PMCategorySkillInventory.Amount
                ELSE
                    Costs.A_PCT75 * PMCategorySkillInventory.Amount
            END
           ) AS Cost,
           (CASE
                WHEN Costs.A_PCT75 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM data.CostsCCE AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubgroupCode = Costs.SOC
               AND PMCategorySkillInventory.LocationId = Costs.LocationId
    WHERE PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.GradeLevel = 4
          AND Costs.AmcosVersionId = @AmcosVersionId
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CategoryName,
           PMCategorySkillInventory.Uic,
           PMCategorySkillInventory.PayPlan,
           PMCategorySkillInventory.CategoryGroupCode,
           PMCategorySkillInventory.CategorySubgroupCode,
           PMCategorySkillInventory.CareerProgramNumber,
           PMCategorySkillInventory.LocationId,
           PMCategorySkillInventory.LocationText,
           PMCategorySkillInventory.STRL,
           5,
           'A_PCT90',
           PMCategorySkillInventory.DependentStatus,
           PMCategorySkillInventory.NumberOfDependents,
           PMCategorySkillInventory.ActiveDutyDays,
           PMCategorySkillInventory.OverheadPercent,
           @CostSummaryName,
           @AvgCostOfSalaryAPPN,
           @AvgCostOfSalaryCostElementCategory,
           @AvgCostOfSalaryCostElementName,
           @AvgCostOfSalaryCostElementId,
           @AvgCostOfSalaryApplyInflation,
           @AvgCostOfSalaryShowOrder,
           PMCategorySkillInventory.Year,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT90 = 9999999 THEN
                    @MaxPayFootnote * PMCategorySkillInventory.Amount
                ELSE
                    Costs.A_PCT90 * PMCategorySkillInventory.Amount
            END
           ) AS Cost,
           (CASE
                WHEN Costs.A_PCT90 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM data.CostsCCE AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubgroupCode = Costs.SOC
               AND PMCategorySkillInventory.LocationId = Costs.LocationId
    WHERE PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.GradeLevel = 5
          AND Costs.AmcosVersionId = @AmcosVersionId;

    INSERT INTO @Costs
    (
        PMCategoryName,
        Uic,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
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
           CategorySubgroupCode,
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
           @CostSummaryName,
           @AvgCostOfBenefitsAPPN,
           @AvgCostOfBenefitsCostElementCategory,
           @AvgCostOfBenefitsCostElementName,
           @AvgCostOfBenefitsCostElementId,
           @AvgCostOfBenefitsApplyInflation,
           @AvgCostOfBenefitsShowOrder,
           Year,
           Inventory,
           Cost * @BenefitRatio,
           ExceedsSalaryLimit
    FROM @Costs
    WHERE CostElementId = @AvgCostOfSalaryCostElementId;

    INSERT INTO @Costs
    (
        PMCategoryName,
        Uic,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
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
           CategorySubgroupCode,
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
           @CostSummaryName,
           @AvgCostOfOverheadAPPN,
           @AvgCostOfOverheadCostElementCategory,
           @AvgCostOfOverheadCostElementName,
           @AvgCostOfOverheadCostElementId,
           @AvgCostOfOverheadApplyInflation,
           @AvgCostOfOverheadShowOrder,
           Year,
           Inventory,
           Cost * OverheadPercent / 100,
           ExceedsSalaryLimit
    FROM @Costs
    WHERE CostElementId = @AvgCostOfSalaryCostElementId;

    RETURN;
END;