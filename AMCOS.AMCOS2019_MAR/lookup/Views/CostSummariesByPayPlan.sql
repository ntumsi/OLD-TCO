

CREATE VIEW [lookup].[CostSummariesByPayPlan]
AS
SELECT CostSummary.SummaryId,
       CostSummary.Name,
       CostSummary.PayPlan,
       CostElement.APPN,
       CostElement.CostElementCategory,
       CostElement.CostElementName,
       CostElement.Amort,
       CostElement.Model,
       CostElement.showOrder,
       CostElement.CostElementId
FROM lookup.CostSummary CostSummary
    INNER JOIN lookup.CostSummaryElement CostSummaryElement
        ON CostSummary.SummaryId = CostSummaryElement.SummaryId
    INNER JOIN lookup.CostElement CostElement
        ON CostSummaryElement.CostElementId = CostElement.CostElementId;