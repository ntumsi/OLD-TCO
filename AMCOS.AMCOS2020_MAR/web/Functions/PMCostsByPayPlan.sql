
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMCostsByPayPlan]
(
    @ProjectId INTEGER,
    @AmcosVersionId INTEGER
)
RETURNS TABLE
AS
RETURN SELECT PMCategorySkillInventory.CategoryName PMCategoryName,
              PMCategorySkillInventory.Uic,
              PMCategorySkillInventory.PayPlan,
              PMCategorySkillInventory.CategoryGroupCode,
              PMCategorySkillInventory.CategorySubgroupCode,
              PMCategorySkillInventory.CareerProgramNumber,
              -1 LocationId,
              '-1' LocationText,
              PMCategorySkillInventory.STRL,
              PMCategorySkillInventory.GradeLevel,
              web.FormatGradeLevel(PMCategorySkillInventory.PayPlan, PMCategorySkillInventory.GradeLevel) Grade,
              PMCategorySkillInventory.DependentStatus,
              PMCategorySkillInventory.NumberOfDependents,
              PMCategorySkillInventory.ActiveDutyDays,
              PMCategorySkillInventory.OverheadPercent,
              CostSummary.Name AS CostSummaryName,
              CostElement.APPN,
              CostElement.CostElementCategory,
              CostElement.CostElementName,
              CostElement.ApplyInflation,
              CostElement.ShowOrder,
              Costs.CostElementId,
              PMCategorySkillInventory.Year,
              PMCategorySkillInventory.Amount Inventory,
              Costs.Amount * PMCategorySkillInventory.Amount Cost
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
           INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
               ON PMCategorySkillInventory.PayPlan = Costs.PayPlan
                  AND PMCategorySkillInventory.CategoryGroupCode = Costs.CategoryGroupCode
                  AND PMCategorySkillInventory.CategorySubgroupCode = Costs.CategorySubgroupCode
                  AND PMCategorySkillInventory.CareerProgramNumber = Costs.CareerProgramNumber
                  AND PMCategorySkillInventory.STRL = Costs.Strl
                  AND PMCategorySkillInventory.GradeLevel = Costs.GradeLevel
                  AND PMCategorySkillInventory.NumberOfDependents = Costs.NumberOfDependents
           INNER JOIN webuser.PMReport PMReport
               ON PMReport.CategoryId = PMCategorySkillInventory.CategoryId
                  AND PMReport.PayPlan = PMCategorySkillInventory.PayPlan
       WHERE Costs.AmcosVersionId = @AmcosVersionId
             AND PMCategorySkillInventory.ProjectId = @ProjectId
             AND PMCategorySkillInventory.PayPlan NOT IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
             AND Costs.LocationId = -1
             AND Costs.DependentStatus = '-1'
             AND Costs.IsLocationSpecific = 0
             AND CostSummary.Name = 'Default'
       UNION ALL
       SELECT PMCategorySkillInventory.CategoryName PMCategoryName,
              PMCategorySkillInventory.Uic,
              PMCategorySkillInventory.PayPlan,
              PMCategorySkillInventory.CategoryGroupCode,
              PMCategorySkillInventory.CategorySubgroupCode,
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
              CostSummary.Name AS CostSummaryName,
              CostElement.APPN,
              CostElement.CostElementCategory,
              CostElement.CostElementName,
              CostElement.ApplyInflation,
              CostElement.ShowOrder,
              Costs.CostElementId,
              PMCategorySkillInventory.Year,
              PMCategorySkillInventory.Amount Inventory,
              Costs.Amount * PMCategorySkillInventory.Amount Cost
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
           INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
               ON PMCategorySkillInventory.PayPlan = Costs.PayPlan
                  AND PMCategorySkillInventory.CategoryGroupCode = Costs.CategoryGroupCode
                  AND PMCategorySkillInventory.CategorySubgroupCode = Costs.CategorySubgroupCode
                  AND PMCategorySkillInventory.CareerProgramNumber = Costs.CareerProgramNumber
                  AND PMCategorySkillInventory.LocationId = Costs.LocationId
                  AND PMCategorySkillInventory.STRL = Costs.Strl
                  AND PMCategorySkillInventory.GradeLevel = Costs.GradeLevel
                  AND PMCategorySkillInventory.DependentStatus = Costs.DependentStatus
                  AND PMCategorySkillInventory.NumberOfDependents = Costs.NumberOfDependents
           INNER JOIN webuser.PMReport PMReport
               ON PMReport.CategoryId = PMCategorySkillInventory.CategoryId
                  AND PMReport.PayPlan = PMCategorySkillInventory.PayPlan
       WHERE Costs.AmcosVersionId = @AmcosVersionId
             AND PMCategorySkillInventory.ProjectId = @ProjectId
             AND PMCategorySkillInventory.PayPlan NOT IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
             AND Costs.IsLocationSpecific = 1
             AND CostSummary.Name = 'Default';