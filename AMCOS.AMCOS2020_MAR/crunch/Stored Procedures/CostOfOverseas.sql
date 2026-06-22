




-- =============================================
-- Author:Dan Hogan
-- Create date: 8/27/2019
-- Description:	Cost of Overseas Allowances
-- =============================================
CREATE PROCEDURE [crunch].[CostOfOverseas]
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

    DROP TABLE IF EXISTS #inventory;
    CREATE TABLE #inventory
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        Inventory INT NULL,
        AmcosVersionId INT NULL,
        Amount NUMERIC(15, 2)
    );

    INSERT INTO #inventory
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

    DROP TABLE IF EXISTS #OverseasPayByVersion;
    CREATE TABLE #OverseasPayByVersion
    (
        PayType NVARCHAR(MAX) NULL,
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        Amount NUMERIC NULL,
        AmcosVersionId INT NULL,
    );

    INSERT INTO #OverseasPayByVersion
    (
        PayType,
        PayPlan,
        GradeLevel,
        Amount,
        AmcosVersionId
    )
    SELECT PayType,
           PayPlan,
           GradeLevel,
           SUM(TotalPayAmount),
           AmcosVersionId
    FROM DMDC.Pay
    WHERE PayType IN ( 'OCONUS 1 COLA Barracks', 'OCONUS 1 Cost of Living', 'OCONUS 2 COLA Barracks',
                       'OCONUS 2 Cost of Living', 'OHA MIHA Miscellaneous', 'OHA MIHA Rent', 'OHA MIHA Security'
                     )
          AND PayPlan IN ( 'AO', 'AE', 'AWO' )
          AND AmcosVersionId IN
              -- we only want the most recent 3 years of DMDC data to compute our sliding average
              (
                  SELECT TOP (3)
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

    DROP TABLE IF EXISTS #AvgOverseasPay;
    CREATE TABLE #AvgOverseasPay
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        GradeConformed NVARCHAR(1) NULL,
        DMDCPay NUMERIC NULL,
        BudgetAmt NUMERIC(15, 2) NULL,
        PercentOfBudget FLOAT NULL,
        Inventory INT NULL,
        OverseasAmount NUMERIC(15, 2) NULL
    );

    INSERT INTO #AvgOverseasPay
    (
        PayPlan,
        GradeLevel,
        DMDCPay
    )

    --in this case we don't care about paytype because we are calculating as one single CE, not seperated by the different
    --overseas pay types (OHA, OCONUS COLA, Misc) so we sum and then average
    SELECT PayPlan,
           GradeLevel,
           AVG(Amount) AS Amount
    FROM
    (
        SELECT PayPlan,
               GradeLevel,
               AmcosVersionId,
               SUM(Amount) AS Amount
        FROM #OverseasPayByVersion
        GROUP BY PayPlan,
                 GradeLevel,
                 AmcosVersionId
    ) AS a
    GROUP BY PayPlan,
             GradeLevel;

    --set the gradetype, because the budget is only by Enlisted (E) and Officer (W & O) we need to hav a field that tracks that
    UPDATE #AvgOverseasPay
    SET GradeConformed = 'E'
    WHERE PayPlan = 'AE';

    UPDATE #AvgOverseasPay
    SET GradeConformed = 'O'
    WHERE PayPlan IN ( 'AO', 'AWO' );

    --Bring in the budget amounts which we are going to divy across the gradelevls
    DECLARE @AO_AWO_budget NUMERIC(20, 2)
        = crunch.GetArmyBudgetSingleValue('AO_AWO_Bdgt_OCONUS_COLA_OHA', 'MPA', 'Avg', @AmcosVersionId),
            @AE_budget NUMERIC(20, 2) = crunch.GetArmyBudgetSingleValue(
                                                                           'Enl_Bdgt_OCONUS_COLA_OHA',
                                                                           'MPA',
                                                                           'Avg',
                                                                           @AmcosVersionId
                                                                       );

    UPDATE #AvgOverseasPay
    SET BudgetAmt = @AE_budget
    WHERE PayPlan IN ( 'AE' );
    UPDATE #AvgOverseasPay
    SET BudgetAmt = @AO_AWO_budget
    WHERE PayPlan IN ( 'AO', 'AWO' );

    /*calculate the percent of the budget each pay plan and grade level should get based on the payouts from DMDC pay*/
    UPDATE #AvgOverseasPay
    SET PercentOfBudget = b.MyPercent
    FROM #AvgOverseasPay AS a
        INNER JOIN
        (
            --this over clause calculates the percentage each grade level's pay compared to its conformed's (O/WO, or E) total DMDC pay
            --which we will later apply to the budget amount to divy it out by grade level since the budget does not do this by grade level
            SELECT PayPlan,
                   GradeConformed,
                   GradeLevel,
                   DMDCPay / SUM(DMDCPay) OVER (PARTITION BY GradeConformed) AS MyPercent
            FROM #AvgOverseasPay
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    --bring in inventory so we can use it to compute the average pay
    UPDATE #AvgOverseasPay
    SET Inventory = b.MyInventory
    FROM #AvgOverseasPay AS a
        LEFT JOIN
        (
            SELECT PayPlan,
                   GradeLevel,
                   SUM(Inventory) AS MyInventory
            FROM #inventory
            GROUP BY PayPlan,
                     GradeLevel
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    /*finally, compute the  amount which is the DMDC's determined portion of the budget divided by inventory*/
    UPDATE #AvgOverseasPay
    SET OverseasAmount = ISNULL(BudgetAmt * PercentOfBudget / Inventory, 0);


    --finally we go back to the inventory table and update the amounts, this is so we can easily use the table as an insert
    --later for all allowable subgroups

    UPDATE #inventory
    SET Amount = ISNULL(b.OverseasAmount, 0)
    FROM #inventory AS a
        INNER JOIN #AvgOverseasPay AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel;

    --these are the CE ids for this costelement, we are going to use them several times so we create a variable now
    -- that can be used over and over
    DECLARE @ce_AE INT = 53;
    DECLARE @CE_AO INT = 161;
    DECLARE @CE_AWO INT = 235;


    IF @Debug = 1
    BEGIN
        SELECT '--- Average overseas tables (not location specific) ----';
        SELECT 'Overseas by version';
        SELECT PayType,
               PayPlan,
               GradeLevel,
               Amount,
               AmcosVersionId
        FROM #OverseasPayByVersion;

        SELECT 'Overseas average and computations';
        SELECT PayPlan,
               GradeLevel,
               GradeConformed,
               DMDCPay,
               BudgetAmt,
               PercentOfBudget,
               Inventory,
               OverseasAmount
        FROM #AvgOverseasPay
        ORDER BY PayPlan,
                 GradeLevel;

        SELECT 'final amount table for insert of non-location specific avg costs';
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               Inventory,
               AmcosVersionId,
               Amount
        FROM #inventory
        ORDER BY PayPlan,
                 GradeLevel,
                 CategorySubgroupCode;
    END;




    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( @ce_AE )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( @CE_AO )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( @CE_AWO )
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
            LocationId,
            DependentStatus
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @ce_AE,
               GradeType,
               GradeLevel,
               -1,
               Amount,
               @CrunchTime,
               @AmcosVersionId,
               -1,
               '-1'
        FROM #inventory
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
            LocationId,
            DependentStatus
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO,
               GradeType,
               GradeLevel,
               -1,
               Amount,
               @CrunchTime,
               @AmcosVersionId,
               -1,
               '-1'
        FROM #inventory
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
            LocationId,
            DependentStatus
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO,
               GradeType,
               GradeLevel,
               -1,
               Amount,
               @CrunchTime,
               @AmcosVersionId,
               -1,
               '-1'
        FROM #inventory
        WHERE PayPlan = 'AWO';
    END;




    -- ##### Begin location specific OCONUS costing




    DROP TABLE IF EXISTS #DMDCDependents;
    CREATE TABLE #DMDCDependents
    (
        AmcosVersionId INT NULL,
        PayPlan NVARCHAR(50) NULL,
        GradeType NVARCHAR(50) NULL,
        GradeLevel NVARCHAR(50) NULL,
        AverageNumberOfDependents INT NULL,
        PercentWithDependents NUMERIC(5, 4) NULL,
    );
    INSERT INTO #DMDCDependents
    (
        AmcosVersionId,
        GradeType,
        GradeLevel,
        AverageNumberOfDependents,
        PercentWithDependents
    )
    SELECT AmcosVersionId,
           GradeType,
           GradeLevel,
           -- the OHA/OCOLA data maxes out at 5 dependents, its unlikely we'd ever have an avg number of dependents that gets close
           -- to 5 let alone exceeds it but we need to handle that scenario incase it ever happens
           CASE
               WHEN ROUND(NumberOfDependents / MembersWithDependents, 0) > 5 THEN
                   5
               ELSE
                   ROUND(NumberOfDependents / MembersWithDependents, 0)
           END AS avgnumdependents,
           CAST(MembersWithDependents AS FLOAT) / TotalMembers AS percwithdependents
    FROM DMDC.MembersAndDependents
    --this is just for the active component
    WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
          AND AmcosVersionId = @AmcosVersionId;


    DROP TABLE IF EXISTS #SpendableIncome;
    CREATE TABLE #SpendableIncome
    (
        HasDependents BIT NULL,
        Grade NVARCHAR(1) NULL,
        GradeLevel INT NULL,
        YearsOfService INT NULL,
        AnnualCompensation NUMERIC(16, 2) NULL,
        AmcosVersionId INT NULL,
        LowerLimit NUMERIC(16, 2) NULL,
        UpperLimit NUMERIC(16, 2) NULL,
        NumberOfDependents INT NULL,
        SpendableIncome NUMERIC(16, 2) NULL,
        ComputedSpendableIncome NUMERIC(16, 2) NULL,
    );

    INSERT INTO #SpendableIncome
    (
        HasDependents,
        Grade,
        GradeLevel,
        YearsOfService,
        AnnualCompensation,
        AmcosVersionId,
        LowerLimit,
        UpperLimit,
        NumberOfDependents,
        SpendableIncome,
        ComputedSpendableIncome
    )
    -- OCONUS COLA is based on spendable income not base pay
    -- so to get spendable income by annual compensation we join these to tables
    SELECT a.HasDependents,
           a.Grade,
           a.GradeLevel,
           a.YoS,
           a.AnnualCompensation,
           a.AmcosVersionId,
           a.LowerLimit,
           a.UpperLimit,
           a.NumberOfDependents,
           a.SpendableIncome,
           a.ComputedSpendableIncome
    FROM
    (
        SELECT a.HasDependents,
               a.Grade,
               a.GradeLevel,
               a.YoS,
               a.AnnualCompensation,
               a.AmcosVersionId,
               b.LowerLimit,
               b.UpperLimit,
               b.NumberOfDependents,
               b.SpendableIncome,

               --because we are doing a cross join we get a bunch of extra results we don't need
               --rows where the annualcomp is outside the limits have no spendable income and thus
               --are not useful and will later be filtered out
               CASE
                   WHEN a.AnnualCompensation
                        BETWEEN b.LowerLimit AND b.UpperLimit THEN
                       b.SpendableIncome
                   ELSE
                       0
               END AS ComputedSpendableIncome
        FROM dataload.MilitaryAnnualComp AS a
            CROSS JOIN dataload.MilitarySpendableIncome AS b
        WHERE
            --another product of the cross join is excess results which we want to filter out when a row has dependents
            --from one table but not in the other, or vice versa
            --this is because only when both tables agree on at least the presence of dependents (number of dependents 
            --is a matter for later) do we want to retain that row

            (
                (
                    b.NumberOfDependents = 0
                    AND a.HasDependents = 0
                )
                OR
                (
                    b.NumberOfDependents >= 1
                    AND a.HasDependents = 1
                )
            )
            AND a.AmcosVersionId = b.AmcosVersionId
            AND a.AmcosVersionId = @AmcosVersionId
            AND b.AmcosVersionId = @AmcosVersionId
    ) AS a
    WHERE ComputedSpendableIncome > 0;




    DROP TABLE IF EXISTS #OCONUS_COLA_OHA;
    CREATE TABLE #OCONUS_COLA_OHA
    (
        OCONUS_COLA NUMERIC(12, 2) NULL,
        rental_amt NUMERIC(12, 2) NULL,
        utility_amt NUMERIC(12, 2) NULL,
        MIHA_amt NUMERIC(12, 2) NULL,
        loccode NVARCHAR(5) NULL,
        locname NVARCHAR(75) NULL,
        Grade NVARCHAR(1) NULL,
        Gradelevel INT NULL,
        YearsOfService INT NULL,
        Dependents INT NULL,
        AverageNumberOfDependents INT NULL,
        ComputedSpendableIncome NUMERIC(16, 2) NULL,
        kyloc NVARCHAR(10) NULL,
        xrat NUMERIC(25, 2) NULL,
        ocola_index INT NULL,
        ocola_groupcode INT NULL,
        perc_o_utility_wdep NUMERIC(10, 2) NULL,
        perc_e_utiliy_wdep NUMERIC(10, 2) NULL,
        o_utility_wdep NUMERIC(10, 2) NULL,
        e_utility_wdep NUMERIC(10, 2) NULL,
        perc_o_rentalallowance_wodep NUMERIC(10, 2) NULL,
        perc_e_rentalallowance_wodep NUMERIC(10, 2) NULL,
        o_miha NUMERIC(10, 2) NULL,
        e_miha NUMERIC(10, 2) NULL,
        off_curr_name NVARCHAR(150) NULL,
        rentalamt_wdep NUMERIC(10, 2) NULL,
        AmcosVersionId INT NULL
    );
    INSERT INTO #OCONUS_COLA_OHA
    (
        OCONUS_COLA,
        rental_amt,
        utility_amt,
        MIHA_amt,
        loccode,
        locname,
        kyloc,
        xrat,
        ocola_index,
        ocola_groupcode,
        perc_o_utility_wdep,
        perc_e_utiliy_wdep,
        o_utility_wdep,
        e_utility_wdep,
        perc_o_rentalallowance_wodep,
        perc_e_rentalallowance_wodep,
        o_miha,
        e_miha,
        off_curr_name,
        Grade,
        Gradelevel,
        rentalamt_wdep,
        AmcosVersionId,
        YearsOfService,
        Dependents,
        ComputedSpendableIncome
    )

    --the data for the index comes in as an integer and needs to be converted to a decimal percent of spendable income
    SELECT b.ComputedSpendableIncome * (a.OCOLA_Index / 100.00 - 1) AS OCONUS_Annual_COLA,
           a.RentalAmt_wDep
           * CASE
                 WHEN b.HasDependents = 0
                      AND a.Grade = 'E' THEN
                     a.Perc_E_RentalAllowance_woDep / 100.00 --number comes in as an int and needs conversion to percentage
                 WHEN b.HasDependents = 0
                      AND a.Grade <> 'E' THEN
                     a.Perc_O_RentalAllowance_woDep / 100.00
                 ELSE
                     1
             END * a.XRAT / POWER(10.00, 12) --do the currency conversion to get dollars
           * 12 -- rental allowance is monthly by AMCOS wants annual
           AS rental_amt,
           CASE
               WHEN b.HasDependents = 0
                    AND a.Grade = 'E' THEN
                   a.E_Utility_wDep * a.Perc_E_Utility_wDep / 100.00 --number comes in as an int and needs conversion to percentage
               WHEN b.HasDependents = 0
                    AND a.Grade <> 'E' THEN
                   a.O_Utility_wDep * a.Perc_O_Utility_wDep / 100.00
               WHEN b.HasDependents = 1
                    AND a.Grade = 'E' THEN
                   a.E_Utility_wDep
               WHEN b.HasDependents = 1
                    AND a.Grade <> 'E' THEN
                   a.O_Utility_wDep
               ELSE
                   0
           END * a.XRAT / POWER(10.00, 12) --do the currency conversion to get dollars
           * 12 --utility is monthly but AMCOS wants annual
           AS utiliy_amt, --utiliy allowance
           CASE
               WHEN a.Grade = 'E' THEN
                   a.E_MIHA
               WHEN a.Grade <> 'E' THEN
                   a.O_MIHA
               ELSE
                   0
           END * a.XRAT / POWER(10.00, 12) --do the currency conversion to get dollars
           * 1 --move-in-housing allowance is a one time thing, the amount does not need to be annualized
           AS MIHA_amt,   --move in allowance (if one applies)
           a.LOCCODE,
           a.LOCNAME,
           a.KEYLOC,
           a.XRAT,
           a.OCOLA_Index,
           a.OCOLA_GroupCode,
           a.Perc_O_Utility_wDep,
           a.Perc_E_Utility_wDep,
           a.O_Utility_wDep,
           a.E_Utility_wDep,
           a.Perc_O_RentalAllowance_woDep,
           a.Perc_E_RentalAllowance_woDep,
           a.O_MIHA,
           a.E_MIHA,
           a.Off_curr_name,
           a.Grade,
           a.GradeLevel,
           a.RentalAmt_wDep,
           a.AmcosVersionId,
           b.YearsOfService,
           b.NumberOfDependents,
           b.ComputedSpendableIncome
    FROM dataload.MilitaryOverseasHousingAllowance AS a
        INNER JOIN #SpendableIncome AS b
            ON a.Grade = b.Grade
               AND a.GradeLevel = b.GradeLevel
               AND a.AmcosVersionId = b.AmcosVersionId
    WHERE a.OCOLA_Index > 0 --if the index is zero then no cola is currently calculated for that area
                            --and a.Mkt_Curr='US' --added 3/2/2023 we don't want any rows that are in a different currency
    ;


    /*bring in the avg num dependents */
    UPDATE #OCONUS_COLA_OHA
    SET AverageNumberOfDependents = b.AverageNumberOfDependents
    FROM #OCONUS_COLA_OHA AS a
        INNER JOIN #DMDCDependents AS b
            ON b.GradeType = a.Grade
               AND b.GradeLevel = a.Gradelevel
               AND b.AverageNumberOfDependents = a.Dependents;
    --this last join statement means a lot of the existing data in the table will be orphaned, this is fine since we are attempting to estimated the average 
    --cost and thus the already computed avg number of dependents by grade level and grade is what we want

    --the above gets us a complete OCONUS COLA and OHA table by YoS and # of Dependents
    --now we need to link that up with inventory by those same things
    DROP TABLE IF EXISTS #OCONUS_OHA_YoS;
    CREATE TABLE #OCONUS_OHA_YoS
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        YearsOfService INT NULL,
        Inventory INT NULL,
        AmcosVersionId INT NULL,
        OCONUS_COLA NUMERIC(15, 2),
        rental NUMERIC(15, 2),
        utility NUMERIC(15, 2),
        MIHA NUMERIC(15, 2),
        AverageNumberOfDependents INT NULL,
        loccode NVARCHAR(5) NULL,
        dependentweight NUMERIC(5, 4) NULL,
    );

    INSERT INTO #OCONUS_OHA_YoS
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        YearsOfService,
        Inventory,
        AmcosVersionId,
        AverageNumberOfDependents,
        loccode
    )
    -- get all the military inventory at the subgroup and YearsOfService level

    SELECT a.PayPlan,
           a.GradeLevel,
           a.GradeType,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.yos,
           a.Inventory,
           a.AmcosVersionId,
           a.AverageNumberOfDependents,
           b.loccode
    FROM
    (
        SELECT PayPlan,
               GradeLevel,
               GradeType,
               CategoryGroupCode,
               CategorySubgroupCode,
                                                 --when yos>40 we need to return it to 40 since input data we have does not exceed 40, might want
                                                 --to fix the input data when we rewrite this
               CASE
                   WHEN YOS > 40 THEN
                       40
                   ELSE
                       YOS
               END AS yos,
               SUM(Inventory) AS Inventory,
               AmcosVersionId,
               NULL AS AverageNumberOfDependents --first insert are those with dependents, we use null because we don't know how many there are yet
                                                 --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
        FROM data.KnownInventory
        WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
              AND AmcosVersionId = @AmcosVersionId
        GROUP BY PayPlan,
                 GradeLevel,
                 GradeType,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 AmcosVersionId,
                 yos
        UNION
        SELECT PayPlan,
               GradeLevel,
               GradeType,
               CategoryGroupCode,
               CategorySubgroupCode,
               YOS,
               SUM(Inventory) AS Inventory,
               AmcosVersionId,
               0 AS AverageNumberOfDependents --second are those without dependents, no dependents are easily identified as 0
                                              --active only benefit, however its possible there are AGRs deployed who get this benefit but its not clear where the budget for them come from so we assume that MPA budget is active only
        FROM data.KnownInventory
        WHERE PayPlan IN ( 'AE', 'AO', 'AWO' )
              AND AmcosVersionId = @AmcosVersionId
        GROUP BY PayPlan,
                 GradeLevel,
                 GradeType,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 AmcosVersionId,
                 YOS
    ) AS a
        CROSS JOIN
        (SELECT loccode FROM #OCONUS_COLA_OHA GROUP BY loccode) AS b; --we have to create every possible scenario so a cross join is needed
                                                                      -- note this is going to create in excess of 20M records so a select * of this table is not recommended


    --first update brings in costs for no dependents
    UPDATE #OCONUS_OHA_YoS
    SET OCONUS_COLA = b.OCONUS_COLA,
        rental = b.rental_amt,
        utility = b.utility_amt,
        MIHA = b.MIHA_amt
    FROM #OCONUS_OHA_YoS AS a
        INNER JOIN #OCONUS_COLA_OHA AS b
            ON a.GradeType = b.Grade
               AND a.GradeLevel = b.Gradelevel
               AND a.YearsOfService = b.YearsOfService
               AND a.loccode = b.loccode
    WHERE b.Dependents = 0
          AND a.AverageNumberOfDependents = 0;

    --next update brings in costs for those with dependents
    UPDATE #OCONUS_OHA_YoS
    SET OCONUS_COLA = b.OCONUS_COLA,
        rental = b.rental_amt,
        utility = b.utility_amt,
        MIHA = b.MIHA_amt,
        AverageNumberOfDependents = b.AverageNumberOfDependents
    FROM #OCONUS_OHA_YoS AS a
        INNER JOIN #OCONUS_COLA_OHA AS b
            ON a.GradeType = b.Grade
               AND a.GradeLevel = b.Gradelevel
               AND a.YearsOfService = b.YearsOfService
               AND a.loccode = b.loccode
    WHERE b.AverageNumberOfDependents > 0
          AND a.AverageNumberOfDependents IS NULL;

    --next update resolves no dependents YoS where the OCONUS COLA/OHA data doesn't have a corresponding YoS
    UPDATE #OCONUS_OHA_YoS
    SET OCONUS_COLA = b.OCONUS_COLA,
        rental = b.rental_amt,
        utility = b.utility_amt,
        MIHA = b.MIHA_amt
    FROM #OCONUS_OHA_YoS AS a
        INNER JOIN #OCONUS_COLA_OHA AS b
            ON a.GradeType = b.Grade
               AND a.GradeLevel = b.Gradelevel
               AND (a.YearsOfService - 1) = b.YearsOfService --drop the YoS down by one to find a linkage
               AND a.loccode = b.loccode
    WHERE b.Dependents = 0
          AND a.AverageNumberOfDependents = 0
          AND a.OCONUS_COLA IS NULL; --only update those records which didn't resolve the first time and are thus still null

    --next update resolves dependents YoS where the OCONUS COLA/OHA data doesn't have a corresponding YoS
    UPDATE #OCONUS_OHA_YoS
    SET OCONUS_COLA = b.OCONUS_COLA,
        rental = b.rental_amt,
        utility = b.utility_amt,
        MIHA = b.MIHA_amt,
        AverageNumberOfDependents = b.AverageNumberOfDependents
    FROM #OCONUS_OHA_YoS AS a
        INNER JOIN #OCONUS_COLA_OHA AS b
            ON a.GradeType = b.Grade
               AND a.GradeLevel = b.Gradelevel
               AND (a.YearsOfService - 1) = b.YearsOfService --drop the YoS down by one to find a linkage
               AND a.loccode = b.loccode
    WHERE b.AverageNumberOfDependents > 0
          AND a.AverageNumberOfDependents IS NULL
          AND a.OCONUS_COLA IS NULL; --only update those records which didn't resolve the first time and are thus still null

    --finally, bring in the percent of dependents
    UPDATE #OCONUS_OHA_YoS
    SET dependentweight = b.PercentWithDependents
    FROM #OCONUS_OHA_YoS AS a
        INNER JOIN #DMDCDependents AS b
            ON b.GradeType = a.GradeType
               AND b.GradeLevel = a.GradeLevel;



    --we invert the percentage when we have no dependents since the number was originally the percent with dependents
    UPDATE #OCONUS_OHA_YoS
    SET dependentweight = 1 - dependentweight
    WHERE AverageNumberOfDependents = 0;


    IF @Debug = 1
    BEGIN
        SELECT '#OCONUS_OHA_YoS gradelevel=10';
        SELECT *
        FROM #OCONUS_OHA_YoS
        WHERE GradeLevel = 10;
        SELECT 'check #oconus_oha_yos for negative values';
        SELECT OCONUS_COLA,
               rental_amt,
               utility_amt,
               MIHA_amt,
               loccode,
               locname,
               Grade,
               Gradelevel,
               YearsOfService,
               Dependents,
               AverageNumberOfDependents,
               ComputedSpendableIncome,
               kyloc,
               xrat,
               ocola_index,
               ocola_groupcode,
               perc_o_utility_wdep,
               perc_e_utiliy_wdep,
               o_utility_wdep,
               e_utility_wdep,
               perc_o_rentalallowance_wodep,
               perc_e_rentalallowance_wodep,
               o_miha,
               e_miha,
               off_curr_name,
               rentalamt_wdep,
               AmcosVersionId
        FROM #OCONUS_COLA_OHA
        WHERE OCONUS_COLA < 0;
    END;




    DROP TABLE IF EXISTS #OCONUS_OHA_Weighted;
    CREATE TABLE #OCONUS_OHA_Weighted
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        Inventory INT NULL,
        AmcosVersionId INT NULL,
        OCONUS_COLA NUMERIC(15, 2),
        rental NUMERIC(15, 2),
        utility NUMERIC(15, 2),
        MIHA NUMERIC(15, 2),
        loccode NVARCHAR(5) NULL,
    );

    INSERT INTO #OCONUS_OHA_Weighted
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        Inventory,
        AmcosVersionId,
        loccode,
        OCONUS_COLA,
        rental,
        utility,
        MIHA
    )
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CategorySubgroupCode,
           SUM(Inventory) / 2,
           AmcosVersionId,
           loccode,
           SUM(OCONUS_COLA * dependentweight * Inventory) / (SUM(Inventory) / 2) AS oconus_cola,
           SUM(rental * dependentweight * Inventory) / (SUM(Inventory) / 2) AS rental,
           SUM(utility * dependentweight * Inventory) / (SUM(Inventory) / 2) AS utility,
           SUM(MIHA * dependentweight * Inventory) / (SUM(Inventory) / 2) AS miha
    FROM #OCONUS_OHA_YoS
    --WHERE loccode = 'AE001'
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CategorySubgroupCode,
             AmcosVersionId,
             loccode;






    IF @Debug = 1
    BEGIN
        SELECT '#OCONUS_OHA_Weighted gradelevel=10';
        SELECT *
        FROM #OCONUS_OHA_Weighted
        WHERE GradeLevel = 10;
        SELECT '--- Average location specific cost tables for overseas ----';
        SELECT 'DMDC dependent table';
        SELECT AmcosVersionId,
               PayPlan,
               GradeType,
               GradeLevel,
               AverageNumberOfDependents,
               PercentWithDependents
        FROM #DMDCDependents;

        SELECT 'OHA Location Specific Spendable Income table';
        SELECT HasDependents,
               Grade,
               GradeLevel,
               YearsOfService,
               AnnualCompensation,
               AmcosVersionId,
               LowerLimit,
               UpperLimit,
               NumberOfDependents,
               SpendableIncome,
               ComputedSpendableIncome
        FROM #SpendableIncome
        ORDER BY Grade,
                 GradeLevel;

        SELECT 'Complete OHA table by YearsOfService and number/dependenant status for specific loccode ';
        SELECT OCONUS_COLA,
               rental_amt,
               utility_amt,
               MIHA_amt,
               loccode,
               locname,
               Grade,
               Gradelevel,
               YearsOfService,
               Dependents,
               AverageNumberOfDependents,
               ComputedSpendableIncome,
               kyloc,
               xrat,
               ocola_index,
               ocola_groupcode,
               perc_o_utility_wdep,
               perc_e_utiliy_wdep,
               o_utility_wdep,
               e_utility_wdep,
               perc_o_rentalallowance_wodep,
               perc_e_rentalallowance_wodep,
               o_miha,
               e_miha,
               off_curr_name,
               rentalamt_wdep,
               AmcosVersionId
        FROM #OCONUS_COLA_OHA
        WHERE loccode = 'NL065'
        ORDER BY Grade,
                 Gradelevel,
                 YearsOfService,
                 Dependents;

        SELECT ' location specific avg costs with YearsOfService before weighting <0 values';
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               YearsOfService,
               Inventory,
               AmcosVersionId,
               OCONUS_COLA,
               rental,
               utility,
               MIHA,
               AverageNumberOfDependents,
               loccode,
               dependentweight
        FROM #OCONUS_OHA_YoS
        WHERE OCONUS_COLA < 0
              OR dependentweight < 0
              OR AverageNumberOfDependents < 0
        ORDER BY PayPlan,
                 loccode,
                 GradeLevel,
                 CategorySubgroupCode;

        SELECT 'Final location specific avg costs check for <0 values';
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               Inventory,
               AmcosVersionId,
               OCONUS_COLA,
               rental,
               utility,
               MIHA,
               loccode
        FROM #OCONUS_OHA_Weighted
        WHERE MIHA < 0
              OR OCONUS_COLA < 0
              OR rental < 0
              OR utility < 0
        ORDER BY PayPlan,
                 loccode,
                 GradeLevel,
                 CategorySubgroupCode;

        SELECT 'Warning, the following MHA codes are missing an entry in the warehouse location table and thus will cause a debug=0 run to fail';
        SELECT a.loccode,
               b.LocationId,
               b.SourceSystemCode,
               b.LocationType,
               b.DisplayName
        FROM
        (SELECT DISTINCT loccode FROM #OCONUS_OHA_Weighted) AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.loccode = b.SourceSystemCode
        WHERE b.SourceSystemCode IS NULL;


        SELECT 'amounts with null values';
        SELECT *
        FROM #OCONUS_OHA_Weighted
        WHERE MIHA IS NULL
              OR OCONUS_COLA IS NULL
              OR rental IS NULL
              OR utility IS NULL;
    END;




    IF @Debug = 0
    BEGIN
        /* the delete statement in the earlier part of this document took care of removing location specific overseas costs */

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
            MHA,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            DependentStatus
        )
        SELECT a.PayPlan,
               a.CategoryGroupCode,
               a.CategorySubgroupCode,
               @ce_AE,
               a.GradeType,
               a.GradeLevel,
               -1,
               OCONUS_COLA + rental + utility + MIHA,
               loccode,
               @CrunchTime,
               @AmcosVersionId,
               b.LocationId,
               '-1'
        FROM #OCONUS_OHA_Weighted AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.loccode = b.SourceSystemCode
        WHERE a.PayPlan = 'AE';



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
            MHA,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            DependentStatus
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AO,
               GradeType,
               GradeLevel,
               -1,
               OCONUS_COLA + rental + utility + MIHA,
               loccode,
               @CrunchTime,
               @AmcosVersionId,
               b.LocationId,
               '-1'
        FROM #OCONUS_OHA_Weighted AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.loccode = b.SourceSystemCode
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
            MHA,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            DependentStatus
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               @CE_AWO,
               GradeType,
               GradeLevel,
               -1,
               OCONUS_COLA + rental + utility + MIHA,
               loccode,
               @CrunchTime,
               @AmcosVersionId,
               b.LocationId,
               '-1'
        FROM #OCONUS_OHA_Weighted AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.loccode = b.SourceSystemCode
        WHERE PayPlan = 'AWO';


    END;






/*
	Here is the exact text I got from the Defence Travel Management Office which was used to re-create their logic
	OCOLA 2019 data:

For E1, no dependents, 2 years of service, the regular military compensation for 2019 
is 40755.  That  puts their spendable income for OCOLA goods and services at the lowest level, again for no dependents, 
spendable income is 21,200 per year.  For historical reasons, Overseas COLA is calculated as a daily amount by dividing 
spendable income by 360, or $58.89, so the COLA index of .42 has a value of $24.73, which is then multiplied by the days 
in the period to get the payout. 


OHA:I think you mean E1 without dependents, that matches the COLA version and is the one you would be multiplying by .9.  
The 11310 for with dependents is in Dirham, the Mkt Curr column is second to last, a two character code for the 
rental allowance.  All rental allowances are monthly amounts.  You would multiply the 11310*.9 to get 10179 Dirham 
for without dependents.  The  rental allowance currency exchange rate is the eighth column, multiplied by 10^12 to 
avoid decimals, so multiple 10179 by the exchange rate and divide by 10^12 to get the value from the calculator.
	
	*/
END;