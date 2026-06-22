-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMUserSummaryElementsCCE]
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 'Default' AS SummaryName,
           'CCE' AS PayPlan,
           'Contractor' AS APPN,
           'Compensation' AS CostElementCategory,
           'Avg Cost of Salary' AS CostElementName,
           dbo.GetCostElementId('CCE', 'Contractor', 'Avg Cost of Salary') AS CostElementId,
           0 AS Amort,
           0 AS Model
    UNION
    SELECT UserSummaries.SummaryName AS Summary,
           UserSummaries.PayPlan,
           CostElement.APPN,
           CostElement.CostElementCategory,
           CostElement.CostElementName,
           CostElement.CostElementId,
           CostElement.Amort,
           CostElement.Model
    FROM web.PMUserSummaryElements(@UserId, @ProjectId) UserSummaryElements
        INNER JOIN web.PMUserSummaries(@UserId, @ProjectId) UserSummaries
            ON UserSummaryElements.SummaryId = UserSummaries.SummaryId
        INNER JOIN lookup.CostElement CostElement
            ON UserSummaryElements.CostElementId = CostElement.CostElementId
);