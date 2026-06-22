
-- =============================================
-- Author:Dan Hogan
-- Create date: 8/7/2019
-- Description:	Cost of Family Separation Allowances

-- =============================================
CREATE PROCEDURE [crunch].[CostOfSeparationPay]
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

    DROP TABLE IF EXISTS #SepCalc;
    CREATE TABLE #SepCalc
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        GradeType NVARCHAR(3) NULL,
        PP_GL_Inv INT NULL,
        O_E_Inv INT NULL,
        AmcosVersionId INT NULL,
        Budget_Vol_sep NUMERIC(15, 2),
        Budget_Invol_sep NUMERIC(15, 2),
        GL_Budget_Leave NUMERIC(15, 2),
        Final_Vol_Sep_Leave NUMERIC(15, 2),
        Final_Invol_Sep NUMERIC(15, 2)
    );

    INSERT INTO #SepCalc
    (
        PayPlan,
        GradeLevel,
        GradeType,
        PP_GL_Inv,
        AmcosVersionId
    )
    -- get all the military inventory at the subgroup level
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           SUM(Inventory) AS inventory,
           AmcosVersionId
    --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             AmcosVersionId;

    --bring in officer/enlisted totals
    --officer and warrants are grouped together in the overall budget numbers so we get totals for both
    UPDATE #SepCalc
    SET O_E_Inv =
        (
            SELECT SUM(Inventory) AS inventory

            --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'AO', 'AWO' )
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY AmcosVersionId
        )
    WHERE GradeType IN ( 'W', 'O' );

    UPDATE #SepCalc
    SET O_E_Inv =
        (
            SELECT SUM(Inventory) AS inventory

            --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'AE' )
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY AmcosVersionId
        )
    WHERE GradeType IN ( 'E' );


    --bring in GL budgets for terminal leave
    UPDATE #SepCalc
    SET GL_Budget_Leave = b.Amount
    FROM #SepCalc AS a
        INNER JOIN dataload.ArmyBudgetManualValues AS b
            ON a.GradeLevel = b.GradeLevel
               AND a.GradeType = b.GradeType
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND b.PayType IN ( 'Enlisted_Terminal_Leave', 'Officer_Warrant_Terminal_Leave' );


    --Bring in the voluntary budget amounts which we are going to divy across the gradelevls
    DECLARE @E_Vol_sep_Budget NUMERIC
        = crunch.GetArmyBudgetSingleValue('Enlisted_Voluntary_Separation', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @O_WO_Vol_Sep_Budget NUMERIC
        = crunch.GetArmyBudgetSingleValue('Officer_Warrant_Voluntary_Separation', 'MPA', 'avg', @AmcosVersionId);
    UPDATE #SepCalc
    SET Budget_Vol_sep = @E_Vol_sep_Budget
    WHERE PayPlan IN ( 'AE' );
    UPDATE #SepCalc
    SET Budget_Vol_sep = @O_WO_Vol_Sep_Budget
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --Bring in the involuntary budget amounts which we are going to divy across the gradelevls
    DECLARE @E_Invol_sep_Budget NUMERIC
        = crunch.GetArmyBudgetSingleValue('Enlisted_Involuntary_Separation', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @O_WO_Invol_Sep_Budget NUMERIC
        = crunch.GetArmyBudgetSingleValue('Officer_Warrant_Involuntary_Separation', 'MPA', 'avg', @AmcosVersionId);
    UPDATE #SepCalc
    SET Budget_Invol_sep = @E_Invol_sep_Budget
    WHERE PayPlan IN ( 'AE' );
    UPDATE #SepCalc
    SET Budget_Invol_sep = @O_WO_Invol_Sep_Budget
    WHERE PayPlan IN ( 'AO', 'AWO' );


    --calculate voluntary leave totals by spreading leave against all inventory and vol sep across the entire inventory base
    UPDATE #SepCalc
    SET Final_Vol_Sep_Leave = (Budget_Vol_sep / O_E_Inv) + (GL_Budget_Leave / PP_GL_Inv);

    --calculate voluntary leave totals by spreading leave against all inventory and vol sep across the entire inventory base
    UPDATE #SepCalc
    SET Final_Invol_Sep = (Budget_Invol_sep / O_E_Inv);



    DROP TABLE IF EXISTS #FinalCosts;
    CREATE TABLE #FinalCosts
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(3) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        inventory INT NULL,
        AmcosVersionId INT NULL,
        Final_Vol_Sep_Leave NUMERIC(15, 2),
        Final_Invol_Sep NUMERIC(15, 2)
    );

    INSERT INTO #FinalCosts
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        inventory,
        AmcosVersionId
    )
    -- get all the military inventory at the subgroup level
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           SUM(inventory) AS inventory,
           AmcosVersionId
    --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             GradeLevel,
             GradeType,
             AmcosVersionId;


    UPDATE #FinalCosts
    SET Final_Vol_Sep_Leave = b.Final_Vol_Sep_Leave,
        Final_Invol_Sep = b.Final_Invol_Sep
    FROM #FinalCosts AS a
        INNER JOIN #SepCalc AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;


    IF @Debug = 1
    BEGIN
        SELECT ' Sep by version';
        SELECT PayPlan,
               GradeLevel,
               GradeType,
               PP_GL_Inv,
               O_E_Inv,
               AmcosVersionId,
               Budget_Vol_sep,
               Budget_Invol_sep,
               GL_Budget_Leave,
               Final_Vol_Sep_Leave,
               Final_Invol_Sep
        FROM #SepCalc;

        SELECT 'final table before insert';
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               inventory,
               AmcosVersionId,
               Final_Vol_Sep_Leave,
               Final_Invol_Sep
        FROM #FinalCosts
        ORDER BY PayPlan,
                 GradeLevel,
                 CategorySubgroupCode;
    END;



    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 44, 46, 45 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 154, 155, 153 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 227, 229, 228 )
              AND AmcosVersionId = @AmcosVersionId;

        /* Insert average cost elements,*/
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
        --voluntary separation
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               44,
               GradeType,
               GradeLevel,
               -1,
               Final_Vol_Sep_Leave,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AE'
        --involuntary separation
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               46,
               GradeType,
               GradeLevel,
               -1,
               Final_Invol_Sep,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AE'
        --total separation
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               45,
               GradeType,
               GradeLevel,
               -1,
               Final_Invol_Sep + Final_Vol_Sep_Leave,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AE';


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
        --voluntary separation
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               153,
               GradeType,
               GradeLevel,
               -1,
               Final_Vol_Sep_Leave,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AO'
        --involuntary separation
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               155,
               GradeType,
               GradeLevel,
               -1,
               Final_Invol_Sep,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AO'
        --total separation
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               154,
               GradeType,
               GradeLevel,
               -1,
               Final_Invol_Sep + Final_Vol_Sep_Leave,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AO';

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
        --voluntary separation
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               227,
               GradeType,
               GradeLevel,
               -1,
               Final_Vol_Sep_Leave,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AWO'
        --involuntary separation
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               229,
               GradeType,
               GradeLevel,
               -1,
               Final_Invol_Sep,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AWO'
        --total separation
        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               228,
               GradeType,
               GradeLevel,
               -1,
               Final_Invol_Sep + Final_Vol_Sep_Leave,
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #FinalCosts
        WHERE PayPlan = 'AWO';
    END;
END;