

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[CivilianEmployerShareRetirement]
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
    /*Compute retirement costs for personnel receiving one of the four elements*/
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
           dbo.GetCostElementId(
                                   @PayPlan,
                                   'Army CivPay',
                                   'Civ Employer Share Retirement (6100.12Y0, 6400.12L0, 6400.12M0, 6400.12X0)'
                               ) AS CostElementId,
           SUM(AmountPaid) * 26 AS Amount
    FROM load_GFEBS.Processed
    WHERE PayPlan = @PayPlan
          AND CostElementCode IN ( '6100.12Y0', '6400.12L0', '6400.12M0', '6400.12X0' )
    GROUP BY PayPlan,
             OccupationalGroupNumber,
             OccupationalSeriesNumber,
             StateCountry,
             FunctionalAreaCode,
             CostCenterCode,
             GradeLevel,
             Step,
             PersonnelNumber;

    /*Compute retirement costs for personnel not receiving one of the four elements*/
    DECLARE @AvgFERS NUMERIC(18, 4);
    WITH SumFERS
    AS (SELECT PayPlan,
               SUM(AmountPaid) AS amount,
               COUNT(DISTINCT PersonnelNumber) AS Personnel
        FROM load_GFEBS.Processed
        WHERE CostElementCode IN ( '6100.12Y0', '6400.12X0' )
              AND PayPlan = @PayPlan
        GROUP BY PayPlan)
    SELECT @AvgFERS = amount / Personnel
    FROM SumFERS;

    WITH PersonnelWithRetirementElements
    AS (SELECT DISTINCT
               PersonnelNumber
        FROM load_GFEBS.Processed
        WHERE CostElementCode IN ( '6100.12Y0', '6400.12L0', '6400.12M0', '6400.12X0' ))
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
           dbo.GetCostElementId(
                                   @PayPlan,
                                   'Army CivPay',
                                   'Civ Employer Share Retirement (6100.12Y0, 6400.12L0, 6400.12M0, 6400.12X0)'
                               ) AS CostElementId,
           @AvgFERS * 26 AS Amount
    FROM load_GFEBS.Processed
    WHERE PayPlan = @PayPlan
          AND PersonnelNumber NOT IN (
                                         SELECT PersonnelNumber FROM PersonnelWithRetirementElements
                                     )
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