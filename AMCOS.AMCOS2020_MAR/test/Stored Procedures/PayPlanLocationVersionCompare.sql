
-- =============================================
-- Author:Dan Hogan
-- Create date: 3/9/2021
-- Description:	displays locations for each pay plan that had costs and inventory go to or come up from zero
-- purpose is to make sure that each release any disappearence or appearance of a location is not unexepcted
-- and if so can be investigated
-- =============================================
CREATE PROCEDURE [test].[PayPlanLocationVersionCompare] @AmcosVersionId INT = -1
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
        locationid INT NULL,
        locationname NVARCHAR(500) NULL,
        currentreleaseCost INT NULL,
        priorreleaseCost INT NULL,
        currentreleaseInventory INT NULL,
        priorreleaseIventory INT NULL
    );

    INSERT INTO #TempCompare
    (
        PayPlan,
        locationid
    )
    --insert a combined list of unique combinations from the most recent 2 releases
    SELECT DISTINCT
           PayPlan,
           locationid
    FROM
    (
        SELECT DISTINCT
               PayPlan,
               LocationId
        FROM data.Costs
        WHERE AmcosVersionId IN ( @AmcosVersionId, @AmcosVersionId - 1 )
        UNION
        SELECT DISTINCT
               PayPlan,
               LocationId
        FROM data.Inventory
        WHERE AmcosVersionId IN ( @AmcosVersionId, @AmcosVersionId - 1 )
    ) AS a;

    --bring in location names so we have some more reference nomen
    UPDATE #TempCompare
    SET locationname = b.DisplayName
    FROM #TempCompare AS a
        INNER JOIN warehouse.Location AS b
            ON a.locationid = b.LocationId;

    --bring in cost data
    UPDATE #TempCompare
    SET currentreleaseCost = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   LocationId
            FROM data.Costs
            WHERE @AmcosVersionId = AmcosVersionId
        ) AS b
            ON a.locationid = b.locationid
               AND b.PayPlan = a.PayPlan;

    UPDATE #TempCompare
    SET priorreleaseCost = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   LocationId
            FROM data.Costs
            WHERE @AmcosVersionId - 1 = AmcosVersionId
        ) AS b
            ON a.locationid = b.locationid
               AND b.PayPlan = a.PayPlan;


    --bring in inventory data
    UPDATE #TempCompare
    SET currentreleaseInventory = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   LocationId
            FROM data.Inventory
            WHERE @AmcosVersionId = AmcosVersionId
        ) AS b
            ON a.locationid = b.locationid
               AND b.PayPlan = a.PayPlan;

    UPDATE #TempCompare
    SET priorreleaseIventory = 1
    FROM #TempCompare AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   PayPlan,
                   LocationId
            FROM data.Inventory
            WHERE @AmcosVersionId - 1 = AmcosVersionId
        ) AS b
            ON a.locationid = b.locationid
               AND b.PayPlan = a.PayPlan;



    SELECT 'check the table below for pp/location combinations present in the previous release but not in the new release';
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