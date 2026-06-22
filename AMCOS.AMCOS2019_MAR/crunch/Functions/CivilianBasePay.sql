
-- ========================================================================================================
-- Description:  Compute civilian base pay for pay plans that receive locality pay.
-- ========================================================================================================
CREATE FUNCTION [crunch].[CivilianBasePay]
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
BEGIN;

    WITH PersonnelNumberThatDoNotReceiveLocalityPay_CTE
    AS (SELECT DISTINCT
               PersonnelNumber
        FROM load_GFEBS.Processed
        WHERE CostElementCode IN ( '6100.11T0', '6100.11J0', '6100.12B0' )),
         PersonnelNumberThatReceiveLocalityPay_CTE
    AS (SELECT DISTINCT
               PersonnelNumber
        FROM load_GFEBS.Processed
        WHERE PersonnelNumber NOT IN
              (
                  SELECT PersonnelNumber FROM PersonnelNumberThatDoNotReceiveLocalityPay_CTE
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
           GradeType,
           GradeLevel,
           Step,
           PersonnelNumber,
           dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Base Pay (6100.11B1)') AS CostElementId,
           SUM(Amount)
    FROM
    (
        SELECT GFEBS.PayPlan,
               GFEBS.OccupationalGroupNumber,
               GFEBS.OccupationalSeriesNumber,
               GFEBS.StateCountry,
               GFEBS.FunctionalAreaCode,
               GFEBS.CostCenterCode,
               NULL AS GradeType,
               GFEBS.GradeLevel,
               GFEBS.Step,
               PersonnelNumberThatReceiveLocalityPay_CTE.PersonnelNumber,
               dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Base Pay (6100.11B1)') AS CostElementId,
               (MAX(GFEBS.ActualHourlyRate) * 2087.0) AS Amount
        FROM load_GFEBS.Processed GFEBS
            INNER JOIN PersonnelNumberThatReceiveLocalityPay_CTE
                ON PersonnelNumberThatReceiveLocalityPay_CTE.PersonnelNumber = GFEBS.PersonnelNumber
        WHERE GFEBS.PayPlan = @PayPlan
              AND GFEBS.CostElementCode IN ( '6100.11B1' )
        GROUP BY GFEBS.PayPlan,
                 GFEBS.OccupationalGroupNumber,
                 GFEBS.OccupationalSeriesNumber,
                 GFEBS.StateCountry,
                 GFEBS.FunctionalAreaCode,
                 GFEBS.CostCenterCode,
                 GFEBS.GradeLevel,
                 GFEBS.Step,
                 PersonnelNumberThatReceiveLocalityPay_CTE.PersonnelNumber
        UNION ALL
        SELECT CivilianLocalityPay.PayPlan,
               CivilianLocalityPay.OccupationalGroupNumber,
               CivilianLocalityPay.OccupationalSeriesNumber,
               CivilianLocalityPay.StateCountry,
               CivilianLocalityPay.FunctionalAreaCode,
               CivilianLocalityPay.CostCenterCode,
               CivilianLocalityPay.GradeType,
               CivilianLocalityPay.GradeLevel,
               CivilianLocalityPay.Step,
               PersonnelNumberThatReceiveLocalityPay_CTE.PersonnelNumber,
               CivilianLocalityPay.CostElementId,
               CivilianLocalityPay.Amount * -1.0
        FROM crunch.CivilianLocalityPay(@PayPlan)
            INNER JOIN PersonnelNumberThatReceiveLocalityPay_CTE
                ON PersonnelNumberThatReceiveLocalityPay_CTE.PersonnelNumber = CivilianLocalityPay.PersonnelNumber
        UNION ALL
        SELECT GFEBS.PayPlan,
               GFEBS.OccupationalGroupNumber,
               GFEBS.OccupationalSeriesNumber,
               GFEBS.StateCountry,
               GFEBS.FunctionalAreaCode,
               GFEBS.CostCenterCode,
               NULL AS GradeType,
               GFEBS.GradeLevel,
               GFEBS.Step,
               PersonnelNumberThatDoNotReceiveLocalityPay_CTE.PersonnelNumber,
               dbo.GetCostElementId(@PayPlan, 'Army CivPay', 'Civ Base Pay (6100.11B1)') AS CostElementId,
               (MAX(GFEBS.ActualHourlyRate) * 2087.0) AS Amount
        FROM load_GFEBS.Processed GFEBS
            INNER JOIN PersonnelNumberThatDoNotReceiveLocalityPay_CTE
                ON PersonnelNumberThatDoNotReceiveLocalityPay_CTE.PersonnelNumber = GFEBS.PersonnelNumber
        WHERE GFEBS.PayPlan = @PayPlan
              AND GFEBS.CostElementCode IN ( '6100.11B1' )
        GROUP BY GFEBS.PayPlan,
                 GFEBS.OccupationalGroupNumber,
                 GFEBS.OccupationalSeriesNumber,
                 GFEBS.StateCountry,
                 GFEBS.FunctionalAreaCode,
                 GFEBS.CostCenterCode,
                 GFEBS.GradeLevel,
                 GFEBS.Step,
                 PersonnelNumberThatDoNotReceiveLocalityPay_CTE.PersonnelNumber
    ) CostsToSum
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