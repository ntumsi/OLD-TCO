CREATE VIEW [test].[ActiveDutyInventoryWithoutBasePay]
AS
WITH ActiveDutyInventory_CTE (PayPlan, CategorySubgroupCode, GradeLevel, Step, YOS)
AS (
   SELECT PayPlan,
          CategorySubgroupCode,
          GradeLevel,
          Step,
          YOS
   FROM data.KnownInventory
   WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
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
    WHERE CostElementName = 'Avg Cost of Base Pay (Military)')
SELECT ActiveDutyInventory_CTE.PayPlan,
       ActiveDutyInventory_CTE.CategorySubgroupCode,
       ActiveDutyInventory_CTE.GradeLevel,
       ActiveDutyInventory_CTE.Step,
       ActiveDutyInventory_CTE.YOS
FROM ActiveDutyInventory_CTE
    LEFT JOIN BasePayCostElement_CTE
        ON ActiveDutyInventory_CTE.PayPlan = BasePayCostElement_CTE.PayPlan
           AND ActiveDutyInventory_CTE.CategorySubgroupCode = BasePayCostElement_CTE.CategorySubgroupCode
           AND ActiveDutyInventory_CTE.GradeLevel = BasePayCostElement_CTE.GradeLevel
WHERE BasePayCostElement_CTE.PayPlan IS NULL;;