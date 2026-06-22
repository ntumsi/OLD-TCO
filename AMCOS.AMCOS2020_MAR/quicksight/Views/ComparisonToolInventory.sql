

/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW quicksight.ComparisonToolInventory
AS
SELECT PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       LocationId,
       Strl,
       GradeLevel,
       SUM(WeightedStepYearsOfService * 1.0) / SUM(Inventory * 1.0) AS AverageStepYearsOfService,
       SUM(Inventory) AS Inventory,
       AmcosVersionId,
       CareerProgramNumber
FROM
(
    /* Specific:  group, subgroup, location */
    /* Non specific:  none */
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           Inventory * CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                                ) THEN
                               YOS
                           ELSE
                               Step
                       END AS WeightedStepYearsOfService,
           Inventory,
           AmcosVersionId,
           -1 AS CareerProgramNumber
    FROM data.KnownInventory
    WHERE LocationId <> -1 --no unknown locations which will then later cause double counting
    UNION ALL
    /* Specific:group,  location */
    /* Non specific: subgroup */
    SELECT PayPlan,
           CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           Inventory * CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                                ) THEN
                               YOS
                           ELSE
                               Step
                       END AS WeightedStepYearsOfService,
           Inventory,
           AmcosVersionId,
           -1 AS CareerProgramNumber
    FROM data.KnownInventory
    WHERE LocationId <> -1 --no unknown locations which will then later cause double counting
    UNION ALL
    --Specific: location
    --Non specific: subgroup,group
    SELECT PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           LocationId,
           Strl,
           GradeType,
           GradeLevel,
           Inventory * CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                                ) THEN
                               YOS
                           ELSE
                               Step
                       END AS WeightedStepYearsOfService,
           Inventory,
           AmcosVersionId,
           -1 AS CareerProgramNumber
    FROM data.KnownInventory
    WHERE LocationId <> -1 --no unknown locations which will then later cause double counting
    UNION ALL
    --Specific: subgroup,group
    --Non specific:  location
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           -1 AS LocationId,
           Strl,
           GradeType,
           GradeLevel,
           Inventory * CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                                ) THEN
                               YOS
                           ELSE
                               Step
                       END AS WeightedStepYearsOfService,
           Inventory,
           AmcosVersionId,
           -1 AS CareerProgramNumber
    FROM data.KnownInventory
    UNION ALL
    --Specific: ,group
    --Non specific:  location, subgroup
    SELECT PayPlan,
           CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           -1 AS LocationId,
           Strl,
           GradeType,
           GradeLevel,
           Inventory * CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                                ) THEN
                               YOS
                           ELSE
                               Step
                       END AS WeightedStepYearsOfService,
           Inventory,
           AmcosVersionId,
           -1 AS CareerProgramNumber
    FROM data.KnownInventory
    UNION ALL
    --Specific: ,
    --Non specific:  location, subgroup, group
    SELECT PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           -1 AS LocationId,
           Strl,
           GradeType,
           GradeLevel,
           Inventory * CASE
                           WHEN PayPlan IN
                                (
                                    SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                                ) THEN
                               YOS
                           ELSE
                               Step
                       END AS WeightedStepYearsOfService,
           Inventory,
           AmcosVersionId,
           -1 AS CareerProgramNumber
    FROM data.KnownInventory
    UNION ALL
    /* bring in Career Program */
    SELECT a.PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           a.LocationId,
           a.Strl,
           a.GradeType,
           a.GradeLevel,
           a.Inventory * a.Step AS WeightedStepYearsOfService,
           a.Inventory,
           a.AmcosVersionId,
           b.CareerProgramNumber AS CareerProgramNumber
    FROM data.KnownInventory AS a
        INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
            ON a.CategorySubgroupCode = b.OccupationalSeriesNumber
               AND a.AmcosVersionId
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
    WHERE a.LocationId <> -1 --no unknown locations which will then later cause double counting
    UNION ALL
    --bring IN Career Program location nonspecific
    SELECT a.PayPlan,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           -1 AS LocationId,
           a.Strl,
           a.GradeType,
           a.GradeLevel,
           a.Inventory * a.Step AS WeightedStepYearsOfService,
           a.Inventory,
           a.AmcosVersionId,
           b.CareerProgramNumber AS CareerProgramNumber
    FROM data.KnownInventory AS a
        INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
            ON a.CategorySubgroupCode = b.OccupationalSeriesNumber
               AND a.AmcosVersionId
               BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
) AS a
GROUP BY PayPlan,
         CategoryGroupCode,
         CategorySubgroupCode,
         LocationId,
         Strl,
         GradeLevel,
         AmcosVersionId,
         CareerProgramNumber;