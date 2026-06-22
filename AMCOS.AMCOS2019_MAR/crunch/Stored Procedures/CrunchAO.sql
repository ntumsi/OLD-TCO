CREATE PROCEDURE [crunch].[CrunchAO]
    @AOC NVARCHAR(4),
    @AmcosVersionId INT = -1
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
        WHERE PayPlan = 'AO'
              AND CategorySubGroupCode = @AOC
    )
        RETURN 0;

    DECLARE @CrunchCosts TABLE
    (
        CostElementId INT NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        WeaponSystemId INT NOT NULL
            DEFAULT (-1),
        Amount FLOAT NULL,
        CrunchTime SMALLDATETIME NULL
    );

    /* IMPORT DATA */
    DECLARE @CMF NCHAR(2) = LEFT(@AOC, 2);
    DECLARE @TotalInventoryForPayPlan FLOAT;
    DECLARE @GradeType CHAR(1) = 'O';

    /* Total Inventory by GradeType, GradeLevel */
    BEGIN
        CREATE TABLE #InventoryByGradeForPayPlan
        (
            GradeType NVARCHAR(3) NOT NULL,
            GradeLevel TINYINT NOT NULL,
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
        FROM crunch.InventoryByGradeForPayPlan('AO');
    END;

    SELECT @TotalInventoryForPayPlan = SUM(Amount)
    FROM #InventoryByGradeForPayPlan;

    /* Average Inventory Projected */
    BEGIN
        DECLARE @tblAverage_Inv_Prj TABLE
        (
            GradeType NCHAR(1) NOT NULL,
            GradeLevel INT NOT NULL,
            Amount FLOAT NULL,
            PRIMARY KEY (
                            GradeType,
                            GradeLevel
                        )
        );
        INSERT INTO @tblAverage_Inv_Prj
        SELECT GradeType,
               GradeLevel,
               Amount
        FROM dataload.SepParms
        WHERE PayPlan = 'AO'
              AND Code = N'AI_PRJ';
    END;

    DECLARE @tblSpecialPaysElig TABLE
    (
        CMF NCHAR(2) NOT NULL PRIMARY KEY,
        OCONUS FLOAT NULL,
        Med FLOAT NULL,
        Dental FLOAT NULL,
        Vet FLOAT NULL,
        ACIP FLOAT NULL,
        Dive FLOAT NULL
    );
    INSERT INTO @tblSpecialPaysElig
    SELECT CMF,
           OCONUS,
           Medical,
           Dental,
           Vet,
           Aviation,
           Dive
    FROM dataload.AO_SpecialPaysElig;

    -- Leave Pay
    DECLARE @tblLstlp TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );
    INSERT INTO @tblLstlp
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM dataload.SepParms
    WHERE PayPlan = 'AO'
          AND Code = N'LSTLP';

    -- Number Leave Pay
    DECLARE @tblNumLstlp TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );
    INSERT INTO @tblNumLstlp
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM dataload.SepParms
    WHERE PayPlan = 'AO'
          AND Code = N'NUM_LSTLP';

    DECLARE @TotalAvgInvPrj FLOAT;
    DECLARE @TotalNumLstlp FLOAT;
    DECLARE @TotalLstlp FLOAT;
    DECLARE @Total_ProjEndStrength INT;

    SELECT @TotalAvgInvPrj = SUM(Amount)
    FROM @tblAverage_Inv_Prj;
    SELECT @TotalNumLstlp = SUM(Amount)
    FROM @tblNumLstlp;
    SELECT @TotalLstlp = SUM(Amount)
    FROM @tblLstlp;

    DECLARE @tblProjEndStrength TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );
    INSERT INTO @tblProjEndStrength
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM dataload.AO_ProjEndstrength;

    SELECT @Total_ProjEndStrength = SUM(Amount)
    FROM @tblProjEndStrength;

    /* Special Pay */
    BEGIN
        DECLARE @tblSpecialPaysBudget TABLE
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
        INSERT INTO @tblSpecialPaysBudget
        SELECT Code,
               GradeType,
               GradeLevel,
               Amount
        FROM dataload.AO_SpecialPaysBudget;
    END;

    /* PCS */
    BEGIN
        DECLARE @tblPCS TABLE
        (
            Code VARCHAR(20) NOT NULL,
            GradeType NCHAR(1) NOT NULL,
            GradeLevel INT NOT NULL,
            Amount FLOAT NULL,
            PRIMARY KEY (
                            Code,
                            GradeType,
                            GradeLevel
                        )
        );
        INSERT INTO @tblPCS
        SELECT Code,
               GradeType,
               GradeLevel,
               Amount
        FROM dataload.AO_PCS;
    END;

    /* Military Compensation Allowances */
    BEGIN
        DECLARE @tblMilCompAllowances TABLE
        (
            Code VARCHAR(20) NOT NULL,
            GradeType NCHAR(1) NOT NULL,
            GradeLevel INT NOT NULL,
            Amount FLOAT NULL,
            PRIMARY KEY (
                            Code,
                            GradeType,
                            GradeLevel
                        )
        );
        INSERT INTO @tblMilCompAllowances
        SELECT Code,
               GradeType,
               GradeLevel,
               Amount
        FROM dataload.AO_MilCompAllowances;
    END;

    /* COLLECT COST DATA */

    -- MISC Data
    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Max_Wage_SSW MONEY = crunch.GetSingleValue('AA', 'Max_Wage_SSW');

    DECLARE @Retired_Pay_Accrual FLOAT;
    DECLARE @Miscellaneous_Benefits FLOAT = crunch.GetArmyBudgetSingleValue('AO_Misc', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @MoraleWelfareRecreation INT
        = crunch.GetArmyBudgetSingleValue('MoraleWelfareRecreation', 'OMA', 'Avg', @AmcosVersionId);
    DECLARE @Avg_OE_End_Strength INT
        = crunch.GetArmyBudgetSingleValue('Avg_OE_End_Strength', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Health_Care_Cost_Per_Family_Member FLOAT;
    DECLARE @Sep_Pay_NonDis INT
        = crunch.GetArmyBudgetSingleValue('Officer_Sep_Pay_NonDis', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Officer_Severence_Pay FLOAT
        = crunch.GetArmyBudgetSingleValue('Officer_Severence_Pay', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @PCS_wDep_Not_Auth INT;
    DECLARE @TDY_30_Plus_Days_wDeps_Not_Near_Stn INT
        = crunch.GetArmyBudgetSingleValue('Officer_TDY_30_Plus_Days_wDeps_Not_Near_Stn', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Temp_Lodging_Allowance FLOAT;
    DECLARE @Other_FS_Bgt FLOAT;
    DECLARE @PCS_Number_Of_Officers_Commissioned INT;
    DECLARE @PCS_Training_Move_Cost INT;
    DECLARE @PCS_Operational_Move_Cost INT;
    DECLARE @PCS_Rotational_Move_Cost INT;
    DECLARE @PCS_Separation_Move_Cost INT;
    DECLARE @PCS_Avg_OCONUS_Tour_Length FLOAT;
    DECLARE @OfficerPCSOperationalMoveBudget INT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Operational_Move_Budget', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @OfficerPCSRotationalMoveBudget INT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Rotational_Move_Budget', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @OfficerPCSSeparationMoveBudget INT
        = crunch.GetArmyBudgetSingleValue('Officer_PCS_Separation_Move_Budget', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @PCS_Total_Weight FLOAT;
    DECLARE @PCS_Total_Sep_Moves FLOAT;
    DECLARE @PCS_Total_Ops_Moves FLOAT;
    DECLARE @PCS_Total_Rot_Moves FLOAT;
    DECLARE @PCS_Est_Total_Ops_Moves FLOAT;
    DECLARE @PCS_Est_Total_Sep_Moves FLOAT;
    DECLARE @PCS_Est_Total_Rot_Moves FLOAT;
    DECLARE @PCS_Est_Total_Ops_Cost FLOAT;
    DECLARE @PCS_Est_Total_Sep_Cost FLOAT;
    DECLARE @PCS_Est_Total_Rot_Cost FLOAT;



    DECLARE @TreasuryContributionToMERHC FLOAT = crunch.GetSingleValue('AA', 'TreasuryContributionToMERHC');




    SELECT @Health_Care_Cost_Per_Family_Member = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AA'
          AND paramName = 'Health_Care_Cost_Per_Family_Member';




    SELECT @Retired_Pay_Accrual = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AA'
          AND paramName = 'Retired_Pay_Accrual';

    SELECT @PCS_Avg_OCONUS_Tour_Length = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_Avg_OCONUS_Tour_Length';

    SELECT @PCS_Number_Of_Officers_Commissioned = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_Number_Of_Officers_Commissioned';

    SELECT @PCS_Operational_Move_Cost = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_Operational_Move_Cost';

    SELECT @PCS_Rotational_Move_Cost = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_Rotational_Move_Cost';

    SELECT @PCS_Separation_Move_Cost = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_Separation_Move_Cost';

    SELECT @PCS_Training_Move_Cost = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_Training_Move_Cost';

    SELECT @PCS_wDep_Not_Auth = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'PCS_wDep_Not_Auth';

    SELECT @Temp_Lodging_Allowance = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'AO'
          AND paramName = 'Temp_Lodging_Allowance';

    SET @PCS_Total_Sep_Moves = @OfficerPCSSeparationMoveBudget / @PCS_Separation_Move_Cost;
    SET @PCS_Total_Ops_Moves = @OfficerPCSOperationalMoveBudget / @PCS_Operational_Move_Cost;
    SET @PCS_Total_Rot_Moves = @OfficerPCSRotationalMoveBudget / @PCS_Rotational_Move_Cost;

    SET @Other_FS_Bgt = @PCS_wDep_Not_Auth + @TDY_30_Plus_Days_wDeps_Not_Near_Stn;

    DECLARE @tblWeightwDep TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );
    INSERT INTO @tblWeightwDep
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS
    WHERE Code = 'WA_wDep';

    DECLARE @tblWeightwoDep TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );
    INSERT INTO @tblWeightwoDep
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS
    WHERE Code = 'WA_woDep';

    DECLARE @tblPctwDep TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );
    INSERT INTO @tblPctwDep
    SELECT GradeType,
           GradeLevel,
           Amount
    FROM @tblMilCompAllowances
    WHERE Code = 'BAH_PWD';

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
    SELECT tblPct.GradeType,
           tblPct.GradeLevel,
           tblWDep.Amount * tblPct.Amount + tblWoDep.Amount * (1 - tblPct.Amount)
    FROM @tblWeightwDep tblWDep
        INNER JOIN @tblWeightwoDep tblWoDep
            ON tblWDep.GradeType = tblWoDep.GradeType
               AND tblWDep.GradeLevel = tblWoDep.GradeLevel
        INNER JOIN @tblPctwDep tblPct
            ON tblWoDep.GradeType = tblPct.GradeType
               AND tblWoDep.GradeLevel = tblPct.GradeLevel;



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

    -- Grade Multiplier
    -- Multiplier is the ratio of the weight allowance for a particular grade to the
    -- overall (inventory adjusted) weight allowance
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

    -- Cost per grade is calculated as the average cost times the grade multiplier
    -- Rotational move cost Per Grade
    DECLARE @PCSCostsRotationalMove TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @PCSCostsRotationalMove
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Rotational_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Operational move cost Per Grade
    DECLARE @PCSCostsOperationalMove TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @PCSCostsOperationalMove
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
    DECLARE @ProbabilityOfSeparationMove TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );

    INSERT INTO @ProbabilityOfSeparationMove
    SELECT tblAvgInv.GradeType,
           tblAvgInv.GradeLevel,
           (@PCS_Total_Sep_Moves / @TotalNumLstlp) * tblLst.Amount / tblAvgInv.Amount
    FROM @tblAverage_Inv_Prj tblAvgInv
        INNER JOIN @tblNumLstlp tblLst
            ON tblAvgInv.GradeType = tblLst.GradeType
               AND tblAvgInv.GradeLevel = tblLst.GradeLevel;

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

    IF @PCS_Number_Of_Officers_Commissioned >
    (
        SELECT SUM(Amount) FROM #InventoryByGradeForPayPlan WHERE GradeLevel = 1
    )
    BEGIN
        INSERT INTO @tblProbAccession
        SELECT GradeType,
               GradeLevel,
               1
        FROM @tblAverage_Inv_Prj;
    END;
    ELSE
    BEGIN
        INSERT INTO @tblProbAccession
        SELECT GradeType,
               GradeLevel,
               @PCS_Number_Of_Officers_Commissioned /
               (
                   SELECT SUM(Amount) FROM #InventoryByGradeForPayPlan WHERE GradeLevel = 1
               ) sumO1
        FROM @tblAverage_Inv_Prj;
    END;

    UPDATE @tblProbAccession
    SET Amount = 0
    WHERE GradeLevel <> 1;

    /* Calculate the probability of a rotational move.  A rotational move is calculated as the probability twice the probability of being overseas
    Divided by the average tour length (twice is to cover being rotated in and out) less the probabilities of being rotated in on an accession move
	or rotated out on a separation move. */
    /*    Probability of Operational Move */
    DECLARE @ProbabilityOfOperationalMove TABLE
    (
        CMF NCHAR(2) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        CMF,
                        GradeType,
                        GradeLevel
                    )
    );

    INSERT INTO @ProbabilityOfOperationalMove
    SELECT tblPct.CMF,
           ProbabilityOfSeparationMove.GradeType,
           ProbabilityOfSeparationMove.GradeLevel,
           (1 - tblPct.OCONUS) / Branch.CONUSTourLength
           - (tblPct.OCONUS / @PCS_Avg_OCONUS_Tour_Length - tblPct.OCONUS * ProbabilityOfSeparationMove.Amount)
    FROM @ProbabilityOfSeparationMove ProbabilityOfSeparationMove
        CROSS JOIN @tblSpecialPaysElig tblPct
        INNER JOIN lookup.CMF_Branch_FA Branch
            ON tblPct.CMF = Branch.Code
    WHERE Branch.GradeType = 'O';

    UPDATE @ProbabilityOfOperationalMove
    SET Amount = 0
    WHERE Amount < 0;

    -- Probability of Rotational Move
    DECLARE @ProbabilityOfRotationalMove TABLE
    (
        CMF NCHAR(2) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        CMF,
                        GradeType,
                        GradeLevel
                    )
    );

    INSERT INTO @ProbabilityOfRotationalMove
    SELECT tblPct.CMF,
           tblAcc.GradeType,
           tblAcc.GradeLevel,
           tblPct.OCONUS * 2 / @PCS_Avg_OCONUS_Tour_Length - (tblPct.OCONUS * tblAcc.Amount)
           - (tblPct.OCONUS * ProbabilityOfSeparationMove.Amount)
    FROM @tblProbAccession tblAcc
        INNER JOIN @ProbabilityOfSeparationMove ProbabilityOfSeparationMove
            ON tblAcc.GradeType = ProbabilityOfSeparationMove.GradeType
               AND tblAcc.GradeLevel = ProbabilityOfSeparationMove.GradeLevel
        CROSS JOIN @tblSpecialPaysElig tblPct;

    UPDATE @ProbabilityOfRotationalMove
    SET Amount = 0
    WHERE Amount < 0;

    -- Now smooth the probabilities to match the budget
    SELECT @PCS_Est_Total_Ops_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT ISNULL(tblOps.Amount, 0) * ISNULL(Inventory.Amount, 0) AS calAmount
        FROM @ProbabilityOfOperationalMove tblOps
            INNER JOIN crunch.InventoryByCategoryGroupGradeYos('AO') Inventory
                ON tblOps.GradeType = Inventory.GradeType
                   AND tblOps.GradeLevel = Inventory.GradeLevel
                   AND tblOps.CMF = Inventory.CategoryGroupCode
    ) tblCal;

    SELECT @PCS_Est_Total_Ops_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT ISNULL(tblOpsCosts.Amount, 0) * ISNULL(tblOps.Amount, 0) * ISNULL(Inventory.Amount, 0) AS calAmount
        FROM @ProbabilityOfOperationalMove tblOps
            INNER JOIN crunch.InventoryByCategoryGroupGradeYos('AO') Inventory
                ON tblOps.GradeType = Inventory.GradeType
                   AND tblOps.GradeLevel = Inventory.GradeLevel
                   AND tblOps.CMF = Inventory.CategoryGroupCode
            INNER JOIN @PCSCostsOperationalMove tblOpsCosts
                ON tblOps.GradeType = tblOpsCosts.GradeType
                   AND tblOps.GradeLevel = tblOpsCosts.GradeLevel
    ) tblCal;

    SELECT @PCS_Est_Total_Rot_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT ISNULL(tblRot.Amount, 0) * Inventory.Amount AS calAmount
        FROM @ProbabilityOfRotationalMove tblRot
            INNER JOIN crunch.InventoryByCategoryGroupGradeYos('AO') Inventory
                ON tblRot.GradeType = Inventory.GradeType
                   AND tblRot.GradeLevel = Inventory.GradeLevel
                   AND tblRot.CMF = Inventory.CategoryGroupCode
    ) tblCal;

    SELECT @PCS_Est_Total_Rot_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblRotCosts.Amount * ISNULL(tblRot.Amount, 0) * Inventory.Amount AS calAmount
        FROM @ProbabilityOfRotationalMove tblRot
            INNER JOIN crunch.InventoryByCategoryGroupGradeYos('AO') Inventory
                ON tblRot.GradeType = Inventory.GradeType
                   AND tblRot.GradeLevel = Inventory.GradeLevel
                   AND tblRot.CMF = Inventory.CategoryGroupCode
            INNER JOIN @PCSCostsRotationalMove tblRotCosts
                ON Inventory.GradeType = tblRotCosts.GradeType
                   AND Inventory.GradeLevel = tblRotCosts.GradeLevel
    ) tblCal;

    SELECT @PCS_Est_Total_Sep_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT ProbabilityOfSeparationMove.Amount * Inventory.Amount AS calAmount
        FROM @ProbabilityOfSeparationMove ProbabilityOfSeparationMove
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON ProbabilityOfSeparationMove.GradeType = Inventory.GradeType
                   AND ProbabilityOfSeparationMove.GradeLevel = Inventory.GradeLevel
    ) tblCal;

    SELECT @PCS_Est_Total_Sep_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblSepCosts.Amount * ProbabilityOfSeparationMove.Amount * Inventory.Amount AS calAmount
        FROM @ProbabilityOfSeparationMove ProbabilityOfSeparationMove
            INNER JOIN @tblPCS_Costs_Sep tblSepCosts
                ON ProbabilityOfSeparationMove.GradeType = tblSepCosts.GradeType
                   AND ProbabilityOfSeparationMove.GradeLevel = tblSepCosts.GradeLevel
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON tblSepCosts.GradeType = Inventory.GradeType
                   AND tblSepCosts.GradeLevel = Inventory.GradeLevel
    ) tblCal;

    -- Adjust the average cost per move to reflect the mix of grades that are going on the moves.
    -- This is necessary because there are fewer rots/ops moves in the cheaper grades. 
    -- They are covered w/accession moves.
    UPDATE @PCSCostsRotationalMove
    SET Amount = Amount * (@PCS_Rotational_Move_Cost / (@PCS_Est_Total_Rot_Cost / @PCS_Est_Total_Rot_Moves));
    UPDATE @PCSCostsOperationalMove
    SET Amount = Amount * (@PCS_Operational_Move_Cost / (@PCS_Est_Total_Ops_Cost / @PCS_Est_Total_Ops_Moves));
    UPDATE @tblPCS_Costs_Sep
    SET Amount = Amount * (@PCS_Separation_Move_Cost / (@PCS_Est_Total_Sep_Cost / @PCS_Est_Total_Sep_Moves));

    -- Now adjust the move number to what it would be under the projected inventory
    SET @PCS_Est_Total_Ops_Moves = @PCS_Est_Total_Ops_Moves * (@TotalAvgInvPrj / @TotalInventoryForPayPlan);
    SET @PCS_Est_Total_Rot_Moves = @PCS_Est_Total_Rot_Moves * (@TotalAvgInvPrj / @TotalInventoryForPayPlan);

    -- Now adjust the number of moves to match the budget projection
    UPDATE @ProbabilityOfOperationalMove
    SET Amount = Amount * (@PCS_Total_Ops_Moves / @PCS_Est_Total_Ops_Moves);
    UPDATE @ProbabilityOfRotationalMove
    SET Amount = Amount * (@PCS_Total_Rot_Moves / @PCS_Est_Total_Rot_Moves);

    -- Compute the average annualized PCS cost (ops, rots, sep) for each MOS.
    -- I have commented out the piece that adds seps. 
    DECLARE @tblPCS_Annualized TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL
    );

    IF EXISTS
    (
        SELECT Amount
        FROM @ProbabilityOfOperationalMove
        WHERE CMF = @CMF
    )
    BEGIN
        INSERT INTO @tblPCS_Annualized
        SELECT ProbabilityOfOperationalMove.GradeType,
               ProbabilityOfOperationalMove.GradeLevel,
               (ISNULL(ProbabilityOfOperationalMove.Amount, 0) * ISNULL(PCSCostsOperationalMove.Amount, 0))
               + (ISNULL(ProbabilityOfRotationalMove.Amount, 0) * ISNULL(PCSCostsRotationalMove.Amount, 0))
        FROM @ProbabilityOfOperationalMove ProbabilityOfOperationalMove
            INNER JOIN @PCSCostsOperationalMove PCSCostsOperationalMove
                ON PCSCostsOperationalMove.GradeType = ProbabilityOfOperationalMove.GradeType
                   AND PCSCostsOperationalMove.GradeLevel = ProbabilityOfOperationalMove.GradeLevel
            INNER JOIN @ProbabilityOfRotationalMove ProbabilityOfRotationalMove
                ON ProbabilityOfOperationalMove.GradeType = ProbabilityOfRotationalMove.GradeType
                   AND ProbabilityOfOperationalMove.GradeLevel = ProbabilityOfRotationalMove.GradeLevel
            INNER JOIN @PCSCostsRotationalMove PCSCostsRotationalMove
                ON ProbabilityOfRotationalMove.GradeType = PCSCostsRotationalMove.GradeType
                   AND ProbabilityOfRotationalMove.GradeLevel = PCSCostsRotationalMove.GradeLevel
        WHERE ProbabilityOfOperationalMove.CMF = @CMF
              AND ProbabilityOfRotationalMove.CMF = @CMF;
    END;
    ELSE
    BEGIN
        INSERT INTO @tblPCS_Annualized
        SELECT ProbabilityOfOperationalMove.GradeType,
               ProbabilityOfOperationalMove.GradeLevel,
               (ISNULL(ProbabilityOfOperationalMove.Amount, 0) * ISNULL(PCSCostsOperationalMove.Amount, 0))
               + (ISNULL(ProbabilityOfRotationalMove.Amount, 0) * ISNULL(PCSCostsRotationalMove.Amount, 0))
        FROM @ProbabilityOfOperationalMove ProbabilityOfOperationalMove
            INNER JOIN @PCSCostsOperationalMove PCSCostsOperationalMove
                ON PCSCostsOperationalMove.GradeType = ProbabilityOfOperationalMove.GradeType
                   AND PCSCostsOperationalMove.GradeLevel = ProbabilityOfOperationalMove.GradeLevel
            INNER JOIN @ProbabilityOfRotationalMove ProbabilityOfRotationalMove
                ON ProbabilityOfOperationalMove.GradeType = ProbabilityOfRotationalMove.GradeType
                   AND ProbabilityOfOperationalMove.GradeLevel = ProbabilityOfRotationalMove.GradeLevel
            INNER JOIN @PCSCostsRotationalMove PCSCostsRotationalMove
                ON ProbabilityOfRotationalMove.GradeType = PCSCostsRotationalMove.GradeType
                   AND ProbabilityOfRotationalMove.GradeLevel = PCSCostsRotationalMove.GradeLevel
        WHERE ProbabilityOfOperationalMove.CMF = 'ZZ'
              AND ProbabilityOfRotationalMove.CMF = 'ZZ';
    END;

    /* PROCESS COST FACTORS */

    /* Military Compensation; Avg Cost of Base Pay (Military) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 128 AS CostElementId,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgCostOfBasePayMilitary('AO', @AOC);


    /* MPA; Retirement; Medicare-Eligible Retiree Health Care (MERHC) */
    DECLARE @MERHC FLOAT = crunch.GetSingleValue('AA', 'MERHC');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 180,
           GradeType,
           GradeLevel,
           @MERHC
    FROM @CrunchCosts
    WHERE CostElementId = 128;


    -- Other Benefits 
    -- Avg Cost of Medical Support Cost
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 173,
           GradeType,
           GradeLevel,
           @Health_Care_Cost_Per_Family_Member AS calAmount
    FROM dataload.AO_OtherBenefits
    WHERE Code = 'AFS'
          AND GradeType = @GradeType
          AND GradeLevel IN
              (
                  SELECT GradeLevel FROM @CrunchCosts WHERE CostElementId = 128
              );

    -- Morale, Welfare and Recreation Costs: Avg Cost of Morale, Welfare and Recreation	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 174,
           GradeType,
           GradeLevel,
           (@MoraleWelfareRecreation / @Avg_OE_End_Strength) AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    -- Other Benefits: Avg Cost of Miscellaneous
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 144,
           GradeType,
           GradeLevel,
           (@Miscellaneous_Benefits / @TotalAvgInvPrj) AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    -- Other Benefits: Avg Cost of FICA
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 143,
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
            SELECT Salary.Salary * Inventory.Amount AS calAmount,
                   Inventory.GradeType,
                   Inventory.GradeLevel
            FROM
            (
                SELECT GradeType,
                       GradeLevel,
                       YOS,
                       Salary = CASE
                                    WHEN Amount < @Max_Wage_SSW THEN
                                        Amount
                                    ELSE
                                        @Max_Wage_SSW
                                END
                FROM crunch.AnnualBasicPayActiveDuty('AO')
            ) Salary
                INNER JOIN crunch.InventoryByGradeYosForCategoryGroup('AO', @CMF) Inventory
                    ON Inventory.GradeType = Salary.GradeType
                       AND Inventory.GradeLevel = Salary.GradeLevel
                       AND Inventory.Step_YOS = Salary.YOS
        ) tblCost
        GROUP BY GradeType,
                 GradeLevel
    ) tblFICA
        INNER JOIN
        (
            SELECT Amount,
                   GradeType,
                   GradeLevel
            FROM crunch.InventoryByGradeForCategoryGroup('AO', @CMF)
        ) Inventory
            ON Inventory.GradeType = tblFICA.GradeType
               AND Inventory.GradeLevel = tblFICA.GradeLevel
    WHERE tblFICA.GradeType = @GradeType
          AND tblFICA.GradeLevel IN
              (
                  SELECT GradeLevel FROM @CrunchCosts WHERE CostElementId = 128
              );

    -- Other Benefits: Avg Cost of Other Benefits
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 145,
           GradeType,
           GradeLevel,
           SUM(Amount) AS sumAmount
    FROM @CrunchCosts
    WHERE CostElementId IN ( 143, 144 )
    GROUP BY GradeType,
             GradeLevel;

    -- Retired Pay Accrual 
    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 151,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    --Special Pays: Avg Cost of Family Separation Pay
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 157,
           tblPrj.GradeType,
           tblPrj.GradeLevel,
           (tblPCS.Amount / tblPrj.Amount) + (@Other_FS_Bgt / @Total_ProjEndStrength)
    FROM @tblProjEndStrength tblPrj
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM @tblSpecialPaysBudget
            WHERE Code = 'PCS_w2Homes'
        ) tblPCS
            ON tblPrj.GradeType = tblPCS.GradeType
               AND tblPrj.GradeLevel = tblPCS.GradeLevel
    WHERE tblPrj.GradeType = @GradeType
          AND tblPrj.GradeLevel IN
              (
                  SELECT GradeLevel FROM @CrunchCosts WHERE CostElementId = 128
              );

    --Special Pays: Avg Cost of Overseas Station Allowance
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 161,
           tblPrj.GradeType,
           tblPrj.GradeLevel,
           (tblOSA.Amount / tblPrj.Amount) + (@Temp_Lodging_Allowance / @Total_ProjEndStrength)
    FROM @tblProjEndStrength tblPrj
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM @tblSpecialPaysBudget
            WHERE Code = 'OSA'
        ) tblOSA
            ON tblPrj.GradeType = tblOSA.GradeType
               AND tblPrj.GradeLevel = tblOSA.GradeLevel
    WHERE tblPrj.GradeType = @GradeType
          AND tblPrj.GradeLevel IN
              (
                  SELECT GradeLevel FROM @CrunchCosts WHERE CostElementId = 128
              );

    -- PCS 
    -- Permanent Change of Station Costs: Avg Cost of an Operational Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 146,
           GradeType,
           GradeLevel,
           Amount
    FROM @PCSCostsOperationalMove
    WHERE GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND [@PCSCostsOperationalMove].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Rotational Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 147,
           GradeType,
           GradeLevel,
           Amount
    FROM @PCSCostsRotationalMove
    WHERE GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND [@PCSCostsRotationalMove].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Separation Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 148,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Costs_Sep
    WHERE GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND [@tblPCS_Costs_Sep].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Training Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 149,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Costs_Training
    WHERE GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND [@tblPCS_Costs_Training].GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Permanent Change of Station-annualized
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 150,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Annualized
    WHERE GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND [@tblPCS_Annualized].GradeLevel = GradeLevel
    );

    -- Separation 
    -- Separation Costs: Avg Cost Separation Moves - Annualized
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 152,
           ProbabilityOfSeparationMove.GradeType,
           ProbabilityOfSeparationMove.GradeLevel,
           ProbabilityOfSeparationMove.Amount * tblCost.Amount AS calAmount
    FROM @ProbabilityOfSeparationMove ProbabilityOfSeparationMove
        INNER JOIN @tblPCS_Costs_Sep tblCost
            ON ProbabilityOfSeparationMove.GradeType = tblCost.GradeType
               AND ProbabilityOfSeparationMove.GradeLevel = tblCost.GradeLevel
    WHERE ProbabilityOfSeparationMove.GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND ProbabilityOfSeparationMove.GradeLevel = GradeLevel
    );

    -- Separation Costs: Avg Cost of Accrued Leave and Separation
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 153,
           tblLeave.GradeType,
           tblLeave.GradeLevel,
           tblLeave.Amount * ((@TotalLstlp + @Officer_Severence_Pay) / @TotalLstlp) / tblPrj.Amount AS calAmount
    FROM @tblLstlp tblLeave
        INNER JOIN @tblAverage_Inv_Prj tblPrj
            ON tblLeave.GradeType = tblPrj.GradeType
               AND tblLeave.GradeLevel = tblPrj.GradeLevel
    WHERE tblLeave.GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND tblLeave.GradeLevel = GradeLevel
    );

    -- Separation Costs: Avg Cost of Full Involuntary Seperation Incentives	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 155,
           tblLeave.GradeType,
           tblLeave.GradeLevel,
           (@Sep_Pay_NonDis / @TotalLstlp) * tblLeave.Amount / tblPrj.Amount AS calAmount
    FROM @tblLstlp tblLeave
        INNER JOIN @tblAverage_Inv_Prj tblPrj
            ON tblLeave.GradeType = tblPrj.GradeType
               AND tblLeave.GradeLevel = tblPrj.GradeLevel
    WHERE tblLeave.GradeType = @GradeType
          AND EXISTS
    (
        SELECT GradeLevel
        FROM @CrunchCosts
        WHERE CostElementId = 128
              AND tblLeave.GradeLevel = GradeLevel
    );

    -- Separation Costs: Avg Cost of Separation Incentives (Total)
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 154,
           GradeType,
           GradeLevel,
           SUM(Amount) AS sumAmount
    FROM @CrunchCosts
    WHERE CostElementId IN ( 152, 153, 155 )
    GROUP BY GradeType,
             GradeLevel;

    /* OMDW; Other Benefits; Discount Groceries */
    DECLARE @DiscountGroceries FLOAT = crunch.GetSingleValue('AA', 'DiscountGroceries');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 790,
           GradeType,
           GradeLevel,
           @DiscountGroceries
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    /* OMDW; Other Benefits; DoDEA and Family Assistance */
    DECLARE @DoDEAandFamilyAssistance FLOAT = crunch.GetSingleValue('AA', 'DoDEAandFamilyAssistance');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 791,
           GradeType,
           GradeLevel,
           @DoDEAandFamilyAssistance
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    /* Federal OM; Other Benefits; Child Education (Impact Aid) */
    DECLARE @ChildEducation FLOAT = crunch.GetSingleValue('AA', 'ChildEducation');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 789,
           GradeType,
           GradeLevel,
           @ChildEducation
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    /* Federal OM; Retirement; Treasury Contribution for Concurrent Receipts */
    DECLARE @TreasuryContributionForConcurrentReceipts FLOAT
        = crunch.GetSingleValue('AA', 'TreasuryContributionForConcurrentReceipts');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 793,
           GradeType,
           GradeLevel,
           @TreasuryContributionForConcurrentReceipts
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    -- OSD CAPE DODI: Treasury Contribution to Medicare Eligible Retiree Health Care Fund (MERHCF)	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 794,
           GradeType,
           GradeLevel,
           @TreasuryContributionToMERHC
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    /* Federal OM; Veteran Benefits; Veterans' Benefits (Cash and In-kind) */
    DECLARE @VeteransBenefits FLOAT = crunch.GetSingleValue('AA', 'VeteransBenefits');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 796,
           GradeType,
           GradeLevel,
           @VeteransBenefits
    FROM @CrunchCosts
    WHERE CostElementId = 128;

    /* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM @CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'AO'
              AND CategorySubGroupCode = @AOC
              AND [@CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );

    SELECT 'AO',
           @CMF,
           @AOC,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;

END;