
-- =============================================
-- Author:Dan Hogan
-- Create date: 11/6/2019
-- Description:	Cost of 1 Active Duty Day
-- Considerations: only calculates costs for variable CEs (all others are fixed):
--		Health Care (Medical Support Costs)
--		Base Pay
--		Subsistence
--		Housing
--		FICA
--		Retired Pay
--		Health Care (Other Benefits)
-- =============================================
CREATE PROCEDURE [crunch].[Crunch1ActiveDay]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;



    DROP TABLE IF EXISTS #BasePaywYOS;
    CREATE TABLE #BasePaywYOS
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        YoS INT NULL,
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
        YoS,
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
    WHERE PayPlan IN ( 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode,
             YOS,
             AmcosVersionId;

    --bring in pay by YoS
    UPDATE #BasePaywYOS
    SET Pay = b.Rate
    FROM #BasePaywYOS AS a
        INNER JOIN PaySchedule.PaySchedule_Military b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.YoS = b.YOS;

    DECLARE @DaysInAMonth AS INT = 30;

    UPDATE #BasePaywYOS
    SET Pay = (b.Rate / @DaysInAMonth)
    FROM #BasePaywYOS AS a
        INNER JOIN PaySchedule.PaySchedule_Military AS b
            ON a.GradeType = b.GradeType
               AND a.GradeLevel = b.GradeLevel
               AND a.YoS = b.YOS
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



    --days in a year, used in the inserts to apportion costs by a single day
    DECLARE @DaysinYr NUMERIC(12, 2) = 365.0;


    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN
        SELECT 'inventory pay as YOS level';
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               YoS,
               Inventory,
               Pay,
               AmcosVersionId
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
    IF @Debug = 0
    BEGIN


        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());


        /* Insert 1day costs */
        --####################  Base Pay   #####################

        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CostElementId IN ( 289, 359, 413, 453, 523, 577 )
              AND AmcosVersionId = @AmcosVersionId;


        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
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
               CASE PayPlan
                   WHEN 'NE' THEN
                       289
                   WHEN 'NO' THEN
                       359
                   WHEN 'NWO' THEN
                       413
                   WHEN 'RE' THEN
                       453
                   WHEN 'RO' THEN
                       523
                   WHEN 'RWO' THEN
                       577
                   ELSE
                       -1
               END,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Pay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay;




        --####################  Cost of Health Care   #####################

        --Cost of Medical Suport
        DECLARE @Amt_Active_medical NUMERIC(20, 2)
            = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member', @AmcosVersionId);

        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CostElementId IN ( 288, 358, 412, 452, 522, 576 )
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
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
               CASE PayPlan
                   WHEN 'NE' THEN
                       288
                   WHEN 'NO' THEN
                       358
                   WHEN 'NWO' THEN
                       412
                   WHEN 'RE' THEN
                       452
                   WHEN 'RO' THEN
                       522
                   WHEN 'RWO' THEN
                       576
                   ELSE
                       -1
               END,
               GradeType,
               GradeLevel,
               -1,
               @Amt_Active_medical / @DaysinYr,
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay;






        --####################  Cost of Basic Allowance for Non Locality BAH   #####################
        --se the basic allowance for BAH crunch for further details, we are just taking the value there and dividing by the # of active days
        DECLARE @activedays AS INT = crunch.GetSingleValue('AA', 'activedays', @AmcosVersionId);

        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CostElementId IN ( 292, 362, 416, 456, 526, 580 )
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CMF,
               MOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_NE
        WHERE CostElementId = 292
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               CMF,
               MOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_RE
        WHERE CostElementId = 456
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               CMF,
               AOC,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_NO
        WHERE CostElementId = 362
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               CMF,
               AOC,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_RO
        WHERE CostElementId = 526
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               Branch,
               WOMOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_NWO
        WHERE CostElementId = 416
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               Branch,
               WOMOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_RWO
        WHERE CostElementId = 580
              AND AmcosVersionId = @AmcosVersionId;





        --####################  Cost of Basic Allowance for Subsistence   #####################
        --see the basic allowance for subsistence crunch for further details, we are just taking the value there and dividing by the # of active days


        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CostElementId IN ( 293, 363, 417, 457, 527, 581 )
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CMF,
               MOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_NE
        WHERE CostElementId = 293
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               CMF,
               MOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_RE
        WHERE CostElementId = 457
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               CMF,
               AOC,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_NO
        WHERE CostElementId = 363
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               CMF,
               AOC,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_RO
        WHERE CostElementId = 527
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               Branch,
               WOMOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_NWO
        WHERE CostElementId = 417
              AND AmcosVersionId = @AmcosVersionId
        UNION
        SELECT PayPlan,
               Branch,
               WOMOS,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               Amount / @activedays,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_RWO
        WHERE CostElementId = 581
              AND AmcosVersionId = @AmcosVersionId;

        --####################  Cost of Health Care   #####################



        --Social Security percentage
        DECLARE @SS FLOAT = crunch.GetSingleValue('AA', 'PercentSocialSecurity', @AmcosVersionId);

        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CostElementId IN ( 290, 360, 414, 454, 524, 578 )
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
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
               CASE PayPlan
                   WHEN 'NE' THEN
                       290
                   WHEN 'NO' THEN
                       360
                   WHEN 'NWO' THEN
                       414
                   WHEN 'RE' THEN
                       454
                   WHEN 'RO' THEN
                       524
                   WHEN 'RWO' THEN
                       578
                   ELSE
                       -1
               END,
               GradeType,
               GradeLevel,
               -1,
               Pay * @SS,
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay;



        --####################  Cost of Retired Pay   #####################



        --calculate retired pay based on base pay
        DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual', @AmcosVersionId);


        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CostElementId IN ( 291, 361, 415, 455, 525, 579 )
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
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
               CASE PayPlan
                   WHEN 'NE' THEN
                       291
                   WHEN 'NO' THEN
                       361
                   WHEN 'NWO' THEN
                       415
                   WHEN 'RE' THEN
                       455
                   WHEN 'RO' THEN
                       525
                   WHEN 'RWO' THEN
                       579
                   ELSE
                       -1
               END,
               GradeType,
               GradeLevel,
               -1,
               Pay * @Retired_Pay_Accrual,
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay;



        --####################  Group Avgs   #####################




        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CategoryGroupCode <> '-1'
              AND CategorySubgroupCode = '-1'
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT a.PayPlan,
               a.CategoryGroupCode,
               '-1' AS CategorySubgroupCode,
               CostElementId,
               a.GradeType,
               a.GradeLevel,
               -1,
               SUM(Amount * b.Inventory) / SUM(b.Inventory),
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_1ActiveDay AS a
            LEFT OUTER JOIN data.KnownInventory AS b
                ON a.PayPlan = b.PayPlan
                   AND b.CategoryGroupCode = a.CategoryGroupCode
                   AND b.CategorySubgroupCode = a.CategorySubgroupCode
                   AND b.GradeLevel = a.GradeLevel
                   AND b.AmcosVersionId = a.AmcosVersionId
        WHERE @AmcosVersionId = a.AmcosVersionId
              AND a.CategorySubgroupCode <> '-1'
        GROUP BY a.PayPlan,
                 a.CategoryGroupCode,
                 CostElementId,
                 a.GradeType,
                 a.GradeLevel;

        --####################  PP Avgs   #####################




        DELETE FROM crunch.Costs_1ActiveDay
        WHERE CategoryGroupCode = '-1'
              AND CategorySubgroupCode = '-1'
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_1ActiveDay
        (
            PayPlan,
            CategoryGroupCode,
            CategorySubgroupCode,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        SELECT a.PayPlan,
               '-1' AS CategoryGroupCode,
               '-1' AS CategorySubgroupCode,
               CostElementId,
               a.GradeType,
               a.GradeLevel,
               -1,
               SUM(Amount * b.Inventory) / SUM(b.Inventory),
               @CrunchTime,
               @AmcosVersionId
        FROM crunch.Costs_1ActiveDay AS a
            LEFT OUTER JOIN data.KnownInventory b
                ON a.PayPlan = b.PayPlan
                   AND b.CategoryGroupCode = a.CategoryGroupCode
                   AND b.CategorySubgroupCode = a.CategorySubgroupCode
                   AND b.GradeLevel = a.GradeLevel
                   AND b.AmcosVersionId = a.AmcosVersionId
        WHERE @AmcosVersionId = a.AmcosVersionId
              AND a.CategorySubgroupCode <> '-1'
        GROUP BY a.PayPlan,
                 CostElementId,
                 a.GradeType,
                 a.GradeLevel;


    END;
END;