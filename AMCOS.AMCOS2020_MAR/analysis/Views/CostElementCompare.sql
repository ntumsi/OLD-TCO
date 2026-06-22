
CREATE VIEW [analysis].[CostElementCompare]
AS
SELECT *,
       CurrentAmount - PriorAmount AS dif,
       CASE
           --WHEN prioramount =-1 THEN 'beginning of historical cost data'
           WHEN ISNULL(CurrentAmount, 0) > 0
                AND ISNULL(PriorAmount, 0) = 0 THEN
               '0a rose from zero'
           WHEN ISNULL(CurrentAmount, 0) = 0
                AND ISNULL(PriorAmount, 0) > 0 THEN
               '0b went to zero'
           WHEN ABS(CurrentAmount - PriorAmount) > 50000 THEN
               '1 >75000'
           WHEN ABS(CurrentAmount - PriorAmount) > 25000 THEN
               '2 >50000'
           WHEN ABS(CurrentAmount - PriorAmount) > 10000 THEN
               '3 >25000'
           WHEN ABS(CurrentAmount - PriorAmount) > 5000 THEN
               '4 >10000'
           WHEN ABS(CurrentAmount - PriorAmount) > 1000 THEN
               '5 >5000'
           WHEN ABS(CurrentAmount - PriorAmount) > 1 THEN
               '6 >1'
           WHEN ABS(CurrentAmount - PriorAmount) <= 1
                AND CurrentAmount <> PriorAmount THEN
               '7 <=1 minimal change'
           WHEN ABS(CurrentAmount - PriorAmount) = 0 THEN
               '8 no change'
           WHEN CurrentAmount = 0
                AND PriorAmount IS NULL THEN
               '9 extra zero/null row'
           ELSE
               'unknown'
       END AS AmtBin
FROM
(
    SELECT *,
           LAG(CurrentAmount, 1, NULL) OVER (PARTITION BY PayPlan,
                                                          CategoryGroupCode,
                                                          CategorySubgroupCode,
                                                          CareerProgramNumber,
                                                          Strl,
                                                          LocationId,
                                                          DependentStatus,
                                                          NumberOfDependents,
                                                          CostElementId,
                                                          GradeLevel,
                                                          WeaponSystemId
                                             ORDER BY PayPlan,
                                                      CategoryGroupCode,
                                                      CategorySubgroupCode,
                                                      CareerProgramNumber,
                                                      Strl,
                                                      LocationId,
                                                      DependentStatus,
                                                      NumberOfDependents,
                                                      CostElementId,
                                                      GradeLevel,
                                                      WeaponSystemId,
                                                      AmcosVersionId
                                            ) AS PriorAmount
    FROM
    (
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
               CostElementId,
               AppropriationGroup,
               APPN,
               CostElementCategory,
               CostElementName,
               GradeLevel,
               WeaponSystemName,
               WeaponSystemId,
               SUM(CurrentAmount) AS CurrentAmount,
               AmcosVersionId
        FROM
        ( --begin union
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
                   CostElementId,
                   AppropriationGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   GradeLevel,
                   WeaponSystemName,
                   WeaponSystemId,
                   Amount AS CurrentAmount,
                   AmcosVersionId
            FROM data.CostsWithDescriptions
            WHERE CostElementId NOT IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostElement
                      WHERE CostElementName LIKE 'actual%'
                  )

            --union in zero data going forward for those records the went to zero so they can show up
            UNION ALL
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
                   CostElementId,
                   AppropriationGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   GradeLevel,
                   WeaponSystemName,
                   WeaponSystemId,
                   0 AS CurrentAmount,
                   AmcosVersionId + 100
            FROM data.CostsWithDescriptions
            -- don't create a forward record for one that doesn't exist
            WHERE AmcosVersionId <
            (
                SELECT MAX(AmcosVersionId)FROM data.Costs
            )
                  AND CostElementId NOT IN
                      (
                          SELECT CostElementId
                          FROM lookup.CostElement
                          WHERE CostElementName LIKE 'actual%'
                      )
            --union in zero data going backwards for those records the went to zero so they can show up
            UNION ALL
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
                   CostElementId,
                   AppropriationGroup,
                   APPN,
                   CostElementCategory,
                   CostElementName,
                   GradeLevel,
                   WeaponSystemName,
                   WeaponSystemId,
                   0 AS CurrentAmount,
                   AmcosVersionId - 100
            FROM data.CostsWithDescriptions
            -- don't create a forward record for one that doesn't exist
            WHERE AmcosVersionId >
            (
                SELECT MIN(AmcosVersionId)FROM data.Costs
            )
                  AND CostElementId NOT IN
                      (
                          SELECT CostElementId
                          FROM lookup.CostElement
                          WHERE CostElementName LIKE 'actual%'
                      )
        ) AS a
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
                 CostElementId,
                 AppropriationGroup,
                 APPN,
                 CostElementCategory,
                 CostElementName,
                 GradeLevel,
                 WeaponSystemName,
                 WeaponSystemId,
                 AmcosVersionId
    ) AS a
) AS a;