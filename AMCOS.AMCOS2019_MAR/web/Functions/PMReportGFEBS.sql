
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMReportGFEBS]
(
    @UserId VARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN WITH GFEBSCosts
       AS (SELECT pm2.PMCategoryName,
                  pm2.[Year],
                  pm2.PayPlan,
                  pm2.CategoryGroupCode,
                  CASE pm2.CategorySubGroupCode
                      WHEN '__ALL__' THEN
                          'ALL'
                      ELSE
                          pm2.CategorySubGroupCode
                  END AS CategorySubGroupCode,
                  pm2.AreaCode,
                  pm2.LocalityId,
                  CASE pm2.StateCountry
                      WHEN '__ALL__' THEN
                          'ALL'
                      ELSE
                          pm2.StateCountry
                  END AS StateCountry,
                  CASE pm2.FunctionalAreaCode
                      WHEN '__ALL__' THEN
                          'ALL'
                      ELSE
                          pm2.FunctionalAreaCode
                  END AS FunctionalAreaCode,
                  CASE pm2.CostCenterCode
                      WHEN '__ALL__' THEN
                          'ALL'
                      ELSE
                          pm2.CostCenterCode
                  END AS CostCenterCode,
                  pm2.PayPlan AS GradeType,
                  c.GradeLevel,
                  pm1.Summary,
                  pm1.APPN,
                  pm1.CostElementCategory,
                  pm1.CostElementName,
                  pm1.CostElementId,
                  pm2.Inventory,
                  web.PMInflatedValue(c.Amount * pm2.Inventory, pm1.CostElementId, pm2.[Year] + p.YearStart, 1, 0, 0) AS Cost
           FROM data.Costs AS c
               INNER JOIN web.PMReportCostSummary(@UserId, @ProjectId) pm1
                   ON c.CostElementId = pm1.CostElementId
               INNER JOIN web.PMInventoryBySkillId(@UserId, @ProjectId) pm2
                   ON pm2.PayPlan = pm1.PayPlan
                      AND pm2.GradeLevel = c.GradeLevel
                      AND
                      (
                          c.CategorySubGroupCode = pm2.CategorySubGroupCode
                          OR pm2.CategorySubGroupCode = '__ALL__'
                      )
                      AND
                      (
                          c.StateCountry = pm2.StateCountry
                          OR pm2.StateCountry = '__ALL__'
                      )
                      AND
                      (
                          c.FunctionalAreaCode = pm2.FunctionalAreaCode
                          OR pm2.FunctionalAreaCode = '__ALL__'
                      )
                      AND
                      (
                          c.CostCenterCode = pm2.CostCenterCode
                          OR pm2.CostCenterCode = '__ALL__'
                      )
               INNER JOIN webuser.PMReport r
                   ON r.CategoryId = pm2.CategoryId
                      AND r.SummaryName = pm1.Summary
                      AND r.UserId = @UserId
                      AND r.ProjectId = @ProjectId
                      AND r.PayPlan = pm2.PayPlan
               INNER JOIN webuser.PMProject p
                   ON p.ProjectId = r.ProjectId
                      AND p.UserId = r.UserId
           WHERE pm2.[Year] < p.YearDuration)
SELECT PMCategoryName,
       [Year],
       PayPlan,
       CategoryGroupCode,
       CategorySubGroupCode,
       AreaCode,
       LocalityId,
       StateCountry,
       FunctionalAreaCode,
       CostCenterCode,
       GradeType,
       GradeLevel,
       Summary,
       APPN,
       CostElementCategory,
       CostElementName,
       CostElementId,
       Inventory,
       AVG(Cost) AS Cost
FROM GFEBSCosts
GROUP BY PMCategoryName,
         [Year],
         PayPlan,
         CategoryGroupCode,
         CategorySubGroupCode,
         AreaCode,
         LocalityId,
         CategorySubGroupCode,
         StateCountry,
         FunctionalAreaCode,
         CostCenterCode,
         GradeType,
         GradeLevel,
         Summary,
         APPN,
         CostElementCategory,
         CostElementName,
         CostElementId,
         Inventory;