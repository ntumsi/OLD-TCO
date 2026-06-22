-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetArmyCesTitles]
(
    @PayPlan NVARCHAR(3),
    @CostSummaryId INTEGER
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
           ArmyCesTitle
    FROM lookup.CostElement ce
        INNER JOIN lookup.CostSummaryElement cse
            ON cse.CostElementId = ce.CostElementId
        INNER JOIN
        (
            SELECT CostElementId,
                   MAX(AmcosVersionIdEnd) AS AmcosVersionIdEndMax
            FROM lookup.CostElement
            GROUP BY CostElementId
        ) AS maxid
            ON ce.CostElementId = maxid.CostElementId
               AND ce.AmcosVersionIdEnd = maxid.AmcosVersionIdEndMax
        INNER JOIN
        (
            SELECT SummaryId,
                   CostElementId,
                   MAX(AmcosVersionIdEnd) AS AmcosVersionIdEndMax
            FROM lookup.CostSummaryElement
            GROUP BY SummaryId,
                     CostElementId
        ) AS maxid2
            ON cse.SummaryId = maxid2.SummaryId
               AND cse.CostElementId = maxid2.CostElementId
               AND cse.AmcosVersionIdEnd = maxid2.AmcosVersionIdEndMax
    WHERE PayPlan = @PayPlan
          AND cse.SummaryId = @CostSummaryId
          AND ArmyCesTitle IS NOT NULL
);