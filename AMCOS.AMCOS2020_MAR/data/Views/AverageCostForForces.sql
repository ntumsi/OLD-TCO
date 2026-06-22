


CREATE VIEW [data].[AverageCostForForces]
AS
SELECT RowId,
       PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       AppropriationGroup,
       APPN,
       CostElementCategory,
       CostElementName,
       GradeType,
       GradeLevel,
       Amount,
       AmcosVersionId
FROM data.Costs
WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
      AND LocationId = -1
      AND DependentStatus = '-1'
      AND CategorySubgroupCode <> '-1'
      --AND AmcosVersionId = 202101
      AND CostElementCategory = 'Training Costs'
      AND CostElementName = 'Avg Cost of Training';