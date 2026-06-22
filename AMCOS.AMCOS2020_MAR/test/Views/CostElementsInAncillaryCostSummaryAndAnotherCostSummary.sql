


CREATE VIEW [test].[CostElementsInAncillaryCostSummaryAndAnotherCostSummary]
AS
WITH CostElementsInAncillaryCostSummary_CTE (CostElementId)
AS (
   SELECT CostSummaryElement.CostElementId
   FROM lookup.CostSummaryElement CostSummaryElement
       INNER JOIN lookup.CostSummary CostSummary
           ON CostSummary.SummaryId = CostSummaryElement.SummaryId
   WHERE CostSummary.Name = 'Ancillary'
   AND (SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion) BETWEEN CostSummary.AmcosVersionIdStart AND CostSummary.AmcosVersionIdEnd
    AND (SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion) BETWEEN CostSummaryElement.AmcosVersionIdStart AND CostSummaryElement.AmcosVersionIdEnd
   )
SELECT CostSummaryElement.CostElementId
FROM lookup.CostSummaryElement CostSummaryElement
    INNER JOIN lookup.CostSummary CostSummary
        ON CostSummary.SummaryId = CostSummaryElement.SummaryId
WHERE CostSummary.Name <> 'Ancillary'
AND (SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion) BETWEEN CostSummary.AmcosVersionIdStart AND CostSummary.AmcosVersionIdEnd
    AND (SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion) BETWEEN CostSummaryElement.AmcosVersionIdStart AND CostSummaryElement.AmcosVersionIdEnd
      AND EXISTS
(
    SELECT *
    FROM CostElementsInAncillaryCostSummary_CTE
    WHERE CostSummaryElement.CostElementId = CostElementsInAncillaryCostSummary_CTE.CostElementId
);