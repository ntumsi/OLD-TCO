
/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [analysis].[InventoryTotals]
AS
SELECT a.*,
       CASE
           WHEN a.PriorInventory = 0
                AND a.CurrentInventory > 0 THEN
               '0a rose from zero'
           WHEN a.PriorInventory < 0
                AND a.CurrentInventory = 0 THEN
               '0b went to zero'
           WHEN a.PriorInventory <> a.CurrentInventory THEN
               '1 change in inventory'
           WHEN a.PriorInventory = a.CurrentInventory THEN
               '2 no change in inventory'
           ELSE
               '3 unknown'
       END AS inventoryBin
FROM
(
    SELECT a.*,
           ISNULL(   LAG(a.CurrentInventory, 1, NULL) OVER (PARTITION BY PayPlan,
                                                                         CategoryGroupCode,
                                                                         CategorySubgroupCode,
                                                                         LocationId,
                                                                         Strl,
                                                                         GradeLevel,
                                                                         CP
                                                            ORDER BY PayPlan,
                                                                     CategoryGroupCode,
                                                                     CategorySubgroupCode,
                                                                     LocationId,
                                                                     Strl,
                                                                     GradeLevel,
                                                                     CP,
                                                                     AmcosVersionId
                                                           ),
                     0
                 ) AS PriorInventory
    FROM
    (
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               LocationId,
               Strl,
               GradeLevel,
               SUM(Inventory) AS CurrentInventory,
               ISNULL(ROUND(NULLIF(SUM(Step_YOS * Inventory * 1.0), 0) / NULLIF(SUM(Inventory * 1.0), 1), 0), 0) AS avg_step_yos,
               AmcosVersionId,
               CP
        FROM
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   CASE
                       WHEN PayPlan IN
                            (
                                SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                            ) THEN
                           -1
                       ELSE
                           LocationId
                   END AS LocationId,
                   Strl,
                   GradeLevel,
                   CASE
                       WHEN PayPlan IN
                            (
                                SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                            ) THEN
                           YOS
                       ELSE
                           Step
                   END AS Step_YOS,
                   Inventory,
                   AmcosVersionId,
                   -1 AS CP
            FROM data.KnownInventory
            --create a dummy 0 value so when we do the compare even records that went aware are still there to compare against
            UNION
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   CASE
                       WHEN PayPlan IN
                            (
                                SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                            ) THEN
                           -1
                       ELSE
                           LocationId
                   END AS LocationId,
                   Strl,
                   GradeLevel,
                   0 AS Step_YOS,
                   0 AS Inventory,
                   AmcosVersionId + 100,
                   -1 AS CP
            FROM data.KnownInventory
            WHERE AmcosVersionId IN
                  (
                      SELECT TOP(3)
                             AmcosVersionId
                      FROM lookup.AMCOSVersion
                      ORDER BY AmcosVersionId DESC
                  )
                  --don't allow the maximum amcosversion or we'll create a new amcosversion version we don't have yet
                  AND AmcosVersionId <
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
        /*
        --bring IN career program
        UNION
        SELECT  [PayPlan]
          ,'-1' AS [CategoryGroupCode]
          ,'-1' AS [CategorySubgroupCode]
          ,locationid
          ,[Strl]

          ,[GradeLevel]
          ,[Step]  AS  Step_YOS
  
          ,[Inventory]
          ,[AmcosVersionId]
          ,b.CareerProgramNumber AS CP
      FROM [data].[KnownInventory] AS a INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
      ON b.OccupationalSeriesNumber=a.CategorySubgroupCode AND a.AmcosVersionId BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
      --CP is not for military
      WHERE a.payplan NOT IN (SELECT payplan FROM lookup.PayPlanTags WHERE tag='military')
      UNION
      --last years data
          SELECT  [PayPlan]
          ,'-1' AS [CategoryGroupCode]
          ,'-1' AS [CategorySubgroupCode]
          ,locationid
          ,[Strl]

          ,[GradeLevel]
          ,[Step]  AS  Step_YOS
  
          ,[Inventory]
          ,[AmcosVersionId]+100
          ,b.CareerProgramNumber AS CP
      FROM [data].[KnownInventory] AS a INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
      ON b.OccupationalSeriesNumber=a.CategorySubgroupCode AND a.AmcosVersionId BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
      --CP is not for military
      WHERE a.payplan NOT IN (SELECT payplan FROM lookup.PayPlanTags WHERE tag='military')
      AND amcosversionid IN 
      (SELECT TOP 3 amcosversionid FROM lookup.AMCOSVersion ORDER BY AmcosVersionId DESC)
        --don't allow the maximum amcosversion or we'll create a new amcosversion version we don't have yet
        AND amcosversionid < (SELECT MAX(amcosversionid) FROM lookup.AMCOSVersion)
        */
        ) AS a
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 LocationId,
                 Strl,
                 GradeLevel,
                 AmcosVersionId,
                 CP
    ) AS a
) AS a;