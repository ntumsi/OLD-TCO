CREATE VIEW data.CostElement
AS
SELECT CostElementId,
       PayPlan,
       AppropriationGroup,
       APPN,
       CostElementCategory,
       CostElementName,
       Amort,
       Model,
       Locality,
       Description,
       BusinessLogic,
       BasisOfComputation,
       Source,
       ShowOrder,
       ArmyCesTitle,
       OsdCapeCesTitle,
       Active
FROM lookup.CostElement
WHERE Active = 1;