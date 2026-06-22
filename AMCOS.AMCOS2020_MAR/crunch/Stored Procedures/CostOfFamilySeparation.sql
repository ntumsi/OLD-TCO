
-- =============================================
-- Author:Dan Hogan
-- Create date: 8/7/2019
-- Description:	Cost of Family Separation Allowances
-- =============================================
CREATE PROCEDURE [crunch].[CostOfFamilySeparation]
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

    DROP TABLE IF EXISTS #Inventory;
    CREATE TABLE #Inventory
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        Inventory INT NULL,
        AmcosVersionId INT NULL,
        amount NUMERIC(17, 2)
    );

    INSERT INTO #Inventory
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        Inventory,
        AmcosVersionId
    )
    -- get all the military inventory at the subgroup level
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           SUM(Inventory) AS Inventory,
           AmcosVersionId
    --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
    FROM data.KnownInventory
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode,
             AmcosVersionId;



    DROP TABLE IF EXISTS #FamSepPaybyVersion;
    CREATE TABLE #FamSepPaybyVersion
    (
        PayType NVARCHAR(MAX) NULL,
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        amount NUMERIC NULL,
        AmcosVersionId INT NULL,
    );

    INSERT INTO #FamSepPaybyVersion
    (
        PayType,
        PayPlan,
        GradeLevel,
        amount,
        AmcosVersionId
    )
    SELECT PayType,
           PayPlan,
           GradeLevel,
           SUM(TotalPayAmount),
           AmcosVersionId
    FROM DMDC.Pay
    WHERE PayType = 'family separation allowance'
          AND PayPlan IN ( 'AO', 'AE', 'AWO' )
          AND AmcosVersionId IN
              -- we only want the most recent 3 years of DMDC data to compute our sliding average
              (
                  SELECT TOP 3
                         AmcosVersionId
                  FROM DMDC.Pay
                  WHERE AmcosVersionId <= @AmcosVersionId
                  GROUP BY AmcosVersionId
                  ORDER BY AmcosVersionId DESC
              )
    GROUP BY PayType,
             PayPlan,
             GradeLevel,
             AmcosVersionId;




    DROP TABLE IF EXISTS #AvgFamSepPay;
    CREATE TABLE #AvgFamSepPay
    (
        PayType NVARCHAR(MAX) NULL,
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        GradeConformed NVARCHAR(1),
        DMDCPay NUMERIC NULL,
        BudgetAmt NUMERIC(17, 2) NULL,
        PercofBudget NUMERIC(17, 2) NULL,
        Inventory INT NULL,
        FamSepAmt NUMERIC(17, 2) NULL
    );

    INSERT INTO #AvgFamSepPay
    (
        PayType,
        PayPlan,
        GradeLevel,
        DMDCPay
    )
    SELECT PayType,
           PayPlan,
           GradeLevel,
           AVG(amount) AS amt
    FROM #FamSepPaybyVersion
    GROUP BY PayType,
             PayPlan,
             GradeLevel;

    --set the gradetype, because the budget is only by Enlisted (E) and Officer (W & O) we need to hav a field that tracks that
    UPDATE #AvgFamSepPay
    SET GradeConformed = 'E'
    WHERE PayPlan = 'AE';
    UPDATE #AvgFamSepPay
    SET GradeConformed = 'O'
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --Bring in the budget amounts which we are going to divy across the gradelevls
    DECLARE @E_Fam_Sep_Budget NUMERIC
        = crunch.GetArmyBudgetSingleValue('Enlisted_Family_Separation', 'MPA', 'avg', @AmcosVersionId);
    DECLARE @O_WO_Fam_Sep_Budget NUMERIC
        = crunch.GetArmyBudgetSingleValue('Officer_Warrant_Family_Separation', 'MPA', 'avg', @AmcosVersionId);
    UPDATE #AvgFamSepPay
    SET BudgetAmt = @E_Fam_Sep_Budget
    WHERE PayPlan IN ( 'AE' );
    UPDATE #AvgFamSepPay
    SET BudgetAmt = @O_WO_Fam_Sep_Budget
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --calculate the percent of the budget each pay plan and grade level should get based on the payouts from DMDC pay
    UPDATE #AvgFamSepPay
    SET PercofBudget = myperc
    FROM #AvgFamSepPay AS a
        INNER JOIN
        (
            --this over clause calculates the percentage each grade level's pay compared to its conformed's (O/WO, or E) total DMDC pay
            --which we will later apply to the budget amount to divy it out by grade level since the budget does not do this by grade level
            SELECT PayType,
                   PayPlan,
                   GradeConformed,
                   GradeLevel,
                   DMDCPay / SUM(DMDCPay) OVER (PARTITION BY GradeConformed) AS myperc
            FROM #AvgFamSepPay
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    --bring in inventory so we can use it to compute the average pay
    UPDATE #AvgFamSepPay
    SET Inventory = myinv
    FROM #AvgFamSepPay AS a
        LEFT JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   SUM(Inventory) AS myinv
            FROM #Inventory
            GROUP BY PayPlan,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    --finally compute the fam sep amount which is the DMDC's determined portion of the budget divided by inventory
    UPDATE #AvgFamSepPay
    SET FamSepAmt = ISNULL(BudgetAmt * PercofBudget / Inventory, 0);


    --finally we go back to the inventory table and update the amounts, this is so we can easily use the table as an insert
    --later for all allowable subgroups

    UPDATE #Inventory
    SET amount = ISNULL(FamSepAmt, 0)
    FROM #Inventory AS a
        INNER JOIN #AvgFamSepPay AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    IF @Debug = 1
    BEGIN
        SELECT 'Fam Sep by version';
        SELECT PayType,
               PayPlan,
               GradeLevel,
               amount,
               AmcosVersionId
        FROM #FamSepPaybyVersion;
        SELECT 'fam sep average';
        SELECT PayType,
               PayPlan,
               GradeLevel,
               GradeConformed,
               DMDCPay,
               BudgetAmt,
               PercofBudget,
               Inventory,
               FamSepAmt
        FROM #AvgFamSepPay;
        SELECT 'final table before insert';
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               Inventory,
               AmcosVersionId,
               amount
        FROM #Inventory;
    END;





    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 48 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 157 )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 231 )
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
            MHA,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               48,
               GradeType,
               GradeLevel,
               -1,
               amount,
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               -1
        FROM #Inventory
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
            MHA,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               157,
               GradeType,
               GradeLevel,
               -1,
               amount,
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               -1
        FROM #Inventory
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
            MHA,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               231,
               GradeType,
               GradeLevel,
               -1,
               amount,
               @CrunchTime,
               @AmcosVersionId,
               '-1',
               -1
        FROM #Inventory
        WHERE PayPlan = 'AWO';


    END;
END;