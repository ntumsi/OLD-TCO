CREATE PROCEDURE [crunch].[CrunchAWO]
    @WOMOS NVARCHAR(4),
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
        WHERE PayPlan = 'AWO'
              AND CategorySubGroupCode = @WOMOS
    )
        RETURN 0;
    DECLARE @CrunchCosts TABLE
    (
        CostElementId INT NOT NULL INDEX ixCostElementId CLUSTERED,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
        WeaponSystemId INT NOT NULL
            DEFAULT (-1),
        Amount FLOAT NULL,
        CrunchTime SMALLDATETIME NULL
    );
    DECLARE @Branch NCHAR(2) = LEFT(@WOMOS, 2);

    /* Total inventory by Grade */
    BEGIN
        CREATE TABLE #InventoryByGradeForPayPlan
        (
            GradeType NVARCHAR(3) NOT NULL,
            GradeLevel TINYINT NOT NULL,
            Amount INT NULL,
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
        FROM crunch.InventoryByGradeForPayPlan('AWO');
    END;
    DECLARE @TotalInventoryForPayPlan INT;
    SELECT @TotalInventoryForPayPlan = SUM(Amount)
    FROM #InventoryByGradeForPayPlan;

    /* InventoryByCategoryGroupGradeYos */
    BEGIN
        CREATE TABLE #InventoryByCategoryGroupGradeYos
        (
            Branch NCHAR(2) NOT NULL,
            GradeType NVARCHAR(3) NOT NULL,
            GradeLevel TINYINT NOT NULL,
            YOS INT NOT NULL,
            Amount INT NULL,
            PRIMARY KEY (
                            Branch,
                            GradeType,
                            GradeLevel,
                            YOS
                        )
        );
        INSERT INTO #InventoryByCategoryGroupGradeYos
        (
            Branch,
            GradeType,
            GradeLevel,
            YOS,
            Amount
        )
        SELECT CategoryGroupCode,
               GradeType,
               GradeLevel,
               Step_YOS,
               Amount
        FROM crunch.InventoryByCategoryGroupGradeYos('AWO');
    END;

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
    BEGIN
        DECLARE @SpecialPaysElig TABLE
        (
            CMF NCHAR(2) NOT NULL PRIMARY KEY,
            OCONUS NUMERIC(9, 4) NULL,
            Medical FLOAT NULL,
            Dental FLOAT NULL,
            Vet FLOAT NULL,
            Aviation FLOAT NULL,
            Dive FLOAT NULL
        );
        INSERT INTO @SpecialPaysElig
        SELECT CMF,
               OCONUS,
               Medical,
               Dental,
               Vet,
               Aviation,
               Dive
        FROM dataload.AO_SpecialPaysElig;
    END;

    /* Leave Pay */
    BEGIN
        DECLARE @LeavePay TABLE
        (
            GradeType NCHAR(1) NULL,
            GradeLevel INT NULL,
            Amount FLOAT NULL
        );
        INSERT INTO @LeavePay
        SELECT GradeType,
               GradeLevel,
               Amount
        FROM dataload.SepParms
        WHERE PayPlan = 'AO'
              AND Code = N'LSTLP';
    END;

    /* Number Leave Pay */
    BEGIN
        DECLARE @tblNumLstlp TABLE
        (
            GradeType NCHAR(1) NULL,
            GradeLevel TINYINT NULL,
            Amount FLOAT NULL
        );
        INSERT INTO @tblNumLstlp
        SELECT GradeType,
               GradeLevel,
               Amount
        FROM dataload.SepParms
        WHERE PayPlan = 'AO'
              AND Code = N'NUM_LSTLP';
    END;
    DECLARE @TotalAvgInvPrj FLOAT;
    DECLARE @TotalNumLstlp FLOAT;
    DECLARE @TotalLstlp FLOAT;
    DECLARE @Total_ProjEndStrength INT;
    SELECT @TotalAvgInvPrj = SUM(Amount)
    FROM @tblAverage_Inv_Prj;
    SELECT @TotalNumLstlp = SUM(Amount)
    FROM @tblNumLstlp;
    SELECT @TotalLstlp = SUM(Amount)
    FROM @LeavePay;
    BEGIN
        DECLARE @ProjectedEndStrength TABLE
        (
            GradeType NCHAR(1) NULL,
            GradeLevel INT NULL,
            Amount FLOAT NULL
        );
        INSERT INTO @ProjectedEndStrength
        SELECT GradeType,
               GradeLevel,
               Amount
        FROM dataload.AO_ProjEndstrength;
    END;
    SELECT @Total_ProjEndStrength = SUM(Amount)
    FROM @ProjectedEndStrength;

    -- Special Pay
    BEGIN
        DECLARE @tblSpecialPaysBudget TABLE
        (
            Code VARCHAR(15) NOT NULL,
            GradeType NCHAR(1) NOT NULL,
            GradeLevel TINYINT NOT NULL,
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

    -- PCS
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

    --Military Compensation Allowances
    DECLARE @tblMilCompAllowances TABLE
    (
        Code VARCHAR(20) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel TINYINT NOT NULL,
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
    BEGIN
        DECLARE @AvailableGradeLevels TABLE
        (
            GradeType NVARCHAR(3) NOT NULL,
            GradeLevel TINYINT NOT NULL,
            PRIMARY KEY (
                            GradeType,
                            GradeLevel
                        )
        );
        INSERT INTO @AvailableGradeLevels
        SELECT DISTINCT
               GradeType,
               GradeLevel
        FROM crunch.AnnualBasicPayByGradeYosForCategorySubgroup('AWO', @WOMOS);
    END;

    -- If no values found
    IF NOT EXISTS
    (
        SELECT GradeLevel
        FROM crunch.AnnualBasicPayByGradeYosForCategorySubgroup('AWO', @WOMOS)
    )
        RETURN 0;

    /* COLLECT COST DATA */

    -- MISC Data
    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Max_Wage_SSW MONEY = crunch.GetSingleValue('AA', 'Max_Wage_SSW');
    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA', 'Retired_Pay_Accrual');
    DECLARE @Miscellaneous_Benefits FLOAT = crunch.GetArmyBudgetSingleValue('AO_Misc', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @MoraleWelfareRecreation INT
        = crunch.GetArmyBudgetSingleValue('MoraleWelfareRecreation', 'OMA', 'Avg', @AmcosVersionId);
    DECLARE @Avg_OE_End_Strength INT
        = crunch.GetArmyBudgetSingleValue('Avg_OE_End_Strength', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @Health_Care_Cost_Per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
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
    DECLARE @DiscountGroceries FLOAT = crunch.GetSingleValue('AA', 'DiscountGroceries');
    DECLARE @DoDEAandFamilyAssistance FLOAT = crunch.GetSingleValue('AA', 'DoDEAandFamilyAssistance');
    DECLARE @ChildEducation FLOAT = crunch.GetSingleValue('AA', 'ChildEducation');
    DECLARE @TreasuryContributionForConcurrentReceipts FLOAT
        = crunch.GetSingleValue('AA', 'TreasuryContributionForConcurrentReceipts');
    DECLARE @VeteransBenefits FLOAT = crunch.GetSingleValue('AA', 'VeteransBenefits');
    DECLARE @MERHC FLOAT = crunch.GetSingleValue('AA', 'MERHC');
    DECLARE @TreasuryContributionToMERHC FLOAT = crunch.GetSingleValue('AA', 'TreasuryContributionToMERHC');
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
    SET @Other_FS_Bgt = @PCS_wDep_Not_Auth + @TDY_30_Plus_Days_wDeps_Not_Near_Stn;
    DECLARE @PCS_Total_Sep_Moves FLOAT;
    SET @PCS_Total_Sep_Moves = @OfficerPCSSeparationMoveBudget / @PCS_Separation_Move_Cost;
    DECLARE @PCS_Total_Ops_Moves FLOAT;
    SET @PCS_Total_Ops_Moves = @OfficerPCSOperationalMoveBudget / @PCS_Operational_Move_Cost;
    DECLARE @PCS_Total_Rot_Moves FLOAT;
    SET @PCS_Total_Rot_Moves = @OfficerPCSRotationalMoveBudget / @PCS_Rotational_Move_Cost;
    DECLARE @tblWeightwDep TABLE
    (
        GradeType NCHAR(1) NULL,
        GradeLevel INT NULL,
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
        GradeType NCHAR(1) NULL,
        GradeLevel INT NULL,
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
        GradeType NCHAR(1) NULL,
        GradeLevel INT NULL,
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
    DECLARE @PCSCostsSeparationMove TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @PCSCostsSeparationMove
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Separation_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Training move cost Per Grade
    DECLARE @PCSCostsTrainingMove TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @PCSCostsTrainingMove
    SELECT GradeType,
           GradeLevel,
           Amount * @PCS_Training_Move_Cost
    FROM @tblPCS_Multiplier;

    -- Probability of Separation Move
    DECLARE @ProbabilityOfSeparationMove TABLE
    (
        GradeType NCHAR(1) NOT NULL,
        GradeLevel TINYINT NOT NULL,
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
    DECLARE @ProbabilityOfAccessionMove TABLE
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
        INSERT INTO @ProbabilityOfAccessionMove
        SELECT GradeType,
               GradeLevel,
               1
        FROM @tblAverage_Inv_Prj;
    END;
    ELSE
    BEGIN
        INSERT INTO @ProbabilityOfAccessionMove
        SELECT GradeType,
               GradeLevel,
               @PCS_Number_Of_Officers_Commissioned /
               (
                   SELECT SUM(Amount) FROM #InventoryByGradeForPayPlan WHERE GradeLevel = 1
               ) sumO1
        FROM @tblAverage_Inv_Prj;
    END;
    UPDATE @ProbabilityOfAccessionMove
    SET Amount = 0
    WHERE GradeLevel <> 1;

    -- Calculate the probability of a rots move a rots move is calculated as the probability twice the probability of being overseas.
    -- Divided by the average tour length (twice is to cover being rotated in and out) less the probabilities of being rotated in on an accession move or rotated out on a separation move.
    -- Probability of Operational Move
    DECLARE @ProbabilityOfOperationalMove TABLE
    (
        Branch VARCHAR(3) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        Branch,
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @ProbabilityOfOperationalMove
    SELECT tblPct.CMF,
           tblSep.GradeType,
           tblSep.GradeLevel,
           (1 - tblPct.OCONUS) / tblCONUS.CONUSTourLength
           - (tblPct.OCONUS / @PCS_Avg_OCONUS_Tour_Length - tblPct.OCONUS * tblSep.Amount)
    FROM @ProbabilityOfSeparationMove tblSep
        CROSS JOIN @SpecialPaysElig tblPct
        INNER JOIN lookup.CMF_Branch_FA tblCONUS
            ON tblPct.CMF = tblCONUS.Code
    WHERE tblCONUS.GradeType = 'O';
    UPDATE @ProbabilityOfOperationalMove
    SET Amount = 0
    WHERE Amount < 0;

    -- Probability of Rotational Move
    DECLARE @ProbabilityOfRotationalMove TABLE
    (
        Branch VARCHAR(3) NOT NULL,
        GradeType NCHAR(1) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        Branch,
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @ProbabilityOfRotationalMove
    SELECT tblPct.CMF,
           tblAcc.GradeType,
           tblAcc.GradeLevel,
           tblPct.OCONUS * 2 / @PCS_Avg_OCONUS_Tour_Length - (tblPct.OCONUS * tblAcc.Amount)
           - (tblPct.OCONUS * tblSep.Amount)
    FROM @ProbabilityOfAccessionMove tblAcc
        INNER JOIN @ProbabilityOfSeparationMove tblSep
            ON tblAcc.GradeType = tblSep.GradeType
               AND tblAcc.GradeLevel = tblSep.GradeLevel
        CROSS JOIN @SpecialPaysElig tblPct;
    UPDATE @ProbabilityOfRotationalMove
    SET Amount = 0
    WHERE Amount < 0;

    -- Now smooth the probabilities to match the budget
    DECLARE @PCS_Est_Total_Ops_Moves FLOAT;
    SELECT @PCS_Est_Total_Ops_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT ISNULL(ProbabilityOfOperationalMove.Amount, 0) * ISNULL(Inventory.Amount, 0) AS calAmount
        FROM @ProbabilityOfOperationalMove ProbabilityOfOperationalMove
            INNER JOIN #InventoryByCategoryGroupGradeYos Inventory
                ON ProbabilityOfOperationalMove.GradeType = Inventory.GradeType
                   AND ProbabilityOfOperationalMove.GradeLevel = Inventory.GradeLevel
                   AND ProbabilityOfOperationalMove.Branch = Inventory.Branch
    ) tblCal;
    DECLARE @PCS_Est_Total_Ops_Cost FLOAT;
    SELECT @PCS_Est_Total_Ops_Cost = SUM(tblCal.Amount)
    FROM
    (
        SELECT ISNULL(PCSCostsOperationalMove.Amount, 0) * ISNULL(ProbabilityOfOperationalMove.Amount, 0)
               * ISNULL(Inventory.Amount, 0) AS Amount
        FROM @ProbabilityOfOperationalMove ProbabilityOfOperationalMove
            INNER JOIN #InventoryByCategoryGroupGradeYos Inventory
                ON ProbabilityOfOperationalMove.GradeType = Inventory.GradeType
                   AND ProbabilityOfOperationalMove.GradeLevel = Inventory.GradeLevel
                   AND ProbabilityOfOperationalMove.Branch = Inventory.Branch
            INNER JOIN @PCSCostsOperationalMove PCSCostsOperationalMove
                ON ProbabilityOfOperationalMove.GradeType = PCSCostsOperationalMove.GradeType
                   AND ProbabilityOfOperationalMove.GradeLevel = PCSCostsOperationalMove.GradeLevel
    ) tblCal;
    DECLARE @PCS_Est_Total_Rot_Moves FLOAT;
    SELECT @PCS_Est_Total_Rot_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT ISNULL(tblRot.Amount, 0) * Inventory.Amount AS calAmount
        FROM @ProbabilityOfRotationalMove tblRot
            INNER JOIN #InventoryByCategoryGroupGradeYos Inventory
                ON tblRot.GradeType = Inventory.GradeType
                   AND tblRot.GradeLevel = Inventory.GradeLevel
                   AND tblRot.Branch = Inventory.Branch
    ) tblCal;
    DECLARE @PCS_Est_Total_Rot_Cost FLOAT;
    SELECT @PCS_Est_Total_Rot_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblRotCosts.Amount * ISNULL(tblRot.Amount, 0) * Inventory.Amount AS calAmount
        FROM @ProbabilityOfRotationalMove tblRot
            INNER JOIN #InventoryByCategoryGroupGradeYos Inventory
                ON tblRot.GradeType = Inventory.GradeType
                   AND tblRot.GradeLevel = Inventory.GradeLevel
                   AND tblRot.Branch = Inventory.Branch
            INNER JOIN @PCSCostsRotationalMove tblRotCosts
                ON Inventory.GradeType = tblRotCosts.GradeType
                   AND Inventory.GradeLevel = tblRotCosts.GradeLevel
    ) tblCal;
    DECLARE @PCS_Est_Total_Sep_Moves FLOAT;
    SELECT @PCS_Est_Total_Sep_Moves = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblSep.Amount * Inventory.Amount AS calAmount
        FROM @ProbabilityOfSeparationMove tblSep
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON tblSep.GradeType = Inventory.GradeType
                   AND tblSep.GradeLevel = Inventory.GradeLevel
    ) tblCal;
    DECLARE @PCS_Est_Total_Sep_Cost FLOAT;
    SELECT @PCS_Est_Total_Sep_Cost = SUM(tblCal.calAmount)
    FROM
    (
        SELECT tblSepCosts.Amount * tblSep.Amount * Inventory.Amount AS calAmount
        FROM @ProbabilityOfSeparationMove tblSep
            INNER JOIN @PCSCostsSeparationMove tblSepCosts
                ON tblSep.GradeType = tblSepCosts.GradeType
                   AND tblSep.GradeLevel = tblSepCosts.GradeLevel
            INNER JOIN #InventoryByGradeForPayPlan Inventory
                ON tblSepCosts.GradeType = Inventory.GradeType
                   AND tblSepCosts.GradeLevel = Inventory.GradeLevel
    ) tblCal;

    -- Adjust the average cost per move to reflect the mix of grades that are going on the moves.
    -- This is necessary because there are fewer rots/ops moves in the cheaper grades. 
    -- They are covered w/acc moves.
    UPDATE @PCSCostsRotationalMove
    SET Amount = Amount * (@PCS_Rotational_Move_Cost / (@PCS_Est_Total_Rot_Cost / @PCS_Est_Total_Rot_Moves));
    UPDATE @PCSCostsOperationalMove
    SET Amount = Amount * (@PCS_Operational_Move_Cost / (@PCS_Est_Total_Ops_Cost / @PCS_Est_Total_Ops_Moves));
    UPDATE @PCSCostsSeparationMove
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
        GradeType NCHAR(1) NULL,
        GradeLevel INT NULL,
        Amount FLOAT NULL
    );
    IF EXISTS
    (
        SELECT Amount
        FROM @ProbabilityOfOperationalMove
        WHERE Branch = @Branch
    )
    BEGIN
        INSERT INTO @tblPCS_Annualized
        SELECT tblProbOps.GradeType,
               tblProbOps.GradeLevel,
               (ISNULL(tblProbOps.Amount, 0) * ISNULL(tblCostOps.Amount, 0))
               + (ISNULL(tblProbRot.Amount, 0) * ISNULL(tblCostRot.Amount, 0))
        FROM @ProbabilityOfOperationalMove tblProbOps
            INNER JOIN @PCSCostsOperationalMove tblCostOps
                ON tblCostOps.GradeType = tblProbOps.GradeType
                   AND tblCostOps.GradeLevel = tblProbOps.GradeLevel
            INNER JOIN @ProbabilityOfRotationalMove tblProbRot
                ON tblProbOps.GradeType = tblProbRot.GradeType
                   AND tblProbOps.GradeLevel = tblProbRot.GradeLevel
            INNER JOIN @PCSCostsRotationalMove tblCostRot
                ON tblProbRot.GradeType = tblCostRot.GradeType
                   AND tblProbRot.GradeLevel = tblCostRot.GradeLevel
        WHERE tblProbOps.Branch = @Branch
              AND tblProbRot.Branch = @Branch;
    END;
    ELSE
    BEGIN
        INSERT INTO @tblPCS_Annualized
        SELECT tblProbOps.GradeType,
               tblProbOps.GradeLevel,
               (ISNULL(tblProbOps.Amount, 0) * ISNULL(tblCostOps.Amount, 0))
               + (ISNULL(ProbabilityOfRotationalMove.Amount, 0) * ISNULL(tblCostRot.Amount, 0))
        FROM @ProbabilityOfOperationalMove tblProbOps
            INNER JOIN @PCSCostsOperationalMove tblCostOps
                ON tblCostOps.GradeType = tblProbOps.GradeType
                   AND tblCostOps.GradeLevel = tblProbOps.GradeLevel
            INNER JOIN @ProbabilityOfRotationalMove ProbabilityOfRotationalMove
                ON tblProbOps.GradeType = ProbabilityOfRotationalMove.GradeType
                   AND tblProbOps.GradeLevel = ProbabilityOfRotationalMove.GradeLevel
            INNER JOIN @PCSCostsRotationalMove tblCostRot
                ON ProbabilityOfRotationalMove.GradeType = tblCostRot.GradeType
                   AND ProbabilityOfRotationalMove.GradeLevel = tblCostRot.GradeLevel
        WHERE tblProbOps.Branch = 'ZZ'
              AND ProbabilityOfRotationalMove.Branch = 'ZZ';
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
    SELECT 204 AS CostElementId,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgCostOfBasePayMilitary('AWO', @WOMOS);

    -- Other Benefits 
    -- Avg Cost of Medical Support Cost
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 247,
           GradeType,
           GradeLevel,
           @Health_Care_Cost_Per_Family_Member AS calAmount
    FROM dataload.AO_OtherBenefits AO_OtherBenefits
    WHERE Code = 'AFS'
          AND GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE AO_OtherBenefits.GradeLevel = GradeLevel
    );

    -- Morale, Welfare and Recreation Costs: Avg Cost of Morale, Welfare and Recreation	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 248,
           GradeType,
           GradeLevel,
           (@MoraleWelfareRecreation / @Avg_OE_End_Strength) AS calAmount
    FROM @AvailableGradeLevels;

    -- Other Benefits: Avg Cost of Miscellaneous
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 218,
           GradeType,
           GradeLevel,
           (@Miscellaneous_Benefits / @TotalAvgInvPrj) AS calAmount
    FROM @AvailableGradeLevels;

    -- Other Benefits: Avg Cost of FICA
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 217,
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
            SELECT tblSalary.Salary * Inventory.Amount AS calAmount,
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
                FROM crunch.AnnualBasicPayActiveDuty('AWO')
            ) tblSalary
                INNER JOIN crunch.InventoryByGradeYosForCategoryGroup('AWO', @Branch) Inventory
                    ON Inventory.GradeType = tblSalary.GradeType
                       AND Inventory.GradeLevel = tblSalary.GradeLevel
                       AND Inventory.Step_YOS = tblSalary.YOS
        ) tblCost
        GROUP BY GradeType,
                 GradeLevel
    ) tblFICA
        INNER JOIN
        (
            SELECT Amount,
                   GradeType,
                   GradeLevel
            FROM crunch.InventoryByGradeForCategoryGroup('AWO', @Branch)
        ) Inventory
            ON Inventory.GradeType = tblFICA.GradeType
               AND Inventory.GradeLevel = tblFICA.GradeLevel
    WHERE tblFICA.GradeType = 'W'
          AND EXISTS
    (
        SELECT * FROM @AvailableGradeLevels WHERE tblFICA.GradeLevel = GradeLevel
    );

    -- Other Benefits: Avg Cost of Other Benefits
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 219,
           GradeType,
           GradeLevel,
           SUM(Amount) AS sumAmount
    FROM @CrunchCosts
    WHERE CostElementId IN ( 218, 217 )
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
    SELECT 225,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 204;

    --Special Pays: Avg Cost of Family Separation Pay
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 231,
           ProjectedEndStrength.GradeType,
           ProjectedEndStrength.GradeLevel,
           (tblPCS.Amount / ProjectedEndStrength.Amount) + (@Other_FS_Bgt / @Total_ProjEndStrength)
    FROM @ProjectedEndStrength ProjectedEndStrength
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM @tblSpecialPaysBudget
            WHERE Code = 'PCS_w2Homes'
        ) tblPCS
            ON ProjectedEndStrength.GradeType = tblPCS.GradeType
               AND ProjectedEndStrength.GradeLevel = tblPCS.GradeLevel
    WHERE ProjectedEndStrength.GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE ProjectedEndStrength.GradeLevel = GradeLevel
    );

    --Special Pays: Avg Cost of Overseas Station Allowance
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 235,
           ProjectedEndStrength.GradeType,
           ProjectedEndStrength.GradeLevel,
           (tblOSA.Amount / ProjectedEndStrength.Amount) + (@Temp_Lodging_Allowance / @Total_ProjEndStrength)
    FROM @ProjectedEndStrength ProjectedEndStrength
        INNER JOIN
        (
            SELECT GradeType,
                   GradeLevel,
                   Amount
            FROM @tblSpecialPaysBudget
            WHERE Code = 'OSA'
        ) tblOSA
            ON ProjectedEndStrength.GradeType = tblOSA.GradeType
               AND ProjectedEndStrength.GradeLevel = tblOSA.GradeLevel
    WHERE ProjectedEndStrength.GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE ProjectedEndStrength.GradeLevel = GradeLevel
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
    SELECT 220,
           GradeType,
           GradeLevel,
           Amount
    FROM @PCSCostsOperationalMove PCSCostsOperationalMove
    WHERE GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE PCSCostsOperationalMove.GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Rotational Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 221,
           GradeType,
           GradeLevel,
           Amount
    FROM @PCSCostsRotationalMove PCSCostsRotationalMove
    WHERE GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE PCSCostsRotationalMove.GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Separation Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 222,
           GradeType,
           GradeLevel,
           Amount
    FROM @PCSCostsSeparationMove tblPCS_Costs_Sep
    WHERE GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE tblPCS_Costs_Sep.GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Cost of an Training Move
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 223,
           GradeType,
           GradeLevel,
           Amount
    FROM @PCSCostsTrainingMove PCSCostsTrainingMove
    WHERE GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE PCSCostsTrainingMove.GradeLevel = GradeLevel
    );

    -- Permanent Change of Station Costs: Avg Permanent Change of Station-annualized
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 224,
           GradeType,
           GradeLevel,
           Amount
    FROM @tblPCS_Annualized tblPCS_Annualized
    WHERE GradeType = 'W'
          AND EXISTS
    (
        SELECT *
        FROM @AvailableGradeLevels
        WHERE tblPCS_Annualized.GradeLevel = GradeLevel
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
    SELECT 226,
           tblProb.GradeType,
           tblProb.GradeLevel,
           tblProb.Amount * PCSCostsSeparationMove.Amount AS calAmount
    FROM @ProbabilityOfSeparationMove tblProb
        INNER JOIN @PCSCostsSeparationMove PCSCostsSeparationMove
            ON tblProb.GradeType = PCSCostsSeparationMove.GradeType
               AND tblProb.GradeLevel = PCSCostsSeparationMove.GradeLevel
    WHERE tblProb.GradeType = 'W'
          AND EXISTS
    (
        SELECT * FROM @AvailableGradeLevels WHERE tblProb.GradeLevel = GradeLevel
    );

    -- Separation Costs: Avg Cost of Accrued Leave and Separation
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 227,
           LeavePay.GradeType,
           LeavePay.GradeLevel,
           LeavePay.Amount * ((@TotalLstlp + @Officer_Severence_Pay) / @TotalLstlp) / tblPrj.Amount AS calAmount
    FROM @LeavePay LeavePay
        INNER JOIN @tblAverage_Inv_Prj tblPrj
            ON LeavePay.GradeType = tblPrj.GradeType
               AND LeavePay.GradeLevel = tblPrj.GradeLevel
    WHERE LeavePay.GradeType = 'W'
          AND EXISTS
    (
        SELECT * FROM @AvailableGradeLevels WHERE LeavePay.GradeLevel = GradeLevel
    );

    -- Separation Costs: Avg Cost of Full Involuntary Separation Incentives	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 229,
           LeavePay.GradeType,
           LeavePay.GradeLevel,
           (@Sep_Pay_NonDis / @TotalLstlp) * LeavePay.Amount / tblPrj.Amount AS calAmount
    FROM @LeavePay LeavePay
        INNER JOIN @tblAverage_Inv_Prj tblPrj
            ON LeavePay.GradeType = tblPrj.GradeType
               AND LeavePay.GradeLevel = tblPrj.GradeLevel
    WHERE LeavePay.GradeType = 'W'
          AND EXISTS
    (
        SELECT * FROM @AvailableGradeLevels WHERE LeavePay.GradeLevel = GradeLevel
    );

    -- Separation Costs: Avg Cost of Separation Incentives (Total)
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 228,
           GradeType,
           GradeLevel,
           SUM(Amount) AS sumAmount
    FROM @CrunchCosts
    WHERE CostElementId IN ( 226, 227, 229 )
    GROUP BY GradeType,
             GradeLevel;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 245,
           GradeType,
           GradeLevel,
           @MERHC
    FROM @AvailableGradeLevels;

    -- OSD CAPE DODI: Discount Groceries	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 806,
           GradeType,
           GradeLevel,
           @DiscountGroceries
    FROM @AvailableGradeLevels;

    -- OSD CAPE DODI: DoDEA and Family Assistance	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 807,
           GradeType,
           GradeLevel,
           @DoDEAandFamilyAssistance
    FROM @AvailableGradeLevels;

    -- OSD CAPE DODI: Child Education (Impact Aid)	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 805,
           GradeType,
           GradeLevel,
           @ChildEducation
    FROM @AvailableGradeLevels;

    -- OSD CAPE DODI: Treasury Contribution for Concurrent Receipts	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 809,
           GradeType,
           GradeLevel,
           @TreasuryContributionForConcurrentReceipts
    FROM @AvailableGradeLevels;

    -- OSD CAPE DODI: Treasury Contribution to Medicare Eligible Retiree Health Care Fund (MERHCF)	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 810,
           GradeType,
           GradeLevel,
           @TreasuryContributionToMERHC
    FROM @AvailableGradeLevels;

    -- OSD CAPE DODI: Veterans' Benefits (Cash AND IN-kind)	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 812,
           GradeType,
           GradeLevel,
           @VeteransBenefits
    FROM @AvailableGradeLevels;

    /* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM @CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'AWO'
              AND CategorySubGroupCode = @WOMOS
              AND [@CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );
    SELECT 'AWO',
           @Branch,
           @WOMOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;
END;