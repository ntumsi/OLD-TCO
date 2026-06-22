
CREATE VIEW [test].[ArchivedCostElementsInCostTables]
AS
WITH ArchivedCostElements_CTE (CostElementId)
AS (
   SELECT CostElementId
   FROM lookup.CostElement
   WHERE Active = 0)
SELECT RowId,
       PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       CareerProgramNumber,
       LocationId,
       Strl,
       CostElementId,
       WeaponSystemId,
       GradeType,
       GradeLevel,
       DependentStatus,
       Amount,
       CrunchTime,
       AmcosVersionId,
       AppropriationGroup,
       APPN,
       CostElementCategory,
       CostElementName,
       Description,
       ArmyCesTitle,
       OsdCapeCesTitle,
       Amort,
       Model,
       Locality,
       ApplyInflation,
       ShowOrder
FROM data.Costs
WHERE EXISTS
(
    SELECT *
    FROM ArchivedCostElements_CTE
    WHERE ArchivedCostElements_CTE.CostElementId = Costs.CostElementId
);