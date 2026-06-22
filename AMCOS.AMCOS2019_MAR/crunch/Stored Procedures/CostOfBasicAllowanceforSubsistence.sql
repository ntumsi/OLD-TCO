-- =============================================
-- Author:Dan Hogan
-- Create date: 2/14/2019
-- Description:      Basic Allowance for Subsistence
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takes place
-- Dependencies: dmdc_pay_processed 
-- to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
-- =============================================
CREATE PROCEDURE [crunch].[CostOfBasicAllowanceforSubsistence]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;


    DROP TABLE IF EXISTS #DMDCBAS;
    CREATE TABLE #DMDCBAS
    (
        PayType NVARCHAR(50) NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        AmcosVersionId INT NULL,
        avg_annual_pay FLOAT NULL,
        avg_annual_payments FLOAT NULL,
    );

    INSERT INTO #DMDCBAS
    (
        PayType,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        AmcosVersionId,
        avg_annual_pay,
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

          AND PayType IN ( 'Basic Allowance for Subsistence', 'Family Supplement Subistence Allowance' );

    --This table aggregates the pay types and removes the subgrp detail
    --BAS is a cost whose value should be consistent across all subgrps despite what DMDC actuall says
    --This is the difference between actual cost accounting and the cost allocation methodology AMCOS strives for
    DROP TABLE IF EXISTS #DMDCBASGradeLevel;
    CREATE TABLE #DMDCBASGradeLevel
    (
        PayPlan NVARCHAR(3) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        AmcosVersionId INT NULL,
        avg_annual_pay FLOAT NULL,
        CostElementId INT NULL,
        Inventory INT NULL,
        adj_ratio FLOAT NULL,
        Cost FLOAT NULL
    );

    INSERT INTO #DMDCBASGradeLevel
    (
        PayPlan,
        GradeType,
        GradeLevel,
        AmcosVersionId,
        avg_annual_pay,
        Inventory,
        adj_ratio,
        Cost
    )
    SELECT PayPlan,
           GradeType,
           GradeLevel,
           AmcosVersionId,
           SUM(avg_annual_pay) AS pay,
           0 AS Inventory,
           1 AS adj_ratio,
           0.0 AS Cost
    FROM #DMDCBAS
    GROUP BY PayPlan,
             GradeType,
             GradeLevel,
             AmcosVersionId;

    UPDATE #DMDCBASGradeLevel
    SET Inventory = b.Inventory
    FROM #DMDCBASGradeLevel AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   SUM(Inventory) AS Inventory
            FROM data.Inventory
            WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
            GROUP BY PayPlan,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    --now get the budget data from the president's budget so we can compute a ratio
    DECLARE @BAS_AO_AWO_Amt AS FLOAT,
            @BAS_AE_Amt AS FLOAT,
            @AO_AWO_ratio AS FLOAT,
            @AE_ratio AS FLOAT;
    SET @BAS_AO_AWO_Amt =
    (
        SELECT Amount
        FROM crunch.ArmyBudgetSingleValues
        WHERE AmcosVersionId = @AmcosVersionId
              AND FY = 'Avg'
              AND Appropriation = 'MPA'
              AND ParameterName = 'BAS_Domestic_AO_AWO'
    );
    SET @BAS_AE_Amt =
    (
        SELECT Amount
        FROM crunch.ArmyBudgetSingleValues
        WHERE AmcosVersionId = @AmcosVersionId
              AND FY = 'Avg'
              AND Appropriation = 'MPA'
              AND ParameterName = 'BAS_Domestic_AE'
    );



    --compute the ratio
    SET @AO_AWO_ratio = @BAS_AO_AWO_Amt /
                        (
                            SELECT SUM(avg_annual_pay) FROM #DMDCBAS WHERE PayPlan IN ( 'AO', 'AWO' )
                        );
    SET @AE_ratio = @BAS_AE_Amt /
                    (
                        SELECT SUM(avg_annual_pay) FROM #DMDCBAS WHERE PayPlan IN ( 'AE' )
                    );

    --add the ratio to the table
    UPDATE #DMDCBASGradeLevel
    SET adj_ratio = @AO_AWO_ratio
    WHERE PayPlan IN ( 'AO', 'AWO' );
    UPDATE #DMDCBASGradeLevel
    SET adj_ratio = @AE_ratio
    WHERE PayPlan IN ( 'AE' );

    --compute the adjust_pay amount
    UPDATE #DMDCBASGradeLevel
    SET Cost = (avg_annual_pay * adj_ratio) / NULLIF(Inventory, 0);

    --set AO/AWO BAS
    --BAS for active is one fixed amount so the DMDC pay data and PB data is irrelevant
    UPDATE #DMDCBASGradeLevel
    SET Cost =
        (
            SELECT paramValue
            FROM dataload.SingleValues
            WHERE PayPlan = 'AA'
                  AND paramName = 'BAS_O_WO'
        )
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --at the time of writing this SP the R/NG DMDC data was all over the map and not reliable for BAS
    --therefore the R/NG legacy crunch methodology was applied to the new Active component methodolgy using the folowing
    --the assumption is that you take the annual cost, divide by 365 to get a daily rate and then multiple by the number of 
    -- active duty days which is assumed ot be 15 (2 weeks of drilling + 1 day)
    --Also, per Marsha 2/13/2019 our users expect to cost reserve soldiers, not AGRs or any full time folks so the legacy methodology holds true
    --instead of trying to use DMDC or President Budget Actuals
    DECLARE @daysinyear AS INT =
            (
                SELECT paramValue
                FROM dataload.SingleValues
                WHERE PayPlan = 'AA'
                      AND paramName = 'daysinyear'
            );
    DECLARE @activedays AS INT =
            (
                SELECT paramValue
                FROM dataload.SingleValues
                WHERE PayPlan = 'AA'
                      AND paramName = 'activedays'
            );

    UPDATE #DMDCBASGradeLevel
    SET Cost = b.Cost / @daysinyear * @activedays
    FROM #DMDCBASGradeLevel AS a
        INNER JOIN
        (
            SELECT *
            FROM #DMDCBASGradeLevel
            WHERE PayPlan IN ( 'AWO', 'AO', 'AE' )
        ) AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
    WHERE a.PayPlan NOT IN ( 'AO', 'AWO', 'AE' );

    --insert CE IDs
    UPDATE #DMDCBASGradeLevel
    SET CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                4
                            WHEN PayPlan = 'AO' THEN
                                131
                            WHEN PayPlan = 'AWO' THEN
                                207
                            WHEN PayPlan = 'RO' THEN
                                527
                            WHEN PayPlan = 'RE' THEN
                                457
                            WHEN PayPlan = 'RWO' THEN
                                581
                            WHEN PayPlan = 'NO' THEN
                                363
                            WHEN PayPlan = 'NE' THEN
                                293
                            WHEN PayPlan = 'NWO' THEN
                                417
                        END;

    --now that we have the costs for all PPs and GLs we need to apply that across all of the inventory
    DROP TABLE IF EXISTS #BASFinal;
    CREATE TABLE #BASFinal
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
    INSERT INTO #BASFinal
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

    /* now that we have inventory at the subgrp level we are ready to bring in are costs which are the same for everysubgrp within a PP and GL combination */
    UPDATE #BASFinal
    SET Cost = b.Cost,
        CostElementId = b.CostElementId
    FROM #BASFinal AS a
        LEFT OUTER JOIN #DMDCBASGradeLevel AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.GradeType = b.GradeType;

    IF @Debug = 1
    BEGIN
        SELECT 'AO/AWO BAS Budget';
        SELECT @BAS_AO_AWO_Amt;

        SELECT 'AE BAS Budget';
        SELECT @BAS_AE_Amt;

        SELECT 'BAS data from DMDC';
        SELECT PayType,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               AmcosVersionId,
               avg_annual_pay,
               avg_annual_payments
        FROM #DMDCBAS
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;

        SELECT 'Payplan & GL costs';
        SELECT PayPlan,
               GradeType,
               GradeLevel,
               AmcosVersionId,
               avg_annual_pay,
               CostElementId,
               Inventory,
               adj_ratio,
               Cost
        FROM #DMDCBASGradeLevel
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
        FROM #BASFinal
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
            FROM #BASFinal
            WHERE Costs_AE.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_AO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_AO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_AWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_AWO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_NE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_NE.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_NO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_NO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_NWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_NWO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_RE
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_RE.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_RO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_RO.CostElementId = CostElementId
        );

        DELETE FROM crunch.Costs_RWO
        WHERE EXISTS
        (
            SELECT CostElementId
            FROM #BASFinal
            WHERE Costs_RWO.CostElementId = CostElementId
        );

        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());

        --we already have the IDs in the table so we only need one insert for each pay plan
        INSERT INTO crunch.Costs_AE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'AE';

        INSERT INTO crunch.Costs_AO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'AO';

        INSERT INTO crunch.Costs_AWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'AWO';

        INSERT INTO crunch.Costs_NE
        (
            [PayPlan],
            CMF,
            MOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'NE';

        INSERT INTO crunch.Costs_NO
        (
            [PayPlan],
            CMF,
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'NO';

        INSERT INTO crunch.Costs_NWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'NWO';

        INSERT INTO crunch.Costs_RE
        (
            [PayPlan],
            CMF,
            MOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'RE';

        INSERT INTO crunch.Costs_RO
        (
            [PayPlan],
            CMF,
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'RO';

        INSERT INTO crunch.Costs_RWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
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
        FROM #BASFinal
        WHERE PayPlan = 'RWO';
    END;

END;