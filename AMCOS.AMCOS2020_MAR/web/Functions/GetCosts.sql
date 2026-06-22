-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetCosts]
(
    @PayPlan NVARCHAR(3),
    @CostSummaryName NVARCHAR(50) = 'Default',
    @CategoryGroupCode NVARCHAR(4) = '-1',
    @CategorySubgroupCode NVARCHAR(5) = '-1',
    @CareerProgramNumber NCHAR(2) = '-1',
    @LocationId INTEGER = -1,
    @STRL NVARCHAR(20) = '-1',
    @DependentStatus NVARCHAR(25) = '-1',
    @NumberOfDependents INTEGER = -1,
    @AmcosVersionId INTEGER = 202001
)
RETURNS TABLE
AS
RETURN
(
    SELECT Costs.AppropriationGroup,
           Costs.APPN,
           Costs.CostElementCategory,
           Costs.CostElementName,
           Costs.Description,
           Costs.CostElementId,
           Costs.ShowOrder,
           Costs.ApplyInflation,
           Costs.GradeLevel,
           Grade = CASE Costs.PayPlan
                       WHEN 'SES' THEN
                           CASE Costs.GradeLevel
                               WHEN 1 THEN
                                   'MIN'
                               WHEN 2 THEN
                                   'AVG'
                               WHEN 3 THEN
                                   'MAX'
                               ELSE
                                   CAST(Costs.GradeLevel AS NVARCHAR(3))
                           END
                       ELSE
                           CAST(Costs.GradeType AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2))
                   END,
           Costs.WeaponSystemId,
           NULL AS WeaponSystemName,
           Costs.Amount,
           Costs.ArmyCesTitle,
           Costs.OsdCapeCesTitle,
           Costs.AmcosVersionId
    FROM data.Costs Costs
        INNER JOIN lookup.CostElement CostElement
            ON CostElement.CostElementId = Costs.CostElementId
               AND @AmcosVersionId
               BETWEEN CostElement.AmcosVersionIdStart AND CostElement.AmcosVersionIdEnd
        INNER JOIN lookup.CostSummaryElement CostSummaryElement
            ON CostSummaryElement.CostElementId = CostElement.CostElementId
               AND @AmcosVersionId
               BETWEEN CostSummaryElement.AmcosVersionIdStart AND CostSummaryElement.AmcosVersionIdEnd
        INNER JOIN lookup.CostSummary CostSummary
            ON CostSummary.SummaryId = CostSummaryElement.SummaryId
               AND @AmcosVersionId
               BETWEEN CostSummary.AmcosVersionIdStart AND CostSummary.AmcosVersionIdEnd
    WHERE Costs.PayPlan = @PayPlan
          AND Costs.CategoryGroupCode = @CategoryGroupCode
          AND Costs.CategorySubgroupCode = @CategorySubgroupCode
          AND Costs.CareerProgramNumber = @CareerProgramNumber
          AND Costs.LocationId = -1
          AND Costs.IsLocationSpecific = 0
          AND Costs.Strl = @STRL
          AND Costs.DependentStatus = '-1'
          AND Costs.NumberOfDependents = @NumberOfDependents
          AND Costs.AmcosVersionId = @AmcosVersionId
          AND CostSummary.Name = @CostSummaryName
    UNION ALL
    SELECT Costs.AppropriationGroup,
           Costs.APPN,
           Costs.CostElementCategory,
           Costs.CostElementName,
           Costs.Description,
           Costs.CostElementId,
           Costs.ShowOrder,
           Costs.ApplyInflation,
           Costs.GradeLevel,
           Grade = CASE Costs.PayPlan
                       WHEN 'SES' THEN
                           CASE Costs.GradeLevel
                               WHEN 1 THEN
                                   'MIN'
                               WHEN 2 THEN
                                   'AVG'
                               WHEN 3 THEN
                                   'MAX'
                               ELSE
                                   CAST(Costs.GradeLevel AS NVARCHAR(3))
                           END
                       ELSE
                           CAST(Costs.GradeType AS NVARCHAR(3)) + CAST(Costs.GradeLevel AS NVARCHAR(2))
                   END,
           Costs.WeaponSystemId,
           NULL AS WeaponSystemName,
           Costs.Amount,
           Costs.ArmyCesTitle,
           Costs.OsdCapeCesTitle,
           Costs.AmcosVersionId
    FROM data.Costs Costs
        INNER JOIN lookup.CostElement CostElement
            ON CostElement.CostElementId = Costs.CostElementId
               AND @AmcosVersionId
               BETWEEN CostElement.AmcosVersionIdStart AND CostElement.AmcosVersionIdEnd
        INNER JOIN lookup.CostSummaryElement CostSummaryElement
            ON CostSummaryElement.CostElementId = CostElement.CostElementId
               AND @AmcosVersionId
               BETWEEN CostSummaryElement.AmcosVersionIdStart AND CostSummaryElement.AmcosVersionIdEnd
        INNER JOIN lookup.CostSummary CostSummary
            ON CostSummary.SummaryId = CostSummaryElement.SummaryId
               AND @AmcosVersionId
               BETWEEN CostSummary.AmcosVersionIdStart AND CostSummary.AmcosVersionIdEnd
    WHERE Costs.PayPlan = @PayPlan
          AND Costs.CategoryGroupCode = @CategoryGroupCode
          AND Costs.CategorySubgroupCode = @CategorySubgroupCode
          AND Costs.CareerProgramNumber = @CareerProgramNumber
          AND Costs.LocationId = @LocationId
          AND Costs.IsLocationSpecific = 1
          AND Costs.Strl = @STRL
          AND Costs.DependentStatus = @DependentStatus
          AND Costs.NumberOfDependents = @NumberOfDependents
          AND Costs.AmcosVersionId = @AmcosVersionId
          AND CostSummary.Name = @CostSummaryName
);