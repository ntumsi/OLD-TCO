

create VIEW [data].[KnownInventoryMILAggregate]
AS
--created 12/10/2019 to provide a single view for crunches to use for inventory so unknown values were excluded
-- not the following objects do not use this yet as data.inventory doesn't go to a deep enough level (missing GSA GLC codes)
-- CostofGAverages & Crunch.CrunchGSeries & crunch.CrunchSES & Crunch.Crunchwage
--note that some crunches use both data.knowninventory and data.inventory; data.inventory is used on occasions when grp/subgrp data is not needed, rather just a total count of inventory is needed
--
SELECT PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       GradeType,
       GradeLevel,       
       SUM(Inventory) AS Inventory,
       AmcosVersionId
FROM data.KnownInventory
WHERE PayPlan IN (SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag='Military')
GROUP BY 
PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       GradeType,
       GradeLevel,
       AmcosVersionId