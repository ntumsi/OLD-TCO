
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMReportCategorySubGroupCodeNotAll]
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
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubGroupCode,
           a.AreaCode,
           a.LocalityId,
           '' AS FunctionalAreaCode,
           '' AS CostCenterCode,
           a.GradeLevel,
           a.Summary,
           a.APPN,
           a.CostElementName,
           a.CostElementId,
           a.Inventory,
           AVG(a.cost) AS Cost,
           a.CostElementCategory
    FROM
    (
        SELECT DISTINCT
               pm2.PMCategoryName,
               pm2.[Year],
               pm2.PayPlan,
               c.CategoryGroupCode,
               c.CategorySubGroupCode,
               pm2.AreaCode,
               pm2.LocalityId,
               pm2.GradeLevel,
               pm1.Summary,
               ce.APPN,
               ce.CostElementName,
               c.CostElementId,
               pm2.Inventory AS Inventory,
               web.PMInflatedValue(
                                      c.Amount * pm2.Inventory,
                                      pm1.CostElementId,
                                      pm2.[Year] + p.YearStart,
                                      pm2.LocalityId,
                                      ISNULL(Costs_NgRes1.Amount, 0) * pm2.Inventory,
                                      pm2.activeDays
                                  ) AS cost,
               pm1.CostElementCategory
        FROM data.Costs AS c
            LEFT JOIN data.Costs_NgRes1 AS Costs_NgRes1
                ON c.PayPlan = Costs_NgRes1.PayPlan
                   AND c.CostElementId = Costs_NgRes1.CostElementId
                   AND c.GradeLevel = Costs_NgRes1.GradeLevel
            INNER JOIN web.PMReportCostSummary(@UserId, @ProjectId) pm1
                ON c.CostElementId = pm1.CostElementId
                   AND c.PayPlan = pm1.PayPlan
            INNER JOIN web.PMInventoryBySkillId(@UserId, @ProjectId) pm2
                ON c.PayPlan = pm2.PayPlan
                   AND c.GradeType = pm2.GradeType
                   AND c.GradeLevel = pm2.GradeLevel
                   AND pm2.CategoryGroupCode = c.CategoryGroupCode
                   AND pm2.CategorySubGroupCode = c.CategorySubGroupCode
            INNER JOIN webuser.PMReport r
                ON pm2.CategoryId = r.CategoryId
                   AND c.PayPlan = r.PayPlan
                   AND pm1.Summary = r.SummaryName
                   AND @UserId = r.UserId
                   AND @ProjectId = r.ProjectId
            INNER JOIN webuser.PMProject p
                ON p.ProjectId = r.ProjectId
                   AND p.UserId = r.UserId
            INNER JOIN lookup.CostElement ce
                ON c.CostElementId = ce.CostElementId
        WHERE pm2.[Year] < p.YearDuration
    ) a
    GROUP BY a.PMCategoryName,
             a.[Year],
             a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubGroupCode,
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