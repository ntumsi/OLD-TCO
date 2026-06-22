-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMReportCostSummary]
(
    @UserId NVARCHAR(50),
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH Summaries
    AS (SELECT us.UserId,
               us.ProjectId,
               s.[Name] AS Summary,
               s.PayPlan,
               e.APPN,
               e.CostElementCategory,
               e.CostElementName,
               e.CostElementId,
               e.Amort,
               e.Model
        FROM lookup.CostSummaryElement se
            JOIN lookup.CostSummary s
                ON se.SummaryId = s.SummaryId
            JOIN lookup.CostElement e
                ON se.CostElementId = e.CostElementId
            JOIN webuser.User_Summaries us
                ON us.SummaryName = s.[Name]
                   AND us.PayPlan = s.PayPlan
        UNION
        SELECT us.UserId,
               us.ProjectId,
               us.SummaryName AS Summary,
               us.PayPlan,
               e.APPN,
               e.CostElementCategory,
               e.CostElementName,
               e.CostElementId,
               e.Amort,
               e.Model
        FROM webuser.User_SummaryElements se
            JOIN webuser.User_Summaries us
                ON se.SummaryId = us.SummaryId
            JOIN lookup.CostElement e
                ON se.CostElementId = e.CostElementId)
    SELECT UserId,
           ProjectId,
           Summary,
           PayPlan,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           Amort,
           Model
    FROM Summaries
    WHERE ProjectId = @ProjectId
          AND UserId = @UserId
);