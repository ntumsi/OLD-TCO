-- Stored Procedure

/* =============================================
-- Author:Dan Hogan
-- Create date: 2/12/2019
-- Description: Basic Allowance for Housing & COLA
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory; is handled in that script, before the work here takes place
-- Dependencies: dmdc_pay_processed , dmdc dependents, non locality BAH
-- to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
--Update history
-- 7/23/2019 - add  BAH by MHA and COLA calculations
-- 8/3/2019 - add grp and subgrp level for BAH and COLA location
original thought was to just insert by grade level since the values are the same for all subgrps but that would cause undesired processsing complications
-- ============================================= */
CREATE PROCEDURE [crunch].[CostOfBasicAllowanceForHousingAndCola]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    DROP TABLE IF EXISTS #KnownInventoryByCategorySubgroup;
    CREATE TABLE #KnownInventoryByCategorySubgroup
    (
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        AmcosVersionId INT NULL,
    );
    INSERT INTO #KnownInventoryByCategorySubgroup
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        AmcosVersionId
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           AmcosVersionId
    FROM data.KnownInventory
    WHERE AmcosVersionId = @AmcosVersionId
          --if there is no pay then don't worry about the row
          AND PayPlan IN ( 'AE', 'AO', 'AWO' );

    DROP TABLE IF EXISTS #DMDCBAH;
    CREATE TABLE #DMDCBAH
    (
        PayType NVARCHAR(50) NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        AmcosVersionId INT NULL,
        AverageAnnualPay NUMERIC(16, 2) NULL,
        AverageAnnualPayments NUMERIC(16, 2) NULL,
        Inventory INT NULL
    );
    INSERT INTO #DMDCBAH
    (
        PayType,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        AmcosVersionId,
        AverageAnnualPay,
        AverageAnnualPayments,
        Inventory
    )
    SELECT b.PayType,
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.PayPlan,
           a.GradeLevel,
           a.AmcosVersionId,
           b.AverageAnnualPay,
           NULL,
           a.Inventory
    FROM
    (
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeLevel,
               AmcosVersionId,
               SUM(Inventory) AS Inventory
        FROM data.KnownInventory
        WHERE AmcosVersionId = @AmcosVersionId
              AND PayPlan IN
                  (
                      SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
                  )
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeLevel,
                 AmcosVersionId
    ) AS a
        LEFT OUTER JOIN
        (
            SELECT PayType,
                   PayPlan,
                   GradeLevel,
                   AVG(AverageAnnualPay) AS AverageAnnualPay
            FROM
            (
                SELECT PayType,
                       PayPlan,
                       GradeLevel,
                       AmcosVersionId,
                       AVG(TotalPayAmount / [Count]) * 12 AS AverageAnnualPay
                FROM DMDC.Pay
                WHERE PayType IN ( 'Basic Allowance for Housing','Non-Locality Basic Allowance for Housing' )
                      --3.9.2022 with the adjustment to using just the dmdc.pay average, if we add in the budget amount of fam sep housing
                      --then it will far exceed the PB amount for domestic bah so this now needs to be removed
                      --, 'Family Separation Housing BAH' ) 
                      AND AmcosVersionId IN
                          (
                              SELECT TOP (3)
                                     AmcosVersionId
                              FROM lookup.AMCOSVersion
                              WHERE AmcosVersionId >= @AmcosVersionId - 200
                              ORDER BY AmcosVersionId DESC
                          )
                GROUP BY PayType,
                         PayPlan,
                         GradeLevel,
                         AmcosVersionId
            ) AS a
            GROUP BY PayType,
                     PayPlan,
                     GradeLevel
        ) AS b
            ON b.PayPlan = a.PayPlan
               AND b.GradeLevel = a.GradeLevel;

    /*
    SELECT PayType,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           AmcosVersionId,
           AverageAnnualPay,
           AverageAnnualPayments
    FROM crunch.DMDCPayProcessed
    WHERE AmcosVersionId = @AmcosVersionId
          --if there is no pay then don't worry about the row
          AND PayType IN ( 'Basic Allowance for Housing', 'Family Separation Housing BAH' );
          */

    DROP TABLE IF EXISTS #DMDCDependents;
    CREATE TABLE #DMDCDependents
    (
        PayPlan NVARCHAR(50) NOT NULL,
        GradeType NVARCHAR(50) NOT NULL,
        GradeLevel NVARCHAR(50) NOT NULL,
        TotalMembers INT NULL,
        MembersWithDependents INT NULL,
        MembersWithoutDependents INT NULL,
        NumberOfDependents INT NULL
    );
    CREATE NONCLUSTERED INDEX idx_DMDCDependents
    ON #DMDCDependents (
                           PayPlan,
                           GradeType,
                           GradeLevel
                       );
    INSERT INTO #DMDCDependents
    (
        PayPlan,
        GradeType,
        GradeLevel,
        TotalMembers,
        MembersWithDependents,
        MembersWithoutDependents,
        NumberOfDependents
    )
    SELECT PayPlan,
           GradeType,
           GradeLevel,
           TotalMembers,
           MembersWithDependents,
           MembersWithoutDependents,
           NumberOfDependents
    FROM DMDC.MembersAndDependents
    WHERE AmcosVersionId = @AmcosVersionId;

    DROP TABLE IF EXISTS #NonLocalityBAHRates;
    CREATE TABLE #NonLocalityBAHRates
    (
        GradeType NVARCHAR(50) NOT NULL,
        GradeLevel NVARCHAR(50) NOT NULL,
        RatePartial NUMERIC(7, 2) NULL,
        RateWithoutDependents NUMERIC(7, 2) NULL,
        RateWithDependents NUMERIC(7, 2) NULL,
        RateDifferential NUMERIC(7, 2) NULL
    );
    CREATE NONCLUSTERED INDEX idx_NonLocalityBAHRates
    ON #NonLocalityBAHRates (
                                GradeType,
                                GradeLevel
                            );
    INSERT INTO #NonLocalityBAHRates
    (
        GradeType,
        GradeLevel,
        RatePartial,
        RateWithoutDependents,
        RateWithDependents,
        RateDifferential
    )
    SELECT GradeType,
           GradeLevel,
           RatePartial,
           RateWithoutDependents,
           RateWithDependents,
           RateDifferential
    FROM dataload.NonLocalityBAHRates
    WHERE AmcosVersionId = @AmcosVersionId;

    --This table aggregates the pay types and removes the subgrp detail
    --BAH is a cost whose value should be consistent across all subgrps despite what DMDC pay data says
    --This is the difference between actual cost accounting and the cost allocation methodology AMCOS strives for
    DROP TABLE IF EXISTS #BAHGradeLevel;
    CREATE TABLE #BAHGradeLevel
    (
        PayPlan NVARCHAR(3) NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        AverageAnnualPay NUMERIC(16, 2) NULL,
        CostElementId INT NULL,
        Inventory INT NULL,
        AmcosAdjustmentAmount NUMERIC(16, 2) NULL,
        Cost NUMERIC(16, 2) NULL
    );
    CREATE NONCLUSTERED INDEX idx_BAHGradeLevel
    ON #BAHGradeLevel (
                          PayPlan,
                          GradeType,
                          GradeLevel
                      );
    INSERT INTO #BAHGradeLevel
    (
        PayPlan,
        GradeType,
        GradeLevel,
        Inventory
    )
    SELECT PayPlan,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS Inventory
    FROM data.Inventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeType,
             GradeLevel;

    UPDATE #BAHGradeLevel
    SET AverageAnnualPay = b.AverageAnnualPay
    FROM #BAHGradeLevel AS a
        INNER JOIN #DMDCBAH AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    /* now get the budget data from the president's budget so we can compute a ratio */
    DECLARE @BAH_AO_AWO_Amt AS NUMERIC(16, 2)
        = crunch.GetArmyBudgetSingleValue('BAH_Domestic_AO_AWO', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @BAH_AE_Amt AS NUMERIC(16, 2)
        = crunch.GetArmyBudgetSingleValue('BAH_Domestic_AE', 'MPA', 'Avg', @AmcosVersionId);

    /* compute the ratio */
    DECLARE @AO_AWO_ratio AS NUMERIC(16, 2);
    SET @AO_AWO_ratio = @BAH_AO_AWO_Amt /
                        (
                            SELECT SUM(AverageAnnualPay * Inventory)
                            FROM #DMDCBAH
                            WHERE PayPlan IN ( 'AO', 'AWO' )
                        );
    DECLARE @AE_ratio AS NUMERIC(16, 2);
    SET @AE_ratio = @BAH_AE_Amt /
                    (
                        SELECT SUM(AverageAnnualPay * Inventory)
                        FROM #DMDCBAH
                        WHERE PayPlan IN ( 'AE' )
                    );

    --add the ratio to the table
    UPDATE #BAHGradeLevel
    SET AmcosAdjustmentAmount = @AO_AWO_ratio
    WHERE PayPlan IN ( 'AO', 'AWO' );

    UPDATE #BAHGradeLevel
    SET AmcosAdjustmentAmount = @AE_ratio
    WHERE PayPlan IN ( 'AE' );

    --compute the adjust_pay amount
    UPDATE #BAHGradeLevel
    SET Cost = AverageAnnualPay * AmcosAdjustmentAmount;

    --TODO: Why is this here? Was Dan troubleshooting an issue?
    --SELECT *
    --FROM #BAHGradeLevel
    --WHERE PayPlan = 'AE'
    --      AND GradeLevel = 8;

    /* The DMDC data includes AGRs and other pay situations which muddy the water for our calculation of reserve BAH
	ARNG and USAR get non-locality BAH which is BAH without locality adjustments so we need to compute NG/R differently
	 */
    UPDATE #BAHGradeLevel
    SET Cost = crunch.GetReserveComponentBAH(
                                                b.RateWithDependents,
                                                b.RateWithoutDependents,
                                                c.TotalMembers,
                                                c.MembersWithDependents,
                                                c.MembersWithoutDependents
                                            )
    FROM #BAHGradeLevel AS a
        LEFT OUTER JOIN #NonLocalityBAHRates AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
        LEFT OUTER JOIN #DMDCDependents AS c
            ON b.GradeType = c.GradeType
               AND c.GradeLevel = c.GradeLevel
               AND a.PayPlan = c.PayPlan
    WHERE a.PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' );

    --finally the rates added are for an entire month so we prorate them
    DECLARE @DaysInYear AS INT = crunch.GetSingleValue('AA', 'daysinyear', @AmcosVersionId);
    DECLARE @ActiveDutyDays AS INT = crunch.GetSingleValue('AA', 'activedays', @AmcosVersionId);

    UPDATE #BAHGradeLevel
    --upconvert monthly to yearly, the down convert to daily, then multiple by active duty days
    SET Cost = Cost * 12 / @DaysInYear * @ActiveDutyDays
    WHERE PayPlan NOT IN ( 'AE', 'AO', 'AWO' );

    /* insert cost element ids */
    UPDATE #BAHGradeLevel
    SET CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                2
                            WHEN PayPlan = 'AO' THEN
                                129
                            WHEN PayPlan = 'AWO' THEN
                                205
                            WHEN PayPlan = 'RO' THEN
                                526
                            WHEN PayPlan = 'RE' THEN
                                456
                            WHEN PayPlan = 'RWO' THEN
                                580
                            WHEN PayPlan = 'NO' THEN
                                362
                            WHEN PayPlan = 'NE' THEN
                                292
                            WHEN PayPlan = 'NWO' THEN
                                416
                            ELSE
                                -1
                        END;

    /* Now that we have the costs for all pay plans and grade levels we need to apply that across all of the inventory */
    DROP TABLE IF EXISTS #BAHFinal;
    CREATE TABLE #BAHFinal
    (
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        Cost NUMERIC(16, 2) NULL,
        Inventory INT NULL,
        CostElementId INT NULL,
    );
    INSERT INTO #BAHFinal
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        Inventory
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS Inventory
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             GradeType,
             GradeLevel;

    /* Now that we have inventory at the category subgroup level we are ready to bring in are costs which are the same
	 for every category subgroup within a payplan and grade level combination */
    UPDATE #BAHFinal
    SET Cost = b.Cost,
        CostElementId = b.CostElementId
    FROM #BAHFinal a
        LEFT OUTER JOIN #BAHGradeLevel AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.GradeType = b.GradeType;


    IF @Debug = 1
    BEGIN
        SELECT 'AO/AWO BAH Budget';
        SELECT @BAH_AO_AWO_Amt;

        SELECT 'AE BAH Budget';
        SELECT @BAH_AE_Amt;

        SELECT 'BAH data from DMDC';
        SELECT PayType,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               AmcosVersionId,
               AverageAnnualPay,
               AverageAnnualPayments
        FROM #DMDCBAH
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;

        SELECT 'ARNG/USAR Calculation table';
        SELECT a.GradeType,
               a.GradeLevel,
               a.[RateWithoutDependents],
               a.[RateWithDependents],
               b.PayPlan,
               b.MembersWithDependents,
               b.MembersWithoutDependents,
               b.TotalMembers,
               crunch.GetReserveComponentBAH(
                                                a.RateWithDependents,
                                                a.RateWithoutDependents,
                                                b.TotalMembers,
                                                b.MembersWithDependents,
                                                b.MembersWithoutDependents
                                            ) AS BAH
        FROM #NonLocalityBAHRates AS a
            INNER JOIN #DMDCDependents AS b
                ON a.GradeType = b.GradeType
                   AND a.GradeLevel = b.GradeLevel
        WHERE b.PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' );

        SELECT 'PayPlan & GradeLevel costs';
        SELECT PayPlan,
               GradeType,
               GradeLevel,
               AverageAnnualPay,
               CostElementId,
               Inventory,
               AmcosAdjustmentAmount,
               Cost
        FROM #BAHGradeLevel
        ORDER BY PayPlan,
                 GradeLevel;

        SELECT 'Final table';
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               Cost,
               Inventory,
               CostElementId
        FROM #BAHFinal
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;
    END;

    /* BAH by Location and dependent status calculation */
    DROP TABLE IF EXISTS #BAHByLocationAndDependentStatus;
    CREATE TABLE #BAHByLocationAndDependentStatus
    (
        MHA NVARCHAR(5) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        withdependents INT NULL,
        DependentStatus NVARCHAR(15) NULL,
        numWithDependents INT NULL,
        numWithoutDependents INT NULL,
        BAHAmount NUMERIC(16, 2) NULL,
        COLABase NUMERIC(16, 2) NULL,
        COLAIndex NUMERIC(16, 2) NULL,
        COLAAmount NUMERIC(16, 2) NULL,
        AmcosVersionId INT NULL,
    );
    INSERT INTO #BAHByLocationAndDependentStatus
    (
        MHA,
        GradeType,
        GradeLevel,
        withdependents,
        DependentStatus,
        numWithDependents,
        numWithoutDependents,
        BAHAmount,
        COLAAmount,
        AmcosVersionId
    )
    SELECT MHA,
           GradeType,
           GradeLevel,
           WithDependents,
           '' AS DependentStatus,
           '' AS numWithDependents,
           '' AS numWithoutDependents,
           Amount * 12 AS BAHAmount, --make them annual
           0.0 AS COLAAmount,
           AmcosVersionId
    FROM dataload.BAHRates
    WHERE AmcosVersionId = @AmcosVersionId
    UNION
    --this part of the union creates a duplicate we will use for the average cost of dependents
    SELECT MHA,
           GradeType,
           GradeLevel,
           99,
           '' AS DependentStatus,
           '' AS numWithDependents,
           '' AS numWithoutDependents,
           0 AS BAHAmount,
           0.0 AS COLAAmount,
           AmcosVersionId
    FROM dataload.BAHRates
    WHERE AmcosVersionId = @AmcosVersionId
          AND WithDependents = 1;

    --bring in the dependent data
    UPDATE #BAHByLocationAndDependentStatus
    SET numWithDependents = b.MembersWithDependents,
        numWithoutDependents = b.MembersWithoutDependents
    FROM #BAHByLocationAndDependentStatus AS a
        INNER JOIN #DMDCDependents AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
    WHERE b.PayPlan IN ( 'AE', 'AO', 'AWO' ) --this is needed because there is no BAH location calculation for ARNG/USAR components
          AND a.withdependents = 99; --we only need dependent information for our average calculation

    --compute BAH weighted average
    UPDATE #BAHByLocationAndDependentStatus
    SET BAHAmount = (a.numWithDependents * b.[1] + a.numWithoutDependents * b.[0])
                    / (a.numWithDependents + a.numWithoutDependents)
    FROM #BAHByLocationAndDependentStatus AS a
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   MHA,
                   [0],
                   [1]
            FROM
            (SELECT * FROM #BAHByLocationAndDependentStatus) AS a
            PIVOT
            (
                MAX(BAHAmount)
                FOR withdependents IN ([0], [1])
            ) AS pivottable
        ) AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
               AND a.MHA = b.MHA
    WHERE a.withdependents = 99;

    -- generate average costs for all lcoations based on the budget
    DECLARE @AE_CONUSCOLA_avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('AE_Bdgt_CONUS_COLA', 'MPA', 'Avg', @AmcosVersionId) /
          (
              SELECT SUM(Inventory)
              FROM data.Inventory
              WHERE AmcosVersionId = @AmcosVersionId
                    AND PayPlan = 'AE'
          );
    -- we use all inventory, not just known inventory, since this is a pay plan average and so unknown inventory is worth including 

    DECLARE @AO_AWO_CONUSCOLA_avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('AO_AWO_Bdgt_CONUS_COLA', 'MPA', 'Avg', @AmcosVersionId) /
          (
              SELECT SUM(Inventory)
              FROM data.Inventory
              WHERE AmcosVersionId = @AmcosVersionId
                    AND PayPlan IN ( 'AO', 'AWO' )
          );

    --COLA base is by YoS but AMCOS wants to display by Gradelevel so we create a weighted calculation
    DROP TABLE IF EXISTS #WeightedCOLA;
    CREATE TABLE #WeightedCOLA
    (
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        WithDependents INT NULL,
        WeightedAmount NUMERIC(16, 2) NULL,
        AmcosVersionId INT NULL,
    );
    INSERT INTO #WeightedCOLA
    (
        GradeType,
        GradeLevel,
        WithDependents,
        WeightedAmount,
        AmcosVersionId
    )
    SELECT GradeType,
           GradeLevel,
           WithDependents,
           SUM((Amount * Inventory)) / SUM(Inventory) AS WeightedAmount,
           AmcosVersionId
    FROM
    (
        SELECT a.*,
               b.Inventory
        FROM dataload.ConusCola AS a
            INNER JOIN
            (
                SELECT GradeType,
                       GradeLevel,
                       ModifiedYearsOfService,
                       SUM(Inventory) AS Inventory
                FROM
                (
                    --compute the round up approach because COLA data is only by even YOS
                    SELECT GradeType,
                           GradeLevel,
                           CASE
                               WHEN YOS < 2 THEN
                                   0 -- less than 2 yos equates to 0 yos for cola
                               WHEN YOS = 3 THEN
                                   3 -- 3 yos is the only odd year provided so we call that out
                               WHEN YOS % 2 = 1 THEN --the number is odd so subtract one since cola data comes in mostly as evens so we need to round down
                                   YOS - 1
                               ELSE --all others are even and return their original value 
                                   YOS
                           END AS ModifiedYearsOfService,
                           YOS,
                           Inventory AS Inventory
                    FROM data.KnownInventory
                    WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
                          AND AmcosVersionId = @AmcosVersionId --filter out unknown YoS
                ) AS a
                GROUP BY GradeType,
                         GradeLevel,
                         ModifiedYearsOfService
            ) AS b
                ON a.GradeType = b.GradeType
                   AND a.GradeLevel = b.GradeLevel
                   AND a.YOS = b.ModifiedYearsOfService
    ) AS a
    GROUP BY GradeType,
             GradeLevel,
             WithDependents,
             AmcosVersionId;

    --## bring in COLA base
    UPDATE #BAHByLocationAndDependentStatus
    SET COLABase = (a.numWithDependents * b.[1] + a.numWithoutDependents * b.[0])
                   / (a.numWithDependents + a.numWithoutDependents)
    FROM #BAHByLocationAndDependentStatus AS a
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   [0],
                   [1]
            FROM
            (SELECT * FROM #WeightedCOLA) AS a
            PIVOT
            (
                MAX(WeightedAmount)
                FOR WithDependents IN ([0], [1])
            ) AS pivottable
        ) AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
    WHERE a.withdependents = 99;

    --bring in weighted COLA based on w/ w/o dependants
    UPDATE #BAHByLocationAndDependentStatus
    SET COLABase = b.WeightedAmount
    FROM #BAHByLocationAndDependentStatus AS a
        INNER JOIN #WeightedCOLA AS b
            ON a.GradeLevel = b.GradeLevel
               AND a.GradeType = b.GradeType
               AND a.withdependents = b.WithDependents;

    --bring in COLA index 
    UPDATE #BAHByLocationAndDependentStatus
    SET COLAIndex = b.DutyStationIndex
    FROM #BAHByLocationAndDependentStatus AS a
        LEFT OUTER JOIN
        (
            SELECT MHA,
                   DutyStationIndex,
                   AmcosVersionId
            FROM
            (
                SELECT a.*,
                       b.MHA
                FROM dataload.ConusColaLocations AS a
                    INNER JOIN xwalk.ZIPToMHA AS b
                        ON a.ZIPCode = b.ZIPCode
                           AND a.AmcosVersionId = b.AmcosVersionId
                WHERE a.AmcosVersionId = @AmcosVersionId
            ) AS a
            GROUP BY MHA,
                     DutyStationIndex,
                     AmcosVersionId
        ) AS b
            ON b.MHA = a.MHA;

    --compute COLA amount, we multiply by 12 because the data is monthly and we need annual
    UPDATE #BAHByLocationAndDependentStatus
    SET COLAAmount = ISNULL(COLABase * COLAIndex * 12, 0);
    --note that in the above when there is a base but no index that means that MHA does not get cola and thus it is not calculated

    /* Update the dependent nomenclatures to prepare them for direct insert into the cost table later */
    UPDATE #BAHByLocationAndDependentStatus
    SET DependentStatus = 'with'
    WHERE withdependents = 1;

    UPDATE #BAHByLocationAndDependentStatus
    SET DependentStatus = 'without'
    WHERE withdependents = 0;

    UPDATE #BAHByLocationAndDependentStatus
    SET DependentStatus = 'average'
    WHERE withdependents = 99;



    --to do an eventual insert we need subgroup data
    DROP TABLE IF EXISTS #BAHLocDepbySubgroup;
    CREATE TABLE #BAHLocDepbySubgroup
    (
        MHA NVARCHAR(5) NULL,
        LocationId INT NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        WithDependents INT NULL,
        DependentStatus NVARCHAR(15) NULL,
        numWithDependents INT NULL,
        numWithoutDependents INT NULL,
        BAHAmount NUMERIC(16, 2) NULL,
        COLABase NUMERIC(16, 2) NULL,
        COLAIndex NUMERIC(16, 2) NULL,
        COLAAmount NUMERIC(16, 2) NULL,
        AmcosVersionId INT NULL,
    );
    INSERT INTO #BAHLocDepbySubgroup
    (
        MHA,
        LocationId,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        WithDependents,
        DependentStatus,
        numWithDependents,
        numWithoutDependents,
        BAHAmount,
        COLABase,
        COLAIndex,
        COLAAmount,
        AmcosVersionId
    )
    SELECT b.MHA,
           l.LocationId,
           i.PayPlan,
           i.CategoryGroupCode,
           i.CategorySubgroupCode,
           i.GradeType,
           i.GradeLevel,
           b.withdependents,
           b.DependentStatus,
           b.numWithDependents,
           b.numWithoutDependents,
           b.BAHAmount,
           b.COLABase,
           b.COLAIndex,
           b.COLAAmount,
           b.AmcosVersionId
    FROM #KnownInventoryByCategorySubgroup AS i
        INNER JOIN #BAHByLocationAndDependentStatus AS b
            ON i.GradeType = b.GradeType
               AND i.GradeLevel = b.GradeLevel
        LEFT OUTER JOIN warehouse.Location l
            ON b.MHA = l.SourceSystemCode;

    IF @Debug = 1
    BEGIN

        SELECT 'Weighted COLA calculation';
        SELECT *
        FROM #WeightedCOLA;

        SELECT 'BAH and COLA';
        SELECT *
        FROM #BAHByLocationAndDependentStatus;

        SELECT 'BAH and COLA by categorysubgroup';
        SELECT TOP 1000
               *
        FROM #BAHLocDepbySubgroup
        WHERE LocationId IS NULL;

        SELECT 'BAH Final';
        SELECT TOP 1000
               *
        FROM #BAHByLocationAndDependentStatus;
    END;


    IF EXISTS (SELECT * FROM #BAHFinal WHERE Cost IS NULL)
    BEGIN
        SELECT *
        FROM #BAHFinal
        WHERE Cost IS NULL;
        RAISERROR('null values not allowed, check output', 18, 1);
        RETURN;
    END;


    IF @Debug = 0
    BEGIN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.Costs_AE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_AE.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_AO.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_AWO.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_NE.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_NO.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_NWO.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_RE.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_RO.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_RWO.CostElementId = CostElementId
        )
              AND AmcosVersionId = @AmcosVersionId;

        --delete the COLA CE IDs, BAH data to include MHA specific locations would have been already deleted by the above code
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 4212 )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 4213 )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 4214 )
              AND AmcosVersionId = @AmcosVersionId;

        --we already have the CostElementIds in the table so we only need one insert for each pay plan
        INSERT INTO crunch.Costs_AE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #BAHFinal
        WHERE PayPlan = 'AE';

        INSERT INTO crunch.Costs_AO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #BAHFinal
        WHERE PayPlan = 'AO';

        INSERT INTO crunch.Costs_AWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #BAHFinal
        WHERE PayPlan = 'AWO';

        INSERT INTO crunch.Costs_NE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHFinal
        WHERE PayPlan = 'NE';

        INSERT INTO crunch.Costs_NO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHFinal
        WHERE PayPlan = 'NO';

        INSERT INTO crunch.Costs_NWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHFinal
        WHERE PayPlan = 'NWO';

        INSERT INTO crunch.Costs_RE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHFinal
        WHERE PayPlan = 'RE';

        INSERT INTO crunch.Costs_RO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHFinal
        WHERE PayPlan = 'RO';

        INSERT INTO crunch.Costs_RWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHFinal
        WHERE PayPlan = 'RWO';



        --BEGIN LOCATION BASED INSERTS FOR MHA AND COLA
        --AE
        INSERT INTO crunch.Costs_AE
        (
            PayPlan,
            CostElementId,
            CMF,
            MOS,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            MHA,
            LocationId,
            DependentStatus,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               2, --BAH
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               BAHAmount,
               MHA,
               LocationId,
               DependentStatus,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               4212, --COLA
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               COLAAmount,
               MHA,
               LocationId,
               DependentStatus,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup
        WHERE PayPlan = 'AE'
              AND ISNULL(COLAAmount, 0) > 0
        UNION
        -- avg cola non-location specific
        SELECT PayPlan,
               4212, --COLA
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               @AE_CONUSCOLA_avg,
               '-1',
               -1,
               '-1',
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup AS a
        WHERE PayPlan = 'AE';

        --AO
        INSERT INTO crunch.Costs_AO
        (
            PayPlan,
            CostElementId,
            CMF,
            AOC,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            MHA,
            LocationId,
            DependentStatus,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               129, --BAH
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               BAHAmount,
               MHA,
               LocationId,
               DependentStatus,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               4213, --COLA
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               COLAAmount,
               MHA,
               LocationId,
               DependentStatus,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup
        WHERE PayPlan = 'AO'
              AND ISNULL(COLAAmount, 0) > 0
        UNION
        -- avg cola non-location specifi
        SELECT PayPlan,
               4213, --COLA
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_CONUSCOLA_avg,
               '-1',
               -1,
               '-1',
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup AS a
        WHERE PayPlan = 'AO';



        /* AWO */
        INSERT INTO crunch.Costs_AWO
        (
            PayPlan,
            CostElementId,
            Branch,
            WOMOS,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            MHA,
            LocationId,
            DependentStatus,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               205, --BAH
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               BAHAmount,
               MHA,
               LocationId,
               DependentStatus,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               4214, --COLA
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               COLAAmount,
               MHA,
               LocationId,
               DependentStatus,
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup
        WHERE PayPlan = 'AWO'
              AND ISNULL(COLAAmount, 0) > 0
        UNION
        -- location unspecific cola avg
        SELECT PayPlan,
               4214, --COLA
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               -1,
               @AO_AWO_CONUSCOLA_avg,
               '-1',
               -1,
               '-1',
               @CrunchTime,
               @AmcosVersionId
        FROM #BAHLocDepbySubgroup AS a
        WHERE PayPlan = 'AWO';
    END;

END;
GO
