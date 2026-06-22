
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMReportAllAll]
(
    @UserId VARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN WITH Costs
       AS (SELECT pm2.PMCategoryName,
                  pm2.[Year],
                  pm2.PayPlan,
                  'ALL' AS CategoryGroupCode,
                  'ALL' AS CategorySubGroupCode,
                  pm2.GradeLevel,
                  pm1.Summary,
                  pm1.APPN,
                  pm1.CostElementCategory,
                  pm1.CostElementName,
                  c.CostElementId,
                  pm2.AreaCode,
                  pm2.LocalityId,
                  pm2.Inventory,
                  web.PMInflatedValue(
                                         c.Amount * pm2.Inventory,
                                         pm1.CostElementId,
                                         pm2.[Year] + p.YearStart,
                                         pm2.LocalityId,
                                         ISNULL(c2.Amount, 0) * pm2.Inventory,
                                         pm2.activeDays
                                     ) AS Cost
           FROM data.Costs AS c
               LEFT JOIN data.Costs_NgRes1 AS c2
                   ON c.PayPlan = c2.PayPlan
                      AND c.CategoryGroupCode = c2.CategoryGroupCode
                      AND c.CategorySubGroupCode = c2.CategorySubGroupCode
                      AND c.GradeType = c2.GradeType
                      AND c.GradeLevel = c2.GradeLevel
                      AND c.CostElementId = c2.CostElementId
               INNER JOIN web.PMReportCostSummary(@UserId, @ProjectId) pm1
                   ON c.CostElementId = pm1.CostElementId
                      AND c.PayPlan = pm1.PayPlan
               INNER JOIN web.PMInventoryBySkillId(@UserId, @ProjectId) pm2
                   ON pm2.PayPlan = c.PayPlan
                      AND pm2.CategoryGroupCode = '__ALL__'
                      AND pm2.CategorySubGroupCode = '__ALL__'
                      AND pm2.GradeType = c.GradeType
                      AND pm2.GradeLevel = c.GradeLevel
               INNER JOIN webuser.PMReport r
                   ON r.CategoryId = pm2.CategoryId
                      AND r.PayPlan = c.PayPlan
                      AND r.SummaryName = pm1.Summary
                      AND r.UserId = pm2.UserId
                      AND r.ProjectId = pm2.ProjectId
               INNER JOIN webuser.PMProject p
                   ON p.ProjectId = r.ProjectId
                      AND p.UserId = r.UserId
           WHERE pm2.[Year] < p.YearDuration)
SELECT PMCategoryName,
       [Year],
       PayPlan,
       CategoryGroupCode,
       CategorySubGroupCode,
       GradeLevel,
       Summary,
       APPN,
       CostElementCategory,
       CostElementName,
       CostElementId,
       AreaCode,
       LocalityId,
       Inventory,
       AVG(Cost) AS Cost
FROM Costs
GROUP BY PMCategoryName,
         [Year],
         PayPlan,
         CategoryGroupCode,
         CategorySubGroupCode,
         GradeLevel,
         Summary,
         APPN,
         CostElementCategory,
         CostElementName,
         CostElementId,
         AreaCode,
         LocalityId,
         Inventory;