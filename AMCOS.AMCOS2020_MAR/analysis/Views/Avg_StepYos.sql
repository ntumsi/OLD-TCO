


CREATE VIEW [analysis].[Avg_StepYos]
AS


--The purpose of this view is to provide a packaged and easy to call way to get the average step / YOS for each subgroup and location (for non-military) compared to the average
-- for the entire GradeLevel and location (for non military)
--One purpose of this is to help with identification of outliers.  For example if a particular base pay calculation is out of the norm it might be because the average
--step/yos of the scenario is much higher or lower than that over the overall step/yos of peer records in the aggregate
--by using this view those disconnects can be set aside to focus on the data which deviates but is not explained with a corresponding deviation in step/yos


--############# MILITARY
/* Military average YOS doesn't matter by location since base pay doesn't vary by location (BAH does) */
SELECT PayPlan,
       CategorySubgroupCode,
       Strl,
       LocationId,
       GradeLevel,
       Avg_StepYOS,
       AmcosVersionId,
       SUM(myweight) OVER (PARTITION BY PayPlan, Strl, GradeLevel)
       / SUM(Inventory) OVER (PARTITION BY PayPlan, Strl, GradeLevel, AmcosVersionId) AS agg_stepyos,
       Inventory,
       0 AS FillIn
FROM
(
    SELECT PayPlan,
           CategorySubgroupCode,
           Strl,
           -1 AS LocationId,
           GradeLevel,
           AmcosVersionId,
           SUM(YOS * Inventory) / SUM(Inventory) AS Avg_StepYOS,
           SUM(Inventory) AS Inventory,
           SUM(YOS * Inventory) AS myweight
    FROM data.KnownInventory
    WHERE PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
          )
          
    GROUP BY PayPlan,
             CategorySubgroupCode,
             Strl,
             GradeLevel,
             AmcosVersionId
) AS a


--############# CIV Inventory
UNION ALL
/* CIV average Step matters by location since pay varies by location */
SELECT PayPlan,
       CategorySubgroupCode,
       Strl,
       LocationId,
       GradeLevel,
       Avg_StepYOS,
       AmcosVersionId,
       SUM(myweight) OVER (PARTITION BY PayPlan,
                                        LocationId,
                                        Strl,
                                        GradeLevel,
                                        a.AmcosVersionId
                          ) / SUM(Inventory) OVER (PARTITION BY PayPlan, LocationId, Strl, GradeLevel, AmcosVersionId) AS agg_stepyos,
       Inventory,
       FillIn
FROM
(
    SELECT PayPlan,
           CategorySubgroupCode,
           Strl,
           LocationId,
           GradeLevel,
           AmcosVersionId,
           SUM(Step * Inventory) / SUM(Inventory) AS Avg_StepYOS,
           SUM(Inventory) AS Inventory,
           SUM(Step * Inventory) AS myweight,
           0 AS FillIn
    FROM data.KnownInventory
    WHERE PayPlan NOT IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
          )
          AND PayPlan NOT IN ( 'GG', 'GS', 'GL' ) --these pay plans are handled separately later to account for fill in the blanks
        
    GROUP BY PayPlan,
             CategorySubgroupCode,
             LocationId,
             Strl,
             GradeLevel,
             AmcosVersionId
) AS a


--############### G Series FIll in the Blanks
UNION ALL
--generate that fill in the blank Inventory
SELECT DISTINCT
       PayPlan,
       CategorySubgroupCode,
       '-1',
       LocationId,
       GradeLevel,
       SUM(myweight) OVER (PARTITION BY PayPlan,
                                        a.CategorySubgroupCode,
                                        LocationId,
                                        GradeLevel,
                                        a.AmcosVersionId
                          ) / SUM(Inventory) OVER (PARTITION BY PayPlan,
                                                                CategorySubgroupCode,
                                                                LocationId,
                                                                GradeLevel,
                                                                AmcosVersionId
                                                  ) AS Avg_StepYOS,
       AmcosVersionId,
       SUM(myweight) OVER (PARTITION BY PayPlan, LocationId, GradeLevel, a.AmcosVersionId)
       / SUM(Inventory) OVER (PARTITION BY PayPlan, LocationId, GradeLevel, AmcosVersionId) AS agg_stepyos,
       SUM(Inventory) OVER (PARTITION BY PayPlan,
                                         a.CategorySubgroupCode,
                                         LocationId,
                                         GradeLevel,
                                         a.AmcosVersionId
                           ) AS Inventory,
       fillin
FROM
(
    --get distinct costs
    SELECT a.PayPlan,
           a.CategorySubgroupCode,
           a.GradeLevel,
           a.LocationId,
           a.AmcosVersionId,
           ISNULL(ISNULL(b.Inventory, c.Inventory), 1) AS Inventory,
           ISNULL(ISNULL(b.Step, c.Step), 5) AS Step,
           ISNULL(ISNULL(b.myweight, c.myweight), 5) AS myweight,
           ISNULL(fillin, 1) AS fillin
    FROM
    (
        SELECT DISTINCT
               PayPlan,
               CategorySubgroupCode,
               GradeLevel,
               LocationId,
               AmcosVersionId
        FROM data.Costs
        WHERE  PayPlan IN ( 'GS', 'GL', 'GG' )
    ) AS a
        LEFT OUTER JOIN

        /* join on known inventory so we can exclude non-matches later */
        (
            SELECT PayPlan,
                   CategorySubgroupCode,
                   GradeLevel,
                   LocationId,
                   AmcosVersionId,
                   SUM(Inventory) AS Inventory,
                   Step,
                   SUM(Inventory) * Step AS myweight,
                   0 AS fillin
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'GS', 'GG', 'GL' )
                 
            GROUP BY PayPlan,
                     CategorySubgroupCode,
                     GradeLevel,
                     LocationId,
                     AmcosVersionId,
                     Step
        ) AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.CategorySubgroupCode = a.CategorySubgroupCode
               AND b.GradeLevel = a.GradeLevel
               AND b.LocationId = a.LocationId
               AND b.PayPlan = a.PayPlan
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   GradeLevel,
                   AmcosVersionId,
                   ROUND(SUM(Inventory * Step) / SUM(Inventory), 0) AS Step,
                   1 AS Inventory,
                   SUM(Inventory * Step) AS myweight
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'GS', 'GG', 'GL' )
                  
            GROUP BY PayPlan,
                     GradeLevel,
                     AmcosVersionId
        ) AS c
            ON c.AmcosVersionId = a.AmcosVersionId
               AND c.GradeLevel = a.GradeLevel
               AND c.PayPlan = a.PayPlan

--AND b.PayPlan IS NULL
--AND a.GradeLevel=3 AND a.LocationId=1852 AND a.PayPlan='GS'
) AS a;