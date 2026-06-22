

CREATE VIEW [load_GFEBS].[PersonnelThatContainOverseasCostElements]
AS
WITH PersonnelNumberThatContainOverseasCostElements_CTE
AS (
   SELECT DISTINCT
          PersonnelNumber,
          AmcosVersionId
   FROM load_GFEBS.Raw
   WHERE CostElementCode LIKE '%6100.11J0%'
         OR CostElementCode LIKE '%6100.12B0%')
SELECT DISTINCT
       PersonnelNumber,
       AmcosVersionId
FROM load_GFEBS.Raw
WHERE EXISTS
(
    SELECT PersonnelNumber
    FROM PersonnelNumberThatContainOverseasCostElements_CTE
    WHERE Raw.PersonnelNumber = PersonnelNumber
          AND Raw.AmcosVersionId = AmcosVersionId
);