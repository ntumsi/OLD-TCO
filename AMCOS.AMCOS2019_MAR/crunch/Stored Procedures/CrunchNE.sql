-- ===============================================================================================
-- Author:		?
-- Create date: ?
-- Description:	Calculate cost elements in the NE pay plan
-- Notes:		This procedure was initially created by copying the contents of the RE pay plan.
-- ===============================================================================================
CREATE PROCEDURE [crunch].[CrunchNE]
    @MOS NVARCHAR(3),
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
        WHERE PayPlan = 'NE'
              AND CategorySubGroupCode = @MOS
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

    DECLARE @CMF NCHAR(2) = LEFT(@MOS, 2);
    DECLARE @Days FLOAT = 365.0;

    -- Average Inventory Projected (Budget)
    DECLARE @tblAverage_Inv_Prj TABLE
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
    INSERT INTO @tblAverage_Inv_Prj
    SELECT Code,
           GradeType,
           GradeLevel,
           Amount
    FROM dataload.SepParms
    WHERE PayPlan = 'NE'
          AND Code = 'AI_PRJ_ARNG';

    DECLARE @TotalAvgInvPrj FLOAT;
    SELECT @TotalAvgInvPrj = SUM(Amount)
    FROM @tblAverage_Inv_Prj;

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
    FROM dataload.NE_MilCompAllowances;

    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual');
    DECLARE @Basic_Benefit FLOAT = crunch.GetArmyBudgetSingleValue('NE_Basic_Benefit', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @Kicker FLOAT = crunch.GetArmyBudgetSingleValue('NE_EDU_Kicker', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @EducationBenefitsAmortizationAmount FLOAT
        = crunch.GetArmyBudgetSingleValue('Edu_Benefits_amort', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @NEStudentLoanRepayment FLOAT
        = crunch.GetArmyBudgetSingleValue('NE_Student_Loan_Repayment', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @Cost_of_Clothing_Allowance_ARNG FLOAT
        = crunch.GetArmyBudgetSingleValue('NE_Clothing_Allowance', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @NE_Endstrength FLOAT = crunch.GetArmyBudgetSingleValue('NE_Endstrength', 'NGPA', 'Avg', @AmcosVersionId);
    DECLARE @Average_Cost_of_Health_Care_per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
    DECLARE @Average_Cost_of_Initial_Issue_Clothing FLOAT
        = crunch.GetSingleValue('NE', 'Average_Cost_of_Initial_Issue_Clothing');
    DECLARE @NE_DHDG FLOAT = crunch.GetArmyBudgetSingleValue('NE_DHDG', 'NGPA', 'Avg', @AmcosVersionId);

    -- Calculations
    DECLARE @Total_Educ_Benefits FLOAT;
    SET @Total_Educ_Benefits = @Basic_Benefit + @Kicker + @EducationBenefitsAmortizationAmount;
    DECLARE @Other_Clothing FLOAT;
    SET @Other_Clothing
        = (@Cost_of_Clothing_Allowance_ARNG - @Average_Cost_of_Initial_Issue_Clothing *
                                              (
                                                  SELECT SUM(Amount)
                                                  FROM crunch.InventoryByCategorySubgroupGradeYos('NE')
                                                  WHERE GradeLevel IN ( 1, 2, 3 )
                                                        AND Step_YOS = 1
                                              )
          ) / (@TotalAvgInvPrj -
               (
                   SELECT SUM(Amount)
                   FROM crunch.InventoryByCategorySubgroupGradeYos('NE')
                   WHERE GradeLevel IN ( 1, 2, 3 )
                         AND Step_YOS = 1
               )
              );
    DECLARE @Avg_Cost_Heath_Care FLOAT;
    SET @Avg_Cost_Heath_Care = @Average_Cost_of_Health_Care_per_Family_Member / @Days;
    DECLARE @Avg_Cost_SLRP FLOAT;
    SET @Avg_Cost_SLRP = @NEStudentLoanRepayment / @TotalAvgInvPrj;
    DECLARE @Avg_Cost_DHDG FLOAT;
    SET @Avg_Cost_DHDG = @NE_DHDG / @NE_Endstrength;
    DECLARE @Avg_Educ_Benefits FLOAT;
    SET @Avg_Educ_Benefits = @Total_Educ_Benefits / @TotalAvgInvPrj;

    /* GET COST VALUES */

    /* Military Compensation; Avg Annualized Cost of Base Pay (Military) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 289,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgAnnualizedCostOfBasePayMilitary('NE', @MOS, @ActiveDutyDays);

    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 291,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    -- Other Benefits
    -- Other Benefits: Avg Cost of FICA
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 290,
           GradeType,
           GradeLevel,
           Amount * @FICA AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    -- Other Benefits
    -- Other Benefits: Disability, Hospitalization & Death Gratuities
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 330,
           GradeType,
           GradeLevel,
           @Avg_Cost_DHDG
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    -- Other Benefits
    -- Other Benefits: Avg Cost of Clothing Allowance
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 327,
           GradeType,
           GradeLevel,
           @Other_Clothing
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    -- Medical Support Costs
    -- Medical Support Costs: Avg Cost of Health Care
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 288,
           GradeType,
           GradeLevel,
           @Avg_Cost_Heath_Care * @ActiveDutyDays
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    -- Educational Benefits
    -- Educational Benefits: Avg Cost of Student Loan Repayment Program	
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 329,
           GradeType,
           GradeLevel,
           @Avg_Cost_SLRP
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    -- Educational Benefits
    -- Educational Benefits: Avg Cost of GI Bill
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 328,
           GradeType,
           GradeLevel,
           @Avg_Educ_Benefits
    FROM @CrunchCosts
    WHERE CostElementId = 289;

    /* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM @CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'NE'
              AND CategorySubGroupCode = @MOS
              AND [@CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );

    SELECT 'NE' AS PayPlan,
           @CMF AS CMF,
           @MOS AS MOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM @CrunchCosts;
END;