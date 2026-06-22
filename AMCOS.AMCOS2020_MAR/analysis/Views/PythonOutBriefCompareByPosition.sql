CREATE VIEW analysis.PythonOutBriefCompareByPosition
AS
/****** SUM DATA *************/
WITH CTE
AS (
   SELECT PayPlan,
          CategoryGroupCode,
          CategoryGroupDescription,
          CategorySubgroupCode,
          CategorySubgroupDescription,
          CareerProgramNumber,
          CP_title,
          Strl,
          LocationId,
          Location_name,
          DependentStatus,
          NumberOfDependents,
          GradeLevel,
          SUM(Amount) AS TotalCost,
          AmcosVersionId
   FROM data.CostsWithDescriptions AS a
   WHERE (
             (
                 PayPlan IN ( 'ae', 'ao', 'awo', 'ne', 'nwo', 'no', 're', 'ro', 'rwo' )
                 AND locationid = -1
             )
             OR PayPlan NOT IN ( 'ae', 'ao', 'awo', 'ne', 'nwo', 'no', 're', 'ro', 'rwo' )
         )
         AND CostElementId IN
             (
                 SELECT b.CostElementId
                 FROM lookup.CostSummary AS a
                     INNER JOIN lookup.CostSummaryElement AS b
                         ON a.SummaryId = b.SummaryId
                 WHERE [Name] = 'Default'
             )
         AND AmcosVersionId >= 202001
   GROUP BY PayPlan,
            CategoryGroupCode,
            CategoryGroupDescription,
            CategorySubgroupCode,
            CategorySubgroupDescription,
            CareerProgramNumber,
            CP_title,
            Strl,
            LocationId,
            Location_name,
            DependentStatus,
            NumberOfDependents,
            GradeLevel,
            AmcosVersionId)
SELECT *,
       TotalCost - priorCost AS delta,
       ABS(TotalCost - priorCost) AS abs,
       CASE
           WHEN amcosversionid - priorVersion <> 100 THEN
               '1 rose from zero'
           WHEN TotalCost = 0
                AND priorCost > 0 THEN
               '2 went to zero'
           WHEN ABS(TotalCost - priorCost) > 100000 THEN
               '3 over 100,000'
           WHEN ABS(TotalCost - priorCost) > 75000 THEN
               '4 over 75,000'
           WHEN ABS(TotalCost - priorCost) > 50000 THEN
               '5 over 50,000'
           WHEN ABS(TotalCost - priorCost) > 25000 THEN
               '6 over 25,000'
           WHEN ABS(TotalCost - priorCost) > 10000 THEN
               '7 over 10,000'
           WHEN ABS(TotalCost - priorCost) > 5000 THEN
               '8 over 5,000'
           WHEN ABS(TotalCost - priorCost) > 1000 THEN
               '9a over 1,000'
           WHEN ABS(TotalCost - priorCost) > 500 THEN
               '9b over 500'
           WHEN ABS(TotalCost - priorCost) > 50 THEN
               '9c over 50'
           ELSE
               '9d very small'
       END AS amt_bin
FROM
(
    SELECT *,
           LAG(TotalCost) OVER (PARTITION BY PayPlan,
                                             CategoryGroupCode,
                                             CategorySubgroupCode,
                                             CareerProgramNumber,
                                             Strl,
                                             LocationId,
                                             DependentStatus,
                                             NumberOfDependents,
                                             GradeLevel
                                ORDER BY AmcosVersionId
                               ) AS priorCost,
           LAG(amcosversionid) OVER (PARTITION BY PayPlan,
                                                  CategoryGroupCode,
                                                  CategorySubgroupCode,
                                                  CareerProgramNumber,
                                                  Strl,
                                                  LocationId,
                                                  DependentStatus,
                                                  NumberOfDependents,
                                                  GradeLevel
                                     ORDER BY AmcosVersionId
                                    ) AS priorVersion
    FROM CTE
) AS a;