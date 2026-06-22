CREATE VIEW lookup.DefaultCostSummaryElements
AS
SELECT CostSummary.SummaryId,
       CostSummary.PayPlan,
       CostSummary.Name,
       CostSummaryElement.CostElementId,
       CostSummary.AmcosVersionIdStart AmcosVersionIdStartCostSummary,
       CostSummary.AmcosVersionIdEnd AmcosVersionIdEndCostSummary,
       CostSummaryElement.AmcosVersionIdStart AmcosVersionIdStartCostSummaryElement,
       CostSummaryElement.AmcosVersionIdEnd AmcosVersionIdEndCostSummaryElement
FROM lookup.CostSummary CostSummary
    INNER JOIN lookup.CostSummaryElement CostSummaryElement
        ON CostSummaryElement.SummaryId = CostSummary.SummaryId;