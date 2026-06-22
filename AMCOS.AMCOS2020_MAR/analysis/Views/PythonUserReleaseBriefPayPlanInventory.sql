CREATE VIEW analysis.PythonUserReleaseBriefPayPlanInventory
AS
SELECT a.PayPlan,
       a.Inventory,
       LEFT(c.AmcosVersionId, 4) AS CY,
       CASE
           WHEN VersionIntroduced <= c.AmcosVersionId THEN
               'Yes'
           ELSE
               'Future'
       END AS 'Included'
FROM
(
    SELECT PayPlan,
           AmcosVersionId,
           SUM(Inventory) AS Inventory
    FROM data.Inventory
    WHERE AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    )
    GROUP BY PayPlan,
             AmcosVersionId
) AS a
    LEFT OUTER JOIN lookup.PayPlan AS b
        ON a.PayPlan = b.PayPlan
    CROSS JOIN
    (SELECT * FROM lookup.AMCOSVersion WHERE AmcosVersionId >= 201601) AS c
WHERE RIGHT(c.AmcosVersionId, 2) = '01';