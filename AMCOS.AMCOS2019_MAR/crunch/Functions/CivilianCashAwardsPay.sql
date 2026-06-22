
-- ==========================================================================================================================
-- Description:	(Civ Base Pay (6100.11B1) + Civ Physician Comparability Pay (Market Pay) (6100.11T0)) * Cash Awards Percentage
-- ==========================================================================================================================
CREATE FUNCTION [crunch].[CivilianCashAwardsPay]
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
    [GradeType] NVARCHAR(3) NULL,
    [GradeLevel] TINYINT NOT NULL,
    [Step] TINYINT NULL,
    [PersonnelNumber] NVARCHAR(10) NOT NULL,
    [CostElementId] INT NOT NULL,
    [Amount] NUMERIC(18, 4) NOT NULL
)
AS
BEGIN


    DECLARE @PercentCivCashAwards FLOAT =
    (
        SELECT paramValue
        FROM dataload.SingleValues
        WHERE PayPlan = 'GP'
              AND paramName = 'percentCivCashAwards'
    ) / 100;

    WITH CostElements_CTE
    AS (SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               GradeType,
               GradeLevel,
               Step,
               PersonnelNumber,
               CostElementId,
               Amount
        FROM crunch.CivilianBasePay(@PayPlan)
        UNION ALL
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               GradeType,
               GradeLevel,
               Step,
               PersonnelNumber,
               CostElementId,
               Amount
        FROM crunch.CivilianLocalityPay(@PayPlan)
        UNION ALL
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               GradeType,
               GradeLevel,
               Step,
               PersonnelNumber,
               CostElementId,
               Amount
        FROM crunch.CivilianPhysicianComparabilityPay(@PayPlan) )
    INSERT INTO @Costs
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        StateCountry,
        FunctionalAreaCode,
        CostCenterCode,
        GradeType,
        GradeLevel,
        Step,
        PersonnelNumber,
        CostElementId,
        Amount
    )
    SELECT PayPlan,
           OccupationalGroupNumber,
           OccupationalSeriesNumber,
           StateCountry,
           FunctionalAreaCode,
           CostCenterCode,
           GradeType,
           GradeLevel,
           Step,
           PersonnelNumber,
           dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Cash Awards Pay (6100.11K0)') AS CostElementId,
           SUM(Amount) * @PercentCivCashAwards
    FROM CostElements_CTE
    GROUP BY PayPlan,
             OccupationalGroupNumber,
             OccupationalSeriesNumber,
             StateCountry,
             FunctionalAreaCode,
             CostCenterCode,
             GradeType,
             GradeLevel,
             Step,
             PersonnelNumber;
    RETURN;
END;