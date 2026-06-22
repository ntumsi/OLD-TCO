CREATE VIEW test.ActiveDutyInventoryWithoutBasePay
AS
WITH ActiveDutyInventory_CTE (PayPlan, CategorySubGroupCode, GradeLevel, Step_YOS)
AS (
   SELECT PayPlan,
          CategorySubGroupCode,
          GradeLevel,
          Step_YOS
   FROM data.Inventory
   WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
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
    WHERE CostElementName = 'Avg Cost of Base Pay (Military)')
SELECT ActiveDutyInventory_CTE.PayPlan,
       ActiveDutyInventory_CTE.CategorySubGroupCode,
       ActiveDutyInventory_CTE.GradeLevel,
       ActiveDutyInventory_CTE.Step_YOS
FROM ActiveDutyInventory_CTE
    LEFT JOIN BasePayCostElement_CTE
        ON ActiveDutyInventory_CTE.PayPlan = BasePayCostElement_CTE.PayPlan
           AND ActiveDutyInventory_CTE.CategorySubGroupCode = BasePayCostElement_CTE.CategorySubGroupCode
           AND ActiveDutyInventory_CTE.GradeLevel = BasePayCostElement_CTE.GradeLevel
WHERE BasePayCostElement_CTE.PayPlan IS NULL;