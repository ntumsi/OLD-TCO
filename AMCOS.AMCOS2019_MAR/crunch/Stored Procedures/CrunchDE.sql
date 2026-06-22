
CREATE PROCEDURE [crunch].[CrunchDE] @AmcosVersionId INT = -1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    TRUNCATE TABLE crunch.TempCostGFEBS;

    /*Calculate annual amounts for cost elements*/
    BEGIN

        /*Army CivPay
			Compensation - Basic
			Civ Base Pay (6100.11B1)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianBasePay('DE');

        /*Army CivPay
			Compensation - Basic
			Civ Locality Pay*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianLocalityPay('DE');

        /*Army CivPay
			Compensation - Basic
			Civ Title 38:  Medical Premium Pay (6100.11N0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianMedicalPremiumPay('DE');

        /*Army CivPay
			Cash Awards
			Civ Cash Awards Pay (6100.11K0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianCashAwardsPay('DE');

        /*Army CivPay
			Benefits
			Civ Employer Share FEGLI (Fed Employees Group Life Insurance) (6400.12K0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianEmployerShareFEGLI('DE');

        /*Army CivPay
			Benefits
			Civ Employer Share FEHB (Fed Employees Group Health Benefit Insurance) (6400.12N0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianEmployerShareFEHB('DE');

        /*Army CivPay
		Benefits
		Civ Employer Share Retirement (6100.12Y0, 6400.12L0, 6400.12M0, 6400.12X0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianEmployerShareRetirement('DE');

        /*Army CivPay
			Benefits
			Civ Non-Foreign COLA (Cost of Living Allowance) Pay (6100.12C0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianNonForeignCOLA('DE');

        /*Army CivPay
			Other
			Civ Other Benefits not Otherwise Classified (6100.12S2)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianOtherBenefits('DE');

        /*Army CivPay
			Benefits
			Civ Overseas Allowances (Civ Quarters, COLA, LQA, & Other not classified) (6100.12B0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianOverseasAllowances('DE');

        /*Army CivPay
			Compensation - Other
			Civ Hazardous Duty Pay*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianHazardousDutyPay('DE');

        /*Army CivPay
			Compensation - Other
			Civ Physician Comparability Pay (Market Pay) (6100.11T0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianPhysicianComparabilityPay('DE');

        /*Army CivPay
			Compensation - Other
			Civ Post Differential Pay (O/S Hardship Post) (6100.11J0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianPostDifferentialPay('DE');

        /*Army CivPay
			Compensation - Other
			Civ Supervisory Special Pay (6100.11Q0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianSupervisorySpecialPay('DE');

        /*Army CivPay
			Benefits
			Civ Employer Share FICA / Medicare (6400.12Q0)*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianEmployerShareFICA('DE');

        /*OMA
			Training Costs
			Training*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianTraining('DE');

        /*Federal OM
			Retired Pay Accrual
			Post Retirement Health*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianPostRetirementHealth('DE');

        /*Federal OM
			Retired Pay Accrual
			Post Retirement Life Insurance*/
        INSERT INTO crunch.TempCostGFEBS
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
            Amount
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               CostElementId,
               GradeLevel,
               PersonnelNumber,
               Amount
        FROM crunch.CivilianPostRetirementLifeInsurance('DE');
    END;

    SELECT 'DE' AS PayPlan,
           OccupationalGroupNumber,
           OccupationalSeriesNumber,
           StateCountry,
           FunctionalAreaCode,
           CostCenterCode,
           GradeLevel,
           PersonnelNumber,
           CostElementId,
           Amount,
           CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime
    FROM crunch.TempCostGFEBS;

END;