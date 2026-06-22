

CREATE VIEW [load_GFEBS].[PersonnelThatDoNotContainOverseasCostElements]
AS
WITH PersonnelNumberThatContainOverseasCostElements_CTE
AS (
   SELECT DISTINCT
          PersonnelNumber
   FROM load_GFEBS.Processed
   WHERE CostElementCode IN ( '6100.11J0', '6100.12B0' ))
SELECT PayPlan,
       OccupationalGroupNumber,
       OccupationalSeriesNumber,
       StateCountry,
       FunctionalAreaCode,
       CostCenterCode,
       GradeLevel,
       PersonnelNumber,
       PayPeriodEndDate,
       CostElementCode,
       PostalCode1
FROM load_GFEBS.Processed
WHERE NOT EXISTS
(
    SELECT PersonnelNumber
    FROM PersonnelNumberThatContainOverseasCostElements_CTE
    WHERE Processed.PersonnelNumber = PersonnelNumber
);