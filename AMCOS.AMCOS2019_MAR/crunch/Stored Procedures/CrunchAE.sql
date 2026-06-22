CREATE PROCEDURE [crunch].[CrunchAE]
    @MOS NVARCHAR(3),
    @AmcosVersionId INT = -1

/*
PROGRAMMER: RBPIII
DATE: 10-02-2013
NOTES
1) Float data types are more percise than the previsous Access version of AMCOS which used single digit numbers. This is
   important because some of the single digit numbers were rounded which produced slightly different numbers than this program.
   The difference will be very small. PCS "Avg Permanent Change of Station-annualized" cost calculations show the greatest change which is up to $15.00.
*/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF NOT EXISTS
    (
        SELECT CategorySubGroupCode
        FROM data.Inventory
        WHERE PayPlan = 'AE'
              AND CategorySubGroupCode = @MOS
    )
        RETURN 0;

    DROP TABLE IF EXISTS #CrunchCosts;
    CREATE TABLE #CrunchCosts
    (
        CostElementId INT NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        WeaponSystemId INT NOT NULL
            DEFAULT (-1),
        Amount FLOAT NULL,
        CrunchTime SMALLDATETIME NULL
    );

    DECLARE @CMF NCHAR(2) = LEFT(@MOS, 2);

    DROP TABLE IF EXISTS #InventoryByGradeForPayPlan;
    CREATE TABLE #InventoryByGradeForPayPlan
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO #InventoryByGradeForPayPlan
    (
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM crunch.InventoryByGradeForPayPlan('AE');

    DECLARE @TotalInventoryForPayPlan INTEGER = crunch.GetTotalInventoryForPayPlan('AE');

    DROP TABLE IF EXISTS #InventoryByCategorySubgroupGradeYos;
    CREATE TABLE #InventoryByCategorySubgroupGradeYos
    (
        MOS VARCHAR(3) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        YOS VARCHAR(2) NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        MOS,
                        GradeType,
                        GradeLevel,
                        YOS
                    )
    );
    INSERT INTO #InventoryByCategorySubgroupGradeYos
    (
        MOS,
        GradeType,
        GradeLevel,
        YOS,
        Amount
    )
    SELECT CategorySubGroupCode,
           GradeType,
           GradeLevel,
           Step_YOS,
           Amount
    FROM crunch.InventoryByCategorySubgroupGradeYos('AE');

    -- Percent of tour for personal in the Continental United States(CONUS)
    DROP TABLE IF EXISTS #tblConus;
    CREATE TABLE #tblConus
    (
        MOS VARCHAR(3) NOT NULL PRIMARY KEY,
        Amount FLOAT NULL
    );
    IF EXISTS
    (
        SELECT MOS
        FROM lookup.MOS
        WHERE MOS = @MOS
              AND CONUSTourLength IS NOT NULL
    )
    BEGIN
        INSERT INTO #tblConus
        SELECT MOS,
               CONUSTourLength
        FROM lookup.MOS
        WHERE MOS <> 'ZZZ';
    END;
    ELSE
    BEGIN
        INSERT INTO #tblConus
        SELECT @MOS,
               CONUSTourLength
        FROM lookup.MOS
        WHERE MOS = 'ZZZ'
        UNION
        SELECT MOS,
               CONUSTourLength
        FROM lookup.MOS
        WHERE MOS <> 'ZZZ';
    END;

    -- Percent of tour for personal outside the Continental United States(OCONUS)
    DROP TABLE IF EXISTS #tblOconus;
    CREATE TABLE #tblOconus
    (
        MOS VARCHAR(3) NOT NULL PRIMARY KEY,
        Amount FLOAT NULL
    );
    IF EXISTS (SELECT MOS FROM dataload.AE_SpecialPaysElig WHERE MOS = @MOS)
    BEGIN
        INSERT INTO #tblOconus
        SELECT MOS,
               OCONUS
        FROM dataload.AE_SpecialPaysElig
        WHERE MOS <> 'ZZZ';
    END;
    ELSE
    BEGIN
        INSERT INTO #tblOconus
        SELECT @MOS,
               OCONUS
        FROM dataload.AE_SpecialPaysElig
        WHERE MOS = 'ZZZ'
        UNION
        SELECT MOS,
               OCONUS
        FROM dataload.AE_SpecialPaysElig
        WHERE MOS <> 'ZZZ';
    END;

    -- Use Default value for OCONUS Tour Length if MOS is not listed.
    DECLARE @OconusTourLength FLOAT;
    SET @OconusTourLength = ISNULL(
                            (
                                SELECT Amount FROM #tblOconus WHERE MOS = @MOS
                            ),
                            0.19
                                  );

    /* Lump Sum Terminal Leave Payments */
    DROP TABLE IF EXISTS #LumpSumTerminalLeavePayments;
    CREATE TABLE #LumpSumTerminalLeavePayments
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO #LumpSumTerminalLeavePayments
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM dataload.SepParms
    WHERE (
              PayPlan = 'AE'
              AND Code = N'LSTLP'
          );

    DECLARE @TotalAvgInvPrj FLOAT;
    SELECT @TotalAvgInvPrj = SUM(Amount)
    FROM crunch.AverageInventoryProjected('AE');

    DECLARE @TotalNumLstlp FLOAT;
    SELECT @TotalNumLstlp = SUM(Amount)
    FROM crunch.NumberOfLumpSumTerminalLeavePayments('AE');

    DECLARE @TotalLstlp FLOAT;
    SELECT @TotalLstlp = SUM(Amount)
    FROM #LumpSumTerminalLeavePayments;

    -- Millitary Compensation Allowances
    DROP TABLE IF EXISTS #MilitaryCompensationAllowances;
    CREATE TABLE #MilitaryCompensationAllowances
    (
        Code VARCHAR(15) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        Code,
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO #MilitaryCompensationAllowances
    SELECT Code,
           GradeType,
           GradeLevel,
           Amount
    FROM dataload.AE_MilCompAllowances;

    /* BEGIN COST FACTOR PROCESSING */
    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Max_Wage_SSW MONEY = crunch.GetSingleValue('AA', 'Max_Wage_SSW');
    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA', 'Retired_Pay_Accrual');
    DECLARE @HQ_Recruits FLOAT = crunch.GetSingleValue('AE', 'HQ_Recruits');
    DECLARE @LQ_Recruits FLOAT = crunch.GetSingleValue('AE', 'LQ_Recruits');
    DECLARE @HQ_Attrition FLOAT = crunch.GetSingleValue('AE', 'HQ_Attrition');
    DECLARE @LQ_Attrition FLOAT = crunch.GetSingleValue('AE', 'LQ_Attrition');
    DECLARE @Accession_Move_Cost FLOAT = crunch.GetSingleValue('AA', 'Accession_Move_Cost');
    DECLARE @PCS_ConusOverseas_30_Dep_Not_Auth INT
        = crunch.GetArmyBudgetSingleValue('PCS_ConusOverseas_30_Dep_Not_Auth', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @TDY_ConusOverseas_30_Dep_Not_Nearby INT
        = crunch.GetArmyBudgetSingleValue('TDY_ConusOverseas_30_Dep_Not_Nearby', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Tot_Amt_For_Temp_Lodging_Allowance INT
        = crunch.GetSingleValue('AE', 'Tot_Amt_For_Temp_Lodging_Allowance');
    DECLARE @Tot_Bdgt_For_Overseas_Station_Allowance INT
        = crunch.GetArmyBudgetSingleValue('Tot_Bdgt_For_Overseas_Station_Allowance', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Tot_ConusOverseas_30_Dep INT;
    DECLARE @Initial_Accessions_Male FLOAT = crunch.GetSingleValue('AE', 'Initial_Accessions_Male');
    DECLARE @InitialAccessionsFemale FLOAT = crunch.GetSingleValue('AE', 'Initial_Accessions_FeMale');
    DECLARE @Initial_Accessions_Perc_Male FLOAT = crunch.GetSingleValue('AE', 'Initial_Accessions_Perc_Male');
    DECLARE @Basic_NonAccessions_Male FLOAT = crunch.GetSingleValue('AE', 'Basic_NonAccessions_Male');
    DECLARE @Basic_NonAccessions_FeMale FLOAT = crunch.GetSingleValue('AE', 'Basic_NonAccessions_FeMale');
    DECLARE @Basic_NonAccessions_Perc_Male FLOAT = crunch.GetSingleValue('AE', 'Basic_NonAccessions_Perc_Male');
    DECLARE @StandardInitialClothingAllowance FLOAT;
    DECLARE @CashClothingReplacementAllowanceBasic FLOAT;
    DECLARE @CashClothingReplacementAllowanceStandard FLOAT;
    DECLARE @CashClothingReplacementAllowanceStandardMale FLOAT = crunch.GetSingleValue('AE', 'Standard_Male');
    DECLARE @CashClothingReplacementAllowanceStandardFemale FLOAT = crunch.GetSingleValue('AE', 'Standard_FeMale');
    DECLARE @Standard_Perc_Male FLOAT = crunch.GetSingleValue('AE', 'Standard_Perc_Male');
    DECLARE @Avg_Rec_Attrition FLOAT;
    DECLARE @Misc INT = crunch.GetArmyBudgetSingleValue('AE_Misc', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Survivor INT = crunch.GetSingleValue('AE', 'Survivor');
    DECLARE @MoraleWelfareRecreation INT
        = crunch.GetArmyBudgetSingleValue('MoraleWelfareRecreation', 'OMA', 'Avg', @AmcosVersionId);
    DECLARE @Avg_OE_End_Strength INT
        = crunch.GetArmyBudgetSingleValue('Avg_OE_End_Strength', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Health_Care_Cost_Per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
    DECLARE @PCS_Training_Move_Cost FLOAT = crunch.GetSingleValue('AE', 'PCS_Training_Move_Cost');
    DECLARE @PCS_Operational_Move_Cost FLOAT = crunch.GetSingleValue('AE', 'PCS_Operational_Move_Cost');
    DECLARE @PCS_Rotational_Move_Cost FLOAT = crunch.GetSingleValue('AE', 'PCS_Rotational_Move_Cost');
    DECLARE @PCS_Separation_Move_Cost FLOAT = crunch.GetSingleValue('AE', 'PCS_Separation_Move_Cost');
    DECLARE @PCS_Avg_OCONUS_Tour_Length FLOAT = crunch.GetSingleValue('AE', 'PCS_Avg_OCONUS_Tour_Length');
    DECLARE @EnlistedPCSOperationalMoveBudget INT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Operational_Move_Budget', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @EnlistedPCSRotationalMoveBudget INT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Rotational_Move_Budget', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @EnlistedPCSSeparationMoveBudget INT
        = crunch.GetArmyBudgetSingleValue('Enlisted_PCS_Separation_Move_Budget', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Sep_Pay_NonDis INT = crunch.GetSingleValue('AE', 'Sep_Pay_NonDis');
    DECLARE @Enlisted_Severence_Pay FLOAT
        = crunch.GetArmyBudgetSingleValue('Enlisted_Severence_Pay', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @DiscountGroceries FLOAT = crunch.GetSingleValue('AA', 'DiscountGroceries');
    DECLARE @DoDEAandFamilyAssistance FLOAT = crunch.GetSingleValue('AA', 'DoDEAandFamilyAssistance');
    DECLARE @ChildEducation FLOAT = crunch.GetSingleValue('AA', 'ChildEducation');
    DECLARE @TreasuryContributionForConcurrentReceipts FLOAT
        = crunch.GetSingleValue('AA', 'TreasuryContributionForConcurrentReceipts');
    DECLARE @VeteransBenefits FLOAT = crunch.GetSingleValue('AA', 'VeteransBenefits');
    DECLARE @MERHC FLOAT = crunch.GetSingleValue('AA', 'MERHC');
    DECLARE @TreasuryContributionToMERHC FLOAT = crunch.GetSingleValue('AA', 'TreasuryContributionToMERHC');

    -- Distribute recruiter time among the recruits; the assumption is that HQ recruits require
    -- 2.25 times as much effort.  the adjustment for attrition will be done at the end.

    SET @Tot_ConusOverseas_30_Dep = @PCS_ConusOverseas_30_Dep_Not_Auth + @TDY_ConusOverseas_30_Dep_Not_Nearby;

    DECLARE @tblPCS2Home TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS2Home
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM dataload.AE_SpecialPays
    WHERE (Code = N'PCS');

    DECLARE @tblPrjWDep TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPrjWDep
    SELECT tblWDep.GradeType,
           tblWDep.GradeLevel,
           tblWDep.Amount * Inventory.Amount
    FROM #MilitaryCompensationAllowances tblWDep
        INNER JOIN crunch.AverageInventoryProjected('AE') Inventory
            ON tblWDep.GradeType = Inventory.GradeType
               AND tblWDep.GradeLevel = Inventory.GradeLevel
    WHERE (tblWDep.Code = N'BAH_PWD');

    SET @Avg_Rec_Attrition
        = (@LQ_Attrition * @LQ_Recruits) + (@HQ_Attrition * @HQ_Recruits) / (@LQ_Recruits + @HQ_Recruits);

    SET @StandardInitialClothingAllowance
        = (@Initial_Accessions_Male * @Initial_Accessions_Perc_Male)
          + (@InitialAccessionsFemale * (1 - @Initial_Accessions_Perc_Male)) / (1 - @Avg_Rec_Attrition);

    SET @CashClothingReplacementAllowanceBasic
        = (@Basic_NonAccessions_Male * @Basic_NonAccessions_Perc_Male)
          + (@Basic_NonAccessions_FeMale * (1 - @Basic_NonAccessions_Perc_Male));

    SET @CashClothingReplacementAllowanceStandard
        = (@CashClothingReplacementAllowanceStandardMale * @Standard_Perc_Male)
          + (@CashClothingReplacementAllowanceStandardFemale * (1 - @Standard_Perc_Male));

    -- New GI Bill Cost 
    -- Eligible individuals can use up to four years of benefits. We assume that four years of benefits divided by the total eligible population 
    -- approximates the per capita cost of the program; this approach as the usage rate built into it since it is factored into the DVA budget numbers.
    -- (We are approaching this from an accrual accounting perspective; in other words, we are trying to calculate the appropriate set-aside for 
    -- future benefit usage for today's soldiers.)

    -- ARE WE OVERESTIMATING THE COST BECAUSE THE SET-ASIDE IS A ONE TIME EVENT?
    -- Another approach might be to take the cost-per-eligible-per-year, multiply by the delimiting period (12 years) and then amortize from the 
    -- point of entry. This yields approximately two-thirds the cost reflected here.
    DECLARE @PCS_Total_Sep_Moves FLOAT;
    SET @PCS_Total_Sep_Moves = @EnlistedPCSSeparationMoveBudget / @PCS_Separation_Move_Cost;
    DECLARE @PCS_Total_Ops_Moves FLOAT;
    SET @PCS_Total_Ops_Moves = @EnlistedPCSOperationalMoveBudget / @PCS_Operational_Move_Cost;
    DECLARE @PCS_Total_Rot_Moves FLOAT;
    SET @PCS_Total_Rot_Moves = @EnlistedPCSRotationalMoveBudget / @PCS_Rotational_Move_Cost;

    DECLARE @PCS_E04_Total_Inv FLOAT;
    SELECT @PCS_E04_Total_Inv = SUM(Inventory)
    FROM crunch.InventoryByCategorySubgroupGrade('AE')
    WHERE GradeLevel = 4;

    DECLARE @PCS_E04_Pct_Over2 FLOAT;
    SET @PCS_E04_Pct_Over2 = (@PCS_E04_Total_Inv -
                              (
                                  SELECT SUM(Amount)
                                  FROM #InventoryByCategorySubgroupGradeYos
                                  WHERE GradeLevel = 4
                                        AND YOS = 1
                              ) -
                              (
                                  SELECT SUM(Amount)
                                  FROM #InventoryByCategorySubgroupGradeYos
                                  WHERE GradeLevel = 4
                                        AND YOS = 2
                              )
                             ) / @PCS_E04_Total_Inv;
    DECLARE @tblPCS_Avg_Weight_Allowance TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS_Avg_Weight_Allowance
    SELECT tblWDep.GradeType,
           tblWDep.GradeLevel,
           tblWDep.sumAmount * tblPctDep.Amount + tblWoDep.sumAmount * (1 - tblPctDep.Amount) AS avgWeightAllowance
    FROM
    (
        SELECT tblOther.GradeType,
               tblOther.GradeLevel,
               tblOther.Amount + tblE04.weightE04 AS sumAmount
        FROM
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM dataload.AE_PCS
            WHERE (Code = 'WA_wDep')
        ) tblOther
            INNER JOIN
            (
                SELECT tblMore.GradeType,
                       tblMore.GradeLevel,
                       (tblMore.w3more * @PCS_E04_Pct_Over2) + (tblLess.w2less * (1 - @PCS_E04_Pct_Over2)) AS weightE04
                FROM
                (
                    SELECT GradeType,
                           GradeLevel,
                           Amount AS w3more
                    FROM dataload.AE_PCS
                    WHERE (Code = 'WA_wDep3more')
                ) tblMore
                    INNER JOIN
                    (
                        SELECT GradeType,
                               GradeLevel,
                               Amount AS w2less
                        FROM dataload.AE_PCS
                        WHERE (Code = 'WA_wDep2less')
                    ) tblLess
                        ON tblMore.GradeType = tblLess.GradeType
                           AND tblMore.GradeLevel = tblLess.GradeLevel
            ) tblE04
                ON tblOther.GradeType = tblE04.GradeType
                   AND tblOther.GradeLevel = tblE04.GradeLevel
    ) tblWDep
        INNER JOIN
        (
            SELECT tblOther.GradeType,
                   tblOther.GradeLevel,
                   tblOther.Amount + tblE04.weightE04 AS sumAmount
            FROM
            (
                SELECT GradeType,
                       GradeLevel,
                       Amount
                FROM dataload.AE_PCS
                WHERE (Code = 'WA_woDep')
            ) tblOther
                INNER JOIN
                (
                    SELECT tblMore.GradeType,
                           tblMore.GradeLevel,
                           (tblMore.w3more * @PCS_E04_Pct_Over2) + (tblLess.w2less * (1 - @PCS_E04_Pct_Over2)) AS weightE04
                    FROM
                    (
                        SELECT GradeType,
                               GradeLevel,
                               Amount AS w3more
                        FROM dataload.AE_PCS
                        WHERE (Code = N'WA_woDep3more')
                    ) tblMore
                        INNER JOIN
                        (
                            SELECT GradeType,
                                   GradeLevel,
                                   Amount AS w2less
                            FROM dataload.AE_PCS
                            WHERE (Code = N'WA_woDep2less')
                        ) tblLess
                            ON tblMore.GradeType = tblLess.GradeType
                               AND tblMore.GradeLevel = tblLess.GradeLevel
                ) tblE04
                    ON tblOther.GradeType = tblE04.GradeType
                       AND tblOther.GradeLevel = tblE04.GradeLevel
        ) tblWoDep
            ON tblWDep.GradeType = tblWoDep.GradeType
               AND tblWDep.GradeLevel = tblWoDep.GradeLevel
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM #MilitaryCompensationAllowances
            WHERE (Code = N'BAH_PWD')
        ) tblPctDep
            ON tblWoDep.GradeType = tblPctDep.GradeType
               AND tblWoDep.GradeLevel = tblPctDep.GradeLevel;

    DECLARE @PCS_Total_Weight FLOAT;
    SELECT @PCS_Total_Weight = SUM(weight)
    FROM
    (
        SELECT tblAvgAllow.GradeType,
               tblAvgAllow.GradeLevel,
               tblAvgAllow.Amount * Inventory.Amount AS weight
        FROM
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM @tblPCS_Avg_Weight_Allowance
        ) tblAvgAllow
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON Inventory.GradeType = tblAvgAllow.GradeType
                   AND Inventory.GradeLevel = tblAvgAllow.GradeLevel
    ) tblWeight;

    -- Multiplier is the ratio of the weight allowance for a particular grade to the overall (inventory adjusted) weight allowance.
    -- Grade Multiplier
    DECLARE @tblPCS_Multiplier TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS_Multiplier
    SELECT GradeType,
           GradeLevel,
           Amount / (@PCS_Total_Weight / @TotalInventoryForPayPlan)
    FROM @tblPCS_Avg_Weight_Allowance;

    -- Rotational move cost Per Grade
    DECLARE @tblPCS_Costs_Rot TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS_Costs_Rot
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Rotational_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Operational move cost Per Grade
    DECLARE @tblPCS_Costs_Ops TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS_Costs_Ops
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Operational_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Seperational move cost Per Grade
    DECLARE @tblPCS_Costs_Sep TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS_Costs_Sep
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Separation_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Training move cost Per Grade
    DECLARE @tblPCS_Costs_Training TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblPCS_Costs_Training
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Training_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Probability of Separation Move
    DROP TABLE IF EXISTS #ProbabilityOfSeparationMove;
    CREATE TABLE #ProbabilityOfSeparationMove
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO #ProbabilityOfSeparationMove
    SELECT tblAvgInv.GradeType,
           tblAvgInv.GradeLevel,
           ((@PCS_Total_Sep_Moves / @TotalNumLstlp) * NumberOfLumpSumTerminalLeavePayments.Amount) / tblAvgInv.Amount
    FROM crunch.AverageInventoryProjected('AE') tblAvgInv
        INNER JOIN crunch.NumberOfLumpSumTerminalLeavePayments('AE') NumberOfLumpSumTerminalLeavePayments
            ON tblAvgInv.GradeType = NumberOfLumpSumTerminalLeavePayments.GradeType
               AND tblAvgInv.GradeLevel = NumberOfLumpSumTerminalLeavePayments.GradeLevel;

    -- Probability of Accession Move
    DECLARE @tblProbAccession TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblProbAccession
    SELECT GradeType,
           GradeLevel,
           (@HQ_Recruits + @LQ_Recruits) /
           (
               SELECT SUM(Amount)
               FROM crunch.AverageInventoryProjected('AE')
               WHERE GradeLevel IN ( 1, 2, 3 )
           ) sumE1E3
    FROM crunch.AverageInventoryProjected('AE');

    UPDATE @tblProbAccession
    SET Amount = 0
    WHERE GradeLevel NOT IN ( 1, 2, 3 );

    -- Calculate the probability of a rots move a rots move is calculated as the probability twice the probability of being overseas.
    -- Divided by the average tour length (twice is to cover being rotated in and out) less the probabilities of being rotated in on an accession move or rotated out on a separation move.
    -- Probability of Operational Move
    DECLARE @tblProbOfOperation TABLE
    (
        MOS VARCHAR(3) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        MOS,
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblProbOfOperation
    SELECT tblOCONUS.MOS,
           tblSep.GradeType,
           tblSep.GradeLevel,
           (1 - tblOCONUS.Amount) / tblCONUS.Amount
           - (tblOCONUS.Amount / @PCS_Avg_OCONUS_Tour_Length - tblOCONUS.Amount * tblSep.Amount)
    FROM #ProbabilityOfSeparationMove tblSep
        CROSS JOIN #tblOconus tblOCONUS
        INNER JOIN #tblConus tblCONUS
            ON tblOCONUS.MOS = tblCONUS.MOS;
    UPDATE @tblProbOfOperation
    SET Amount = 0
    WHERE Amount < 0;

    -- Probability of Rotational Move
    DECLARE @tblProbOfRotation TABLE
    (
        MOS VARCHAR(3) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        MOS,
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblProbOfRotation
    SELECT tblOCONUS.MOS,
           tblAcc.GradeType,
           tblAcc.GradeLevel,
           tblOCONUS.Amount * 2 / @PCS_Avg_OCONUS_Tour_Length - (tblOCONUS.Amount * tblAcc.Amount)
           - (tblOCONUS.Amount * tblSep.Amount)
    FROM @tblProbAccession tblAcc
        INNER JOIN #ProbabilityOfSeparationMove tblSep
            ON tblAcc.GradeType = tblSep.GradeType
               AND tblAcc.GradeLevel = tblSep.GradeLevel
        CROSS JOIN #tblOconus tblOCONUS;
    UPDATE @tblProbOfRotation
    SET Amount = 0
    WHERE Amount < 0;

    -- Now smooth the probabilities to match the budget
    DECLARE @PCS_Est_Total_Ops_Moves FLOAT;
    SELECT @PCS_Est_Total_Ops_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblOps.Amount * Inventory.Amount AS calAmount
        FROM @tblProbOfOperation tblOps
            INNER JOIN #InventoryByCategorySubgroupGradeYos Inventory
                ON tblOps.GradeType = Inventory.GradeType
                   AND tblOps.GradeLevel = Inventory.GradeLevel
                   AND tblOps.MOS = Inventory.MOS
    ) tblCal;

    DECLARE @PCS_Est_Total_Ops_Cost FLOAT;
    SELECT @PCS_Est_Total_Ops_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblOpsCosts.Amount * tblOps.Amount * Inventory.Amount AS calAmount
        FROM @tblProbOfOperation tblOps
            INNER JOIN #InventoryByCategorySubgroupGradeYos Inventory
                ON tblOps.GradeType = Inventory.GradeType
                   AND tblOps.GradeLevel = Inventory.GradeLevel
                   AND tblOps.MOS = Inventory.MOS
            INNER JOIN @tblPCS_Costs_Ops tblOpsCosts
                ON tblOps.GradeType = tblOpsCosts.GradeType
                   AND tblOps.GradeLevel = tblOpsCosts.GradeLevel
    ) tblCal;

    DECLARE @PCS_Est_Total_Rot_Moves FLOAT;
    SELECT @PCS_Est_Total_Rot_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblRot.Amount * Inventory.Amount AS calAmount
        FROM @tblProbOfRotation tblRot
            INNER JOIN #InventoryByCategorySubgroupGradeYos Inventory
                ON tblRot.GradeType = Inventory.GradeType
                   AND tblRot.GradeLevel = Inventory.GradeLevel
                   AND tblRot.MOS = Inventory.MOS
    ) tblCal;

    DECLARE @PCS_Est_Total_Rot_Cost FLOAT;
    SELECT @PCS_Est_Total_Rot_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblRotCosts.Amount * tblRot.Amount * Inventory.Amount AS calAmount
        FROM @tblProbOfRotation tblRot
            INNER JOIN #InventoryByCategorySubgroupGradeYos Inventory
                ON tblRot.GradeType = Inventory.GradeType
                   AND tblRot.GradeLevel = Inventory.GradeLevel
                   AND tblRot.MOS = Inventory.MOS
            INNER JOIN @tblPCS_Costs_Rot tblRotCosts
                ON Inventory.GradeType = tblRotCosts.GradeType
                   AND Inventory.GradeLevel = tblRotCosts.GradeLevel
    ) tblCal;

    DECLARE @PCS_Est_Total_Sep_Moves FLOAT;
    SELECT @PCS_Est_Total_Sep_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblSep.Amount * Inventory.Amount AS calAmount
        FROM #ProbabilityOfSeparationMove tblSep
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON tblSep.GradeType = Inventory.GradeType
                   AND tblSep.GradeLevel = Inventory.GradeLevel
    ) tblCal;

    DECLARE @PCS_Est_Total_Sep_Cost FLOAT;
    SELECT @PCS_Est_Total_Sep_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblSepCosts.Amount * tblSep.Amount * Inventory.Amount AS calAmount
        FROM #ProbabilityOfSeparationMove tblSep
            INNER JOIN @tblPCS_Costs_Sep tblSepCosts
                ON tblSep.GradeType = tblSepCosts.GradeType
                   AND tblSep.GradeLevel = tblSepCosts.GradeLevel
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON tblSepCosts.GradeType = Inventory.GradeType
                   AND tblSepCosts.GradeLevel = Inventory.GradeLevel
    ) tblCal;

    -- Adjust the average cost per move to reflect the mix of grades that are going on the moves.
    -- This is necessary because there are fewer rots/ops moves in the cheaper grades. 
    -- They are covered w/acc moves.
    UPDATE @tblPCS_Costs_Rot
    SET Amount = Amount * (@PCS_Rotational_Move_Cost / (@PCS_Est_Total_Rot_Cost / @PCS_Est_Total_Rot_Moves));
    UPDATE @tblPCS_Costs_Ops
    SET Amount = Amount * (@PCS_Operational_Move_Cost / (@PCS_Est_Total_Ops_Cost / @PCS_Est_Total_Ops_Moves));
    UPDATE @tblPCS_Costs_Sep
    SET Amount = Amount * (@PCS_Separation_Move_Cost / (@PCS_Est_Total_Sep_Cost / @PCS_Est_Total_Sep_Moves));

    -- Now adjust the move number to what it would be under the projected inventory
    SET @PCS_Est_Total_Ops_Moves = @PCS_Est_Total_Ops_Moves * (@TotalAvgInvPrj / @TotalInventoryForPayPlan);
    SET @PCS_Est_Total_Rot_Moves = @PCS_Est_Total_Rot_Moves * (@TotalAvgInvPrj / @TotalInventoryForPayPlan);

    -- Now adjust the number of moves to match the budget projection
    UPDATE @tblProbOfOperation
    SET Amount = Amount * (@PCS_Total_Ops_Moves / @PCS_Est_Total_Ops_Moves);
    UPDATE @tblProbOfRotation
    SET Amount = Amount * (@PCS_Total_Rot_Moves / @PCS_Est_Total_Rot_Moves);

    -- Compute the average annualized PCS cost (ops, rots, sep) for each MOS.
    -- I have commented out the piece that adds seps. 
    DECLARE @tblPCS_Annualized TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    IF EXISTS (SELECT Amount FROM @tblProbOfOperation WHERE MOS = @MOS)
    BEGIN
        INSERT INTO @tblPCS_Annualized
        SELECT tblProbOps.GradeType,
               tblProbOps.GradeLevel,
               (tblProbOps.Amount * tblCostOps.Amount) + (tblProbRot.Amount * tblCostRot.Amount)
        FROM @tblProbOfOperation tblProbOps
            INNER JOIN @tblPCS_Costs_Ops tblCostOps
                ON tblCostOps.GradeType = tblProbOps.GradeType
                   AND tblCostOps.GradeLevel = tblProbOps.GradeLevel
            INNER JOIN @tblProbOfRotation tblProbRot
                ON tblProbOps.GradeType = tblProbRot.GradeType
                   AND tblProbOps.GradeLevel = tblProbRot.GradeLevel
            INNER JOIN @tblPCS_Costs_Rot tblCostRot
                ON tblProbRot.GradeType = tblCostRot.GradeType
                   AND tblProbRot.GradeLevel = tblCostRot.GradeLevel
        WHERE tblProbOps.MOS = @MOS
              AND tblProbRot.MOS = @MOS;
    END;
    ELSE
    BEGIN
        INSERT INTO @tblPCS_Annualized
        SELECT tblProbOps.GradeType,
               tblProbOps.GradeLevel,
               (tblProbOps.Amount * tblCostOps.Amount) + (tblProbRot.Amount * tblCostRot.Amount)
        FROM @tblProbOfOperation tblProbOps
            INNER JOIN @tblPCS_Costs_Ops tblCostOps
                ON tblCostOps.GradeType = tblProbOps.GradeType
                   AND tblCostOps.GradeLevel = tblProbOps.GradeLevel
            INNER JOIN @tblProbOfRotation tblProbRot
                ON tblProbOps.GradeType = tblProbRot.GradeType
                   AND tblProbOps.GradeLevel = tblProbRot.GradeLevel
            INNER JOIN @tblPCS_Costs_Rot tblCostRot
                ON tblProbRot.GradeType = tblCostRot.GradeType
                   AND tblProbRot.GradeLevel = tblCostRot.GradeLevel
        WHERE tblProbOps.MOS = 'ZZZ'
              AND tblProbRot.MOS = 'ZZZ';
    END;

    /* INSERT COST FACTORS */

    /* Military Compensation; Avg Cost of Base Pay (Military) */
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 1 AS CostElementId,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgCostOfBasePayMilitary('AE', @MOS);

    -- Avg Cost of Tax Advantage
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 6 AS CostElementId,
           tblRMC.GradeType,
           tblRMC.GradeLevel,
           (tblRMC.Amount - tblBasePay.Amount - tblBAS.Amount - tblBASinCash.Amount) AS calAmount
    FROM
    (
        SELECT GradeType,
               GradeLevel,
               Amount
        FROM #CrunchCosts
        WHERE CostElementId = 102
    ) tblRMC
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM #CrunchCosts
            WHERE CostElementId = 100
        ) tblBasePay
            ON tblRMC.GradeType = tblBasePay.GradeType
               AND tblRMC.GradeLevel = tblBasePay.GradeLevel
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM #CrunchCosts
            WHERE CostElementId = 101
        ) tblBAS
            ON tblRMC.GradeType = tblBAS.GradeType
               AND tblRMC.GradeLevel = tblBAS.GradeLevel
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM #CrunchCosts
            WHERE CostElementId = 103
        ) tblBASinCash
            ON tblRMC.GradeType = tblBASinCash.GradeType
               AND tblRMC.GradeLevel = tblBASinCash.GradeLevel;

    -- Other Benefits 
    -- Avg Cost of Medical Support Cost
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 74 AS CostElementId,
           GradeType,
           GradeLevel,
           @Health_Care_Cost_Per_Family_Member AS calAmount
    FROM dataload.AE_OtherBenefits
    WHERE Code = 'AFS'
          AND EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND AE_OtherBenefits.GradeLevel = GradeLevel
    );

    -- Morale, Welfare and Recreation Costs: Avg Cost of Morale, Welfare and Recreation	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 75 AS CostElementId,
           GradeType,
           GradeLevel,
           (@MoraleWelfareRecreation / @Avg_OE_End_Strength) AS calAmount
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- Other Benefits: Avg Cost of Miscellaneous
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 9,
           GradeType,
           GradeLevel,
           (@Misc / @TotalAvgInvPrj) AS calAmount
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- Other Benefits: Avg Cost of Survivor Benefits
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 11 AS CostElementId,
           GradeType,
           GradeLevel,
           (@Survivor / @TotalAvgInvPrj) AS calAmount
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- Other Benefits: Avg Cost of Clothing Allowance E1 - E3
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 7 AS CostElementId,
           GradeType,
           GradeLevel,
           (
           (
               SELECT ISNULL(SUM(tblInvA.Amount), 0)
               FROM #InventoryByCategorySubgroupGradeYos tblInvA
               WHERE MOS = @MOS
                     AND YOS = 1
                     AND tblInvA.GradeType = tblCost.GradeType
                     AND tblInvA.GradeLevel = tblCost.GradeLevel
           ) /
           (
               SELECT ISNULL(SUM(tblInvB.Amount), 1)
               FROM #InventoryByCategorySubgroupGradeYos tblInvB
               WHERE MOS = @MOS
                     AND tblInvB.GradeType = tblCost.GradeType
                     AND tblInvB.GradeLevel = tblCost.GradeLevel
           ) * @StandardInitialClothingAllowance
           )
           + ((1 - (
           (
               SELECT ISNULL(SUM(tblInvC.Amount), 0)
               FROM #InventoryByCategorySubgroupGradeYos tblInvC
               WHERE MOS = @MOS
                     AND YOS = 1
                     AND tblInvC.GradeType = tblCost.GradeType
                     AND tblInvC.GradeLevel = tblCost.GradeLevel
           ) /
           (
               SELECT ISNULL(SUM(tblInvD.Amount), 1)
               FROM #InventoryByCategorySubgroupGradeYos tblInvD
               WHERE MOS = @MOS
                     AND tblInvD.GradeType = tblCost.GradeType
                     AND tblInvD.GradeLevel = tblCost.GradeLevel
           )
                   )
              ) * @CashClothingReplacementAllowanceBasic
             ) AS calAmount
    FROM
    (
        SELECT GradeType,
               GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND GradeLevel IN ( 1, 2, 3 )
    ) tblCost;

    -- Other Benefits: Avg Cost of Clothing Allowance E4 - E9
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 7 AS CostElementId,
           GradeType,
           GradeLevel,
           @CashClothingReplacementAllowanceStandard AS calAmount
    FROM
    (
        SELECT GradeType,
               GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND GradeLevel NOT IN ( 1, 2, 3 )
    ) tblGrade;

    -- **** RE_WRITE TO USE WEIGHTED AVERAGE TABLE ****
    -- Other Benefits: Avg Cost of FICA
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 8 AS CostElementId,
           tblFICA.GradeType,
           tblFICA.GradeLevel,
           tblFICA.sumCosts / Inventory.Amount * @FICA AS calAmount
    FROM
    (
        SELECT SUM(calAmount) AS sumCosts,
               GradeType,
               GradeLevel
        FROM
        (
            SELECT tblSalary.Amount * Inventory.Amount AS calAmount,
                   Inventory.GradeType,
                   Inventory.GradeLevel
            FROM
            (
                SELECT GradeType,
                       GradeLevel,
                       Step_YOS,
                       Amount = CASE
                                    WHEN Rate * 12 < @Max_Wage_SSW THEN
                                        Rate * 12
                                    ELSE
                                        @Max_Wage_SSW
                                END
                FROM data.PaySchedules
                WHERE (PayPlan = N'AE')
            ) tblSalary
                INNER JOIN
                (
                    SELECT SUM(Amount) AS Amount,
                           GradeType,
                           GradeLevel,
                           YOS
                    FROM #InventoryByCategorySubgroupGradeYos
                    WHERE (MOS = @MOS)
                          AND (Amount <> 0)
                    GROUP BY GradeType,
                             GradeLevel,
                             YOS
                ) Inventory
                    ON Inventory.GradeType = tblSalary.GradeType
                       AND Inventory.GradeLevel = tblSalary.GradeLevel
                       AND Inventory.YOS = tblSalary.Step_YOS
        ) tblCost
        GROUP BY GradeType,
                 GradeLevel
    ) tblFICA
        INNER JOIN
        (
            SELECT Amount,
                   GradeType,
                   GradeLevel
            FROM crunch.InventoryByGradeForCategorySubgroup('AE', @MOS)
            WHERE (Amount <> 0)
        ) Inventory
            ON Inventory.GradeType = tblFICA.GradeType
               AND Inventory.GradeLevel = tblFICA.GradeLevel
    WHERE EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND tblFICA.GradeType = GradeType
              AND tblFICA.GradeLevel = GradeLevel
    );

    -- Other Benefits: Avg Cost of Other Benefits
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 10 AS CostElementId,
           GradeType,
           GradeLevel,
           SUM(Amount) AS sumAmount
    FROM #CrunchCosts
    WHERE CostElementId IN ( 7, 8, 9, 11 )
    GROUP BY GradeType,
             GradeLevel;

    -- Retired Pay Accrual 
    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 32 AS CostElementId,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- Allowances: Avg Cost of Overseas Station Allowance	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 53,
           GradeType,
           GradeLevel,
           @OconusTourLength
           * (ISNULL(Amount, 0) * (@Tot_Amt_For_Temp_Lodging_Allowance + @Tot_Bdgt_For_Overseas_Station_Allowance)
              / @Tot_Bdgt_For_Overseas_Station_Allowance
             ) AS calAmount
    FROM dataload.AE_SpecialPays
    WHERE Code = 'OSA'
          AND GradeLevel IN
              (
                  SELECT GradeLevel FROM #CrunchCosts WHERE CostElementId = 1
              );

    -- Allowances: Avg Cost of Family Separation Pay	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 48,
           tblPCS.GradeType,
           tblPCS.GradeLevel,
           (tblWDep.Amount / Inventory.Amount) * (@Tot_ConusOverseas_30_Dep /
                                                  (
                                                      SELECT SUM(Amount) FROM @tblPrjWDep
                                                  )
                                                 ) + tblPCS.Amount / Inventory.Amount
    FROM @tblPCS2Home tblPCS
        INNER JOIN crunch.AverageInventoryProjected('AE') Inventory
            ON tblPCS.GradeType = Inventory.GradeType
               AND tblPCS.GradeLevel = Inventory.GradeLevel
        INNER JOIN @tblPrjWDep tblWDep
            ON Inventory.GradeType = tblWDep.GradeType
               AND Inventory.GradeLevel = tblWDep.GradeLevel
    WHERE tblPCS.GradeLevel IN
          (
              SELECT GradeLevel FROM #CrunchCosts WHERE CostElementId = 1
          );

    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 83,
           GradeType,
           GradeLevel,
           @MERHC
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- Separation Costs
    -- Separation Costs: Avg Cost Separation Moves - Annualized
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 43,
           ProbabilityOfSeparationMove.GradeType,
           ProbabilityOfSeparationMove.GradeLevel,
           ProbabilityOfSeparationMove.Amount * tblCost.Amount AS calAmount
    FROM #ProbabilityOfSeparationMove ProbabilityOfSeparationMove
        INNER JOIN @tblPCS_Costs_Sep tblCost
            ON ProbabilityOfSeparationMove.GradeType = tblCost.GradeType
               AND ProbabilityOfSeparationMove.GradeLevel = tblCost.GradeLevel
    WHERE ProbabilityOfSeparationMove.GradeLevel IN
          (
              SELECT GradeLevel FROM #CrunchCosts WHERE CostElementId = 1
          );

    -- Separation Costs: Avg Cost of Accrued Leave and Separation
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 44,
           tblLeave.GradeType,
           tblLeave.GradeLevel,
           tblLeave.Amount * ((@TotalLstlp + @Enlisted_Severence_Pay) / @TotalLstlp) / tblPrj.Amount AS calAmount
    FROM #LumpSumTerminalLeavePayments tblLeave
        INNER JOIN crunch.AverageInventoryProjected('AE') tblPrj
            ON tblLeave.GradeType = tblPrj.GradeType
               AND tblLeave.GradeLevel = tblPrj.GradeLevel
    WHERE tblLeave.GradeLevel IN
          (
              SELECT GradeLevel FROM #CrunchCosts WHERE CostElementId = 1
          );

    -- Separation Costs: Avg Cost of Full Involuntary Seperation Incentives	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 46,
           LumpSumTerminalLeavePayments.GradeType,
           LumpSumTerminalLeavePayments.GradeLevel,
           (@Sep_Pay_NonDis / @TotalLstlp) * LumpSumTerminalLeavePayments.Amount / AverageInventoryProjected.Amount AS calAmount
    FROM #LumpSumTerminalLeavePayments LumpSumTerminalLeavePayments
        INNER JOIN crunch.AverageInventoryProjected('AE') AverageInventoryProjected
            ON LumpSumTerminalLeavePayments.GradeType = AverageInventoryProjected.GradeType
               AND LumpSumTerminalLeavePayments.GradeLevel = AverageInventoryProjected.GradeLevel
    WHERE LumpSumTerminalLeavePayments.GradeLevel IN
          (
              SELECT GradeLevel FROM #CrunchCosts WHERE CostElementId = 1
          );

    -- Separation Costs: Avg Cost of Separation Incentives (Total)
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 45,
           GradeType,
           GradeLevel,
           SUM(Amount) AS sumAmount
    FROM #CrunchCosts
    WHERE CostElementId IN ( 43, 44, 46 )
    GROUP BY GradeType,
             GradeLevel;

    -- Permanent Change of Station Cost(PCS) 
    -- Permanent Change of Station Costs: Avg Cost of an Accession Move
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 12,
           AverageInventoryProjected.GradeType,
           AverageInventoryProjected.GradeLevel,
           @Accession_Move_Cost AS Amount
    FROM crunch.AverageInventoryProjected('AE') AverageInventoryProjected
    WHERE AverageInventoryProjected.GradeLevel IN ( 1, 2, 3 )
          AND EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND AverageInventoryProjected.GradeType = GradeType
              AND AverageInventoryProjected.GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Operational Move
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 13,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Costs_Ops
    WHERE EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND [@tblPCS_Costs_Ops].GradeType = GradeType
              AND [@tblPCS_Costs_Ops].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Rotational Move
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 14,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Costs_Rot
    WHERE EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND [@tblPCS_Costs_Rot].GradeType = GradeType
              AND [@tblPCS_Costs_Rot].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Separation Move
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 15,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Costs_Sep
    WHERE EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND [@tblPCS_Costs_Sep].GradeType = GradeType
              AND [@tblPCS_Costs_Sep].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Training Move
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 16,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Costs_Training
    WHERE EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND [@tblPCS_Costs_Training].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Permanent Change of Station-annualized (Total differance of (Ops + Rots))
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 17,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Annualized
    WHERE EXISTS
    (
        SELECT GradeLevel
        FROM #CrunchCosts
        WHERE CostElementId = 1
              AND [@tblPCS_Annualized].GradeLevel = GradeLevel
    );

    -- OSD CAPE DODI: Discount Groceries	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 774,
           GradeType,
           GradeLevel,
           @DiscountGroceries
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- OSD CAPE DODI: DoDEA and Family Assistance	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 775,
           GradeType,
           GradeLevel,
           @DoDEAandFamilyAssistance
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- OSD CAPE DODI: Child Education (Impact Aid)	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 773,
           GradeType,
           GradeLevel,
           @ChildEducation
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- OSD CAPE DODI: Treasury Contribution for Concurrent Receipts	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 777,
           GradeType,
           GradeLevel,
           @TreasuryContributionForConcurrentReceipts
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 778,
           GradeType,
           GradeLevel,
           @TreasuryContributionToMERHC
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    -- OSD CAPE DODI: Veterans' Benefits (Cash and In-kind)	
    INSERT INTO #CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 780,
           GradeType,
           GradeLevel,
           @VeteransBenefits
    FROM #CrunchCosts
    WHERE CostElementId = 1;

    /* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM #CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'AE'
              AND CategorySubGroupCode = @MOS
              AND [#CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );

    SELECT 'AE',
           @CMF,
           @MOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM #CrunchCosts;

END;