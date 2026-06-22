

CREATE VIEW [analysis].[PythonOutBriefCompareByInventory]
AS
/****** SUM DATA *************/

SELECT *,
       inv - priorInv AS deltainv,
       ABS(inv - priorInv) AS absinv,
       CASE
           WHEN amcosversionid - priorVersion <> 100 THEN
               '1 new'
           WHEN inv = 0
                AND inv > 0 THEN
               '2 went away'
           WHEN ABS(inv - priorInv) > 100 THEN
               '3 over 100'
           WHEN ABS(inv - priorInv) > 50 THEN
               '4 over 50'
           WHEN ABS(inv - priorInv) > 25 THEN
               '5 over 25'
           WHEN ABS(inv - priorInv) > 10 THEN
               '6 over 10'
           WHEN ABS(inv - priorInv) >= 1 THEN
               '7 over 1'
           WHEN ABS(inv - priorInv) = 0 THEN
               '8 no change'
           ELSE
               '9 unknown'
       END AS invchange,
       Avg_Step_YOS - priorAvgStepYos AS deltaStepYos,
       ABS(Avg_Step_YOS - priorAvgStepYos) AS absstepyos,
       CASE
           WHEN amcosversionid - priorVersion <> 100 THEN
               '1 new'
           WHEN inv = 0
                AND inv > 0 THEN
               '2 went away'
           WHEN ABS(Avg_Step_YOS - priorAvgStepYos) >= 8 THEN
               '3 over 8'
           WHEN ABS(Avg_Step_YOS - priorAvgStepYos) > 5 THEN
               '4 over 5'
           WHEN ABS(Avg_Step_YOS - priorAvgStepYos) > 0 THEN
               '5 over 0'
           WHEN ABS(Avg_Step_YOS - priorAvgStepYos) = 0 THEN
               '6 no change'
           ELSE
               '7 unknown'
       END AS stepyoschange,
       (inv - priorInv) / NULLIF(priorInv, 0) AS invpercentchange,
       ABS((inv - priorInv) / NULLIF(priorInv, 0)) AS absinvpercentchange,
       CASE
           WHEN amcosversionid - priorVersion <> 100
                OR priorInv IS NULL THEN
               '1 new'
           WHEN ABS((inv - priorInv) / NULLIF(priorInv, 0)) >= .75 THEN
               '3 75% change'
           WHEN ABS((inv - priorInv) / NULLIF(priorInv, 0)) >= .50 THEN
               '4 over 50% change'
           WHEN ABS((inv - priorInv) / NULLIF(priorInv, 0)) >= .25 THEN
               '3 over 25% change'
           WHEN ABS((inv - priorInv) / NULLIF(priorInv, 0)) >= .10 THEN
               '5 over 10% change'
           WHEN ABS((inv - priorInv) / NULLIF(priorInv, 0)) > 0 THEN
               '6 less than 10%'
           WHEN ABS((inv - priorInv) / NULLIF(priorInv, 0)) = 0 THEN
               '7 no change'
           ELSE
               '8 unknown'
       END AS invpercentchangebin
FROM
(
    SELECT *,
           LAG(inv) OVER (PARTITION BY payplan,
                                       categorygroupcode,
                                       categorysubgroupcode,
                                       strl,
                                       locationid,
                                       gradelevel,
                                       locationtype,
                                       displayname
                          ORDER BY amcosversionid
                         ) AS priorInv,
           LAG(Avg_Step_YOS) OVER (PARTITION BY payplan,
                                                categorygroupcode,
                                                categorysubgroupcode,
                                                strl,
                                                locationid,
                                                gradelevel,
                                                locationtype,
                                                displayname
                                   ORDER BY amcosversionid
                                  ) AS priorAvgStepYos,
           LAG(amcosversionid) OVER (PARTITION BY payplan,
                                                  categorygroupcode,
                                                  categorysubgroupcode,
                                                  strl,
                                                  locationid,
                                                  gradelevel,
                                                  locationtype,
                                                  displayname
                                     ORDER BY amcosversionid
                                    ) AS priorVersion
    FROM
    (
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               Strl,
               LocationId,
               GradeLevel,
               MAX(Avg_Step_YOS) AS Avg_Step_YOS,
               SUM(Inventory) AS inv,
               AmcosVersionId,
               LocationType,
               DisplayName
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   Strl,
                   LocationId,
                   GradeLevel,
                   AVG(Step_YOS) OVER (PARTITION BY PayPlan,
                                                    CategoryGroupCode,
                                                    CategorySubgroupCode,
                                                    Strl,
                                                    LocationId,
                                                    GradeLevel,
                                                    AmcosVersionId
                                      ) AS Avg_Step_YOS,
                   Inventory,
                   AmcosVersionId,
                   LocationType,
                   DisplayName
            FROM
            (
                SELECT a.PayPlan,
                       a.CategoryGroupCode,
                       a.CategorySubgroupCode,
                       a.Strl,
                       a.GradeLevel,
                       CASE
                           WHEN a.PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' ) THEN
                               a.YOS * 1.0
                           ELSE
                               a.Step * 1.0
                       END AS Step_YOS,
                       CASE
                           WHEN a.PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' ) THEN
                               -1
                           ELSE
                               a.LocationId
                       END AS LocationId,
                       CASE
                           WHEN a.PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' ) THEN
                               'None'
                           ELSE
                               LocationType
                       END AS LocationType,
                       CASE
                           WHEN a.PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' ) THEN
                               'All'
                           ELSE
                               DisplayName
                       END AS DisplayName,
                       a.Inventory * 1.0 AS Inventory,
                       a.AmcosVersionId
                FROM data.KnownInventory AS a
                    INNER JOIN warehouse.Location AS b
                        ON a.LocationId = b.LocationId
                WHERE a.AmcosVersionId >= 202001 --and PayPlan='GS' and GradeLevel=13 and a.LocationId=1837 and AmcosVersionId=202301 and CategorySubgroupCode='1515'
            ) AS a
        ) AS a
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 Strl,
                 a.LocationId,
                 GradeLevel,
                 AmcosVersionId,
                 LocationType,
                 DisplayName
    ) AS a
) AS a;