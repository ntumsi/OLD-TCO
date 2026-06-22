CREATE VIEW analysis.payschedulescenarios
AS
SELECT DISTINCT
       PayPlan,
       CASE
           WHEN CategorySubgroupCode <> '-1' THEN
               'Subgrp'
           ELSE
               'PP Avg'
       END AS SubgroupLevel,
       CASE
           WHEN LocationId <> '-1' THEN
               'Location'
           ELSE
               'Location non-specific'
       END AS mylocation,
       CASE
           WHEN Strl <> '-1' THEN
               'STRL specific'
           ELSE
               'STRL non-specific'
       END AS STRL,
       CASE
           WHEN Step <> -1 THEN
               'step'
           ELSE
               'no step'
       END AS Step,
       CASE
           WHEN YOS <> -1 THEN
               'yos'
           ELSE
               'NO yos'
       END AS YOS
--,							gradelevel
FROM data.PaySchedules;