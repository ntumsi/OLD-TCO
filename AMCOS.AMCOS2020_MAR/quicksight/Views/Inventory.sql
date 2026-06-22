CREATE VIEW [quicksight].[Inventory]
AS
SELECT a.*,
       b.LocationType,
       SourceSystemCode,
       CASE
           WHEN DisplayName IS NULL THEN
               'Unknown'
           ELSE
               DisplayName
       END AS LocationName,
       CASE
           WHEN c.CategorySubgroupDescription IS NULL THEN
               'Unknown'
           ELSE
               a.CategorySubgroupCode + ' - ' + c.CategorySubgroupDescription
       END AS CategorySubgroupDescription,
       CASE
           WHEN z.CategoryGroupDescription IS NULL THEN
               'Unknown'
           ELSE
               z.CategoryGroupCode + ' - ' + z.CategoryGroupDescription
       END AS CategorygroupDescription,
       CASE
           WHEN a.Strl = '-1' THEN
               'Not Applicable'
           ELSE
               e.STRLName
       END AS strlTitle,
       d.DisplayTitle AS PayPlanTitle,

       --CASE 
       --	WHEN a.payplan IN (SELECT payplan FROM lookup.PayPlanTags WHERE tag='Military') THEN LTRIM(STR(a.yos ))

       --	ELSE LTRIM(STR(a.step)) END AS [Step-YoS]
       CASE
           WHEN Step = '-1' THEN
               'Unknown'
           WHEN Step = '99' THEN
               'Unknown'
           ELSE
               CAST(Step AS NVARCHAR(3))
       END AS DisplayStep,
       CASE
           WHEN YOS IS NULL
                OR YOS = -1 THEN
               'Unknown'
           WHEN YOS = 99 THEN
               'Unknown'
           ELSE
               CAST(YOS AS NVARCHAR(3))
       END AS DisplayYoS,
       LEFT(a.AmcosVersionId, 4) AS [Year]
--, CASE
--	WHEN  a.payplan IN (SELECT payplan FROM lookup.PayPlanTags WHERE tag='Military') THEN inventory / LAG(inventory,1) OVER (PARTITION BY  a.PayPlan,a.CategoryGroupCode,a.CategorySubgroupCode,a.LocationId,a.YOS,GradeLevel,a.Strl  ORDER BY AmcosVersionId asc) 
--	ELSE inventory / LAG(inventory,1) OVER (PARTITION BY  a.PayPlan,a.CategoryGroupCode,a.CategorySubgroupCode,a.LocationId,a.Step,GradeLevel,a.Strl  ORDER BY AmcosVersionId asc) 
--	END AS PercentChange
FROM data.Inventory AS a
    LEFT OUTER JOIN warehouse.Location AS b
        ON a.LocationId = b.LocationId
    LEFT OUTER JOIN data.CategorySubgroup AS c
        ON c.CategorySubgroupCode = a.CategorySubgroupCode
           AND c.PayPlan = a.PayPlan
    LEFT OUTER JOIN data.CategoryGroup AS z
        ON z.CategoryGroupCode = a.CategoryGroupCode
           AND z.PayPlan = a.PayPlan
    INNER JOIN lookup.PayPlan AS d
        ON d.PayPlan = a.PayPlan
    LEFT OUTER JOIN
    (
        SELECT DISTINCT
               STRL,
               STRLName
        FROM xwalk.UICToSTRL
        WHERE
        (
            SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion
        )
        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
    ) AS e
        ON a.Strl = e.Strl
WHERE a.AmcosVersionId IN
      (
          SELECT MAX(LEFT(AmcosVersionId, 4)) + MAX(RIGHT(AmcosVersionId, 2))
          FROM
          (
              SELECT AmcosVersionId
              FROM lookup.AMCOSVersion
              WHERE AmcosVersionId <> -1
          ) AS A
          GROUP BY LEFT(AmcosVersionId, 4)
      );
GO
