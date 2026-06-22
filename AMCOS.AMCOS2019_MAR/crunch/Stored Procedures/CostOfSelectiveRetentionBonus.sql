
-- =============================================
-- Author:Dan Hogan
-- Create date: 8/24/2018
-- Description:	Selective Retention Bonus Calculation
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takes place
-- =============================================
CREATE PROCEDURE [crunch].[CostOfSelectiveRetentionBonus]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DECLARE @RRB AS NVARCHAR(50) = N'Regular Reenlistment Bonus'; --this is active only, reserve component receiving it is an anomoly
    DECLARE @SRB AS NVARCHAR(50) = N'Selective Reenlistment Bonus'; --this is active only, reserve component receiving it is an anomoly
    DECLARE @Sel_Res_PSEB AS NVARCHAR(50) = N'Sel Res Prior Service Enlistment Bonus'; -- this IS reserve component only
    DECLARE @Sel_Res_RB AS NVARCHAR(50) = N'Sel Res Reenlistment Bonus'; -- this is reserve component only
    DECLARE @SRB_Max AS FLOAT;


    DROP TABLE IF EXISTS crunch.TempDMDCPayProcessed;
    CREATE TABLE crunch.TempDMDCPayProcessed
    (
        PayType NVARCHAR(50) NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(4) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        avg_cost FLOAT NULL,
        AmcosVersionId INT NULL,
        avg_annual_pay FLOAT NULL,
        avg_annual_payments FLOAT NULL,
        pay_cap FLOAT NULL,
        capped_avg_mpa_pay FLOAT NULL
    );

    INSERT INTO crunch.TempDMDCPayProcessed
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
    FROM crunch.DMDCPayProcessed
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

    DROP TABLE IF EXISTS crunch.TempMilitarySRBCaps;
    CREATE TABLE crunch.TempMilitarySRBCaps
    (
        [MOS] NVARCHAR(3) NOT NULL,
        [GradeLevel] NVARCHAR(2) NOT NULL,
        [Tier] INT NOT NULL,
        [AmcosVersionId] INT NOT NULL,
        [BonusCap] FLOAT NULL
    );

    INSERT INTO crunch.TempMilitarySRBCaps
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
    DECLARE @SRB_Kicker AS FLOAT = crunch.GetSingleValue('AE', 'SRB_Kicker');

    --the reserve component have a single cap set according to FMR Volume 7a Chapter 56
    DECLARE @Sel_Reenliste_Max AS FLOAT = crunch.GetSingleValue('RC', 'Sel_Reenliste_Max');

    --the reserve component have a single cap set according to FMR Volume 7a Chapter 56
    DECLARE @Sel_PriosService_Max AS FLOAT = crunch.GetSingleValue('RC', 'Sel_PriosService_Max');

    --bring in the pay cap from the MILPERS message (published by HRC usually quarterly, but not less than annually)
    UPDATE crunch.TempDMDCPayProcessed
    SET pay_cap = b.BonusCap
    FROM crunch.TempDMDCPayProcessed AS a
        INNER JOIN crunch.TempMilitarySRBCaps AS b
            ON a.CategorySubgroupCode = b.MOS
               AND a.GradeLevel = b.GradeLevel
               --pay caps right now only apply to SRB so make sure we only include them for that pay type
               AND a.PayType = @SRB
               AND a.PayPlan = 'AE';

    --update the pay caps above zero to account for the kicker
    UPDATE crunch.TempDMDCPayProcessed
    SET pay_cap = pay_cap + @SRB_Kicker
    FROM crunch.TempDMDCPayProcessed AS a
    WHERE PayType = @SRB
          AND pay_cap > 0
          AND PayPlan = 'AE';


    --bring in the reserve pay caps
    UPDATE crunch.TempDMDCPayProcessed
    SET pay_cap = @Sel_Reenliste_Max
    FROM crunch.TempDMDCPayProcessed AS a
    WHERE PayType = @Sel_Res_RB;

    UPDATE crunch.TempDMDCPayProcessed
    SET pay_cap = @Sel_PriosService_Max
    FROM crunch.TempDMDCPayProcessed AS a
    WHERE PayType = @Sel_Res_PSEB;


    --populate the capped pay column
    UPDATE crunch.TempDMDCPayProcessed
    SET capped_avg_mpa_pay = avg_annual_pay;


    --implement pay caps
    UPDATE crunch.TempDMDCPayProcessed
    SET capped_avg_mpa_pay = pay_cap * avg_annual_payments
    WHERE avg_annual_pay > (pay_cap * avg_annual_payments);


    --one final calculation for those over the total cap
    UPDATE crunch.TempDMDCPayProcessed
    SET capped_avg_mpa_pay = @SRB_Max * avg_annual_payments
    WHERE avg_annual_pay > (@SRB_Max * avg_annual_payments)
          AND PayType = @SRB;

    --bring in inventory
    DROP TABLE IF EXISTS crunch.TempSRBPay;
    CREATE TABLE crunch.TempSRBPay
    (
        [PayPlan] NVARCHAR(3) NOT NULL,
        [CategoryGroupCode] NVARCHAR(4) NOT NULL,
        [CategorySubGroupCode] NVARCHAR(4) NOT NULL,
        [GradeType] NVARCHAR(3) NOT NULL,
        [GradeLevel] TINYINT NOT NULL,
        [Inventory] INT NOT NULL,
        [CGLAInventory] INT NOT NULL,
        [avg_annual_pay] FLOAT NOT NULL,
        [pay_cap] FLOAT NOT NULL,
        [CGLA_MPA_Pay] FLOAT NOT NULL
    );

    INSERT INTO crunch.TempSRBPay
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubGroupCode,
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
           CategorySubGroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS Inventory,
           0 AS CGLAInventory, --this is all the inventory at and above the pp, GL, AOC for bonus amounts
           0.0 AS avg_annual_pay,
           0.0 AS pay_cap,
           0.0 AS CGLA_MPA_Pay
    FROM data.Inventory
    WHERE GradeType IN ( 'E' )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubGroupCode,
             GradeType,
             GradeLevel;

    --generate CGLA inventory
    --compute my CGLA inventory
    --cgla is the cummulative inventory at or above any one PayPlan & subgroup combination
    --it is later used to average bonus costs across later grades
    UPDATE crunch.TempSRBPay
    SET CGLAInventory = b.rev_cumulative
    FROM crunch.TempSRBPay AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Averaging (CGLA)
            SELECT PayPlan,
                   CategorySubGroupCode,
                   GradeType,
                   GradeLevel,
                   Inventory,
                   SUM(Inventory) OVER (PARTITION BY PayPlan,
                                                     CategorySubGroupCode
                                        ORDER BY PayPlan,
                                                 CategorySubGroupCode,
                                                 GradeLevel DESC
                                       --)  AS rev_cumulative
                                       )
                   + crunch.GetParentInventoryRecursive(PayPlan, CategorySubGroupCode, GradeType, GradeLevel) AS rev_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubGroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS inventory
                FROM data.Inventory
                GROUP BY PayPlan,
                         CategorySubGroupCode,
                         GradeType,
                         GradeLevel
            ) AS A
            WHERE GradeType IN ( 'E' )
            GROUP BY PayPlan,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel,
                     inventory
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubGroupCode = B.CategorySubGroupCode
               AND A.GradeLevel = B.GradeLevel;

    ----bring in SRB payment amounts with caps
    UPDATE crunch.TempSRBPay
    SET avg_annual_pay = B.capped_avg_mpa_pay,
        pay_cap = B.pay_cap
    FROM crunch.TempSRBPay AS A
        INNER JOIN
        (
            --because we can have multiple entries within a category subgroup we need to calculate a sum before we run an update
            --so it isn't selectively applying updates based on whatever the sort order is
            SELECT PayPlan,
                   CategorySubgroupCode,
                   GradeLevel,
                   SUM(capped_avg_mpa_pay) AS capped_avg_mpa_pay,
                   MAX(pay_cap) AS pay_cap
            FROM crunch.TempDMDCPayProcessed
            GROUP BY PayPlan,
                     CategorySubgroupCode,
                     GradeLevel
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubGroupCode = B.CategorySubGroupCode
               AND A.GradeLevel = CONVERT(INT, B.GradeLevel);


    --because there can actually be more payments then inventory we need to do one final implementation of pay caps
    --if inventory * pay cap exceeds DMDC reported data we need to throttle it
    --individual cap check
    UPDATE crunch.TempSRBPay
    SET avg_annual_pay = pay_cap * Inventory
    WHERE avg_annual_pay > (pay_cap * Inventory);
    --total cap check
    UPDATE crunch.TempSRBPay
    SET avg_annual_pay = @SRB_Max * Inventory
    WHERE avg_annual_pay > (@SRB_Max * Inventory);
    --AND PayType=@SRB



    --execute the CGLA math to spread a bonus cost in one grade level across all later grade levels within that subgroup based on inventory
    UPDATE crunch.TempSRBPay
    SET CGLA_MPA_Pay = B.CGLA_Bonus
    FROM crunch.TempSRBPay AS A
        INNER JOIN
        (
            SELECT *,
                   SUM(avg_annual_pay / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                          CategorySubGroupCode
                                                             ORDER BY PayPlan,
                                                                      CategorySubGroupCode,
                                                                      GradeLevel ASC
                                                            )
                   + crunch.GetChildBonusRecursive(
                                                      PayPlan,
                                                      CategorySubGroupCode,
                                                      GradeType,
                                                      GradeLevel,
                                                      'RetentionBonus'
                                                  ) AS CGLA_Bonus
            FROM crunch.TempSRBPay
        ) AS B
            ON A.PayPlan = B.PayPlan
               AND A.CategorySubGroupCode = B.CategorySubGroupCode
               AND A.GradeLevel = B.GradeLevel;


    --this is a relic, leaving it in here just for reference as we finalize the SP
    IF @Debug = 1
    BEGIN
        SELECT MOS,
               GradeLevel,
               Tier,
               AmcosVersionId,
               BonusCap
        FROM crunch.TempMilitarySRBCaps;
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
        FROM crunch.TempDMDCPayProcessed
        ORDER BY capped_avg_mpa_pay DESC;

        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               Inventory,
               CGLAInventory,
               avg_annual_pay,
               pay_cap,
               CGLA_MPA_Pay
        FROM crunch.TempSRBPay
        ORDER BY CategorySubGroupCode,
                 PayPlan,
                 GradeLevel;
    END;


    IF @Debug = 0
    BEGIN

        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 3963, 3966 );

        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 342, 3964 );

        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 506, 3965 );

        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());

        --Insert average cost elements, we only have one APPN for each PayPlan
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               3966,
               GradeType,
               GradeLevel,
               -1,
               CGLA_MPA_Pay,
               @CrunchTime
        FROM crunch.TempSRBPay
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               342,
               GradeType,
               GradeLevel,
               -1,
               CGLA_MPA_Pay,
               @CrunchTime
        FROM crunch.TempSRBPay
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               506,
               GradeType,
               GradeLevel,
               -1,
               CGLA_MPA_Pay,
               @CrunchTime
        FROM crunch.TempSRBPay
        WHERE PayPlan = 'RE';

        --Insert actual cost elements, we only have one APPN for each PP
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               3963,
               GradeType,
               GradeLevel,
               -1,
               avg_annual_pay,
               @CrunchTime
        FROM crunch.TempSRBPay
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               3964,
               GradeType,
               GradeLevel,
               -1,
               avg_annual_pay,
               @CrunchTime
        FROM crunch.TempSRBPay
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
            CrunchTime
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               3965,
               GradeType,
               GradeLevel,
               -1,
               avg_annual_pay,
               @CrunchTime
        FROM crunch.TempSRBPay
        WHERE PayPlan = 'RE';
    END;

--this is  a relic, leaving it in here just for reference as we finalize this SP

--INSERT INTO dbo.PreCrunchCosts
--SELECT * 
--FROM
--(

--select 'proposed' as bin, PayPlan, cmf, CategorySubgroupCode, 'MPA' as 'appn', 'Selective Retention Bonus' as category, CONCAT('NEW Avg Cost of Selective Retention Bonus: ',PayType) as 'CostElementName', grade, GradeLevel , capped_avg_mpa_pay as amt from TempDMDCPayProcessed
--WHERE PayType IN (@RRB, @SRB) AND PayPlan = 'AE'
--UNION
--select 'proposed' as bin, PayPlan, cmf, CategorySubgroupCode, 'RPA' as 'appn', 'Selective Retention Bonus' as category, CONCAT('NEW Avg Cost of Selective Retention Bonus: ',PayType) as 'CostElementName', grade, GradeLevel , capped_avg_mpa_pay as amt from TempDMDCPayProcessed
--WHERE PayType IN (@Sel_Res_PSEB, @Sel_Res_RB) AND PayPlan='RE'
--UNION
--select 'proposed' as bin, PayPlan, cmf, CategorySubgroupCode, 'NGPA' as 'appn', 'Selective Retention Bonus' as category, CONCAT('NEW Avg Cost of Selective Retention Bonus: ',PayType) as 'CostElementName', grade, GradeLevel , capped_avg_mpa_pay as amt from TempDMDCPayProcessed
--WHERE PayType IN (@Sel_Res_PSEB, @Sel_Res_RB) AND PayPlan='NE'
--) AS a
END;