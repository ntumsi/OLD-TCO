/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW analysis.PythonPositionCostTotalsDefaultSummary
AS
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
       SUM(Amount) AS Amount,
       AmcosVersionId
FROM data.CostsWithDescriptions
WHERE CostElementId IN
      (
          SELECT CostElementId
          FROM lookup.CostElement
          WHERE CostElementId IN
                (
                    SELECT CostElementId
                    FROM lookup.CostSummaryElement
                    WHERE SummaryId IN
                          (
                              SELECT SummaryId FROM lookup.CostSummary WHERE [Name] = 'Default'
                          )
                )
      )
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
         AmcosVersionId;