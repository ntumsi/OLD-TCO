


/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [analysis].[AggregateKnownInv]
AS
SELECT *
FROM
(
    --mil subgrp
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           -1 AS LocationId,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * YOS * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    --mil grp
    UNION
    SELECT PayPlan,
           CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           -1 AS LocationId,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * YOS * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --mil payplan
    SELECT PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           -1 AS LocationId,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * YOS * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --civ loc subgroup
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * Step * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             LocationId,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --civ loc grp
    SELECT PayPlan,
           CategoryGroupCode,
           '-1',
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * Step * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             LocationId,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --civ loc pp
    SELECT PayPlan,
           '-1',
           '-1',
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * Step * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             LocationId,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --civ nonloc subgroup
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           -1,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * Step * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --civ nonloc group
    SELECT PayPlan,
           CategoryGroupCode,
           '-1',
           -1,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * Step * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION
    --civ nonloc pp
    SELECT PayPlan,
           '-1',
           '-1',
           -1,
           Strl,
           GradeType,
           GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(Inventory) AS inventory,
           AmcosVersionId,
           '-1' AS CP,
           SUM(Inventory * Step * 1.0) / SUM(NULLIF(Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             Strl,
             GradeType,
             GradeLevel,
             AmcosVersionId
    UNION

    --civ loc CP
    SELECT a.PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           a.LocationId,
           a.Strl,
           a.GradeType,
           a.GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(a.Inventory) AS inventory,
           a.AmcosVersionId,
           b.CareerProgramNumber,
           SUM(a.Inventory * a.Step * 1.0) / SUM(NULLIF(a.Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory AS a
        LEFT OUTER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
            ON b.OccupationalSeriesNumber = a.CategorySubgroupCode
               AND 202401
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    WHERE a.PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
          AND b.CareerProgramNumber IS NOT NULL
          AND a.PayPlan NOT IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage'
              )
    GROUP BY a.PayPlan,
             a.LocationId,
             a.Strl,
             a.GradeType,
             a.GradeLevel,
             a.AmcosVersionId,
             b.CareerProgramNumber
    UNION
    --civ nonloc CP
    SELECT a.PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           -1 AS LocationId,
           a.Strl,
           a.GradeType,
           a.GradeLevel,
           -1 AS step,
           -1 AS yos,
           SUM(a.Inventory) AS inventory,
           a.AmcosVersionId,
           b.CareerProgramNumber,
           SUM(a.Inventory * a.Step * 1.0) / SUM(NULLIF(a.Inventory, 0) * 1.0) AS weighted_Step_YoS
    FROM data.KnownInventory AS a
        LEFT OUTER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
            ON b.OccupationalSeriesNumber = a.CategorySubgroupCode
               AND 202401
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    WHERE a.PayPlan NOT IN ( 'AO', 'AWO', 'AE', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
          AND b.CareerProgramNumber IS NOT NULL
          AND a.PayPlan NOT IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage'
              )
    GROUP BY a.PayPlan,
             a.Strl,
             a.GradeType,
             a.GradeLevel,
             a.AmcosVersionId,
             b.CareerProgramNumber
) AS a;