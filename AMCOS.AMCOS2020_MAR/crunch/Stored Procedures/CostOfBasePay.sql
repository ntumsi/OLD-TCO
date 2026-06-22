/*
-- Author:Dan Hogan
-- Create date: 7/30/2019
-- Description:	Cost of Military Base Pay
-- Considerations: calculates the annualized cost of both the active and NG/R base pay
*/
CREATE PROCEDURE [crunch].[CostOfBasePay]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    DROP TABLE IF EXISTS #BasePaywYOS;
    CREATE TABLE #BasePaywYOS
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel INT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        YOS INT NULL,
        Inventory INT NULL,
        Pay NUMERIC(18, 2) NULL,
        AmcosVersionId INT NULL,
    );

    INSERT INTO #BasePaywYOS
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        YOS,
        Inventory,
        AmcosVersionId
    )
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           YOS,
           SUM(Inventory) AS Inventory,
           AmcosVersionId
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode,
             YOS,
             AmcosVersionId;

    --bring in pay by YOS
    UPDATE #BasePaywYOS
    SET Pay = b.Rate
    FROM #BasePaywYOS AS a
        INNER JOIN PaySchedule.PaySchedule_Military AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.YOS = b.YOS
               AND b.AmcosVersionId = a.AmcosVersionId;

    --the pay is monthly (active) and by drills (monthly) for NG/R so we increase that to annual
    DECLARE @activedays AS INT = crunch.GetSingleValue('AA', 'activedays', @AmcosVersionId);
    DECLARE @MonthsInAyear AS INT = 12;
    DECLARE @DaysInAMonth AS INT = 30;
    UPDATE #BasePaywYOS
    SET Pay = Pay * @MonthsInAyear
    WHERE PayPlan IN ( 'AO', 'AE', 'AWO' );


    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN
        SELECT 'inventory pay as YOS level active only b4 NG/R comp';
        SELECT *
        FROM #BasePaywYOS
        WHERE PayPlan IN ( 'AO', 'AE', 'AWO' )
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;

    END;

    --NG/R you take the pay, annualize that for 12 months, then add in 2 weeks of active pay 
    UPDATE #BasePaywYOS
    SET Pay = (a.Pay * @MonthsInAyear) + (b.Rate * @activedays / @DaysInAMonth)
    FROM #BasePaywYOS AS a
        INNER JOIN PaySchedule.PaySchedule_Military AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
               AND a.YOS = b.YOS
               AND b.AmcosVersionId = a.AmcosVersionId
    WHERE a.PayPlan IN ( 'NO', 'NE', 'NWO', 'RE', 'RO', 'RWO' )
          AND b.PayPlan IN ( 'AE', 'AO', 'AWO' );

    DROP TABLE IF EXISTS #WeightedBasePay;
    --base pay is weighted at the grade level and subgroup so we weight and roll it up to that level
    CREATE TABLE #WeightedBasePay
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        Pay NUMERIC(18, 2) NULL,
    );

    INSERT INTO #WeightedBasePay
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        Pay
    )
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           SUM(Inventory * Pay) / SUM(Inventory)
    FROM #BasePaywYOS
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode;



    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN
        SELECT 'inventory pay as YOS level';
        SELECT *
        FROM #BasePaywYOS
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;

        SELECT 'weighted pay';
        SELECT *
        FROM #WeightedBasePay
        ORDER BY PayPlan,
                 CategorySubgroupCode,
                 GradeLevel;

    END;

    --we can't insert invalid subgroup data so delete them
    DELETE FROM #WeightedBasePay
    WHERE CategorySubgroupCode = 'ZZZZ';

    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 1 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 128 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 204 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 289 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 359 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 413 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 453 )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 523 )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 577 )
              AND AmcosVersionId = @AmcosVersionId;

        /* Insert average cost elements, note we calculate at the grade level but we need costs at the subgroup level
        so we join on inventory to bring in the subgroups */
        --AE
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
               1,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #WeightedBasePay
        WHERE PayPlan = 'AE';


        --NE
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
               289,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NE';

        --RE
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
               453,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'RE';

        --AO
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
               128,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #WeightedBasePay
        WHERE PayPlan = 'AO';

        --RO
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
               523,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'RO';

        --NO
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
               359,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NO';

        --AWO
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
               204,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #WeightedBasePay
        WHERE PayPlan = 'AWO';

        --RWO
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
               577,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'RWO';

        --NWO
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
               413,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NWO';

    END;
END;