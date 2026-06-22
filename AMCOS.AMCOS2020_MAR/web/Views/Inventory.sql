
CREATE VIEW [web].[Inventory]
AS

/*
  The purpose of this view is to provide an easy way for the web to get inventory at all levels of aggregation with location specific data and career programs
  if this data was in the data.inventory view, used by crunches, it would duplicate data and cause calculation errors thus a seperate view is used to generate this data
  for purposes in the web when a WHERE clause will be used to find a very specific scenario
  in testing this showed 1sec response time to locate any particular scenario
  */
SELECT a.PayPlan,
       a.CategoryGroupCode,
       a.CategorySubgroupCode,
       a.LocationId,
       a.CareerProgramNumber,
       a.Strl,
       a.GradeLevel,
       a.GradeType,
       a.Inventory
FROM
(
    --non military non ses
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.LocationId,
           a.CareerProgramNumber,
           a.Strl,
           a.GradeLevel,
           a.GradeType,
           ISNULL(b.Inventory, 0) AS Inventory
    FROM data.Costs AS a
        LEFT OUTER JOIN
        (
            --subgroup inventory w/ location w/strl 
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     LocationId,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --subgroup inventory w/o location w/strl 
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   '-1' AS LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --group inventory w/ location w/strl 
            SELECT PayPlan,
                   CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     LocationId,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --group inventory w/o location w/strl 
            SELECT PayPlan,
                   CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   '-1' AS LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --pp inventory w/ location w/strl 
            SELECT PayPlan,
                   '-1' AS CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     LocationId,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --pp inventory w/o location w/strl 
            SELECT PayPlan,
                   '-1' AS CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   '-1' AS LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --CP inventory w/location
            SELECT PayPlan,
                   '-1' AS CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   LocationId,
                   CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory AS a
                INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
                    ON b.OccupationalSeriesNumber = a.CategorySubgroupCode
                       AND
                       (
                           SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion
                       )
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
            GROUP BY PayPlan,
                     CareerProgramNumber,
                     LocationId,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --CP inventory wo/location
            SELECT PayPlan,
                   '-1' AS CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   '-1' AS LocationId,
                   CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory AS a
                INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
                    ON b.OccupationalSeriesNumber = a.CategorySubgroupCode
                       AND
                       (
                           SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion
                       )
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
            GROUP BY PayPlan,
                     CareerProgramNumber,
                     Strl,
                     GradeLevel,
                     GradeType
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategoryGroupCode = b.CategoryGroupCode
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.CareerProgramNumber = b.CareerProgramNumber
               AND a.LocationId = b.LocationId
               AND a.Strl = b.Strl
               --SES costs are GL1-3 for min, avg, max but inventory is GL0 because SES doesn't have a GL so we make the adjustment in the join
               AND CASE
                       WHEN a.PayPlan = 'SES' THEN
                           0
                       ELSE
                           a.GradeLevel
                   END = b.GradeLevel
    WHERE AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion
    )
          AND a.PayPlan NOT IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
              )
    UNION ALL

    --military stripping out location for security reasons per discussion with Marsha on 4/21/2020
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.LocationId,
           a.CareerProgramNumber,
           a.Strl,
           a.GradeLevel,
           a.GradeType,
           ISNULL(b.Inventory, 0) AS Inventory
    FROM data.Costs AS a
        LEFT OUTER JOIN
        (
            --subgroup inventory w/o location w/strl 
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   '-1' AS LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION

            --group inventory w/o location w/strl 
            SELECT PayPlan,
                   CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   '-1' AS LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     Strl,
                     GradeLevel,
                     GradeType
            UNION
            --pp inventory w/o location w/strl 
            SELECT PayPlan,
                   '-1' AS CategoryGroupCode,
                   '-1' AS CategorySubgroupCode,
                   '-1' AS LocationId,
                   '-1' AS CareerProgramNumber,
                   Strl,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            GROUP BY PayPlan,
                     Strl,
                     GradeLevel,
                     GradeType
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategoryGroupCode = b.CategoryGroupCode
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.CareerProgramNumber = b.CareerProgramNumber
               AND a.Strl = b.Strl
               AND a.GradeLevel = b.GradeLevel
    WHERE AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion
    )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
              )
) AS a;