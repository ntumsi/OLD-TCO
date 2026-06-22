

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMCostsByPayPlanReserveComponents]
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
              DefaultSummaryCostElements.ApplyInflation,
              DefaultSummaryCostElements.ShowOrder,
              Costs.CostElementId,
              PMCategorySkillInventory.Year,
              PMCategorySkillInventory.Amount Inventory,
              (Costs.Amount * PMCategorySkillInventory.Amount)
              + web.GetAdjustedAvgAnnualizedCostOfFica(
                                                          DefaultSummaryCostElements.CostElementId,
                                                          (PMCategorySkillInventory.ActiveDutyDays - 15)
                                                          * ISNULL(CostsActiveDutyDay.Amount, 0)
                                                          * PMCategorySkillInventory.Amount,
                                                          @AmcosVersionId
                                                      ) Cost
       FROM data.Costs Costs
           LEFT OUTER JOIN crunch.Costs_1ActiveDay CostsActiveDutyDay
               ON CostsActiveDutyDay.PayPlan = Costs.PayPlan
                  AND CostsActiveDutyDay.CategoryGroupCode = Costs.CategoryGroupCode
                  AND CostsActiveDutyDay.CategorySubgroupCode = Costs.CategorySubgroupCode
                  AND CostsActiveDutyDay.CostElementId = Costs.CostElementId
                  AND CostsActiveDutyDay.GradeType = Costs.GradeType
                  AND CostsActiveDutyDay.GradeLevel = Costs.GradeLevel
                  AND CostsActiveDutyDay.WeaponSystemId = Costs.WeaponSystemId
                  AND CostsActiveDutyDay.AmcosVersionId = Costs.AmcosVersionId
           INNER JOIN data.CurrentDefaultSummaryCostElements DefaultSummaryCostElements
               ON Costs.CostElementId = DefaultSummaryCostElements.CostElementId
           INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
               ON PMCategorySkillInventory.PayPlan = Costs.PayPlan
                  AND PMCategorySkillInventory.CategoryGroupCode = Costs.CategoryGroupCode
                  AND PMCategorySkillInventory.CategorySubgroupCode = Costs.CategorySubgroupCode
                  AND PMCategorySkillInventory.CareerProgramNumber = Costs.CareerProgramNumber
                  AND PMCategorySkillInventory.LocationId = Costs.LocationId
                  AND PMCategorySkillInventory.STRL = Costs.Strl
                  AND PMCategorySkillInventory.GradeLevel = Costs.GradeLevel
                  AND PMCategorySkillInventory.DependentStatus = Costs.DependentStatus
           INNER JOIN webuser.PMReport PMReport
               ON PMReport.CategoryId = PMCategorySkillInventory.CategoryId
                  AND PMReport.PayPlan = PMCategorySkillInventory.PayPlan
       WHERE Costs.AmcosVersionId = @AmcosVersionId
             AND PMCategorySkillInventory.ProjectId = @ProjectId
             AND PMCategorySkillInventory.PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' );