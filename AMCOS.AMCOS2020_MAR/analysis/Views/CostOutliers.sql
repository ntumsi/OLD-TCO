CREATE VIEW [analysis].[CostOutliers]
AS
SELECT *,
       CASE
           WHEN LEFT(A.AmtBin, 2) = LEFT(A.inventoryBin, 2) THEN
               0 --not an outlier as inventory explains it
           WHEN CurrentInventory IS NULL
                AND CAST(LEFT(A.AmtBin, 1) AS INT) > 3 THEN
               0 --fill in the blank but not enough of a change to be an outlier
           WHEN CAST(LEFT(A.AmtBin, 1) AS INT) > 3 THEN
               0 --note big enough of a chance to be considered an outlier
           ELSE
               1 --an outlier
       END AS outlier_status
FROM
(
    SELECT a.*,
           b.inventoryBin,
           b.CurrentInventory,
           b.PriorInventory,
           b.avg_step_yos
    FROM analysis.CostTotals AS a
        LEFT OUTER JOIN analysis.InventoryTotals AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.GradeLevel = a.GradeLevel
               AND b.LocationId = a.LocationId
               AND b.Strl = a.Strl
               AND b.PayPlan = a.PayPlan
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.CategoryGroupCode = b.CategoryGroupCode
               AND a.CareerProgramNumber = b.CP
) AS A;