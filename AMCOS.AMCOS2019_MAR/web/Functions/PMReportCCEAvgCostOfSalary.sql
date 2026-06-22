
-- =============================================
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMReportCCEAvgCostOfSalary]
(
    @UserId VARCHAR(50),
    @ProjectId INT
)
RETURNS @Table_Var TABLE
(
    CategoryName NVARCHAR(50) NOT NULL,
    [Year] INT NOT NULL,
    PayPlan NVARCHAR(3) NOT NULL,
    CategoryGroupCode NVARCHAR(10) NOT NULL,
    CategorySubgroupCode NVARCHAR(10) NOT NULL,
    Area NVARCHAR(500) NOT NULL,
    Locality NVARCHAR(100) NOT NULL,
    Grade NVARCHAR(10) NOT NULL,
    Summary NVARCHAR(200) NOT NULL,
    APPN NVARCHAR(100) NOT NULL,
    CostElementName NVARCHAR(300) NOT NULL,
    CostElementId INT NOT NULL,
    Inv INT NOT NULL,
    Cost MONEY NOT NULL,
    CostElementCategory NVARCHAR(50) NOT NULL,
    ExceedsSalaryLimit BIT NOT NULL
)
AS
BEGIN
    DECLARE @AvgCostOfSalary INTEGER = dbo.GetCostElementId('CCE', 'Contractor', 'Avg Cost of Salary');
    DECLARE @ProjectStartYear INTEGER;
    DECLARE @NumberOfYears INTEGER;

    SELECT @ProjectStartYear = YearStart,
           @NumberOfYears = YearDuration
    FROM webuser.PMProject
    WHERE ProjectId = @ProjectId;


    INSERT INTO @Table_Var
    (
        CategoryName,
        Year,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        Area,
        Locality,
        Grade,
        Summary,
        APPN,
        CostElementName,
        CostElementId,
        Inv,
        Cost,
        CostElementCategory,
        ExceedsSalaryLimit
    )
    SELECT DISTINCT
           PMCategorySkillInventory.CatName,
           PMCategorySkillInventory.[Year],
           'CCE',
           LEFT(Costs.SOC, 3) + '0000',
           Costs.SOC,
           Costs.AreaCode,
           '',
           'A_PCT10',
           PMUserSummaryElementsCCE.SummaryName,
           PMUserSummaryElementsCCE.APPN,
           PMUserSummaryElementsCCE.CostElementName,
           PMUserSummaryElementsCCE.CostElementId,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT10 = 9999999 THEN
                    208000
                ELSE
                    web.PMInflatedValue(
                                           Costs.A_PCT10 * PMCategorySkillInventory.Amount,
                                           PMUserSummaryElementsCCE.CostElementId,
                                           PMCategorySkillInventory.[Year] + @ProjectStartYear,
                                           1,
                                           0,
                                           0
                                       )
            END
           ) AS Cost,
           PMUserSummaryElementsCCE.CostElementCategory,
           (CASE
                WHEN Costs.A_PCT10 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM dataload.OccupationalEmploymentStatisticsMetro AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubGroupCode = Costs.SOC
               AND PMCategorySkillInventory.AreaCode = Costs.AreaCode
        INNER JOIN web.PMUserSummaryElementsCCE(@UserId, @ProjectId) PMUserSummaryElementsCCE
            ON PMUserSummaryElementsCCE.PayPlan = PMCategorySkillInventory.PayPlan
               AND PMUserSummaryElementsCCE.SummaryName = PMCategorySkillInventory.SummaryName
    WHERE PMCategorySkillInventory.UserId = @UserId
          AND PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.PayPlan = 'CCE'
          AND PMCategorySkillInventory.SummaryName = 'Default'
          AND PMUserSummaryElementsCCE.CostElementId = @AvgCostOfSalary
          AND PMUserSummaryElementsCCE.APPN = 'Contractor'
          AND PMCategorySkillInventory.[Year] < @NumberOfYears
          AND PMCategorySkillInventory.GradeLevel = 1
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CatName,
           PMCategorySkillInventory.[Year],
           'CCE',
           LEFT(Costs.SOC, 3) + '0000',
           Costs.SOC,
           Costs.AreaCode,
           '',
           'A_PCT25',
           PMUserSummaryElementsCCE.SummaryName,
           PMUserSummaryElementsCCE.APPN,
           PMUserSummaryElementsCCE.CostElementName,
           PMUserSummaryElementsCCE.CostElementId,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT25 = 9999999 THEN
                    208000
                ELSE
                    web.PMInflatedValue(
                                           Costs.A_PCT25 * PMCategorySkillInventory.Amount,
                                           PMUserSummaryElementsCCE.CostElementId,
                                           PMCategorySkillInventory.[Year] + @ProjectStartYear,
                                           1,
                                           0,
                                           0
                                       )
            END
           ) AS Cost,
           PMUserSummaryElementsCCE.CostElementCategory,
           (CASE
                WHEN Costs.A_PCT25 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM dataload.OccupationalEmploymentStatisticsMetro AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubGroupCode = Costs.SOC
               AND PMCategorySkillInventory.AreaCode = Costs.AreaCode
        INNER JOIN web.PMUserSummaryElementsCCE(@UserId, @ProjectId) PMUserSummaryElementsCCE
            ON PMUserSummaryElementsCCE.PayPlan = PMCategorySkillInventory.PayPlan
               AND PMUserSummaryElementsCCE.SummaryName = PMCategorySkillInventory.SummaryName
    WHERE PMCategorySkillInventory.UserId = @UserId
          AND PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.PayPlan = 'CCE'
          AND PMCategorySkillInventory.SummaryName = 'Default'
          AND PMUserSummaryElementsCCE.CostElementId = @AvgCostOfSalary
          AND PMUserSummaryElementsCCE.APPN = 'Contractor'
          AND PMCategorySkillInventory.[Year] < @NumberOfYears
          AND PMCategorySkillInventory.GradeLevel = 2
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CatName,
           PMCategorySkillInventory.[Year],
           'CCE',
           LEFT(Costs.SOC, 3) + '0000',
           Costs.SOC,
           Costs.AreaCode,
           '',
           'A_MEDIAN',
           PMUserSummaryElementsCCE.SummaryName,
           PMUserSummaryElementsCCE.APPN,
           PMUserSummaryElementsCCE.CostElementName,
           PMUserSummaryElementsCCE.CostElementId,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_MEDIAN = 9999999 THEN
                    208000
                ELSE
                    web.PMInflatedValue(
                                           Costs.A_MEDIAN * PMCategorySkillInventory.Amount,
                                           PMUserSummaryElementsCCE.CostElementId,
                                           PMCategorySkillInventory.[Year] + @ProjectStartYear,
                                           1,
                                           0,
                                           0
                                       )
            END
           ) AS Cost,
           PMUserSummaryElementsCCE.CostElementCategory,
           (CASE
                WHEN Costs.A_MEDIAN = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM dataload.OccupationalEmploymentStatisticsMetro AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubGroupCode = Costs.SOC
               AND PMCategorySkillInventory.AreaCode = Costs.AreaCode
        INNER JOIN web.PMUserSummaryElementsCCE(@UserId, @ProjectId) PMUserSummaryElementsCCE
            ON PMUserSummaryElementsCCE.PayPlan = PMCategorySkillInventory.PayPlan
               AND PMUserSummaryElementsCCE.SummaryName = PMCategorySkillInventory.SummaryName
    WHERE PMCategorySkillInventory.UserId = @UserId
          AND PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.PayPlan = 'CCE'
          AND PMCategorySkillInventory.SummaryName = 'Default'
          AND PMUserSummaryElementsCCE.CostElementId = @AvgCostOfSalary
          AND PMUserSummaryElementsCCE.APPN = 'Contractor'
          AND PMCategorySkillInventory.[Year] < @NumberOfYears
          AND PMCategorySkillInventory.GradeLevel = 3
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CatName,
           PMCategorySkillInventory.[Year],
           'CCE',
           LEFT(Costs.SOC, 3) + '0000',
           Costs.SOC,
           Costs.AreaCode,
           '',
           'A_PCT75',
           PMUserSummaryElementsCCE.SummaryName,
           PMUserSummaryElementsCCE.APPN,
           PMUserSummaryElementsCCE.CostElementName,
           PMUserSummaryElementsCCE.CostElementId,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT75 = 9999999 THEN
                    208000
                ELSE
                    web.PMInflatedValue(
                                           Costs.A_PCT75 * PMCategorySkillInventory.Amount,
                                           PMUserSummaryElementsCCE.CostElementId,
                                           PMCategorySkillInventory.[Year] + @ProjectStartYear,
                                           1,
                                           0,
                                           0
                                       )
            END
           ) AS Cost,
           PMUserSummaryElementsCCE.CostElementCategory,
           (CASE
                WHEN Costs.A_PCT75 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM dataload.OccupationalEmploymentStatisticsMetro AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubGroupCode = Costs.SOC
               AND PMCategorySkillInventory.AreaCode = Costs.AreaCode
        INNER JOIN web.PMUserSummaryElementsCCE(@UserId, @ProjectId) PMUserSummaryElementsCCE
            ON PMUserSummaryElementsCCE.PayPlan = PMCategorySkillInventory.PayPlan
               AND PMUserSummaryElementsCCE.SummaryName = PMCategorySkillInventory.SummaryName
    WHERE PMCategorySkillInventory.UserId = @UserId
          AND PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.PayPlan = 'CCE'
          AND PMCategorySkillInventory.SummaryName = 'Default'
          AND PMUserSummaryElementsCCE.CostElementId = @AvgCostOfSalary
          AND PMUserSummaryElementsCCE.APPN = 'Contractor'
          AND PMCategorySkillInventory.[Year] < @NumberOfYears
          AND PMCategorySkillInventory.GradeLevel = 4
    UNION
    SELECT DISTINCT
           PMCategorySkillInventory.CatName,
           PMCategorySkillInventory.[Year],
           'CCE',
           LEFT(Costs.SOC, 3) + '0000',
           Costs.SOC,
           Costs.AreaCode,
           '',
           'A_PCT90',
           PMUserSummaryElementsCCE.SummaryName,
           PMUserSummaryElementsCCE.APPN,
           PMUserSummaryElementsCCE.CostElementName,
           PMUserSummaryElementsCCE.CostElementId,
           PMCategorySkillInventory.Amount,
           (CASE
                WHEN Costs.A_PCT90 = 9999999 THEN
                    208000
                ELSE
                    web.PMInflatedValue(
                                           Costs.A_PCT90 * PMCategorySkillInventory.Amount,
                                           PMUserSummaryElementsCCE.CostElementId,
                                           PMCategorySkillInventory.[Year] + @ProjectStartYear,
                                           1,
                                           0,
                                           0
                                       )
            END
           ) AS Cost,
           PMUserSummaryElementsCCE.CostElementCategory,
           (CASE
                WHEN Costs.A_PCT90 = 9999999 THEN
                    1
                ELSE
                    0
            END
           ) AS ExceedsSalaryLimit
    FROM dataload.OccupationalEmploymentStatisticsMetro AS Costs
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategorySubGroupCode = Costs.SOC
               AND PMCategorySkillInventory.AreaCode = Costs.AreaCode
        INNER JOIN web.PMUserSummaryElementsCCE(@UserId, @ProjectId) PMUserSummaryElementsCCE
            ON PMUserSummaryElementsCCE.PayPlan = PMCategorySkillInventory.PayPlan
               AND PMUserSummaryElementsCCE.SummaryName = PMCategorySkillInventory.SummaryName
    WHERE PMCategorySkillInventory.UserId = @UserId
          AND PMCategorySkillInventory.ProjectId = @ProjectId
          AND PMCategorySkillInventory.PayPlan = 'CCE'
          AND PMCategorySkillInventory.SummaryName = 'Default'
          AND PMUserSummaryElementsCCE.CostElementId = @AvgCostOfSalary
          AND PMUserSummaryElementsCCE.APPN = 'Contractor'
          AND PMCategorySkillInventory.[Year] < @NumberOfYears
          AND PMCategorySkillInventory.GradeLevel = 5;

    RETURN;
END;