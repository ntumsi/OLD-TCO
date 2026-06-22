
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[CivilianEmployerShareFICA]
(
    @PayPlan NVARCHAR(3)
)
RETURNS @Costs TABLE
(
    [PayPlan] NVARCHAR(3) NULL,
    [OccupationalGroupNumber] NVARCHAR(4) NULL,
    [OccupationalSeriesNumber] NVARCHAR(4) NOT NULL,
    [StateCountry] NVARCHAR(50) NOT NULL,
    [FunctionalAreaCode] NVARCHAR(50) NOT NULL,
    [CostCenterCode] NVARCHAR(50) NOT NULL,
    [CostElementId] INT NOT NULL,
    [GradeLevel] TINYINT NOT NULL,
    [PersonnelNumber] NVARCHAR(10) NOT NULL,
    [Step] TINYINT NULL,
    [Amount] NUMERIC(18, 4) NOT NULL
)
AS
BEGIN

    DECLARE @PercentMedicare NUMERIC(9, 8) = crunch.GetSingleValue('AA', 'percentMedicare');
    DECLARE @PercentSocialSecurity NUMERIC(9, 8) = crunch.GetSingleValue('AA', 'PercentSocialSecurity');
    DECLARE @SocialSecurityUpperLimit NUMERIC(6, 0) = crunch.GetSingleValue('AA', 'SocialSecurityUpperLimit');
    DECLARE @MaxSocialSecurityDeduction NUMERIC(18, 2) = @PercentSocialSecurity * @SocialSecurityUpperLimit;

    DECLARE @CostElementId INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Employer Share FICA / Medicare (6400.12Q0)');


    DECLARE @CostElementIdBasePay INT = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Base Pay (6100.11B1)');
    DECLARE @CostElementIdLocalityPay INT = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Locality Pay');
    DECLARE @CostElementIdHazardousDutyPay INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Hazardous Duty Pay (6100.11H0)');
    DECLARE @CostElementIdPostDifferentialPay INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Post Differential Pay (O/S Hardship Post) (6100.11J0)');
    DECLARE @CostElementIdCashAwardsPay INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Cash Awards Pay (6100.11K0)');
    DECLARE @CostElementIdMedicalPremiumPay INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Title 38:  Medical Premium Pay (6100.11N0)');
    DECLARE @CostElementIdSupervisorySpecialPay INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Supervisory Special Pay (6100.11Q0)');
    DECLARE @CostElementIdPhysicianComparabilityPay INT
        = dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Physician Comparability Pay (Market Pay) (6100.11T0)');
    DECLARE @CostElementIdOverseasAllowances INT
        = dbo.GetCostElementId(
                                  @PayPlan,
                                  'Army CivPay',
                                  'Civ Overseas Allowances (Civ Quarters, COLA, LQA, & Other not classified) (6100.12B0)'
                              );
    DECLARE @CostElementIdNonForeignCOLA INT
        = dbo.GetCostElementId(
                                  @PayPlan,
                                  'Army CivPay',
                                  'Civ Non-Foreign COLA (Cost of Living Allowance) Pay (6100.12C0)'
                              );


    /* Calculate Medicare */
    WITH Medicare_CTE (PayPlan, OccupationalGroupNumber, OccupationalSeriesNumber, StateCountry, FunctionalAreaCode,
                       CostCenterCode, CostElementId, GradeLevel, PersonnelNumber, Step, Amount
                      )
    AS (SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               @CostElementId,
               GradeLevel,
               PersonnelNumber,
               Step,
               SUM(Amount) * @PercentMedicare AS Amount
        FROM crunch.TempCostGFEBS
        WHERE PayPlan = @PayPlan
              AND CostElementId IN ( @CostElementIdBasePay, @CostElementIdLocalityPay, @CostElementIdHazardousDutyPay,
                                     @CostElementIdPostDifferentialPay, @CostElementIdCashAwardsPay,
                                     @CostElementIdMedicalPremiumPay, @CostElementIdSupervisorySpecialPay,
                                     @CostElementIdPhysicianComparabilityPay, @CostElementIdOverseasAllowances,
                                     @CostElementIdNonForeignCOLA
                                   )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 StateCountry,
                 FunctionalAreaCode,
                 CostCenterCode,
                 GradeLevel,
                 PersonnelNumber,
                 Step),
         /* Calculate Social Security */
         SocialSecurity_CTE (PayPlan, OccupationalGroupNumber, OccupationalSeriesNumber, StateCountry,
                             FunctionalAreaCode, CostCenterCode, CostElementId, GradeLevel, PersonnelNumber, Step,
                             Amount
                            )
    AS (SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               @CostElementId,
               GradeLevel,
               PersonnelNumber,
               Step,
               Amount = CASE
                            WHEN SUM(Amount) * @PercentSocialSecurity > @MaxSocialSecurityDeduction THEN
                                @MaxSocialSecurityDeduction
                            ELSE
                                SUM(Amount) * @PercentSocialSecurity
                        END
        FROM crunch.TempCostGFEBS
        WHERE PayPlan = @PayPlan
              AND CostElementId IN ( @CostElementIdBasePay, @CostElementIdLocalityPay, @CostElementIdHazardousDutyPay,
                                     @CostElementIdPostDifferentialPay, @CostElementIdCashAwardsPay,
                                     @CostElementIdMedicalPremiumPay, @CostElementIdSupervisorySpecialPay,
                                     @CostElementIdPhysicianComparabilityPay, @CostElementIdOverseasAllowances,
                                     @CostElementIdNonForeignCOLA
                                   )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 StateCountry,
                 FunctionalAreaCode,
                 CostCenterCode,
                 GradeLevel,
                 PersonnelNumber,
                 Step)
    INSERT INTO @Costs
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        StateCountry,
        FunctionalAreaCode,
        CostCenterCode,
        CostElementId,
        GradeLevel,
        PersonnelNumber,
        Step,
        Amount
    )
    SELECT Medicare.PayPlan,
           Medicare.OccupationalGroupNumber,
           Medicare.OccupationalSeriesNumber,
           Medicare.StateCountry,
           Medicare.FunctionalAreaCode,
           Medicare.CostCenterCode,
           @CostElementId,
           Medicare.GradeLevel,
           Medicare.PersonnelNumber,
           Medicare.Step,
           Medicare.Amount + SocialSecurity.Amount AS Amount
    FROM Medicare_CTE Medicare
        INNER JOIN SocialSecurity_CTE SocialSecurity
            ON SocialSecurity.PayPlan = Medicare.PayPlan
               AND SocialSecurity.OccupationalGroupNumber = Medicare.OccupationalGroupNumber
               AND SocialSecurity.OccupationalSeriesNumber = Medicare.OccupationalSeriesNumber
               AND SocialSecurity.StateCountry = Medicare.StateCountry
               AND SocialSecurity.FunctionalAreaCode = Medicare.FunctionalAreaCode
               AND SocialSecurity.CostCenterCode = Medicare.CostCenterCode
               AND SocialSecurity.GradeLevel = Medicare.GradeLevel
               AND SocialSecurity.PersonnelNumber = Medicare.PersonnelNumber;

    RETURN;
END;