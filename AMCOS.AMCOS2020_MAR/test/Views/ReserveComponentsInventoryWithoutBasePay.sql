CREATE VIEW [test].[ReserveComponentsInventoryWithoutBasePay]
AS
WITH ReserveComponentsInventory_CTE (PayPlan, CategorySubgroupCode, GradeLevel, Step, YOS)
AS (
   SELECT PayPlan,
          CategorySubgroupCode,
          GradeLevel,
          Step,
          YOS
   FROM data.KnownInventory
   WHERE PayPlan IN ( 'NO', 'NE', 'NWO', 'RO', 'RE', 'RWO' )
   GROUP BY PayPlan,
            CategorySubgroupCode,
            GradeLevel,
            Step,
            YOS),
     BasePayCostElement_CTE (PayPlan, CategorySubgroupCode, GradeLevel)
AS (SELECT PayPlan,
           CategorySubgroupCode,
           GradeLevel
    FROM data.Costs
    WHERE CostElementName = 'Avg Annualized Cost of Base Pay (Military)')
SELECT ReserveComponentsInventory_CTE.PayPlan,
       ReserveComponentsInventory_CTE.CategorySubgroupCode,
       ReserveComponentsInventory_CTE.GradeLevel,
       ReserveComponentsInventory_CTE.Step,
       ReserveComponentsInventory_CTE.YOS
FROM ReserveComponentsInventory_CTE
    LEFT JOIN BasePayCostElement_CTE
        ON ReserveComponentsInventory_CTE.PayPlan = BasePayCostElement_CTE.PayPlan
           AND ReserveComponentsInventory_CTE.CategorySubgroupCode = BasePayCostElement_CTE.CategorySubgroupCode
           AND ReserveComponentsInventory_CTE.GradeLevel = BasePayCostElement_CTE.GradeLevel
WHERE BasePayCostElement_CTE.PayPlan IS NULL;