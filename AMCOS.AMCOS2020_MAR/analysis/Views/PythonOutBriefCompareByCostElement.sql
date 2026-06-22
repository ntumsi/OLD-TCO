

CREATE VIEW [analysis].[PythonOutBriefCompareByCostElement]
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
          CostElementName,
          CostElementCategory,
          CostElementId,
          APPN,
          WeaponSystemName,
          GradeLevel,
          Amount,
          AmcosVersionId
   FROM data.CostsWithDescriptions AS a
   WHERE AmcosVersionId IN
         (
             SELECT TOP (4)
                    AmcosVersionId
             FROM lookup.AMCOSVersion
             ORDER BY AmcosVersionId DESC
         )
         --we only look at average costs, not actual costs which will always have changes that are must higher than our avg costs
         AND a.CostElementId NOT IN
             (
                 SELECT CostElementId
                 FROM lookup.CostElement
                 WHERE CostElementName LIKE 'actual%'
             ))
SELECT *,
       amount - priorCost AS delta,
       ABS(amount - priorCost) AS abs,
       CASE
           WHEN AmcosVersionId - priorVersion <> 100 THEN
               '1 rose from zero'
           WHEN amount = 0
                AND priorCost > 0 THEN
               '2 went to zero'
           WHEN ABS(amount - priorCost) > 100000 THEN
               '3 over 100,000'
           WHEN ABS(amount - priorCost) > 75000 THEN
               '4 over 75,000'
           WHEN ABS(amount - priorCost) > 50000 THEN
               '5 over 50,000'
           WHEN ABS(amount - priorCost) > 25000 THEN
               '6 over 25,000'
           WHEN ABS(amount - priorCost) > 10000 THEN
               '7 over 10,000'
           WHEN ABS(amount - priorCost) > 5000 THEN
               '8 over 5,000'
           WHEN ABS(amount - priorCost) > 1000 THEN
               '9a over 1,000'
           WHEN ABS(amount - priorCost) > 500 THEN
               '9b over 500'
           WHEN ABS(amount - priorCost) > 50 THEN
               '9c over 50'
           ELSE
               '9d very small'
       END AS amt_bin
FROM
(
    SELECT *,
           LAG(amount) OVER (PARTITION BY PayPlan,
                                          CategoryGroupCode,
                                          CategorySubgroupCode,
                                          CareerProgramNumber,
                                          Strl,
                                          LocationId,
                                          costelementid,
                                          weaponsystemname,
                                          DependentStatus,
                                          NumberOfDependents,
                                          GradeLevel
                             ORDER BY AmcosVersionId
                            ) AS priorCost,
           LAG(AmcosVersionId) OVER (PARTITION BY PayPlan,
                                                  CategoryGroupCode,
                                                  CategorySubgroupCode,
                                                  CareerProgramNumber,
                                                  Strl,
                                                  LocationId,
                                                  costelementid,
                                                  weaponsystemname,
                                                  DependentStatus,
                                                  NumberOfDependents,
                                                  GradeLevel
                                     ORDER BY AmcosVersionId
                                    ) AS priorVersion
    FROM CTE
) AS a;