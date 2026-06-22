

CREATE VIEW [data].[InventoryWithUnknownStepYOSOnly]
AS
WITH InventoryWithoutUnknown_CTE
AS (
   SELECT DISTINCT
          PayPlan,
          CategoryGroupCode,
          CategorySubgroupCode,
          LocationId,
          GradeType,
          GradeLevel,
          Step,
          YOS
   FROM data.Inventory)
SELECT DISTINCT
       PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       Inventory.LocationId,
       GradeType,
       GradeLevel,
       Step,
       YOS
FROM data.Inventory Inventory
WHERE NOT EXISTS
(
    SELECT *
    FROM InventoryWithoutUnknown_CTE
    WHERE Inventory.PayPlan = InventoryWithoutUnknown_CTE.PayPlan
          AND Inventory.CategoryGroupCode = InventoryWithoutUnknown_CTE.CategoryGroupCode
          AND Inventory.CategorySubgroupCode = InventoryWithoutUnknown_CTE.CategorySubgroupCode
          AND ISNULL(Inventory.LocationId, 'ZZZ') = ISNULL(InventoryWithoutUnknown_CTE.LocationId, 'ZZZ')
          AND Inventory.GradeType = InventoryWithoutUnknown_CTE.GradeType
          AND Inventory.GradeLevel = InventoryWithoutUnknown_CTE.GradeLevel
);