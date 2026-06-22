-- =============================================
-- Author:Dan Hogan
-- Create date: 2/12/2019
-- Description:      Basic Allowance for Housing
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takes place
-- Dependencies: dmdc_pay_processed , dmdc dependents, non locality BAH
-- to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
-- =============================================
CREATE PROCEDURE [crunch].[CostOfBasicAllowanceforHousing]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

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
        AverageAnnualPay FLOAT NULL,
        avg_annual_payments FLOAT NULL,
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
        avg_annual_payments
    )
    SELECT PayType,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           AmcosVersionId,
           avg_annual_pay,
           avg_annual_payments
    FROM crunch.DMDCPayProcessed
    WHERE AmcosVersionId = @AmcosVersionId
          --if there is no pay then don't worry about the row
          AND PayType IN ( 'Basic Allowance for Housing', 'Family Separation Housing BAH' );


    DROP TABLE IF EXISTS #DMDCDependents;
    CREATE TABLE #DMDCDependents
    (
        AmcosVersionId INT NULL,
        PayPlan NVARCHAR(50) NULL,
        GradeType NVARCHAR(50) NULL,
        GradeLevel NVARCHAR(50) NULL,
        TotalMembers INT NULL,
        MembersWithDependents INT NULL,
        MembersWithoutDependents INT NULL,
        NumberOfDependents INT NULL
    );
    INSERT INTO #DMDCDependents
    (
        AmcosVersionId,
        PayPlan,
        GradeType,
        GradeLevel,
        TotalMembers,
        MembersWithDependents,
        MembersWithoutDependents,
        NumberOfDependents
    )
    SELECT AmcosVersionId,
           PayPlan,
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
        AmcosVersionId INT NOT NULL,
        GradeType NVARCHAR(50) NOT NULL,
        GradeLevel NVARCHAR(50) NOT NULL,
        RatePartial NUMERIC(7, 2) NULL,
        RateWithoutDependents NUMERIC(7, 2) NULL,
        RateWithDependents NUMERIC(7, 2) NULL,
        RateDifferential NUMERIC(7, 2) NULL
    );

    INSERT INTO #NonLocalityBAHRates
    (
        AmcosVersionId,
        GradeType,
        GradeLevel,
        RatePartial,
        RateWithoutDependents,
        RateWithDependents,
        RateDifferential
    )
    SELECT AmcosVersionId,
           GradeType,
           GradeLevel,
           RatePartial,
           RateWithoutDependents,
           RateWithDependents,
           RateDifferential
    FROM dataload.NonLocalityBAHRates
    WHERE AmcosVersionId = @AmcosVersionId;

    --This table aggregates the pay types and removes the subgrp detail
    --BAH is a cost whose value should be consistent across all subgrps despite what DMDC actuall says
    --This is the difference between actual cost accounting and the cost allocation methodology AMCOS strives for
    DROP TABLE IF EXISTS #BAHGradeLevel;
    CREATE TABLE #BAHGradeLevel
    (
        PayPlan NVARCHAR(3) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        AmcosVersionId INT NULL,
        AverageAnnualPay FLOAT NULL,
        CostElementId INT NULL,
        inventory INT NULL,
        adj_ratio FLOAT NULL,
        cost FLOAT NULL
    );
    INSERT INTO #BAHGradeLevel
    (
        PayPlan,
        GradeType,
        GradeLevel,
        AmcosVersionId,
        inventory
    )
    SELECT PayPlan,
           GradeType,
           GradeLevel,
           @AmcosVersionId,
           SUM(Inventory) AS inventory
    FROM data.Inventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
    GROUP BY PayPlan,
             GradeType,
             GradeLevel;

    UPDATE #BAHGradeLevel
    SET AverageAnnualPay = b.totalpay
    FROM #BAHGradeLevel AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   AmcosVersionId,
                   SUM(AverageAnnualPay) AS totalpay
            FROM #DMDCBAH
            GROUP BY PayPlan,
                     GradeLevel,
                     AmcosVersionId
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;


    /* now get the budget data from the president's budget so we can compute a ratio */
    DECLARE @BAH_AO_AWO_Amt AS FLOAT
        = crunch.GetArmyBudgetSingleValue('BAH_Domestic_AO_AWO', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @BAH_AE_Amt AS FLOAT = crunch.GetArmyBudgetSingleValue('BAH_Domestic_AE', 'MPA', 'Avg', @AmcosVersionId);

    /* compute the ratio */
    DECLARE @AO_AWO_ratio AS FLOAT;
    SET @AO_AWO_ratio = @BAH_AO_AWO_Amt /
                        (
                            SELECT SUM(AverageAnnualPay) FROM #DMDCBAH WHERE PayPlan IN ( 'AO', 'AWO' )
                        );
    DECLARE @AE_ratio AS FLOAT;
    SET @AE_ratio = @BAH_AE_Amt /
                    (
                        SELECT SUM(AverageAnnualPay) FROM #DMDCBAH WHERE PayPlan IN ( 'AE' )
                    );

    --add the ratio to the table
    UPDATE #BAHGradeLevel
    SET adj_ratio = @AO_AWO_ratio
    WHERE PayPlan IN ( 'AO', 'AWO' );

    UPDATE #BAHGradeLevel
    SET adj_ratio = @AE_ratio
    WHERE PayPlan IN ( 'AE' );

    --compute the adjust_pay amount
    UPDATE #BAHGradeLevel
    SET cost = (AverageAnnualPay * adj_ratio) / NULLIF(inventory, 0);

    /* The DMDC data includes AGRs and other pay situations which muddy the water for our calculation of reserve BAH
	NG/R  get non-locality BAH which is BAH without locality adjustments so we need to compute NG/R differently
	 */

    UPDATE #BAHGradeLevel
    SET cost = b.BAH
    FROM #BAHGradeLevel AS a
        INNER JOIN
        (
            SELECT a.GradeType,
                   a.GradeLevel,
                   a.RateWithoutDependents,
                   a.RateWithDependents,
                   b.PayPlan,
                   b.MembersWithDependents,
                   b.MembersWithoutDependents,
                   b.TotalMembers,
                   CASE
                       --if there are no members then force some number, when writing this the only case was RO O9 (Chief Army Reserve which its not known why that is zero when the position is filled)
                       WHEN b.TotalMembers = 0 THEN
                           a.RateWithDependents
                       --else run the calcualtion as planned
                       ELSE
                           -- we calculate using a weighted average of those with and without dependents against the corresponding rate for each
                           a.RateWithDependents
                           * (ISNULL(CAST(b.MembersWithDependents AS FLOAT) / NULLIF(b.TotalMembers, 0), 0))
                           + (a.RateWithoutDependents
                              * (ISNULL(CAST(b.MembersWithoutDependents AS FLOAT) / NULLIF(b.TotalMembers, 0), 0))
                             )
                   END AS BAH
            FROM #NonLocalityBAHRates AS a
                INNER JOIN #DMDCDependents AS b
                    ON a.GradeType = b.GradeType
                       AND a.GradeLevel = b.GradeLevel
            WHERE b.PayPlan IN ( 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    --finally the rates added are for an entire month so we prorate them
    DECLARE @DaysInYear AS INT = crunch.GetSingleValue('AA', 'daysinyear');
    DECLARE @ActiveDutyDays AS INT = crunch.GetSingleValue('AA', 'activedays');

    UPDATE #BAHGradeLevel
    --upconvert monthly to yearly, the down convert to daily, then multiple by active duty days
    SET cost = cost * 12 / @DaysInYear * @ActiveDutyDays
    WHERE PayPlan NOT IN ( 'AO', 'AWO', 'AE' );


    /* insert CE IDs */
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
        Cost FLOAT NULL,
        AmcosVersionId INT NULL,
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
        Inventory,
        AmcosVersionId
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubGroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS Inventory,
           @AmcosVersionId
    FROM data.Inventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubGroupCode,
             GradeType,
             GradeLevel;

    /* Now that we have inventory at the category subgroup level we are ready to bring in are costs which are the same
	 for every category subgroup within a payplan and grade level combination */
    UPDATE #BAHFinal
    SET Cost = DMDCBAHGradeLevel.cost,
        CostElementId = DMDCBAHGradeLevel.CostElementId
    FROM #BAHFinal BAHFinal
        LEFT OUTER JOIN #BAHGradeLevel AS DMDCBAHGradeLevel
            ON BAHFinal.PayPlan = DMDCBAHGradeLevel.PayPlan
               AND BAHFinal.GradeLevel = DMDCBAHGradeLevel.GradeLevel
               AND BAHFinal.GradeType = DMDCBAHGradeLevel.GradeType;


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
               avg_annual_payments
        FROM #DMDCBAH
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;

        SELECT 'NG/R calculation table';
        SELECT a.GradeType,
               a.GradeLevel,
               a.[RateWithoutDependents],
               a.[RateWithDependents],
               b.PayPlan,
               b.MembersWithDependents,
               b.MembersWithoutDependents,
               b.TotalMembers,
               CASE
                   --if there are no members then force some number, when writing this the only case was RO O9 (Chief Army Reserve which its not known why that is zero when the position is filled)
                   WHEN b.TotalMembers = 0 THEN
                       a.RateWithDependents
                   --else run the calcualtion as planned
                   ELSE
                       -- we calculate using a weighted average of those with and without dependents against the corresponding rate for each
                       a.RateWithDependents
                       * (ISNULL(CAST(b.MembersWithDependents AS FLOAT) / NULLIF(b.TotalMembers, 0), 0))
                       + (a.RateWithoutDependents
                          * (ISNULL(CAST(b.MembersWithoutDependents AS FLOAT) / NULLIF(b.TotalMembers, 0), 0))
                         )
               END AS BAH
        FROM #NonLocalityBAHRates AS a
            INNER JOIN #DMDCDependents AS b
                ON a.GradeType = b.GradeType
                   AND a.GradeLevel = b.GradeLevel
        WHERE b.PayPlan IN ( 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' );

        SELECT 'Payplan & GL costs';
        SELECT PayPlan,
               GradeType,
               GradeLevel,
               AmcosVersionId,
               AverageAnnualPay,
               CostElementId,
               inventory,
               adj_ratio,
               cost
        FROM #BAHGradeLevel
        ORDER BY PayPlan,
                 GradeLevel;

        SELECT 'final table';
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               Cost,
               AmcosVersionId,
               Inventory,
               CostElementId
        FROM #BAHFinal
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;
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
        );

        DELETE FROM crunch.Costs_AO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_AO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_AWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_AWO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_NE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_NE.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_NO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_NO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_NWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_NWO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_RE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_RE.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_RO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_RO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_RWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BAHFinal
            WHERE Costs_RWO.CostElementId = CostElementId
        );

        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());

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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Cost,
               @CrunchTime
        FROM #BAHFinal
        WHERE PayPlan = 'RWO';
    END;

END;