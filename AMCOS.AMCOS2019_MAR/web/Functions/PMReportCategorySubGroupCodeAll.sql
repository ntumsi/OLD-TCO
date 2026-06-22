
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMReportCategorySubGroupCodeAll]
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT a.PMCategoryName,
           a.[Year],
           a.PayPlan AS PayPlan,
           CategoryGroupCode,
           'ALL' AS CategorySubGroupCode,
           a.AreaCode AS AreaCode,
           a.LocalityId AS LocalityId,
           '' AS FunctionalAreaCode,
           '' AS CostCenterCode,
           a.GradeLevel AS GradeLevel,
           a.Summary,
           a.APPN,
           a.CostElementName,
           a.CostElementId,
           a.Inventory,
           AVG(a.Cost) AS Cost,
           a.CostElementCategory AS CostElementCategory
    FROM
    (
        SELECT DISTINCT
               pm2.PMCategoryName,
               pm2.[Year] AS Year,
               pm2.PayPlan AS PayPlan,
               c.CategoryGroupCode,
               c.CategorySubGroupCode,
               pm2.AreaCode AS AreaCode,
               pm2.LocalityId AS LocalityId,
               pm2.GradeLevel AS GradeLevel,
               pm1.Summary,
               ce.APPN,
               ce.CostElementName,
               c.CostElementId,
               pm2.Inventory AS Inventory,
               web.PMInflatedValue(
                                      c.Amount * pm2.Inventory,
                                      pm1.CostElementId,
                                      pm2.[Year] + p.YearStart,
                                      LocalityId,
                                      ISNULL(Costs_NgRes1.Amount, 0) * pm2.Inventory,
                                      pm2.activeDays
                                  ) AS Cost,
               pm1.CostElementCategory
        FROM data.Costs AS c
            LEFT JOIN data.Costs_NgRes1 AS Costs_NgRes1
                ON Costs_NgRes1.PayPlan = c.PayPlan
                   AND Costs_NgRes1.CategoryGroupCode = c.CategoryGroupCode
                   AND Costs_NgRes1.CategorySubGroupCode = c.CategorySubGroupCode
                   AND Costs_NgRes1.CostElementId = c.CostElementId
                   AND Costs_NgRes1.GradeType = c.GradeType
                   AND Costs_NgRes1.GradeLevel = c.GradeLevel
            INNER JOIN web.PMReportCostSummary(@UserId, @ProjectId) pm1
                ON pm1.CostElementId = c.CostElementId
                   AND pm1.PayPlan = c.PayPlan
            INNER JOIN web.PMInventoryBySkillId(@UserId, @ProjectId) pm2
                ON c.PayPlan = pm2.PayPlan
                   AND c.GradeType = pm2.GradeType
                   AND c.GradeLevel = pm2.GradeLevel
                   AND c.CategoryGroupCode = pm2.CategoryGroupCode
            INNER JOIN webuser.PMReport r
                ON r.CategoryId = pm2.CategoryId
                   AND r.PayPlan = c.PayPlan
                   AND r.SummaryName = pm1.Summary
                   AND r.UserId = @UserId
                   AND r.ProjectId = @ProjectId
            INNER JOIN webuser.PMProject p
                ON p.ProjectId = r.ProjectId
                   AND p.UserId = r.UserId
            INNER JOIN lookup.CostElement ce
                ON ce.CostElementId = c.CostElementId
        WHERE pm2.CategorySubGroupCode = '__ALL__'
              AND pm2.[Year] < p.YearDuration
    ) a
    GROUP BY a.PMCategoryName,
             a.[Year],
             a.PayPlan,
             a.CategoryGroupCode,
             a.AreaCode,
             a.LocalityId,
             a.GradeLevel,
             a.Summary,
             a.APPN,
             a.CostElementName,
             a.CostElementId,
             a.Inventory,
             a.CostElementCategory
);