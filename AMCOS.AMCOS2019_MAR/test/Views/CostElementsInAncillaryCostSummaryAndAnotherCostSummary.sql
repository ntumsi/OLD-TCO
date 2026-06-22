

CREATE VIEW [test].[CostElementsInAncillaryCostSummaryAndAnotherCostSummary]
AS
WITH CostElementsInAncillaryCostSummary_CTE (CostElementId)
AS (
   SELECT CostSummaryElement.CostElementId
   FROM lookup.CostSummaryElement CostSummaryElement
       INNER JOIN lookup.CostSummary CostSummary
           ON CostSummary.SummaryId = CostSummaryElement.SummaryId
   WHERE CostSummary.Name = 'Ancillary')
SELECT CostSummaryElement.CostElementId
FROM lookup.CostSummaryElement CostSummaryElement
    INNER JOIN lookup.CostSummary CostSummary
        ON CostSummary.SummaryId = CostSummaryElement.SummaryId
WHERE CostSummary.Name <> 'Ancillary'
      AND EXISTS
(
    SELECT *
    FROM CostElementsInAncillaryCostSummary_CTE
    WHERE CostSummaryElement.CostElementId = CostElementsInAncillaryCostSummary_CTE.CostElementId
);