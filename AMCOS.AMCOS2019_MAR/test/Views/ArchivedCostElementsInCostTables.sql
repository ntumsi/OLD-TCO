
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
       CategorySubGroupCode,
       SpecialRateTableNumber,
       WageArea,
       StateCountry,
       FunctionalAreaCode,
       CostCenterCode,
       CostElementId,
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
       showOrder,
       GradeType,
       GradeLevel,
       WeaponSystemId,
       Amount,
       CrunchTime
FROM data.Costs
WHERE EXISTS
(
    SELECT *
    FROM ArchivedCostElements_CTE
    WHERE ArchivedCostElements_CTE.CostElementId = Costs.CostElementId
);