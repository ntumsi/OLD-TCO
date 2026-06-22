
/*
-- Author:Dan Hogan
-- Create date: 6/22/2020
-- Description:	Crunch CY
-- CY-1 is equivalent to GL 2 through 3
-- CY-2 is equivalent to GL 4 through 5
*/
CREATE PROCEDURE [crunch].[CrunchCY]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 /* to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0 */

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);
    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF @AmcosVersionId <
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01')
        FROM lookup.PayPlan
        WHERE PayPlan = 'CY'
    )
    BEGIN
        PRINT (CAST(@AmcosVersionId AS NVARCHAR(6)) + ' is before creation date of pay plan CY, crunch skipped');
        RETURN 0;
    END;

    /* Used as a way to detect cost updates which didn't happen correctly */
    DECLARE @LargeNegativeValue NUMERIC(16, 2) = -1000000;

    /* Integrate payschedule, all possible occupational series, and inventory */
    DROP TABLE IF EXISTS #PayScheduleWithInventory;
    CREATE TABLE #PayScheduleWithInventory
    (
        PayPlan NVARCHAR(3) NOT NULL,
        PayBand TINYINT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        Inventory INT NOT NULL
            DEFAULT (0),
        LocationId INT NOT NULL,
        LocationName NVARCHAR(150) NULL,
        AmcosVersionId INT NOT NULL,
        Pay NUMERIC(16, 2) NULL
    );
    INSERT INTO #PayScheduleWithInventory
    (
        PayPlan,
        PayBand,
        CategoryGroupCode,
        CategorySubgroupCode,
        LocationId,
        AmcosVersionId,
        Pay
    )
    SELECT PayPlan,
           PayBand,
           '1700',
           '1702',
           LocationId,
           AmcosVersionId,
           (MaxPay + MinPay) / 2 AS rate --DMDC doesn't provide us the step or pay amount so we just assume a straight average of the min and max pay
    FROM PaySchedule.PaySchedule_CY
    WHERE LocationId <> -1 --base pay without locality pay is not an allowed cost
          AND AmcosVersionId = @AmcosVersionId;

    /* Now bring in inventory which is used for computation of location non-specific averages at the end */
    UPDATE #PayScheduleWithInventory
    SET Inventory = ISNULL(b.Inventory, 0)
    FROM #PayScheduleWithInventory AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   LocationId,
                   GradeLevel,
                   SUM(Inventory) AS Inventory,
                   AmcosVersionId
            FROM data.KnownInventory
            WHERE AmcosVersionId = @AmcosVersionId
                  AND PayPlan = 'CY'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     LocationId,
                     GradeLevel,
                     AmcosVersionId
        ) AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.CategoryGroupCode = a.CategoryGroupCode
               AND b.CategorySubgroupCode = a.CategorySubgroupCode
               AND b.LocationId = a.LocationId
               AND b.PayPlan = a.PayPlan;

    IF @Debug = 1
    BEGIN
        SELECT 'pay and inventory table';

        SELECT *
        FROM #PayScheduleWithInventory;
    END;

    --get single values for later use in special pay and non special pay calculations
    -- these single values are for every pay plan that uses them
    DECLARE @PostRetHealthIns NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'PostRetHealthIns', @AmcosVersionId);
    DECLARE @PostRetLifeIns NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'PostRetLifeIns', @AmcosVersionId);
    DECLARE @Training NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'Training', @AmcosVersionId);

    -- create a master table to hold costs
    CREATE TABLE #Costs
    (
        PayPlan NVARCHAR(3) NOT NULL,
        PayBand TINYINT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        BasePay NUMERIC(16, 2) NOT NULL,
        CostAmount NUMERIC(16, 2) NOT NULL,
        LocationName NVARCHAR(100) NULL,
        CostElementId INT NOT NULL,
        CostElementName NVARCHAR(150) NOT NULL,
        CostElementCategory NVARCHAR(150) NOT NULL,
        Appn NVARCHAR(25) NOT NULL,
        AmcosVersionId INT NOT NULL,
        LocationId INT NOT NULL
    );
    INSERT INTO #Costs
    (
        PayPlan,
        PayBand,
        CategoryGroupCode,
        CategorySubgroupCode,
        BasePay,
        CostAmount,
        CostElementId,
        CostElementName,
        CostElementCategory,
        Appn,
        AmcosVersionId,
        LocationId
    )

    /* Insert all locations and their base pay and all possible cost elements */
    SELECT a.PayPlan,
           a.PayBand,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.Pay,
           @LargeNegativeValue,
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           b.APPN,
           a.AmcosVersionId,
           a.LocationId
    FROM
    (
        SELECT PayPlan,
               PayBand,
               CategoryGroupCode,
               CategorySubgroupCode,
               LocationId,
               AmcosVersionId,
               Pay
        FROM #PayScheduleWithInventory
        GROUP BY PayPlan,
                 PayBand,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 LocationId,
                 AmcosVersionId,
                 Pay
    ) AS a
        INNER JOIN lookup.CostElement AS b
            ON a.PayPlan = b.PayPlan
    WHERE @AmcosVersionId
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    DECLARE @PayPlan NVARCHAR(3) = N'GS'; --use the same ratios and data as GS

    --Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian) 
    UPDATE #Costs
    SET CostAmount = BasePay
    WHERE CostElementId IN ( 4846 );

    /* Cost-of-living-allowances (COLA) for white-collar civilian Federal employees 
    in nonforeign areas (Alaska, Hawaii, Guam and the Northern Mariana Islands,
    Puerto Rico, and the U.S. Virgin Islands)
    
    The amount is calculated by multiplying base pay * a cola % per OPM, see traffic in comments below
    because the gs_locality pay table has the acronym but the #paybylocationcosts uses locationid
    we do an intermediate join to bring the two together */
    UPDATE #Costs
    SET CostAmount = ISNULL(c.ColaRate / 100, 0) * a.BasePay
    FROM #Costs AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
			INNER JOIN [lookup].[NonforeignArea] x
			ON x.LocalityCode = b.SourceSystemCode
        INNER JOIN PaySchedule.NonforeignAreaCostOfLivingAllowances AS c
            ON x.NonforeignAreaCode = c.NonforeignAreaCode
    WHERE @AmcosVersionId = c.AmcosVersionId AND 
          b.LocationType IN ('Nonforeign Area', 'Locality Pay Area') --just in case any other location codes match our locality areas
          AND a.CostElementId IN ( 4896 );
	-- Remove 4896 values that are not non foreign area.
	DELETE FROM #Costs WHERE CostElementId = 4896 AND LocationId NOT IN (SELECT LocationId FROM warehouse.Location a JOIN lookup.NonforeignArea b ON b.LocalityCode = a.SourceSystemCode WHERE @AmcosVersionId = b.AmcosVersionId)

    -- Army CivPay; Compensation - Other; Avg Cost of Other Compensation 
    UPDATE #Costs
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'OtherComp', @AmcosVersionId)
    WHERE CostElementId IN ( 4851 );

    -- Army CivPay; Benefits; Avg Cost of Benefits 
    UPDATE #Costs
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'BenefitsRet', @AmcosVersionId)
    WHERE CostElementId IN ( 4852 );

    -- Army CivPay; Benefits; Avg Cost of Former Employee Compensation 
    UPDATE #Costs
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'FormerEmp', @AmcosVersionId)
    WHERE CostElementId IN ( 4850 );

    -- Army CivPay; Cash Awards; Avg Cost of Cash Awards 
    UPDATE #Costs
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'CashAwards', @AmcosVersionId)
    WHERE CostElementId IN ( 4849 );

    -- Army CivPay; Holiday Pay; Avg Cost of Holiday Pay 
    UPDATE #Costs
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'Holiday', @AmcosVersionId)
    WHERE CostElementId IN ( 4847 );

    -- Army CivPay; Overtime Pay; Avg Cost of Overtime Pay 
    UPDATE #Costs
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'Ovrt', @AmcosVersionId)
    WHERE CostElementId IN ( 4848 );

    -- OMA; Training Costs; Training
    UPDATE #Costs
    SET CostAmount = @Training
    WHERE CostElementId IN ( 4853 );

    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance 
    UPDATE #Costs
    SET CostAmount = @PostRetHealthIns
    WHERE CostElementId IN ( 4855 );

    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance 
    UPDATE #Costs
    SET CostAmount = @PostRetLifeIns
    WHERE CostElementId IN ( 4854 );

    IF @Debug = 1
    BEGIN
        SELECT 'Negative or zero cost values';
        SELECT a.*, b.LocationType, b.DisplayName, b.SourceSystemCode, x.LocalityCode, x.NonforeignAreaCode, c.NonforeignAreaCode
        FROM #Costs a
		LEFT JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
			LEFT JOIN [lookup].[NonforeignArea] x
			ON x.LocalityCode = b.SourceSystemCode
        LEFT JOIN PaySchedule.NonforeignAreaCostOfLivingAllowances AS c
            ON x.NonforeignAreaCode = c.NonforeignAreaCode		
        WHERE a.CostAmount < 0
              OR a.CostAmount IS NULL
        ORDER BY a.LocationName,
                 a.CategorySubgroupCode;

        SELECT 'Costs';
        SELECT *
        FROM #Costs
        ORDER BY LocationName,
                 CategorySubgroupCode;
    END;

    IF @Debug = 0
    BEGIN
        /* Remove the old costs for this version and pay plan before inserting the new costs */
        DELETE FROM crunch.Costs_CY
        WHERE AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_CY
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CostElementId,
            GradeType,
            PayBand,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               PayPlan,
               PayBand,
               CostAmount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId
        FROM #Costs
        UNION
        /* Category group with location average */
        SELECT PayPlan,
               CategoryGroupCode,
               '-1' AS CategorySubgroupCode,
               CostElementId,
               PayPlan,
               PayBand,
               AVG(CostAmount),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId
        FROM #Costs
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CostElementId,
                 PayPlan,
                 PayBand,
                 LocationId
        UNION
        /* Pay Plan with location average */
        SELECT PayPlan,
               '-1' AS CategoryGroupCode,
               '-1' AS CategorySubgroupCode,
               CostElementId,
               PayPlan,
               PayBand,
               AVG(CostAmount),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId
        FROM #Costs
        GROUP BY PayPlan,
                 CostElementId,
                 PayPlan,
                 PayBand,
                 LocationId
        UNION
        /* Category subgroup without location average */
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               PayPlan,
               PayBand,
               AVG(CostAmount),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               '-1' AS locationid
        FROM #Costs
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 PayPlan,
                 PayBand
        UNION
        /* Category group without location average */
        SELECT PayPlan,
               CategoryGroupCode,
               '-1' AS CategorySubgroupCode,
               CostElementId,
               PayPlan,
               PayBand,
               AVG(CostAmount),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               '-1' AS locationid
        FROM #Costs
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CostElementId,
                 PayPlan,
                 PayBand
        UNION
        /* Pay plan without location average */
        SELECT PayPlan,
               '-1' AS CategoryGroupCode,
               '-1' AS CategorySubgroupCode,
               CostElementId,
               PayPlan,
               PayBand,
               AVG(CostAmount),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               '-1' AS locationid
        FROM #Costs
        GROUP BY PayPlan,
                 CostElementId,
                 PayPlan,
                 PayBand;

        /* get rid of zero costs */
        DELETE FROM crunch.Costs_CY
        WHERE Amount = 0
              AND AmcosVersionId = @AmcosVersionId;



    --if we ever use inventory for this the pp the code is below but we are assuming the middle of the range so this is not used right now

    ---- pay plan averages for non-location specific
    --UNION
    --SELECT a.PayPlan,
    --       '-1', --a.CategoryGroupCode,
    --       '-1', --a.CategorySubgroupCode,

    --       costelementid,
    --       a.PayPlan,
    --       a.payband,
    --       SUM(costamount * b.inventory) / (SUM(b.inventory)),
    --       CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
    --       @AmcosVersionId,
    --       -1
    --FROM #PaybyLocationCosts AS a
    --    INNER JOIN #PayScheduleWithInventory AS b
    --        ON b.locationid = a.locationid
    --           AND b.payband = a.payband
    --           AND b.AmcosVersionId = a.AmcosVersionId
    --           AND b.CategoryGroupCode = a.CategoryGroupCode
    --           AND b.CategorySubgroupCode = a.CategorySubgroupCode
    --           AND b.PayPlan = a.PayPlan
    --WHERE inventory > 0 --0 inventory places (fill in the blank) shouldn't carry any weight in the average)
    --GROUP BY a.PayPlan,
    --         -- a.CategoryGroupCode,
    --         --a.CategorySubgroupCode,

    --         a.costelementid,
    --         a.PayPlan,
    --         a.payband


    ---- group average without location
    --UNION
    --SELECT a.PayPlan,
    --       a.CategoryGroupCode,
    --       '-1', --a.CategorySubgroupCode,

    --       costelementid,
    --       a.PayPlan,
    --       a.payband,
    --       SUM(costamount * b.inventory) / ISNULL(SUM(b.inventory), -1),
    --       CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
    --       @AmcosVersionId,
    --       -1
    --FROM #PaybyLocationCosts AS a
    --    INNER JOIN #PayScheduleWithInventory AS b
    --        ON b.locationid = a.locationid
    --           AND b.payband = a.payband
    --           AND b.AmcosVersionId = a.AmcosVersionId
    --           AND b.CategoryGroupCode = a.CategoryGroupCode --AND b.CategorySubgroupCode = a.CategorySubgroupCode 
    --           AND b.PayPlan = a.PayPlan
    --WHERE inventory > 0 --0 inventory places (fill in the blank) shouldn't carry any weight in the average)
    --GROUP BY a.PayPlan,
    --         a.CategoryGroupCode,
    --         a.CategorySubgroupCode,
    --         a.costelementid,
    --         a.PayPlan,
    --         a.payband


    ---- group average with location
    --UNION
    --SELECT a.PayPlan,
    --       a.CategoryGroupCode,
    --       '-1', --a.CategorySubgroupCode,

    --       costelementid,
    --       a.PayPlan,
    --       a.payband,
    --       SUM(costamount * b.inventory) / ISNULL(SUM(b.inventory), -1),
    --       CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
    --       @AmcosVersionId,
    --       a.locationid
    --FROM #PaybyLocationCosts AS a
    --    INNER JOIN #PayScheduleWithInventory AS b
    --        ON b.locationid = a.locationid
    --           AND b.payband = a.payband
    --           AND b.AmcosVersionId = a.AmcosVersionId
    --           AND b.CategoryGroupCode = a.CategoryGroupCode --AND b.CategorySubgroupCode = a.CategorySubgroupCode 
    --           AND b.PayPlan = a.PayPlan
    --WHERE inventory > 0 --0 inventory places (fill in the blank) shouldn't carry any weight in the average)
    --GROUP BY a.PayPlan,
    --         a.CategoryGroupCode,
    --         a.CategorySubgroupCode,
    --         a.costelementid,
    --         a.PayPlan,
    --         a.payband,
    --         a.locationid

    ----series average without location
    --UNION
    --SELECT a.PayPlan,
    --       a.CategoryGroupCode,
    --       a.CategorySubgroupCode,
    --       costelementid,
    --       a.PayPlan,
    --       a.payband,
    --       SUM(costamount * b.inventory) / ISNULL(SUM(b.inventory), -1),
    --       CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
    --       @AmcosVersionId,
    --       -1 -- a.locationid
    --FROM #PaybyLocationCosts AS a
    --    INNER JOIN #PayScheduleWithInventory AS b
    --        ON b.locationid = a.locationid
    --           AND b.payband = a.payband
    --           AND b.AmcosVersionId = a.AmcosVersionId
    --           AND b.CategoryGroupCode = a.CategoryGroupCode
    --           AND b.CategorySubgroupCode = a.CategorySubgroupCode
    --           AND b.PayPlan = a.PayPlan
    --WHERE inventory > 0 --0 inventory places (fill in the blank) shouldn't carry any weight in the average)
    --GROUP BY a.PayPlan,
    --         a.CategoryGroupCode,
    --         a.CategorySubgroupCode,
    --         a.costelementid,
    --         a.PayPlan,
    --         a.payband;
    --a.locationid
    END;
END;