
-- =============================================
-- Author:Dan Hogan
-- Create date: 10/16/2018
-- Description:	Recruiting & Enlistment Bonus Calculation
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary subgrp conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takesplace
-- Dependencies
--      - Single Values
--      - data.inventory
--      - 
-- Input:
--		- to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
-- =============================================
CREATE PROCEDURE [crunch].[CostOfRecruiting]
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

    DECLARE @REB_Max AS NUMERIC(18, 2);
    DECLARE @AEB_Max AS NUMERIC(18, 2);

    -- =============================================
    --Set up the recruiting cost table by bringing in inventory
    -- =============================================
    TRUNCATE TABLE crunch_temp.CostOfRecruiting;

    INSERT INTO crunch_temp.CostOfRecruiting
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubGroupCode,
        GradeType,
        GradeLevel,
        Inventory,
        BonusAverageAnnualPay,
        bonus_avg_annual_payments,
        BonusPayCap,
        bonus_capped_amt,
        CGLAInventory,
        CGLA_Bonus,
        MPA_recruiting,
        OMA_recruiting,
        MPA_total
    )
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubGroupCode,
           a.GradeType,
           a.GradeLevel,
           a.Inventory,
           0.0 AS BonusAverageAnnualPay,
           0.0 AS bonus_avg_annual_payments,
           0.0 AS BonusPayCap,
           0.0 AS bonus_capped_amt,
           0 AS CGLAInventory,
           0.0 AS CGLA_Bonus,
           0.0 AS MPA_recruiting,
           0.0 AS OMA_recruiting,
           0.0 AS MPA_total
    FROM
    (
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               SUM(Inventory) AS Inventory
        FROM data.KnownInventory
        WHERE GradeType IN ( 'E' )
              AND AmcosVersionId = @AmcosVersionId
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel
    ) AS a;

    --generate CGLA inventory
    --cgla is the cummulative inventory at or above any one PayPlan & subgroup combination
    --it is later used to average bonus costs across later grades
    UPDATE crunch_temp.CostOfRecruiting
    SET CGLAInventory = b.rev_cumulative
    FROM crunch_temp.CostOfRecruiting AS a
        INNER JOIN
        (
            --compute the reverse sum which wil later be used to do Cross Grade Level Allocation (CGLA)
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
                                       ) + crunch.GetParentInventory(PayPlan, CategorySubGroupCode, @AmcosVersionId) AS rev_cumulative
            FROM
            (
                SELECT PayPlan,
                       CategorySubgroupCode,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                GROUP BY PayPlan,
                         CategorySubgroupCode,
                         GradeType,
                         GradeLevel
            ) AS a
            WHERE GradeType IN ( 'E' )
            GROUP BY PayPlan,
                     CategorySubGroupCode,
                     GradeType,
                     GradeLevel,
                     Inventory
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel;

    -- =============================================
    --Compute the Contribution of Active Accession move costs
    -- =============================================
    DECLARE @Inv_AEs AS NUMERIC(18, 2);
    DECLARE @Accession_cost_per_Enlisted AS NUMERIC(18, 2);
    DECLARE @Accession_cost_3yr_avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Accession_Travel_Enlisted', 'MPA', 'avg', @AmcosVersionId);

    SET @Inv_AEs =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'AE' )
              AND AmcosVersionId = @AmcosVersionId
    );

    SET @Accession_cost_per_Enlisted = @Accession_cost_3yr_avg / @Inv_AEs;

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('Accession Travel: 3 yr avg: ', FORMAT(@Accession_cost_3yr_avg, 'C', 'en-us'));
        SELECT CONCAT('Number AEs ', @Inv_AEs);

        SELECT CONCAT('Accession Travel: Cost per AE  ', FORMAT(@Accession_cost_per_Enlisted, 'C', 'en-us'));

    END;

    --bring in recruiting costs ot our master table
    UPDATE crunch_temp.CostOfRecruiting
    SET MPA_recruiting = @Accession_cost_per_Enlisted + MPA_recruiting
    WHERE PayPlan = 'AE';



    -- =============================================
    --Compute the Contribution of Advertising costs
    -- =============================================

    --The JBooks do not publish recruiting and advertising costs by SoC or by Grade type so we'll compute our own estimate

    DECLARE @adv_OMA_3yr_Avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Advertising', 'OMA', 'avg', @AmcosVersionId);
    DECLARE @Inv_Es NUMERIC(18, 2);
    DECLARE @Inv_Total NUMERIC(18, 2);
    DECLARE @adv_OMA_E_Estimate NUMERIC(18, 2);
    DECLARE @adv_OMA_E_Per_soldier NUMERIC(18, 2);

    --use the army budget to compute the 3 year avg, so we have a very specific query to do that

    --get the inventory so we can make a ratio and divvy out R&A costs to officers, there's no precise way to do this so we do a simple ratio of total inventory
    -- we assume that the R&A budget benefits the entire force (all 3 components) even though it is an MPA line item
    SET @Inv_Es =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'AE', 'NE', 'RE' )
              AND AmcosVersionId = @AmcosVersionId
    );
    SET @Inv_Total =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE @AmcosVersionId = AmcosVersionId
    );

    SET @adv_OMA_E_Estimate = (@Inv_Es / @Inv_Total) * @adv_OMA_3yr_Avg;
    SET @adv_OMA_E_Per_soldier = @adv_OMA_E_Estimate / @Inv_Es;



    IF @Debug = 1
    BEGIN
        SELECT CONCAT('Advertising  3 yr avg: ', FORMAT(@adv_OMA_3yr_Avg, 'C', 'en-us'));
        SELECT CONCAT('Advertising enlisted estimate of 3 yr avg ', FORMAT(@adv_OMA_E_Estimate, 'C', 'en-us'));
        SELECT CONCAT('Advertising cost per enlisted ', FORMAT(@adv_OMA_E_Per_soldier, 'C', 'en-us'));
    END;

    --Advertising is spread across the entire force
    UPDATE crunch_temp.CostOfRecruiting
    SET OMA_recruiting = @adv_OMA_E_Per_soldier + OMA_recruiting;

    -- =============================================
    --Compute the Contribution of Active Recruiting costs
    -- =============================================

    --The JBooks do not publish recruiting and advertising costs by SoC or by Grade type so we'll compute our own estimate

    DECLARE @Recruiting_OMA_3yr_Avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting', 'OMA', 'avg', @AmcosVersionId);

    DECLARE @Recruiting_OMA_AE_Per_soldier NUMERIC(18, 2) = @Recruiting_OMA_3yr_Avg / @Inv_AEs;


    --Compute the MPA recruiting costs
    DECLARE @Recruiting_EndStrength_Officer_3yr_Avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Officer_Recruiters', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_EndStrength_Enlisted_3yr_avg AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Enlisted_Recruiters', 'MPA', 'avg', @AmcosVersionId);

    --assume O3 & E7 recruiters
    DECLARE @E7_Composite_Standard AS NUMERIC(18, 2)
        = crunch.GetSingleValue('AA', 'E7_Composite_Standard_Rate', @AmcosVersionId);
    DECLARE @O3_Composite_Standard AS NUMERIC(18, 2)
        = crunch.GetSingleValue('AA', 'O3_Composite_Standard_Rate', @AmcosVersionId);

    DECLARE @Recruiting_MPA_Est AS NUMERIC(18, 2);
    DECLARE @Recruiting_MPA_Est_per_AE AS NUMERIC(18, 2);

    SET @Recruiting_MPA_Est
        = (@O3_Composite_Standard * @Recruiting_EndStrength_Officer_3yr_Avg + @Recruiting_EndStrength_Enlisted_3yr_avg
           * @E7_Composite_Standard
          );
    SET @Recruiting_MPA_Est_per_AE = @Recruiting_MPA_Est / @Inv_AEs;

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('Recruiting OMA AE 3 yr avg: ', FORMAT(@Recruiting_OMA_3yr_Avg, 'C', 'en-us'));
        SELECT CONCAT('Recruiting OMA AE cost per enlisted ', FORMAT(@Recruiting_OMA_AE_Per_soldier, 'C', 'en-us'));
        SELECT CONCAT(
                         'Recruiting MPA Officer Pay Est: ',
                         FORMAT(@O3_Composite_Standard * @Recruiting_EndStrength_Officer_3yr_Avg, 'C', 'en-us')
                     );
        SELECT CONCAT(
                         'Recruiting MPA Enlisted  Pay Est: ',
                         FORMAT(@Recruiting_EndStrength_Enlisted_3yr_avg * @E7_Composite_Standard, 'C', 'en-us')
                     );
        SELECT CONCAT('Recruiting MPA Est: ', FORMAT(@Recruiting_MPA_Est, 'C', 'en-us'));
        SELECT CONCAT('Recruiting MPA AE cost per enlisted ', FORMAT(@Recruiting_MPA_Est_per_AE, 'C', 'en-us'));
    END;

    UPDATE crunch_temp.CostOfRecruiting
    SET OMA_recruiting = @Recruiting_OMA_AE_Per_soldier + OMA_recruiting,
        MPA_recruiting = MPA_recruiting + @Recruiting_MPA_Est_per_AE
    WHERE PayPlan = 'AE';

    -- =============================================
    --Compute the Contribution of Army Reserve Recruiting
    -- =============================================

    --####### RPA Non-Full Time reservists (e.g. short tours of duty to support recruiting mission) #######

    DECLARE @Recruiting_RPA_Non_FT_3yr_avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting', 'RPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_RPA_Non_FT_E_Per_soldier NUMERIC(18, 2);

    DECLARE @Inv_R_Es NUMERIC(18, 2);
    SET @Inv_R_Es =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'RE' )
              AND AmcosVersionId = @AmcosVersionId
    );
    DECLARE @Inv_R NUMERIC(18, 2);
    SET @Inv_R =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'RO', 'RWO', 'RE' )
              AND AmcosVersionId = @AmcosVersionId
    );
    --compute the officer percentage of this cost, the recruiting CE will pick up the rest
    SET @Recruiting_RPA_Non_FT_E_Per_soldier = @Recruiting_RPA_Non_FT_3yr_avg * (@Inv_R_Es / @Inv_R) / @Inv_R_Es;



    IF @Debug = 1
    BEGIN
        SELECT CONCAT('RPA Reserve Non-FT Recruiting 3yr avg: ', FORMAT(@Recruiting_RPA_Non_FT_3yr_avg, 'C', 'en-us'));
        SELECT CONCAT(
                         'RPA Recruiting Non-FT Recruiting cost per RE ',
                         FORMAT(@Recruiting_RPA_Non_FT_E_Per_soldier, 'C', 'en-us')
                     );
    END;


    UPDATE crunch_temp.CostOfRecruiting
    SET MPA_recruiting = @Recruiting_RPA_Non_FT_E_Per_soldier + MPA_recruiting
    WHERE PayPlan = 'RE';


    --####### RPA drill reservists #######
    --we do this differently from active because active provides the number of recruiters on mission, we assume the reserve recruiters to be inventory for 79R

    DECLARE @Recruiting_RPA_Est AS NUMERIC(18, 2);
    DECLARE @Recruiting_RPA_Est_per_RE AS NUMERIC(18, 2);



    SET @Recruiting_RPA_Est =
    (
        SELECT SUM(weighted_pay) AS total_pay
        FROM
        (
            SELECT a.*,
                   b.pay,
                   a.Inventory * b.pay AS weighted_pay
            FROM
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       CategorySubgroupCode,
                       YOS,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory
                FROM data.Inventory
                WHERE PayPlan = 'RE'
                      AND CategorySubgroupCode = '79R'
                      AND AmcosVersionId = @AmcosVersionId
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         CategorySubgroupCode,
                         YOS,
                         GradeType,
                         GradeLevel
            ) AS a
                INNER JOIN
                (
                    SELECT PayPlan,
                           GradeType,
                           GradeLevel,
                           YOS,
                           Rate * 15 AS pay
                    FROM data.PaySchedules
                    WHERE PayPlan = 'RE'
                          AND AmcosVersionId = @AmcosVersionId
                ) AS b
                    ON a.PayPlan = b.PayPlan
                       AND a.GradeType = b.GradeType
                       AND a.GradeLevel = b.GradeLevel
                       AND a.YOS = b.YOS
        ) AS a
    );
    --in the above its 15 because that's the number needed to annualize drill pay



    SET @Recruiting_RPA_Est_per_RE = @Recruiting_RPA_Est / @Inv_R_Es;

    IF @Debug = 1
    BEGIN

        SELECT CONCAT('RPA Recruiting RPA Est: ', FORMAT(@Recruiting_RPA_Est, 'C', 'en-us'));

        SELECT CONCAT('RPA Inventory for RE: ', @Inv_R_Es);
        SELECT CONCAT('RPA Recruiting RPA cost per enlisted ', FORMAT(@Recruiting_RPA_Est_per_RE, 'C', 'en-us'));

    END;
    UPDATE crunch_temp.CostOfRecruiting
    SET MPA_recruiting = @Recruiting_RPA_Est_per_RE + MPA_recruiting
    WHERE PayPlan = 'RE';


    --####### OMAR Recruiting Costs #######


    DECLARE @Recruiting_OMAR_Est AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting', 'OMAR', 'avg', @AmcosVersionId);

    DECLARE @Recruiting_OMAR_Est_per_RE AS NUMERIC(18, 2);
    SET @Recruiting_OMAR_Est_per_RE = @Recruiting_OMAR_Est / @Inv_R_Es;

    IF @Debug = 1
    BEGIN

        SELECT CONCAT('OMAR Recruiting  Est: ', FORMAT(@Recruiting_OMAR_Est, 'C', 'en-us'));

        SELECT CONCAT('Inventory for RE: ', @Inv_R_Es);
        SELECT CONCAT('OMAR Recruiting  cost per enlisted ', FORMAT(@Recruiting_OMAR_Est_per_RE, 'C', 'en-us'));

    END;
    UPDATE crunch_temp.CostOfRecruiting
    SET OMA_recruiting = @Recruiting_OMAR_Est_per_RE + OMA_recruiting
    WHERE PayPlan = 'RE';



    -- =============================================
    --Compute the Contribution of Army Guard Recruiting
    -- =============================================



    --####### NGPA Non-Full Time reservists (e.g. short tours of duty to support recruiting mission) #######

    DECLARE @Recruiting_NGPA_Non_FT_3yr_avg NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting_Retention', 'NGPA', 'avg', @AmcosVersionId);
    DECLARE @Recruiting_NGPA_Non_FT_E_Per_soldier NUMERIC(18, 2);

    DECLARE @Inv_NG_Es NUMERIC(18, 2);
    SET @Inv_NG_Es =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'NE' )
              AND AmcosVersionId = @AmcosVersionId
    );
    DECLARE @Inv_NG NUMERIC(18, 2);
    SET @Inv_NG =
    (
        SELECT SUM(Inventory)
        FROM data.Inventory
        WHERE PayPlan IN ( 'NO', 'NWO', 'NE' )
              AND AmcosVersionId = @AmcosVersionId
    );

    SET @Recruiting_NGPA_Non_FT_E_Per_soldier = @Recruiting_NGPA_Non_FT_3yr_avg * (@Inv_NG_Es / @Inv_NG) / @Inv_NG_Es;

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('NGPA Non FT  Recruiting 3yr avg: ', FORMAT(@Recruiting_NGPA_Non_FT_3yr_avg, 'C', 'en-us'));


        SELECT CONCAT(
                         'NGPA Non FT Recruiting cost per NE ',
                         FORMAT(@Recruiting_NGPA_Non_FT_E_Per_soldier, 'C', 'en-us')
                     );

    END;


    UPDATE crunch_temp.CostOfRecruiting
    SET MPA_recruiting = @Recruiting_NGPA_Non_FT_E_Per_soldier + MPA_recruiting
    WHERE PayPlan = 'NE';


    --####### NGPA Full Time reservists #######
    --we do this differently from active because active provides the number of recruiters on mission, we assume the reserve recruiters to be inventory for 79R

    DECLARE @Recruiting_NGPA_Est AS NUMERIC(18, 2);
    DECLARE @Recruiting_NGPA_Est_per_NE AS NUMERIC(18, 2);


    SET @Recruiting_NGPA_Est =
    (
        SELECT SUM(weighted_pay) AS total_pay
        FROM
        (
            SELECT a.*,
                   b.pay,
                   a.Inventory * b.pay AS weighted_pay
            FROM
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       CategorySubgroupCode,
                       YOS,
                       GradeType,
                       GradeLevel,
                       SUM(Inventory) AS Inventory
                FROM data.Inventory
                WHERE PayPlan = 'NE'
                      AND CategorySubgroupCode = '79R'
                      AND AmcosVersionId = @AmcosVersionId
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         CategorySubgroupCode,
                         YOS,
                         GradeType,
                         GradeLevel
            ) AS a
                INNER JOIN
                (
                    SELECT PayPlan,
                           GradeType,
                           GradeLevel,
                           YOS,
                           Rate * 15 AS pay
                    FROM data.PaySchedules
                    WHERE PayPlan = 'NE'
                          AND AmcosVersionId = @AmcosVersionId
                ) AS b
                    ON a.GradeType = b.GradeType
                       AND a.GradeLevel = b.GradeLevel
                       AND a.YOS = b.YOS
        ) AS a
    );

    SET @Recruiting_NGPA_Est_per_NE = @Recruiting_NGPA_Est / @Inv_NG_Es;

    IF @Debug = 1
    BEGIN

        SELECT CONCAT('NGPA Recruiting  Est: ', FORMAT(@Recruiting_NGPA_Est, 'C', 'en-us'));

        SELECT CONCAT('Inventory for RE: ', @Inv_R_Es);
        SELECT CONCAT('NGPA Recruiting  cost per enlisted ', FORMAT(@Recruiting_NGPA_Est_per_NE, 'C', 'en-us'));

    END;
    UPDATE crunch_temp.CostOfRecruiting
    SET MPA_recruiting = @Recruiting_NGPA_Est_per_NE + MPA_recruiting
    WHERE PayPlan = 'NE';


    --####### OMNG Recruiting Costs #######
    DECLARE @Recruiting_OMNG_Est AS NUMERIC(18, 2)
        = crunch.GetArmyBudgetSingleValue('Recruiting', 'OMNG', 'avg', @AmcosVersionId);

    DECLARE @Recruiting_OMNG_Est_per_NE AS NUMERIC(18, 2) = @Recruiting_OMNG_Est / @Inv_NG_Es;

    IF @Debug = 1
    BEGIN
        SELECT CONCAT('Recruiting NGPA Est: ', FORMAT(@Recruiting_OMNG_Est, 'C', 'en-us'));
        SELECT CONCAT('Inventory for RE: ', @Inv_NG_Es);
        SELECT CONCAT('Recruiting NGPA cost per enlisted ', FORMAT(@Recruiting_OMNG_Est_per_NE, 'C', 'en-us'));
    END;

    UPDATE crunch_temp.CostOfRecruiting
    SET OMA_recruiting = @Recruiting_OMNG_Est_per_NE + OMA_recruiting
    WHERE PayPlan = 'NE';

    -- =============================================
    --Compute the Contribution of Enlistment Bonus
    -- =============================================
    DECLARE @DMDCEnlistmentBonus TABLE
    (
        PayType NVARCHAR(50) NULL,
        PayPlan NVARCHAR(3) NULL,
        CMF NVARCHAR(2) NULL,
        subgrp NVARCHAR(4) NULL,
        GradeType NVARCHAR(2) NULL,
        GradeLevel NVARCHAR(2) NULL,
        avg_cost NUMERIC(18, 2) NULL,
        AmcosVersionId INT NULL,
        [avg_annual_pay] NUMERIC(18, 2) NULL,
        [avg_annual_payments] NUMERIC(18, 2) NULL,
        [pay_cap] NUMERIC(18, 2) NULL,
        [capped_avg_mpa_pay] NUMERIC(18, 2) NULL
    );

    INSERT INTO @DMDCEnlistmentBonus
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
          AND avg_annual_pay > 0
          AND
          (
              --In this script we handle the following DMDC Pay Types 
              --Active enlistment bonus, we exclude reserve component enlistment bonus because that belongs really in the active and is a reporting anomoly
              --the reserve components have their own enlistment bonus programs as shown below
              (
                  PayType IN ( 'Enlistment Bonus' )
                  AND PayPlan LIKE 'A%'
              )
              --now pull in the reserve bonus types
              OR
              (
                  PayType IN ( 'Sel Res Enlisted Accession Bonus', 'Sel Res Enlisted Affiliation Bonus' )
                  AND PayPlan IN ( 'NE', 'RE' )
              )
          );


    TRUNCATE TABLE crunch_temp.BonusCaps;

    INSERT INTO crunch_temp.BonusCaps
    (
        MOS,
        Cap,
        AmcosVersionId
    )
    SELECT MOS,
           Cap,
           AmcosVersionId
    FROM dataload.MilitaryEnlistmentBonusCap
    WHERE AmcosVersionId = @AmcosVersionId;

    --in addition to the EB caps there is a maximum allowed by law 37 U.S.C. 309
    SELECT @AEB_Max = crunch.GetSingleValue('AE', 'EnlistmentBonus_Max', @AmcosVersionId);

    --FMR Volume 7A Chapter 56 sets a maximum limit on reserve accession or affiliation bonus in the selected reserve
    SELECT @REB_Max = crunch.GetSingleValue('RC', 'EnlistmentBonus_Max', @AmcosVersionId);

    --bring in the pay cap from the MILPERS message (published by HRC usually quarterly, but not less than annually)
    UPDATE @DMDCEnlistmentBonus
    SET pay_cap = b.Cap
    FROM @DMDCEnlistmentBonus AS a
        INNER JOIN crunch_temp.BonusCaps AS b
            ON a.subgrp = b.MOS
    --the milpers message pay caps only seems to apply to active, the FMR governs reserve pay caps but not by MOS
    WHERE a.PayPlan IN ( 'AE' );

    --bring in pay caps for reserves
    UPDATE @DMDCEnlistmentBonus
    SET pay_cap = @REB_Max
    WHERE PayPlan IN ( 'RE', 'NE' );

    --copy the avg cost into the capped pay before we start adjusting by the cap
    UPDATE @DMDCEnlistmentBonus
    SET capped_avg_mpa_pay = avg_annual_pay;

    --move data collected so far into our recruiting table
    UPDATE crunch_temp.CostOfRecruiting
    SET BonusAverageAnnualPay = b.avg_annual_pay,
        bonus_avg_annual_payments = b.avg_annual_payments,
        BonusPayCap = b.pay_cap
    FROM crunch_temp.CostOfRecruiting AS a
        INNER JOIN
        (
            -- because we can have multiple entries within a subgrp we need to do a sum before
            -- we run an udpate so it isn't selectively applying updates based on whatever the sort order is
            SELECT PayPlan,
                   subgrp,
                   GradeLevel,
                   SUM(avg_annual_pay) AS avg_annual_pay,
                   SUM(avg_annual_payments) AS avg_annual_payments,
                   MAX(pay_cap) AS pay_cap
            FROM @DMDCEnlistmentBonus
            GROUP BY PayPlan,
                     subgrp,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.subgrp
               AND a.GradeLevel = b.GradeLevel;

    --implement pay caps
    UPDATE crunch_temp.CostOfRecruiting
    SET bonus_capped_amt = BonusPayCap * bonus_avg_annual_payments
    WHERE BonusAverageAnnualPay > (BonusPayCap * bonus_avg_annual_payments);

    --do a pay cap against inventory to make sure we don't allocate bonus pay for more soldiers then we have in inventory
    UPDATE crunch_temp.CostOfRecruiting
    SET bonus_capped_amt = BonusPayCap * Inventory
    WHERE BonusAverageAnnualPay > (BonusPayCap * Inventory);


    --implement the maximum cap for AE, the reserve max pay cap is already taken care of
    UPDATE crunch_temp.CostOfRecruiting
    SET bonus_capped_amt = bonus_avg_annual_payments * @AEB_Max
    WHERE BonusAverageAnnualPay > (@AEB_Max * bonus_avg_annual_payments)
          AND PayPlan IN ( 'AE' );

    --implement the maximum cap for AE, against inventory
    UPDATE crunch_temp.CostOfRecruiting
    SET bonus_capped_amt = Inventory * @AEB_Max
    WHERE BonusAverageAnnualPay > (@AEB_Max * Inventory)
          AND PayPlan IN ( 'AE' );

    --from the 2018 PB
    --The Army pays up to $10,000 at the first permanent duty station after successful completion of basic and initial training, then equal periodic payments, 
    --IF required. The Army also has the authority to pay up to $40,000 (not to exceed a total enlistment bonus of this amount) to recruits who select a 
    --critical MOS and are willing to ship to training within 30 days.
    --So according to this it should take a maximum of 4 years to pay out the entire bonus 
    --according to DMDC inventory 4 YOS can take an enlisted member all the way to an E6
    --therefore we cap any E7s and above at 0 dollars
    UPDATE crunch_temp.CostOfRecruiting
    SET bonus_capped_amt = 0
    WHERE CONVERT(INT, GradeLevel) >= 7;



    ----bring in CGLA calculation
    UPDATE crunch_temp.CostOfRecruiting
    SET CGLA_Bonus = mybonus
    FROM crunch_temp.CostOfRecruiting AS a
        INNER JOIN
        (
            SELECT *,
                   SUM(bonus_capped_amt / CGLAInventory) OVER (PARTITION BY PayPlan,
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
                                                      'Recruiting',
                                                      @AmcosVersionId
                                                  ) AS mybonus
            FROM crunch_temp.CostOfRecruiting
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubGroupCode = b.CategorySubGroupCode
               AND a.GradeLevel = b.GradeLevel;

    --compute the total mpa including recruiting and bonus costs
    UPDATE crunch_temp.CostOfRecruiting
    SET MPA_total = ISNULL(MPA_recruiting, 0) + ISNULL(CGLA_Bonus, 0);




    IF @Debug = 1
    BEGIN
        SELECT 'enlistment bonus table';
        SELECT PayType,
               PayPlan,
               CMF,
               subgrp,
               GradeType,
               GradeLevel,
               avg_cost,
               AmcosVersionId,
               avg_annual_pay,
               avg_annual_payments,
               pay_cap,
               capped_avg_mpa_pay
        FROM @DMDCEnlistmentBonus
        ORDER BY avg_cost DESC;

        SELECT 'Recruiting costs by subgrp';
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               Inventory,
               BonusAverageAnnualPay,
               bonus_avg_annual_payments,
               BonusPayCap,
               bonus_capped_amt,
               CGLAInventory,
               CGLA_Bonus,
               MPA_recruiting,
               OMA_recruiting,
               MPA_total
        FROM crunch_temp.CostOfRecruiting
        ORDER BY CategorySubGroupCode,
                 GradeLevel,
                 PayPlan;

        SELECT 'Recruiting costs by mpa_total';
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode,
               GradeType,
               GradeLevel,
               Inventory,
               BonusAverageAnnualPay,
               bonus_avg_annual_payments,
               BonusPayCap,
               bonus_capped_amt,
               CGLAInventory,
               CGLA_Bonus,
               MPA_recruiting,
               OMA_recruiting,
               MPA_total
        FROM crunch_temp.CostOfRecruiting
        ORDER BY CGLA_Bonus DESC;
    END;

    IF @Debug = 0
    BEGIN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 4189, 22, 80 )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 4191, 331, 298 )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 4190, 462, 495 )
              AND AmcosVersionId = @AmcosVersionId;

        --Insert average cost elements, we only have two APPNs for each PP
        --AE
        --MPA
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
               CategorySubGroupCode,
               22,
               GradeType,
               GradeLevel,
               -1,
               MPA_total,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'AE';
        --OMA
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
               CategorySubGroupCode,
               80,
               GradeType,
               GradeLevel,
               -1,
               OMA_recruiting,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'AE';

        --NE
        --NGPA
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
               CategorySubGroupCode,
               331,
               GradeType,
               GradeLevel,
               -1,
               MPA_total,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'NE';
        --OMNG
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
               CategorySubGroupCode,
               298,
               GradeType,
               GradeLevel,
               -1,
               OMA_recruiting,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'NE';

        --RE
        --RPA
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
               CategorySubGroupCode,
               495,
               GradeType,
               GradeLevel,
               -1,
               MPA_total,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'RE';
        --OMAR
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
               CategorySubGroupCode,
               462,
               GradeType,
               GradeLevel,
               -1,
               OMA_recruiting,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'RE';

        --Insert actual cost elements, we only have have MPA/RPA/NGPA APPNs
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
               CategorySubGroupCode,
               4189,
               GradeType,
               GradeLevel,
               -1,
               BonusAverageAnnualPay,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM crunch_temp.CostOfRecruiting
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
               CategorySubGroupCode,
               4191,
               GradeType,
               GradeLevel,
               -1,
               BonusAverageAnnualPay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfRecruiting
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
               CategorySubGroupCode,
               4190,
               GradeType,
               GradeLevel,
               -1,
               BonusAverageAnnualPay,
               @CrunchTime,
               @AmcosVersionId
        FROM crunch_temp.CostOfRecruiting
        WHERE PayPlan = 'RE';
    END;


END;