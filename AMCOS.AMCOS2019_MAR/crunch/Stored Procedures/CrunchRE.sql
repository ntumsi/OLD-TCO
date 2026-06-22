-- =============================================
-- Author:		RBPIII
-- Create date: July 14, 2002
-- Description:	Calculate cost elements in the RE pay plan
-- Update:		July 22, 2010
--				2011 Fiscal Year Full Update
-- Update:		September 20, 2011
--				2012 Full Update
-- =============================================
CREATE PROCEDURE [crunch].[CrunchRE]
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
        WHERE PayPlan = 'RE'
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
    WHERE PayPlan = 'RE'
          AND Code = 'AI_PRJ_USAR';

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
    FROM dataload.RE_MilCompAllowances;

    DECLARE @Retired_Pay_Accrual FLOAT = crunch.GetSingleValue('AA2', 'Retired_Pay_Accrual');
    DECLARE @Basic_Benefit FLOAT = crunch.GetArmyBudgetSingleValue('RE_Basic_Benefit', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Kicker FLOAT = crunch.GetArmyBudgetSingleValue('RE_Edu_Kicker', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @EducationBenefitsAmortizationAmount FLOAT
        = crunch.GetArmyBudgetSingleValue('Edu_Benefits_amort', 'MPA', 'Avg', @AmcosVersionId);
    DECLARE @REStudentLoanRepayment FLOAT
        = crunch.GetArmyBudgetSingleValue('RE_Student_Loan_Repayment', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Average_Cost_of_Health_Care_per_Family_Member FLOAT
        = crunch.GetSingleValue('AA', 'Health_Care_Cost_Per_Family_Member');
    DECLARE @Total_Educ_Benefits FLOAT;
    SET @Total_Educ_Benefits = @Basic_Benefit + @Kicker + @EducationBenefitsAmortizationAmount;

    /* GET COST VALUES */
    /* Military Compensation; Avg Annualized Cost of Base Pay (Military) */
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 453,
           GradeType,
           GradeLevel,
           Amount
    FROM crunch.AvgAnnualizedCostOfBasePayMilitary('RE', @MOS, @ActiveDutyDays);

    -- Retired Pay Accrual: Avg Cost of Retired Pay Accrual
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 455,
           GradeType,
           GradeLevel,
           Amount * @Retired_Pay_Accrual AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    -- Other Benefits: Avg Cost of FICA
    DECLARE @FICA FLOAT = crunch.GetSingleValue('AA', 'FICA');
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 454,
           GradeType,
           GradeLevel,
           Amount * @FICA AS calAmount
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    -- Other Benefits: Disability, Hospitalization & Death Gratuities
    DECLARE @RE_DHDG FLOAT = crunch.GetArmyBudgetSingleValue('RE_DHDG', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @RE_Endstrength FLOAT = crunch.GetArmyBudgetSingleValue('RE_Endstrength', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Avg_Cost_DHDG FLOAT = @RE_DHDG / @RE_Endstrength;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 494,
           GradeType,
           GradeLevel,
           @Avg_Cost_DHDG
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    -- Other Benefits: Avg Cost of Clothing Allowance
    DECLARE @Cost_of_Clothing_Allowance_USAR FLOAT
        = crunch.GetArmyBudgetSingleValue('RE_Clothing_Allowance', 'RPA', 'Avg', @AmcosVersionId);
    DECLARE @Average_Cost_of_Initial_Issue_Clothing FLOAT
        = crunch.GetSingleValue('RE', 'Average_Cost_of_Initial_Issue_Clothing');
    DECLARE @Other_Clothing FLOAT;
    SET @Other_Clothing
        = (@Cost_of_Clothing_Allowance_USAR - @Average_Cost_of_Initial_Issue_Clothing *
                                              (
                                                  SELECT SUM(Amount)
                                                  FROM crunch.InventoryByCategorySubgroupGradeYos('RE')
                                                  WHERE GradeLevel IN ( 1, 2, 3 )
                                                        AND Step_YOS = 1
                                              )
          ) / (@TotalAvgInvPrj -
               (
                   SELECT SUM(Amount)
                   FROM crunch.InventoryByCategorySubgroupGradeYos('RE')
                   WHERE GradeLevel IN ( 1, 2, 3 )
                         AND Step_YOS = 1
               )
              );
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 491,
           GradeType,
           GradeLevel,
           @Other_Clothing
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    -- Medical Support Costs: Avg Cost of Health Care
    DECLARE @Avg_Cost_Heath_Care FLOAT;
    SET @Avg_Cost_Heath_Care = @Average_Cost_of_Health_Care_per_Family_Member / @Days;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 452,
           GradeType,
           GradeLevel,
           @Avg_Cost_Heath_Care * @ActiveDutyDays
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    -- Educational Benefits: Avg Cost of Student Loan Repayment Program	
    DECLARE @Avg_Cost_SLRP FLOAT;
    SET @Avg_Cost_SLRP = @REStudentLoanRepayment / @TotalAvgInvPrj;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 493,
           GradeType,
           GradeLevel,
           @Avg_Cost_SLRP
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    -- Educational Benefits: Avg Cost of GI Bill
    DECLARE @Avg_Educ_Benefits FLOAT;
    SET @Avg_Educ_Benefits = @Total_Educ_Benefits / @TotalAvgInvPrj;
    INSERT INTO @CrunchCosts
    (
        CostElementId,
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT 492,
           GradeType,
           GradeLevel,
           @Avg_Educ_Benefits
    FROM @CrunchCosts
    WHERE CostElementId = 453;

    /* Delete rows in which there is no inventory for the given CategorySubGroup and GradeLevel*/
    DELETE FROM @CrunchCosts
    WHERE NOT EXISTS
    (
        SELECT DISTINCT
               GradeLevel
        FROM data.Inventory
        WHERE PayPlan = 'RE'
              AND CategorySubGroupCode = @MOS
              AND [@CrunchCosts].GradeLevel = GradeLevel
              AND Inventory > 0
    );

    SELECT 'RE' AS PayPlan,
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