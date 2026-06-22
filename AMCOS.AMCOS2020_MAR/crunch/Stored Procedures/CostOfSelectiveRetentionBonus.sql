
-- =============================================
-- Author:Dan Hogan
-- Create date: 8/24/2018
-- Description:	Selective Retention Bonus Calculation
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takes place
-- =============================================
CREATE PROCEDURE [crunch].[CostOfSelectiveRetentionBonus]
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

    DECLARE @RRB AS NVARCHAR(50) = N'Regular Reenlistment Bonus'; --this is active only, reserve component receiving it is an anomoly
    DECLARE @SRB AS NVARCHAR(50) = N'Selective Reenlistment Bonus'; --this is active only, reserve component receiving it is an anomoly
    DECLARE @Sel_Res_PSEB AS NVARCHAR(50) = N'Sel Res Prior Service Enlistment Bonus'; -- this IS reserve component only
    DECLARE @Sel_Res_RB AS NVARCHAR(50) = N'Sel Res Reenlistment Bonus'; -- this is reserve component only
    DECLARE @SRB_Max AS NUMERIC(16, 2);


    TRUNCATE TABLE crunch_temp.DMDCPayProcessed;
    INSERT INTO crunch_temp.DMDCPayProcessed
    (
        PayType,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        avg_cost,
        AmcosVersionId,
        avg_annual_pay,
        avg_annual_payments,
        pay_cap,
        capped_avg_mpa_pay
    )
    SELECT PayType,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           avg_cost,
           AmcosVersionId,
           avg_annual_pay,
           avg_annual_payments,
           0.0 AS pay_cap,
           0.0 AS capped_avg_mpa_pay
    FROM crunch.PayProcessed
    WHERE AmcosVersionId = @AmcosVersionId
          --if there is no pay then don't worry about the row
          AND avg_cost > 0
          AND
          (
              (
                  PayType IN ( @RRB, @SRB )
                  AND PayPlan = 'AE'
              )
              OR
              (
                  PayType IN ( @Sel_Res_PSEB, @Sel_Res_RB )
                  AND PayPlan IN ( 'RE', 'NE' )
              )
          );

    TRUNCATE TABLE crunch_temp.MilitarySRBCaps;
    INSERT INTO crunch_temp.MilitarySRBCaps
    (
        MOS,
        GradeLevel,
        Tier,
        AmcosVersionId,
        BonusCap
    )
    SELECT MOS,
           GradeLevel,
           Tier,
           AmcosVersionId,
           BonusCap
    FROM dataload.MilitarySRBCaps
    WHERE AmcosVersionId = @AmcosVersionId;

    --in addition to the SRB caps there is a kicker allowed for reenlistments within 10-15 months of contractual ETS
    DECLARE @SRB_Kicker AS NUMERIC(16, 2) = crunch.GetSingleValue('AE', 'SRB_Kicker', @AmcosVersionId);

    --the reserve component have a single cap set according to FMR Volume 7a Chapter 56
    DECLARE @Sel_Reenliste_Max AS NUMERIC(16, 2) = crunch.GetSingleValue('RC', 'Sel_Reenliste_Max', @AmcosVersionId);

    --the reserve component have a single cap set according to FMR Volume 7a Chapter 56
    DECLARE @Sel_PriosService_Max AS NUMERIC(16, 2)
        = crunch.GetSingleValue('RC', 'Sel_PriosService_Max', @AmcosVersionId);

    --bring in the pay cap from the MILPERS message (published by HRC usually quarterly, but not less than annually)
    UPDATE crunch_temp.DMDCPayProcessed
    SET pay_cap = b.BonusCap
    FROM crunch_temp.DMDCPayProcessed AS a
        INNER JOIN crunch_temp.MilitarySRBCaps AS b
            ON a.CategorySubgroupCode = b.MOS
               AND a.GradeLevel = b.GradeLevel
               --pay caps right now only apply to SRB so make sure we only include them for that pay type
               AND a.PayType = @SRB
               AND a.PayPlan = 'AE';

    --update the pay caps above zero to account for the kicker
    UPDATE crunch_temp.DMDCPayProcessed
    SET pay_cap = pay_cap + @SRB_Kicker
    FROM crunch_temp.DMDCPayProcessed AS a
    WHERE PayType = @SRB
          AND pay_cap > 0
          AND PayPlan = 'AE';


    --bring in the reserve pay caps
    UPDATE crunch_temp.DMDCPayProcessed
    SET pay_cap = @Sel_Reenliste_Max
    FROM crunch_temp.DMDCPayProcessed AS a
    WHERE PayType = @Sel_Res_RB;

    UPDATE crunch_temp.DMDCPayProcessed
    SET pay_cap = @Sel_PriosService_Max
    FROM crunch_temp.DMDCPayProcessed AS a
    WHERE PayType = @Sel_Res_PSEB;


    --populate the capped pay column
    UPDATE crunch_temp.DMDCPayProcessed
    SET capped_avg_mpa_pay = avg_annual_pay;


    --implement pay caps
    UPDATE crunch_temp.DMDCPayProcessed
    SET capped_avg_mpa_pay = pay_cap * avg_annual_payments
    WHERE avg_annual_pay > (pay_cap * avg_annual_payments);


    --one final calculation for those over the total cap
    UPDATE crunch_temp.DMDCPayProcessed
    SET capped_avg_mpa_pay = @SRB_Max * avg_annual_payments
    WHERE avg_annual_pay > (@SRB_Max * avg_annual_payments)
          AND PayType = @SRB;

    --bring in inventory
    TRUNCATE TABLE crunch_temp.SRBPay;
    INSERT INTO crunch_temp.SRBPay
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        Inventory,
        CGLAInventory,
        avg_annual_pay,
        pay_cap,
        CGLA_MPA_Pay
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS Inventory,
           0 AS CGLAInventory, --this is all the inventory at and above the pp, GL, AOC for bonus amounts
           0.0 AS avg_annual_pay,
           0.0 AS pay_cap,
           0.0 AS CGLA_MPA_Pay
    FROM data.KnownInventory
    WHERE GradeType IN ( 'E' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             GradeType,
             GradeLevel;

    --generate CGLA inventory
    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one PayPlan & subgroup combination
    --it is later used to average bonus costs across later grades
    UPDATE crunch_temp.SRBPay
    SET CGLAInventory = b.rev_cumulative
    FROM crunch_temp.SRBPay AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Allocation (CGLA)
            SELECT PayPlan,
                   CategorySubgroupCode,
                   GradeType,
                   GradeLevel,
                   inventory,
                   SUM(inventory) OVER (PARTITION BY PayPlan,
                                                     CategorySubgroupCode
                                        ORDER BY PayPlan,
                                                 CategorySubgroupCode,
                                                 GradeLevel DESC
                                       --)  AS rev_cumulative
                                       ) + crunch.GetParentInventory(PayPlan, CategorySubgroupCode, @AmcosVersionId) AS rev_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubgroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                GROUP BY PayPlan,
                         CategorySubgroupCode,
                         GradeType,
                         GradeLevel
            ) AS a
            WHERE GradeType IN ( 'E' )
            GROUP BY PayPlan,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.GradeLevel = b.GradeLevel;

    ----bring in SRB payment amounts with caps
    UPDATE crunch_temp.SRBPay
    SET avg_annual_pay = b.capped_avg_mpa_pay,
        pay_cap = b.pay_cap
    FROM crunch_temp.SRBPay AS a
        INNER JOIN
        (
            --because we can have multiple entries within a category subgroup we need to calculate a sum before we run an update
            --so it isn't selectively applying updates based on whatever the sort order is
            SELECT PayPlan,
                   CategorySubgroupCode,
                   GradeLevel,
                   SUM(capped_avg_mpa_pay) AS capped_avg_mpa_pay,
                   MAX(pay_cap) AS pay_cap
            FROM crunch_temp.DMDCPayProcessed
            GROUP BY PayPlan,
                     CategorySubgroupCode,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.GradeLevel = CONVERT(INT, b.GradeLevel);


    --because there can actually be more payments then inventory we need to do one final implementation of pay caps
    --if inventory * pay cap exceeds DMDC reported data we need to throttle it
    --individual cap check
    UPDATE crunch_temp.SRBPay
    SET avg_annual_pay = pay_cap * Inventory
    WHERE avg_annual_pay > (pay_cap * Inventory);
    --total cap check
    UPDATE crunch_temp.SRBPay
    SET avg_annual_pay = @SRB_Max * Inventory
    WHERE avg_annual_pay > (@SRB_Max * Inventory);
    --AND PayType=@SRB



    --execute the CGLA math to spread a bonus cost in one grade level across all later grade levels within that subgroup based on inventory
    UPDATE crunch_temp.SRBPay
    SET CGLA_MPA_Pay = b.CGLA_Bonus
    FROM crunch_temp.SRBPay AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(avg_annual_pay / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                          CategorySubgroupCode
                                                             ORDER BY PayPlan,
                                                                      CategorySubgroupCode,
                                                                      GradeLevel ASC
                                                            )
                   + crunch.GetChildBonusRecursive(
                                                      PayPlan,
                                                      CategorySubgroupCode,
                                                      GradeType,
                                                      GradeLevel,
                                                      'RetentionBonus',
                                                      @AmcosVersionId
                                                  ) AS CGLA_Bonus
            FROM crunch_temp.SRBPay
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.GradeLevel = b.GradeLevel;


    --this is a relic, leaving it in here just for reference as we finalize the SP
    IF @Debug = 1
    BEGIN
        SELECT MOS,
               GradeLevel,
               Tier,
               AmcosVersionId,
               BonusCap
        FROM crunch_temp.MilitarySRBCaps;
        SELECT PayType,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               avg_cost,
               AmcosVersionId,
               avg_annual_pay,
               avg_annual_payments,
               pay_cap,
               capped_avg_mpa_pay
        FROM crunch_temp.DMDCPayProcessed
        ORDER BY capped_avg_mpa_pay DESC;

        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               Inventory,
               CGLAInventory,
               avg_annual_pay,
               pay_cap,
               CGLA_MPA_Pay
        FROM crunch_temp.SRBPay
        ORDER BY CategorySubgroupCode,
                 PayPlan,
                 GradeLevel;
    END;


    IF @Debug = 0
    BEGIN

        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 3963, 3966 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 342, 3964 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 506, 3965 )
              AND AmcosVersionId = @AmcosVersionId;

        --Insert average cost elements, we only have one APPN for each PayPlan
        --AE
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
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3966,
               GradeType,
               GradeLevel,
               -1,
               CGLA_MPA_Pay,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.SRBPay
        WHERE PayPlan = 'AE';

        --NE
        INSERT INTO crunch.Costs_NE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               342,
               GradeType,
               GradeLevel,
               -1,
               CGLA_MPA_Pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.SRBPay
        WHERE PayPlan = 'NE';

        --RE
        INSERT INTO crunch.Costs_RE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               506,
               GradeType,
               GradeLevel,
               -1,
               CGLA_MPA_Pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.SRBPay
        WHERE PayPlan = 'RE';

        --Insert actual cost elements, we only have one APPN for each PP
        --AE
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
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3963,
               GradeType,
               GradeLevel,
               -1,
               avg_annual_pay,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.SRBPay
        WHERE PayPlan = 'AE';
        --NE
        INSERT INTO crunch.Costs_NE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3964,
               GradeType,
               GradeLevel,
               -1,
               avg_annual_pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.SRBPay
        WHERE PayPlan = 'NE';
        --RE
        INSERT INTO crunch.Costs_RE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3965,
               GradeType,
               GradeLevel,
               -1,
               avg_annual_pay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.SRBPay
        WHERE PayPlan = 'RE';
    END;

END;