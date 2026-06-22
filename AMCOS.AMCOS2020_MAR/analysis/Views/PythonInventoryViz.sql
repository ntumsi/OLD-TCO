CREATE VIEW analysis.PythonInventoryViz
AS
SELECT PayPlan,
       CategoryGroupCode,
       CategorySubgroupCode,
       Strl,
       LocationId,
       GradeLevel,
       CASE
           WHEN StepYoS = 99 THEN
               -1
           ELSE
               StepYoS
       END AS StepYoS,
       Inventory,
       AmcosVersionId
FROM
(
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           Strl,
           LocationId,
           GradeLevel,
           CASE
               WHEN PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' ) THEN
                   YOS
               ELSE
                   Step
           END AS StepYoS,
           Inventory,
           AmcosVersionId
    FROM data.Inventory
) AS a;