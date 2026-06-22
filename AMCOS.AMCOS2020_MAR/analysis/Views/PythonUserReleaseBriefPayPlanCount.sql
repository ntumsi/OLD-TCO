CREATE VIEW analysis.PythonUserReleaseBriefPayPlanCount
AS
SELECT CY,
       Included,
       COUNT(*) AS mycount
FROM
(
    SELECT PayPlan,
           DisplayTitle,
           GroupTitle,
           LEFT(AmcosVersionId, 4) AS CY,
           CASE
               WHEN VersionIntroduced < 201601 THEN
                   '2016'
               ELSE
                   ISNULL(CAST(LEFT(VersionIntroduced, 4) AS NVARCHAR), 'Future')
           END AS VersionAvailable,
           CASE
               WHEN VersionIntroduced <= AmcosVersionId THEN
                   'Yes'
               ELSE
                   'Future'
           END AS 'Included'
    FROM lookup.PayPlan AS a
        CROSS JOIN lookup.AMCOSVersion AS B
    WHERE VersionIntroduced IS NOT NULL
          AND AmcosVersionId >= 201601
          AND RIGHT(AmcosVersionId, 2) = '01'
) AS a
GROUP BY CY,
         Included;