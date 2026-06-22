
-- =============================================
-- Author:Dan Hogan
-- Create date: 3/9/2021
-- Description:	displays categories for each pay plan that had costs and inventory go to or come up from zero
-- purpose is to make sure that each release any disappearence or appearance of a location is not unexepcted
-- and if so can be investigated
-- =============================================
CREATE PROCEDURE [test].[PayPlanCategoryVersionCompare] @AmcosVersionId INT = -1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DROP TABLE IF EXISTS #TempCompare;
    CREATE TABLE #TempCompare
    (
        PayPlan NVARCHAR(3) NULL,
        series NVARCHAR(5) NULL,
        seriesname NVARCHAR(500) NULL,
        currentreleaseCost INT NULL,
        priorreleaseCost INT NULL,
        currentreleaseInventory INT NULL,
        priorreleaseIventory INT NULL
    );

    INSERT INTO #TempCompare
    (
        PayPlan,
        series
    )
    --insert a combined list of unique combinations from the most recent 2 releases
    SELECT DISTINCT
           PayPlan,
           CategorySubgroupCode
    FROM
    (
        SELECT DISTINCT
               PayPlan,
               CategorySubgroupCode
        FROM data.Costs
        WHERE AmcosVersionId IN ( @AmcosVersionId, @AmcosVersionId - 1 )
        UNION
        SELECT DISTINCT
               PayPlan,
               CategorySubgroupCode
        FROM data.Inventory
        WHERE AmcosVersionId IN ( @AmcosVersionId, @AmcosVersionId - 1 )
    ) AS a;

    --bring in location names so we have some more reference nomen
    UPDATE #TempCompare
    SET seriesname = b.CategorySubgroupDescription
    FROM #TempCompare AS a
        INNER JOIN data.CategorySubgroup AS b
            ON a.PayPlan = b.PayPlan
               AND b.CategorySubgroupCode = a.series;

    --bring in cost data
    UPDATE #TempCompare
    SET currentreleaseCost = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   CategorySubgroupCode
            FROM data.Costs
            WHERE @AmcosVersionId = AmcosVersionId
        ) AS b
            ON a.series = b.CategorySubgroupCode
               AND b.PayPlan = a.PayPlan;

    UPDATE #TempCompare
    SET priorreleaseCost = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   CategorySubgroupCode
            FROM data.Costs
            WHERE @AmcosVersionId - 1 = AmcosVersionId
        ) AS b
            ON a.series = b.CategorySubgroupCode
               AND b.PayPlan = a.PayPlan;


    --bring in inventory data
    UPDATE #TempCompare
    SET currentreleaseInventory = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   CategorySubgroupCode
            FROM data.KnownInventory
            WHERE @AmcosVersionId = AmcosVersionId
        ) AS b
            ON a.series = b.CategorySubgroupCode
               AND b.PayPlan = a.PayPlan;

    UPDATE #TempCompare
    SET priorreleaseIventory = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   CategorySubgroupCode
            FROM data.KnownInventory
            WHERE @AmcosVersionId - 1 = AmcosVersionId
        ) AS b
            ON a.series = b.CategorySubgroupCode
               AND b.PayPlan = a.PayPlan;



    SELECT 'check the table below for pp/subgrp combinations present in the previous release but not in the new release';
    SELECT *
    FROM #TempCompare
    WHERE (
              (
                  priorreleaseCost = 1
                  AND currentreleaseCost <> 1 --costs that went to zero
              )
              OR
              (
                  priorreleaseCost <> 1
                  AND currentreleaseCost = 1 --costs that appeared from zero

              )
          );
--AND currentreleaseInventory=1 AND priorreleaseIventory=1 --removes inventory driven changes from consideration


END;