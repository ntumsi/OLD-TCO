
CREATE VIEW [quicksight].[CostSummaryByVersion]
AS
SELECT a.Name AS SummaryName,
       a.AmcosVersionId,
       a.Description AS ReleaseName,
       b.CostElementId
FROM
(
    SELECT a.SummaryId,
           a.PayPlan,
           a.Name,
           a.AmcosVersionIdStart,
           a.AmcosVersionIdEnd,
           b.AmcosVersionId,
           b.Description
    FROM lookup.CostSummary AS a
        INNER JOIN lookup.AMCOSVersion AS b
            ON b.AmcosVersionId
               BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
) AS a
    INNER JOIN
    (
        SELECT a.SummaryId,
               a.CostElementId,
               a.AmcosVersionIdStart,
               a.AmcosVersionIdEnd,
               b.AmcosVersionId,
               b.Description
        FROM lookup.CostSummaryElement AS a
            INNER JOIN lookup.AMCOSVersion AS b
                ON b.AmcosVersionId
                   BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
    ) AS b
        ON b.AmcosVersionId = a.AmcosVersionId
           AND b.SummaryId = a.SummaryId;