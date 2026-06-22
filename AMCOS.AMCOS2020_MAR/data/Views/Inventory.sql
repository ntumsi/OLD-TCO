





CREATE VIEW [data].[Inventory]
AS
/* Military & Civ data */
SELECT PayPlan AS PayPlan,
       CategoryGroup AS CategoryGroupCode,
       CategorySubgroup AS CategorySubgroupCode,
       '-1' AS Strl,
       LocationId,
       GradeType,
       GradeLevel,
       Step,
       YOS,
       Inventory,
       AmcosVersionId
FROM crunch.InventoryProcessed
WHERE PayPlan IN
      (
          SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'DMDC'
      )

/* Wage and ES grade pay plans  don't have a payschedule get their pay data from wass so their inventory needs to come from there as well */
UNION ALL
SELECT PayPlan AS PayPlan,
       [Group] AS CategoryGroupCode,
       Subgroup AS CategorySubgroupCode,
       '-1' AS Strl,
       LocationId AS LocationId,
       GradeType,
       GradeLevel,
       Step,
       NULL AS YOS,
       Inventory,
       AmcosVersionId AS AmcosVersionId
FROM crunch.WASS_Processed
WHERE PayPlan IN
      (
          SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'WASS'
      )

/* GFEBS based pay plans have their inventory come from GFEBS */
UNION ALL
SELECT PayPlan,
       OccupationalGroupNumber AS CategoryGroupCode,
       OccupationalSeriesNumber AS CategorySubgroupCode,
       STRL,
       LocationId AS LocationId,
       GradeType,
       GradeLevel,
       Step AS Step,
       YOS AS YOS,
       Inventory,
       AmcosVersionId
FROM crunch.Inventory_GFEBS;