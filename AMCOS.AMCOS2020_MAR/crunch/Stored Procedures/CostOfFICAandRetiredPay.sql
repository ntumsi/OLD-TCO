
-- =============================================
-- Author:Dan Hogan
-- Create date: 7/30/2019
-- Updated 8/3/2019 - added retired pay calculation
-- Description:	Cost of Military FICA and Retired Pay
-- Considerations: calculates the cost using singlevalue variables and the base pay cost elements
-- Updates
-- 8/6/2019 - removed the Medical part of FICA as that is a employee cost, not an employer cost, left it commented out for future reference should it ever be needed
-- =============================================
CREATE PROCEDURE [crunch].[CostOfFICAandRetiredPay]
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

    DECLARE @PercentSocialSecurity NUMERIC(26, 6)
        = crunch.GetSingleValue('AA', 'PercentSocialSecurity', @AmcosVersionId);
    DECLARE @PercentMedicare NUMERIC(26, 6) = crunch.GetSingleValue('AA', 'percentMedicare', @AmcosVersionId);
    DECLARE @Max_Wage_SSW NUMERIC(26, 6) = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);

    DROP TABLE IF EXISTS #WeightedBasePay;
    --base pay is weighted at the grade level and subgroup so we weight and roll it up to that level
    CREATE TABLE #WeightedBasePay
    (
        CostElementId INT NULL,
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        Pay NUMERIC(17, 2) NULL,
        SocialSecurity_amt NUMERIC(17, 2) NULL,
        Medicare_amt NUMERIC(17, 2) NULL,
        Total_FICA NUMERIC(17, 2) NULL,
        retiredpay NUMERIC(17, 2) NULL
    );

    INSERT INTO #WeightedBasePay
    (
        CostElementId,
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        Pay
    )
    SELECT CostElementId,
           PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           Amount
    FROM data.Costs
    --get all the military base pay elements so we can quickly calculate
    WHERE AmcosVersionId = @AmcosVersionId
          AND CostElementId IN ( 1, 128, 204, 289, 359, 413, 453, 523, 577 );

    --Social security is capped so we need to account for that with this case statement
    UPDATE #WeightedBasePay
    SET SocialSecurity_amt = CASE
                                 WHEN Pay < @Max_Wage_SSW THEN
                                     Pay * @PercentSocialSecurity
                                 ELSE
                                     @Max_Wage_SSW * @PercentSocialSecurity
                             END;

    --medicare amount does not have a cap so that calculation is simple
    UPDATE #WeightedBasePay
    SET Medicare_amt = Pay * @PercentMedicare;

    --total is the SUM of the two
    UPDATE #WeightedBasePay
    SET Total_FICA = ISNULL(Medicare_amt, 0) + ISNULL(SocialSecurity_amt, 0);

    --calculate retired pay based on base pay
    DECLARE @Active_Retired_Pay_Accrual NUMERIC(26, 6)
        = crunch.GetSingleValue('AA', 'Retired_Pay_Accrual', @AmcosVersionId);
    DECLARE @NGR_Retired_Pay_Accrual NUMERIC(26, 6)
        = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual', @AmcosVersionId);
    UPDATE #WeightedBasePay
    SET retiredpay = Pay * @Active_Retired_Pay_Accrual
    WHERE PayPlan IN ( 'AO', 'AE', 'AWO' );

    UPDATE #WeightedBasePay
    SET retiredpay = Pay * @NGR_Retired_Pay_Accrual
    WHERE PayPlan IN ( 'RO', 'RE', 'RWO', 'NE', 'NO', 'NWO' );


    --show calculations up to this point if debug mode is on
    IF @Debug = 1
    BEGIN
        SELECT 'FICA and retired pay by pay amount';
        SELECT CostElementId,
               PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               Pay,
               SocialSecurity_amt,
               Medicare_amt,
               Total_FICA,
               retiredpay
        FROM #WeightedBasePay
        ORDER BY Pay;
        SELECT 'FICA and retired pay by pp/gl/grp/subgrp';
        SELECT CostElementId,
               PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               Pay,
               SocialSecurity_amt,
               Medicare_amt,
               Total_FICA,
               retiredpay
        FROM #WeightedBasePay
        ORDER BY PayPlan,
                 GradeLevel,
                 CategorySubgroupCode;

    END;

    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 151, 143 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 32, 8 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 225, 217 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 291, 290 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 361, 360 )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 415, 414 )
              AND AmcosVersionId = @AmcosVersionId;


        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 455, 454 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 525, 524 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 579, 578 )
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
            MHA,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               8,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               -1
        FROM #WeightedBasePay
        WHERE PayPlan = 'AE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               32,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
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
               290,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               291,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
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
               454,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'RE'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               455,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
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
            MHA,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               143,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               -1
        FROM #WeightedBasePay
        WHERE PayPlan = 'AO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               151,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
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
               524,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'RO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               525,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
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
               360,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               361,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
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
            MHA,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               217,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               -1
        FROM #WeightedBasePay
        WHERE PayPlan = 'AWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               225,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
               @CrunchTime,
               @AmcosVersionId,
               '-1',
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
               578,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'RWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               579,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
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
               414,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(Total_FICA, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NWO'
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               415,
               GradeType,
               GradeLevel,
               -1,
               ISNULL(retiredpay, 0),
               @CrunchTime,
               @AmcosVersionId
        FROM #WeightedBasePay
        WHERE PayPlan = 'NWO';


    END;
END;