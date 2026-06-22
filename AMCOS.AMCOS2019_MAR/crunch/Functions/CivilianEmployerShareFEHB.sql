
-- =============================================
-- Description:		If the person has this element then use Amount * 26
--					If the person is missing 12N, then compute an average within the pay plan of those who do have the 12N
-- =============================================
CREATE FUNCTION [crunch].[CivilianEmployerShareFEHB]
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

    DECLARE @AvgCivlianEmployerShareFEHB NUMERIC(18, 4);

    SELECT @AvgCivlianEmployerShareFEHB = AVG(AmountPaid)
    FROM load_GFEBS.Processed
    WHERE CostElementCode IN ( '6400.12N0' )
          AND PayPlan = @PayPlan;

    WITH PersonnelNumberThatContainFEHB_CTE
    AS (SELECT DISTINCT
               PersonnelNumber
        FROM load_GFEBS.Processed
        WHERE CostElementCode IN ( '6400.12N0' )),
         PersonnelNumberThatDoNotContainFEHB_CTE
    AS (SELECT DISTINCT
               PersonnelNumber
        FROM load_GFEBS.Processed
        WHERE PersonnelNumber NOT IN (
                                         SELECT PersonnelNumber FROM PersonnelNumberThatContainFEHB_CTE
                                     ))
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
                                   'Civ Employer Share FEHB (Fed Employees Group Health Benefit Insurance) (6400.12N0)'
                               ) AS CostElementId,
           SUM(AmountPaid) * 26 AS Amount
    FROM load_GFEBS.Processed
    WHERE PayPlan = @PayPlan
          AND CostElementCode IN ( '6400.12N0' )
          AND PersonnelNumber IN (
                                     SELECT PersonnelNumber FROM PersonnelNumberThatContainFEHB_CTE
                                 )
    GROUP BY PayPlan,
             OccupationalGroupNumber,
             OccupationalSeriesNumber,
             StateCountry,
             FunctionalAreaCode,
             CostCenterCode,
             GradeLevel,
             Step,
             PersonnelNumber
    UNION ALL
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
                                   'Civ Employer Share FEHB (Fed Employees Group Health Benefit Insurance) (6400.12N0)'
                               ) AS CostElementId,
           @AvgCivlianEmployerShareFEHB * 26 AS Amount
    FROM load_GFEBS.Processed
    WHERE PayPlan = @PayPlan
          AND PersonnelNumber IN (
                                     SELECT PersonnelNumber FROM PersonnelNumberThatDoNotContainFEHB_CTE
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