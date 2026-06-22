CREATE VIEW test.ReserveComponentsInventoryWithoutBasePay
AS
WITH ReserveComponentsInventory_CTE (PayPlan, CategorySubGroupCode, GradeLevel, Step_YOS)
AS (
   SELECT PayPlan,
          CategorySubGroupCode,
          GradeLevel,
          Step_YOS
   FROM data.Inventory
   WHERE PayPlan IN ( 'NO', 'NE', 'NWO', 'RO', 'RE', 'RWO' )
         AND Step_YOS <> 99
   GROUP BY PayPlan,
            CategorySubGroupCode,
            GradeLevel,
            Step_YOS),
     BasePayCostElement_CTE (PayPlan, CategorySubGroupCode, GradeLevel)
AS (SELECT PayPlan,
           CategorySubGroupCode,
           GradeLevel
    FROM data.Costs
    WHERE CostElementName = 'Avg Annualized Cost of Base Pay (Military)')
SELECT ReserveComponentsInventory_CTE.PayPlan,
       ReserveComponentsInventory_CTE.CategorySubGroupCode,
       ReserveComponentsInventory_CTE.GradeLevel,
       ReserveComponentsInventory_CTE.Step_YOS
FROM ReserveComponentsInventory_CTE
    LEFT JOIN BasePayCostElement_CTE
        ON ReserveComponentsInventory_CTE.PayPlan = BasePayCostElement_CTE.PayPlan
           AND ReserveComponentsInventory_CTE.CategorySubGroupCode = BasePayCostElement_CTE.CategorySubGroupCode
           AND ReserveComponentsInventory_CTE.GradeLevel = BasePayCostElement_CTE.GradeLevel
WHERE BasePayCostElement_CTE.PayPlan IS NULL;