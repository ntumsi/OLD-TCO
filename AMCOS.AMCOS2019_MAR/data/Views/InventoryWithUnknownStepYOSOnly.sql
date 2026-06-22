
CREATE VIEW [data].[InventoryWithUnknownStepYOSOnly]
AS
WITH InventoryWithoutUnknown_CTE
AS (
   SELECT DISTINCT
          PayPlan,
          CategoryGroupCode,
          CategorySubGroupCode,
          WageArea,
          GradeType,
          GradeLevel,
          Step_YOS
   FROM data.Inventory
   WHERE Step_YOS <> 99)
SELECT DISTINCT
       PayPlan,
       CategoryGroupCode,
       CategorySubGroupCode,
       WageArea,
       GradeType,
       GradeLevel,
       Step_YOS
FROM data.Inventory Inventory
WHERE Step_YOS = 99
      AND NOT EXISTS
(
    SELECT *
    FROM InventoryWithoutUnknown_CTE
    WHERE Inventory.PayPlan = InventoryWithoutUnknown_CTE.PayPlan
          AND Inventory.CategoryGroupCode = InventoryWithoutUnknown_CTE.CategoryGroupCode
          AND Inventory.CategorySubGroupCode = InventoryWithoutUnknown_CTE.CategorySubGroupCode
          AND ISNULL(Inventory.WageArea, 'ZZZ') = ISNULL(InventoryWithoutUnknown_CTE.WageArea, 'ZZZ')
          AND Inventory.GradeType = InventoryWithoutUnknown_CTE.GradeType
          AND Inventory.GradeLevel = InventoryWithoutUnknown_CTE.GradeLevel
);