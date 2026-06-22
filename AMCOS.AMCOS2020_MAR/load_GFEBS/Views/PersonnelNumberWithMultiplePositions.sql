
CREATE VIEW [load_GFEBS].[PersonnelNumberWithMultiplePositions]
AS
WITH JobsByPerson_CTE
AS (
   SELECT DISTINCT
          PersonnelNumber,
          FunctionalAreaCode,
          CostCenterCode,
          AmcosVersionId
   FROM load_GFEBS.Raw
   GROUP BY PersonnelNumber,
            FunctionalAreaCode,
            CostCenterCode,
            AmcosVersionId)
SELECT DISTINCT
       PersonnelNumber,
       JobsByPerson_CTE.AmcosVersionId
FROM JobsByPerson_CTE
GROUP BY JobsByPerson_CTE.PersonnelNumber,
         JobsByPerson_CTE.AmcosVersionId
HAVING COUNT(*) > 1;