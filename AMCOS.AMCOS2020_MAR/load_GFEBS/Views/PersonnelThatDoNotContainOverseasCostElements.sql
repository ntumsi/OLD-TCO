

CREATE VIEW [load_GFEBS].[PersonnelThatDoNotContainOverseasCostElements]
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
WHERE NOT EXISTS
(
    SELECT PersonnelNumber,
           AmcosVersionId
    FROM PersonnelNumberThatContainOverseasCostElements_CTE
    WHERE Raw.PersonnelNumber = PersonnelNumber
          AND Raw.AmcosVersionId = AmcosVersionId
);