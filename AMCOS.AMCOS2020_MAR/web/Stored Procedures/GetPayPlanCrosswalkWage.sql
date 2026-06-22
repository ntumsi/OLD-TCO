
-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================

CREATE PROCEDURE [web].[GetPayPlanCrosswalkWage]
(
    @PayPlan NVARCHAR(3),
    @LocationId INT,
    @GradeLevel TINYINT,
    @AmcosVersionId INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (
            SELECT ISNULL(Amount, 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Base Pay (Civilian)'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblSalaryW,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Overtime Pay'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_OvertimePay,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Premium Pay'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_PremiumPay,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Federal Employees Gov''t Health Insurance'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_Health,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Federal Employees Gov''t Life Insurance'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_Life,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Miscellaneous Pay'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_MiscPay,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Training'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_wTraining,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Army-Funded Retirement'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_aRetirement,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Cash Awards'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_wCashAward,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Annualized Cost of FICA'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_wFICA,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Former Employee Compensation'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_wFormerEmpComp,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Post Retirement Health Insurance'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_HealthPost,
        (
            SELECT ISNULL(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = @PayPlan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = @LocationId
                  AND GradeLevel = @GradeLevel
                  AND CostElementName = 'Avg Cost of Post Retirement Life Insurance'
                  AND AmcosVersionId = @AmcosVersionId
        ) AS lblV_LifePost;
END;