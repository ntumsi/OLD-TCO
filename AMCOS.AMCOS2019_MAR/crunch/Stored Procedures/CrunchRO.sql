CREATE PROCEDURE [crunch].[CrunchRO]
    @AOC NVARCHAR(4),
    @ActiveDutyDays TINYINT = 15,
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
        WHERE PayPlan = 'RO'
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

    /* BEGIN TABLE DATA COLLECTION */
    DECLARE @CMF NCHAR(2) = LEFT(@AOC, 2);
    DECLARE @Days FLOAT = 365.0;

    -- Average Inventory Projected (Budget)
    DECLARE @tblAverage_Prj_Inv TABLE
    (
        Code VARCHAR(15) NOT NULL,
        GradeType VARCHAR(3) NOT NULL,
        GradeLevel INT NOT NULL,
        Amount FLOAT NULL,
        PRIMARY KEY (
                        Code,
                        GradeType,
                        GradeLevel
                    )
    );
    INSERT INTO @tblAverage_Prj_Inv
    SELECT Code,
           GradeType,
           GradeLevel,
           Amount
    FROM dataload.RO_ProjectedInventory
    WHERE GradeType = 'O'
          AND Code = 'USAR';

    DECLARE @TotalAvgPrjInv FLOAT;
    SELECT @TotalAvgPrjInv = SUM(Amount)
    FROM @tblAverage_Prj_Inv;

    -- Millitary Compensation Allowances
    DECLARE @MilitaryCompensationAllowances TABLE
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
    INSERT INTO @MilitaryCompensationAllowances
    SELECT Code,
           GradeType,
           GradeLevel,
           Amount
    FROM dataload.RO_MilCompAllowances;

    /* BEGIN COST FACTOR PROCESSING */
    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Average_Cost_of_Health_Care_per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual');
    DECLARE @RO_Clothing_Allowance FLOAT
        = crunch.GetArmyBudgetSingleValue('RO_Clothing_allowance', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @RO_RWO_DHDG FLOAT = crunch.GetArmyBudgetSingleValue('RO_RWO_DHDG', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @RO_RWO_Endstrength FLOAT
        = crunch.GetArmyBudgetSingleValue('RO_RWO_Endstrength', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Avg_Cost_Heath_Care FLOAT = @Average_Cost_of_Health_Care_per_Family_Member / @Days;
    DECLARE @Avg_Cost_DHDG FLOAT = @RO_RWO_DHDG / @RO_RWO_Endstrength;

    /* GET COST VALUES */

    /* Military Compensation; Avg Annualized Cost of Base Pay (Military) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 523,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgAnnualizedCostOfBasePayMilitary('RO', @AOC, @ActiveDutyDays);

    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 525,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 523;

    -- Other Benefits
    -- Other Benefits: Avg Cost of FICA
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 524,
           GradeType,
           GradeLevel,
           Amount * @FICA AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 523;

    -- Other Benefits
    -- Other Benefits: Disability, Hospitalization & Death Gratuities
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 563,
           GradeType,
           GradeLevel,
           @Avg_Cost_DHDG
    FROM @CrunchCosts
    WHERE CostElementId = 523;

    -- Other Benefits
    -- Other Benefits: Avg Cost of Clothing Allowance
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 562,
           GradeType,
           GradeLevel,
           ISNULL(@RO_Clothing_Allowance, 0) / ISNULL(@TotalAvgPrjInv, 0)
    FROM @CrunchCosts
    WHERE CostElementId = 523;

    -- Medical Support Costs
    -- Medical Support Costs: Avg Cost of Health Care
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 522,
           GradeType,
           GradeLevel,
           @Avg_Cost_Heath_Care * @ActiveDutyDays
    FROM @CrunchCosts
    WHERE CostElementId = 523;

    /* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM @CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'RO'
              AND CategorySubGroupCode = @AOC
              AND [@CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );

    SELECT 'RO',
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