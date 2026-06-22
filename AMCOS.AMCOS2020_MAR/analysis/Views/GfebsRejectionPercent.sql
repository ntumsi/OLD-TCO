
CREATE VIEW [analysis].[GfebsRejectionPercent]
AS
SELECT PayPlan,
       AmcosVersionId,
       SUM(MyTotal) AS MyTotal,
       SUM(ISNULL(MyCleaned, 0)) AS MyCleaned,
       SUM(ISNULL(MyRejected, 0)) AS MyRejected,
       SUM(ISNULL(MyRejected * 1.0, 0)) / SUM(MyTotal * 1.0) AS perc_rejected
FROM
(
    SELECT a.PayPlan,
           a.PersonnelNumber,
           a.MyTotal,
           b.MyCleaned,
           c.MyRejected,
           a.AmcosVersionId
    FROM
    (
        SELECT DISTINCT
               RIGHT(PayPlan, 2) AS PayPlan,
               PersonnelNumber,
               1 AS MyTotal,
               AmcosVersionId
        FROM load_GFEBS.Raw
    ) AS a
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   PersonnelNumber,
                   1 AS MyCleaned,
                   AmcosVersionId
            FROM load_GFEBS.Cleaned
        ) AS b
            ON a.PersonnelNumber = b.PersonnelNumber
               AND a.PayPlan = b.PayPlan
               AND a.AmcosVersionId = b.AmcosVersionId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   PersonnelNumber,
                   1 AS MyRejected,
                   AmcosVersionId
            FROM load_GFEBS.Rejected
        ) AS c
            ON a.PersonnelNumber = c.PersonnelNumber
               AND a.PayPlan = c.PayPlan
               AND a.AmcosVersionId = c.AmcosVersionId
) AS a
GROUP BY PayPlan,
         AmcosVersionId;