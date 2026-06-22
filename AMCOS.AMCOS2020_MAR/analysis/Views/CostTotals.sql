
/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [analysis].[CostTotals]
AS
SELECT a.*,
       CASE
           WHEN ISNULL(CurrentTotal, 0) > 0
                AND ISNULL(PriorTotal, 0) = 0 THEN
               '0a rose from zero'
           WHEN ISNULL(CurrentTotal, 0) = 0
                AND ISNULL(PriorTotal, 0) > 0 THEN
               '0b went to zero'
           WHEN ABS(CurrentTotal - PriorTotal) > 150000 THEN
               '1 >150000'
           WHEN ABS(CurrentTotal - PriorTotal) > 100000 THEN
               '2 >100000'
           WHEN ABS(CurrentTotal - PriorTotal) > 75000 THEN
               '3 >75000'
           WHEN ABS(CurrentTotal - PriorTotal) > 50000 THEN
               '4 >50000'
           WHEN ABS(CurrentTotal - PriorTotal) > 25000 THEN
               '5 >25000'
           WHEN ABS(CurrentTotal - PriorTotal) > 10000 THEN
               '6 >10000'
           WHEN ABS(CurrentTotal - PriorTotal) > 1 THEN
               '7a >1'
           WHEN ABS(CurrentTotal - PriorTotal) <= 1
                AND CurrentTotal <> PriorTotal THEN
               '7b <=1 minimal change'
           WHEN ABS(CurrentTotal - PriorTotal) = 0 THEN
               '8 no change'
           WHEN CurrentTotal = 0
                AND PriorTotal IS NULL THEN
               '9 extra zero/null row'
           ELSE
               'unknown'
       END AS AmtBin
FROM
(
    SELECT a.*,
           CurrentTotal - PriorTotal AS Delta,
           ABS(CurrentTotal - PriorTotal) AS AbsDelta
    FROM
    (
        SELECT a.*,
               ISNULL(   LAG(CurrentTotal, 1, NULL) OVER (PARTITION BY PayPlan,
                                                                       [Group],
                                                                       [Subgroup],
                                                                       CareerProgram,
                                                                       [Strl],
                                                                       [Location],
                                                                       locationid,
                                                                       [DependentStatus],
                                                                       [NumberOfDependents],
                                                                       [GradeLevel]
                                                          ORDER BY PayPlan,
                                                                   [Group],
                                                                   [Subgroup],
                                                                   CareerProgram,
                                                                   [Strl],
                                                                   [Location],
                                                                   locationid,
                                                                   [DependentStatus],
                                                                   [NumberOfDependents],
                                                                   [GradeLevel],
                                                                   [AmcosVersionId]
                                                         ),
                         0
                     ) AS PriorTotal
        FROM
        (
            SELECT PayPlan,
                   [Group],
                   [CategoryGroupCode],
                   [Subgroup],
                   CategorySubgroupCode,
                   CareerProgram,
                   [CareerProgramNumber],
                   [Strl],
                   [Location],
                   locationid,
                   [DependentStatus],
                   [NumberOfDependents],
                   [GradeLevel],
                   SUM(ISNULL(Amount, 0)) AS CurrentTotal,
                   [AmcosVersionId]
            FROM
            (
                SELECT [PayPlan],
                       [CategoryGroupCode] + '-' + [CategoryGroupDescription] AS [Group],
                       [CategoryGroupCode],
                       [CategorySubgroupCode] + '-' + [CategorySubgroupDescription] AS [Subgroup],
                       [CategorySubgroupCode],
                       [CareerProgramNumber] + '-' + [CP_title] AS CareerProgram,
                       [CareerProgramNumber],
                       [Strl],
                       [Location_name] + '(' + CAST(LocationId AS NVARCHAR) + ')' AS [Location],
                       LocationId,
                       [DependentStatus],
                       [NumberOfDependents],
                       [GradeLevel],
                       [Amount],
                       [AmcosVersionId]
                FROM [data].[CostsWithDescriptions]
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
                                        SELECT TOP 3
                                               AmcosVersionId
                                        FROM lookup.AMCOSVersion
                                        ORDER BY AmcosVersionId DESC
                                    )
                      )
                UNION
                SELECT [PayPlan],
                       [CategoryGroupCode] + '-' + [CategoryGroupDescription] AS [Group],
                       [CategoryGroupCode],
                       [CategorySubgroupCode] + '-' + [CategorySubgroupDescription] AS [Subgroup],
                       [CategorySubgroupCode],
                       [CareerProgramNumber] + '-' + [CP_title] AS CareerProgram,
                       [CareerProgramNumber],
                       [Strl],
                       [Location_name] + '(' + CAST(LocationId AS NVARCHAR) + ')' AS [Location],
                       LocationId,
                       [DependentStatus],
                       [NumberOfDependents],
                       [GradeLevel],
                       0 AS [Amount],
                       [AmcosVersionId] + 100
                FROM [data].[CostsWithDescriptions]
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
                                        SELECT TOP 3
                                               AmcosVersionId
                                        FROM lookup.AMCOSVersion
                                        ORDER BY AmcosVersionId DESC
                                    )
                                --don't allow the maximum amcosversion or we'll create a new amcosversion version we don't have yet
                                AND AmcosVersionId <
                                (
                                    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                                )
                      )
            ) AS a
            GROUP BY [PayPlan],
                     [Group],
                     [CategoryGroupCode],
                     [Subgroup],
                     [CategorySubgroupCode],
                     [CareerProgram],
                     [Strl],
                     [Location],
                     locationid,
                     [DependentStatus],
                     [NumberOfDependents],
                     [GradeLevel],
                     [AmcosVersionId],
                     [CareerProgramNumber]
        ) AS a
    ) AS a
) AS a;