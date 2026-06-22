

CREATE VIEW [data].[KnownInventory]
AS
--created 12/10/2019 to provide a single view for crunches to use for inventory so unknown values were excluded
-- not the following objects do not use this yet as data.inventory doesn't go to a deep enough level (missing GSA GLC codes)
-- CostofGAverages & Crunch.CrunchGSeries & crunch.CrunchSES & Crunch.Crunchwage
--note that some crunches use both data.knowninventory and data.inventory; data.inventory is used on occasions when grp/subgrp data is not needed, rather just a total count of inventory is needed
--
SELECT PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       LocationId,
       Strl,
       GradeType,
       GradeLevel,
       Step,
       YOS,
       Inventory,
       AmcosVersionId
FROM data.Inventory
WHERE (
          (
              /* Can't use MIL inventory with an invalid YOS */
              PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
              )
              AND YOS <> 99
              AND YOS <> -1
          )
          OR
          (
              /* can't use DMDC CIV (blue and white collar) inventory with an invalid step */
              PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'DMDC'
              )
              AND Step <> 99
              AND Step <> -1
              AND PayPlan NOT IN
                  (
                      SELECT PayPlan
                      FROM lookup.PayPlanTags
                      WHERE Tag = 'Military'
                      UNION
                      SELECT 'CY'
                  )
          )
          OR PayPlan = 'CY' --CY comes in as is 
          OR (
          /* GFEBS data doesn't have steps or YOS so we let it all in */
          PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'GFEBS'
          )
             )
          OR (
          /* WASS data doesn't have a pay plan so anything that has a wage comes in as inventory */
          PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'WASS'
          )
             )
      )
      AND CategoryGroupCode <> 'ZZ';