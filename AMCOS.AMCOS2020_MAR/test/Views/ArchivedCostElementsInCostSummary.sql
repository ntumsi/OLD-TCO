CREATE VIEW test.ArchivedCostElementsInCostSummary
AS
WITH ArchivedCostElements_CTE (CostElementId)
AS (
   SELECT CostElementId
   FROM lookup.CostElement
   WHERE Active = 0)
SELECT SummaryId,
       CostElementId
FROM lookup.CostSummaryElement
WHERE EXISTS
(
    SELECT *
    FROM ArchivedCostElements_CTE
    WHERE ArchivedCostElements_CTE.CostElementId = CostSummaryElement.CostElementId
);