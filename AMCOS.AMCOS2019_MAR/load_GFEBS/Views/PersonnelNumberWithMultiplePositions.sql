CREATE VIEW load_GFEBS.PersonnelNumberWithMultiplePositions
AS
WITH JobsByPerson_CTE
AS (
   SELECT DISTINCT
          PersonnelNumber,
          FunctionalAreaCode,
          CostCenterCode
   FROM load_GFEBS.Raw
   GROUP BY PersonnelNumber,
            FunctionalAreaCode,
            CostCenterCode)
SELECT DISTINCT
       PersonnelNumber
FROM JobsByPerson_CTE
GROUP BY JobsByPerson_CTE.PersonnelNumber
HAVING COUNT(*) > 1;