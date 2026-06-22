



CREATE VIEW [quicksight].[PaySchedule]
AS
SELECT a.PayPlan,
       a.GradeLevelDescription,
       a.Rate,
       a.RateType,
       a.AmcosVersionId,
       a.YOS,
       a.GradeLevel,
       CASE
           WHEN a.CategoryGroupCode = -1 THEN
               'Average'
           ELSE
               a.CategoryGroupCode
       END AS CategoryGroupCode,
       a.CategorySubgroupCode,
       UPPER(LEFT(a.RateType, 1)) + LOWER(RIGHT(a.RateType, LEN(a.RateType) - 1)) AS RateTypeConformed,
       CASE
           WHEN b.LocationType IS NULL THEN
               'Not Applicable'
           ELSE
               b.LocationType
       END AS LocationType,
       b.SourceSystemCode,
       CASE
           WHEN b.DisplayName IS NULL THEN
               'All'
           ELSE
               b.DisplayName
       END AS LocationName,
       --give the user one and only one caegory option by combining them with these rules
       CASE
           WHEN a.CategorySubgroupCode <> '-1' THEN
               a.CategorySubgroupCode + ' - ' + c.CategorySubgroupDescription
           WHEN a.CategorySubgroupCode = '-1'
                AND a.CategoryGroupCode <> '-1' THEN
               a.CategoryGroupCode + ' - ' + c.CategoryGroupDescription
           ELSE
               'All'
       END AS Category,
       --added for cyberworkforce
       CASE
           WHEN a.WorkRoleCode = '-1' THEN
               'Not Applicable'
           ELSE
               a.WorkRoleCode + ' - ' + zz.WorkRoleName
       END AS CyberWorkCodeDesciption,
       --help us order by putting all at the top
       CASE
           --put all first by assigning it 1, all others can have two allowing order by categoryorder, category to produce the right results
           WHEN a.CategorySubgroupCode = '-1'
                AND a.CategoryGroupCode = '-1' THEN
               1
           ELSE
               2
       END AS CategoryOrder,
       CASE
           WHEN a.Strl = '-1' THEN
               'Not Applicable'
           ELSE
               e.STRLName
       END AS strlTitle,
       d.GroupTitle + ' - ' + d.DisplayTitle AS PayPlanTitle,
       CASE
           WHEN a.PayPlan IN
                (
                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
                ) THEN
               LTRIM(STR(a.YOS))
           --WHEN a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag='Pay Band') THEN LTRIM(REPLACE(REPLACE(STR(a.step),STR(1),'Min'),10,'Max'))

           ELSE
               LTRIM(CAST(a.StepDescription AS NVARCHAR(15)))
       END AS [Step-YoS],
       LEFT(a.AmcosVersionId, 4) AS [Year],
       ISNULL(a.Rate / NULLIF(   LAG(a.Rate, 1) OVER (PARTITION BY a.PayPlan,
                                                                   a.CategoryGroupCode,
                                                                   a.CategorySubgroupCode,
                                                                   a.LocationId,
                                                                   a.RateType,
                                                                   a.Step,
                                                                   a.YOS,
                                                                   a.GradeLevel,
                                                                   a.Strl
                                                      ORDER BY a.AmcosVersionId ASC
                                                     ),
                                 0
                             ),
              0
             ) AS PercentChange
FROM data.PaySchedules AS a
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
    --added the below to account for cyber work codes
    LEFT OUTER JOIN lookup.DCWFWorkRole AS zz
        ON a.WorkRoleCode = zz.WorkRoleCode
    LEFT OUTER JOIN
    (
        SELECT DISTINCT
               STRL,
               STRLName
        FROM xwalk.UICToSTRL
        WHERE
        (
            SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
        )
        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
    ) AS e
        ON a.Strl = e.STRL
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

