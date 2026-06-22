
CREATE VIEW [load_GFEBS].[PersonnelThatDoNotContainBasePay]
AS
WITH PersonnelNumberThatContainBasePay_CTE
AS (
   SELECT DISTINCT
          PersonnelNumber,
          AmcosVersionId
   FROM load_GFEBS.Raw
   WHERE (
             CostElementCode IN ( 'ARMY/6100.11B1', '6100.11B1' )
             AND PayPlan <> '10/AD'
         )
         OR
         (
             CostElementCode IN ( 'ARMY/6100.11B1', 'ARMY/6100.11B3', '6100.11B1', '6100.11B3' )
             AND (PayPlan IN ( '10/AD', '10/EE', '10/EF', '10/IP' ))
         ))
SELECT PersonnelNumber,
       AmcosVersionId
FROM load_GFEBS.Raw
WHERE NOT EXISTS
(
    SELECT PersonnelNumber
    FROM PersonnelNumberThatContainBasePay_CTE
    WHERE Raw.PersonnelNumber = PersonnelNumber
          AND Raw.AmcosVersionId = AmcosVersionId
)
GROUP BY PersonnelNumber,
         AmcosVersionId;