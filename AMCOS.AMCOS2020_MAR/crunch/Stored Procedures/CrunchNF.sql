/*
-- Author:Dan Hogan
-- Create date: 5/18/2021
-- Description:	Crunch NF
-- Similar to the CY pay plan
*/
CREATE PROCEDURE [crunch].[CrunchNF]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 /* to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0 */

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);
    DECLARE @largenegativevalue NUMERIC(15, 2) = -1000000; --used as a way to detect cost updates which didn't happen correctly
    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DROP TABLE IF EXISTS #temppay;
    CREATE TABLE #temppay
    (
        PayPlan NVARCHAR(2) NOT NULL,
        Payband TINYINT NOT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(4) NOT NULL,
        LocationId INT NOT NULL,
        AmcosVersionId INT NOT NULL,
        Inventory INT NOT NULL,
        MinPay NUMERIC(18, 2) NOT NULL,
        MaxPay NUMERIC(18, 2) NOT NULL,
        AvgPay NUMERIC(18, 2) NOT NULL
    );
    INSERT INTO #temppay
    (
        PayPlan,
        Payband,
        CategoryGroupCode,
        CategorySubgroupCode,
        LocationId,
        AmcosVersionId,
        Inventory,
        MinPay,
        MaxPay,
        AvgPay
    )

    --inventory subgroup location based specific costs

    SELECT a.PayPlan,
           a.PayBand,
           b.CategoryGroupCode,
           b.CategorySubgroupCode,
           b.LocationId,
           b.AmcosVersionId,
           b.inventory,
           a.MinPay,
           a.MaxPay,
           (a.MinPay + a.MaxPay) / 2
    FROM crunch.NfPayProcessed AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   LocationId,
                   GradeLevel,
                   AmcosVersionId,
                   SUM(Inventory) AS inventory
            FROM data.Inventory
            WHERE AmcosVersionId = @AmcosVersionId
                  AND PayPlan = 'NF'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     LocationId,
                     GradeLevel,
                     AmcosVersionId
        ) AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.GradeLevel = a.PayBand
               AND b.LocationId = a.LocationId
               AND b.PayPlan = a.PayPlan
    WHERE a.PayPlan = 'NF'
          AND a.AmcosVersionId = @AmcosVersionId;

    --now insert a bunch of the averages
    INSERT INTO #temppay
    (
        PayPlan,
        Payband,
        CategoryGroupCode,
        CategorySubgroupCode,
        LocationId,
        AmcosVersionId,
        Inventory,
        MinPay,
        MaxPay,
        AvgPay
    )
    --subgroup no location
    SELECT PayPlan,
           Payband,
           CategoryGroupCode,
           CategorySubgroupCode,
           -1,
           AmcosVersionId,
           SUM(Inventory),
           SUM(MinPay * Inventory) / SUM(Inventory),
           SUM(MaxPay * Inventory) / SUM(Inventory),
           SUM(AvgPay * Inventory) / SUM(Inventory)
    FROM #temppay
    GROUP BY PayPlan,
             Payband,
             CategoryGroupCode,
             CategorySubgroupCode,
             AmcosVersionId
    UNION ALL
    --group with location
    SELECT PayPlan,
           Payband,
           CategoryGroupCode,
           '-1',
           LocationId,
           AmcosVersionId,
           SUM(Inventory),
           SUM(MinPay * Inventory) / SUM(Inventory),
           SUM(MaxPay * Inventory) / SUM(Inventory),
           SUM(AvgPay * Inventory) / SUM(Inventory)
    FROM #temppay
    GROUP BY PayPlan,
             Payband,
             CategoryGroupCode,
             LocationId,
             AmcosVersionId
    UNION ALL
    --group without location
    SELECT PayPlan,
           Payband,
           CategoryGroupCode,
           '-1',
           -1,
           AmcosVersionId,
           SUM(Inventory),
           SUM(MinPay * Inventory) / SUM(Inventory),
           SUM(MaxPay * Inventory) / SUM(Inventory),
           SUM(AvgPay * Inventory) / SUM(Inventory)
    FROM #temppay
    GROUP BY PayPlan,
             Payband,
             CategoryGroupCode,
             AmcosVersionId
    UNION ALL
    --pp with location
    SELECT PayPlan,
           Payband,
           '-1',
           '-1',
           LocationId,
           AmcosVersionId,
           SUM(Inventory),
           SUM(MinPay * Inventory) / SUM(Inventory),
           SUM(MaxPay * Inventory) / SUM(Inventory),
           SUM(AvgPay * Inventory) / SUM(Inventory)
    FROM #temppay
    GROUP BY PayPlan,
             Payband,
             LocationId,
             AmcosVersionId
    UNION ALL
    --pp without location
    SELECT PayPlan,
           Payband,
           '-1',
           '-1',
           '-1',
           AmcosVersionId,
           SUM(Inventory),
           SUM(MinPay * Inventory) / SUM(Inventory),
           SUM(MaxPay * Inventory) / SUM(Inventory),
           SUM(AvgPay * Inventory) / SUM(Inventory)
    FROM #temppay
    GROUP BY PayPlan,
             Payband,
             AmcosVersionId;

    --now we need to fill in the blanks in inventory at the PP, location specific level
    INSERT INTO #temppay
    (
        PayPlan,
        Payband,
        CategoryGroupCode,
        CategorySubgroupCode,
        LocationId,
        AmcosVersionId,
        Inventory,
        MinPay,
        MaxPay,
        AvgPay
    )
    SELECT PayPlan,
           PayBand,
           '-1' AS CategoryGroupCode,
           '-1' AS CategorySubgroupCode,
           LocationId,
           AmcosVersionId,
           0,
           MinPay,
           MaxPay,
           (MaxPay + MinPay) / 2 AS avgpay
    FROM crunch.NfPayProcessed
    WHERE AmcosVersionId = @AmcosVersionId
          AND LocationId NOT IN
              (
                  SELECT LocationId FROM #temppay WHERE CategoryGroupCode = '-1'
              );


    IF @Debug = 1
    BEGIN
        SELECT 'pay and inventory table';

        SELECT *
        FROM #temppay;

    END;

    --get single values for later use in special pay and non special pay calculations
    -- these single values are for every pay plan that uses them
    DECLARE @PostRetHealthIns NUMERIC(26, 6) = crunch.GetSingleValue('AA', 'PostRetHealthIns', @AmcosVersionId);
    DECLARE @PostRetLifeIns NUMERIC(26, 6) = crunch.GetSingleValue('AA', 'PostRetLifeIns', @AmcosVersionId);
    DECLARE @Training NUMERIC(26, 6) = crunch.GetSingleValue('AA', 'Training', @AmcosVersionId);

    -- create a master table to hold costs
    CREATE TABLE #PayByLocationCosts
    (
        PayPlan NVARCHAR(3) NOT NULL,
        Payband TINYINT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        SubgroupTitle NVARCHAR(150) NULL,
        BasePay NUMERIC(15, 2) NOT NULL,
        CostAmount NUMERIC(15, 2) NOT NULL,
        LocationName NVARCHAR(100) NULL,
        CostElementId INT NOT NULL,
        CostElementName NVARCHAR(150) NOT NULL,
        CostElementCategory NVARCHAR(150) NOT NULL,
        Appn NVARCHAR(25) NOT NULL,
        AmcosVersionId INT NOT NULL,
        LocationId INT NOT NULL,
        Inventory INT NOT NULL
    );
    INSERT INTO #PayByLocationCosts
    (
        PayPlan,
        Payband,
        CategoryGroupCode,
        CategorySubgroupCode,
        BasePay,
        CostAmount,
        CostElementId,
        CostElementName,
        CostElementCategory,
        Appn,
        AmcosVersionId,
        LocationId,
        Inventory
    )

    --insert is a cross join between all locations and their base pay and all possible cost elements
    SELECT a.PayPlan,
           a.Payband,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.AvgPay,
           @largenegativevalue,
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           b.APPN,
           a.AmcosVersionId,
           a.LocationId,
           a.Inventory
    FROM #temppay AS a
        INNER JOIN lookup.CostElement AS b
            ON a.PayPlan = b.PayPlan
    WHERE @AmcosVersionId
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;


    DECLARE @PayPlan NVARCHAR(3) = N'GS'; --use the same ratios and data as GS

    --Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian) 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay
    WHERE CostElementId IN ( 4915 );

    --Non-foreign COLA
    --NFC is the base pay * a cola % per OPM, see traffic in comments below
    --because the gs_locality pay table has the acronym but the #paybylocationcosts uses locationid
    --we do an intermediate join to bring the two together
    UPDATE #PayByLocationCosts
    SET CostAmount = ISNULL(c.ColaRate / 100, 0) * a.BasePay
    FROM #PayByLocationCosts AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        INNER JOIN PaySchedule.NonforeignAreaCostOfLivingAllowances AS c
            ON b.SourceSystemCode = c.NonforeignAreaCode
    WHERE @AmcosVersionId = c.AmcosVersionId
          AND b.LocationType = 'Nonforeign Area' --just in case any other location codes match our locality areas
          AND a.CostElementId IN ( 4925 );

    -- Army CivPay; Compensation - Other; Avg Cost of Other Compensation 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'OtherComp', @AmcosVersionId)
    WHERE CostElementId IN ( 4920 );

    -- Army CivPay; Benefits; Avg Cost of Benefits 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'BenefitsRet', @AmcosVersionId)
    WHERE CostElementId IN ( 4921 );


    -- Army CivPay; Benefits; Avg Cost of Former Employee Compensation 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'FormerEmp', @AmcosVersionId)
    WHERE CostElementId IN ( 4919 );

    -- Army CivPay; Cash Awards; Avg Cost of Cash Awards 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'CashAwards', @AmcosVersionId)
    WHERE CostElementId IN ( 4918 );

    -- Army CivPay; Holiday Pay; Avg Cost of Holiday Pay 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'Holiday', @AmcosVersionId)
    WHERE CostElementId IN ( 4916 );

    -- Army CivPay; Overtime Pay; Avg Cost of Overtime Pay 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(@PayPlan, 'Ovrt', @AmcosVersionId)
    WHERE CostElementId IN ( 4917 );


    -- OMA; Training Costs; Training
    UPDATE #PayByLocationCosts
    SET CostAmount = @Training
    WHERE CostElementId IN ( 4922 );


    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance 
    UPDATE #PayByLocationCosts
    SET CostAmount = @PostRetHealthIns
    WHERE CostElementId IN ( 4924 );


    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance 
    UPDATE #PayByLocationCosts
    SET CostAmount = @PostRetLifeIns
    WHERE CostElementId IN ( 4923 );

    IF @Debug = 1
    BEGIN

        SELECT 'there should be no negative values';
        SELECT *
        FROM #PayByLocationCosts
        WHERE CostAmount < 0
        ORDER BY LocationName,
                 CategorySubgroupCode;
        SELECT 'full  pay cost table for insert';
        SELECT *
        FROM #PayByLocationCosts
        ORDER BY LocationName,
                 CategorySubgroupCode;
    END;

    IF @Debug = 0
    BEGIN
        --remove the old costs for this version and pay plan before inserting the new costs
        DELETE FROM crunch.Costs_NF
        WHERE AmcosVersionId = @AmcosVersionId;


        INSERT INTO crunch.Costs_NF
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
               Payband,
               CostAmount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId
        FROM #PayByLocationCosts
        WHERE CostAmount > 0;





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
    --    INNER JOIN #Pay_Inv AS b
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
    --    INNER JOIN #Pay_Inv AS b
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
    --    INNER JOIN #Pay_Inv AS b
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
    --    INNER JOIN #Pay_Inv AS b
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