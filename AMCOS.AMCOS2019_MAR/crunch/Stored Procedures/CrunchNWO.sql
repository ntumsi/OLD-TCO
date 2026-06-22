CREATE PROCEDURE [crunch].[CrunchNWO]
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
        WHERE PayPlan = 'NWO'
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
    WHERE GradeType = 'W'
          AND Code = 'ARNG';

    DECLARE @TotalAvgPrjInv FLOAT;
    SELECT @TotalAvgPrjInv = SUM(Amount)
    FROM @tblAverage_Prj_Inv;

    DECLARE @tblMilCompAllowances TABLE
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
    INSERT INTO @tblMilCompAllowances
    SELECT Code,
           GradeType,
           GradeLevel,
           Amount
    FROM dataload.NO_MilCompAllowances;

    /* BEGIN COST FACTOR PROCESSING */
    DECLARE @NO_NWO_Endstrength FLOAT
        = crunch.GetArmyBudgetSingleValue('NO_NWO_Endstrength', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @NO_NWO_DHDG FLOAT = crunch.GetArmyBudgetSingleValue('NO_NWO_DHDG', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @NO_NWO_Clothing_Allowance FLOAT
        = crunch.GetArmyBudgetSingleValue('NO_NWO_Clothing_allowance', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Average_Cost_of_Health_Care_per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual');
    DECLARE @Avg_Cost_Heath_Care FLOAT;
    SET @Avg_Cost_Heath_Care = @Average_Cost_of_Health_Care_per_Family_Member / @Days;
    DECLARE @Avg_Cost_DHDG FLOAT;
    SET @Avg_Cost_DHDG = @NO_NWO_DHDG / @NO_NWO_Endstrength;

    /* GET COST VALUES */

    /* Military Compensation; Avg Annualized Cost of Base Pay (Military) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 413,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgAnnualizedCostOfBasePayMilitary('NWO', @WOMOS, @ActiveDutyDays);

    -- Retired Pay Accrual 
    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 415,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 413;

    -- Other Benefits
    -- Other Benefits: Avg Cost of FICA
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 414,
           GradeType,
           GradeLevel,
           Amount * @FICA AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 413;

    -- Other Benefits
    -- Other Benefits: Disability, Hospitalization & Death Gratuities
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 439,
           GradeType,
           GradeLevel,
           @Avg_Cost_DHDG
    FROM @CrunchCosts
    WHERE CostElementId = 413;

    -- Other Benefits
    -- Other Benefits: Avg Cost of Clothing Allowance
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 438,
           GradeType,
           GradeLevel,
           @NO_NWO_Clothing_Allowance / @TotalAvgPrjInv
    FROM @CrunchCosts
    WHERE CostElementId = 413;

    -- Medical Support Costs
    -- Medical Support Costs: Avg Cost of Health Care
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 412,
           GradeType,
           GradeLevel,
           @Avg_Cost_Heath_Care * @ActiveDutyDays
    FROM @CrunchCosts
    WHERE CostElementId = 413;

    --/* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM @CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'NWO'
              AND CategorySubGroupCode = @WOMOS
              AND [@CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );

    SELECT 'NWO',
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