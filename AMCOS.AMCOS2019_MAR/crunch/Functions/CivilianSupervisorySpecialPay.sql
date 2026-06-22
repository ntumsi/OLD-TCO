




-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[CivilianSupervisorySpecialPay]
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
           NULL AS GradeType,
           GradeLevel,
           Step,
           PersonnelNumber,
           dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Supervisory Special Pay (6100.11Q0)') AS CostElementId,
           SUM(AmountPaid) * 26 AS Amount
    FROM load_GFEBS.Processed
    WHERE PayPlan = @PayPlan
          AND CostElementCode IN ( '6100.11Q0' )
    GROUP BY PayPlan,
             OccupationalGroupNumber,
             OccupationalSeriesNumber,
             StateCountry,
             FunctionalAreaCode,
             CostCenterCode,
             GradeLevel,
             Step,
             PersonnelNumber;

    RETURN;
END;