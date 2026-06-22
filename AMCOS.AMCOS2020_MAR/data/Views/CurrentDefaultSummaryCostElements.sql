

CREATE VIEW [data].[CurrentDefaultSummaryCostElements]
AS
WITH CostSummaryElement_CTE (SummaryId, CostElementId, AmcosVersionIdEnd)
AS (
   SELECT SummaryId,
          CostElementId,
          MAX(AmcosVersionIdEnd) AS AmcosVersionIdEnd
   FROM lookup.CostSummaryElement
   GROUP BY SummaryId,
            CostElementId),
     CostSummary_CTE (SummaryId, Name, AmcosVersionIdEnd)
AS (SELECT SummaryId,
           Name,
           MAX(AmcosVersionIdEnd) AS AmcosVersionIdEnd
    FROM lookup.CostSummary
    WHERE Name = 'Default'
    GROUP BY SummaryId,
             Name),
     CostElement_CTE (CostElementId, PayPlan, APPN, CostElementCategory, CostElementName, ApplyInflation, ShowOrder,
                      AmcosVersionIdEnd
                     )
AS (SELECT CostElementId,
           PayPlan,
           APPN,
           CostElementCategory,
           CostElementName,
           ApplyInflation,
           ShowOrder,
           MAX(AmcosVersionIdEnd) AS AmcosVersionIdEnd
    FROM lookup.CostElement
    GROUP BY CostElementId,
             PayPlan,
             APPN,
             CostElementCategory,
             CostElementName,
             ApplyInflation,
             ShowOrder)
SELECT CostSummaryElement_CTE.CostElementId,
       CostElement_CTE.PayPlan,
       CostElement_CTE.APPN,
       CostElement_CTE.CostElementCategory,
       CostElement_CTE.CostElementName,
       CostElement_CTE.ApplyInflation,
       CostElement_CTE.ShowOrder,
       CostSummary_CTE.Name CostSummaryName
FROM CostSummary_CTE
    INNER JOIN CostSummaryElement_CTE
        ON CostSummaryElement_CTE.SummaryId = CostSummary_CTE.SummaryId
    INNER JOIN CostElement_CTE
        ON CostElement_CTE.CostElementId = CostSummaryElement_CTE.CostElementId;