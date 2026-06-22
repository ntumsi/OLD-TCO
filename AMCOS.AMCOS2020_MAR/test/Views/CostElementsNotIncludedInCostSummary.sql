

CREATE VIEW [test].[CostElementsNotIncludedInCostSummary]
AS
WITH CostElements_CTE (CostElementId)
AS (
   SELECT CostElementId
   FROM data.CostElement)
SELECT *	
FROM CostElements_CTE
WHERE NOT EXISTS
(
    SELECT *
    FROM lookup.CostSummaryElement
    WHERE CostSummaryElement.CostElementId = CostElements_CTE.CostElementId
);