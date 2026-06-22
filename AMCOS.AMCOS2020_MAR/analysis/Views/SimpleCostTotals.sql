

CREATE VIEW [analysis].[SimpleCostTotals]
AS
SELECT PayPlan,
       [Group],
       Subgroup,
       CareerProgram,
       Strl,
       Location,
       LocationId,
       DependentStatus,
       NumberOfDependents,
       GradeLevel,
       SUM(Amount) AS total,
       AmcosVersionId
FROM
(
    SELECT PayPlan,
           CategoryGroupCode + '-' + CategoryGroupDescription AS [Group],
           CategorySubgroupCode + '-' + CategorySubgroupDescription AS Subgroup,
           CareerProgramNumber + '-' + CP_title AS CareerProgram,
           Strl,
           Location_name + '(' + CAST(LocationId AS NVARCHAR) + ')' AS Location,
           LocationId,
           DependentStatus,
           NumberOfDependents,
           GradeLevel,
           Amount,
           AmcosVersionId
    FROM data.CostsWithDescriptions
    WHERE CAST(CostElementId AS NVARCHAR) + CAST(AmcosVersionId AS NVARCHAR)IN
          (
              SELECT CAST(CostElementId AS NVARCHAR) + CAST(AmcosVersionId AS NVARCHAR)
              FROM lookup.CostSummaryElement AS a
                  INNER JOIN lookup.CostSummary AS b
                      ON a.SummaryId = b.SummaryId
                  INNER JOIN lookup.AMCOSVersion AS c
                      ON c.AmcosVersionId
                         BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                         AND c.AmcosVersionId
                         BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
              WHERE b.Name = 'Default'
                    AND AmcosVersionId IN
                        (
                            SELECT TOP (3)
                                   AmcosVersionId
                            FROM lookup.AMCOSVersion
                            ORDER BY AmcosVersionId DESC
                        )
          )
          AND
          (
              LocationId = -1
              AND PayPlan IN
                  (
                      SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
                  )
          )
          OR
          (
              LocationId >= -1
              AND PayPlan NOT IN
                  (
                      SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
                  )
          )
) AS a
GROUP BY PayPlan,
         [Group],
         Subgroup,
         CareerProgram,
         Strl,
         Location,
         LocationId,
         DependentStatus,
         NumberOfDependents,
         GradeLevel,
         AmcosVersionId;