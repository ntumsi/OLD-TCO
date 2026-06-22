CREATE PROCEDURE [crunch].[CrunchRWO]
    @WOMOS NVARCHAR(4),
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
        WHERE PayPlan = 'RWO'
              AND CategorySubGroupCode = @WOMOS
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

    DECLARE @Branch NCHAR(2) = LEFT(@WOMOS, 2);
    DECLARE @Days FLOAT = 365.0;

    -- Average Inventory Projected (Budget)
    DECLARE @tblAverage_Prj_Inv TABLE
    (
        Code VARCHAR(15) NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NOT NULL,
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
    WHERE GradeType = 'W'
          AND Code = 'USAR';

    DECLARE @TotalAvgPrjInv FLOAT;
    SELECT @TotalAvgPrjInv = SUM(Amount)
    FROM @tblAverage_Prj_Inv;

    -- Millitary Compensation Allowances
    DECLARE @tblMilCompAllowances TABLE
    (
        Code VARCHAR(15) NOT NULL,
        GradeType NVARCHAR(3) NOT NULL,
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
    FROM dataload.RO_MilCompAllowances;

    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Average_Cost_of_Health_Care_per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual');
    DECLARE @RWO_Clothing_Allowance FLOAT
        = crunch.GetArmyBudgetSingleValue('RWO_Clothing_allowance', 'RPA', 'Avg', @AmcosVersionId);
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
    SELECT 577,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgAnnualizedCostOfBasePayMilitary('RWO', @WOMOS, @ActiveDutyDays);

    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 579,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 577;

    -- Other Benefits: Avg Cost of FICA
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 578,
           GradeType,
           GradeLevel,
           Amount * @FICA AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 577;

    -- Other Benefits: Disability, Hospitalization & Death Gratuities
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 603,
           GradeType,
           GradeLevel,
           @Avg_Cost_DHDG
    FROM @CrunchCosts
    WHERE CostElementId = 577;

    -- Other Benefits: Avg Cost of Clothing Allowance
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 602,
           GradeType,
           GradeLevel,
           ISNULL(@RWO_Clothing_Allowance / @TotalAvgPrjInv, 0)
    FROM @CrunchCosts
    WHERE CostElementId = 577;

    -- Medical Support Costs: Avg Cost of Health Care
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 576,
           GradeType,
           GradeLevel,
           @Avg_Cost_Heath_Care * @ActiveDutyDays
    FROM @CrunchCosts
    WHERE CostElementId = 577;

    SELECT 'RWO',
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