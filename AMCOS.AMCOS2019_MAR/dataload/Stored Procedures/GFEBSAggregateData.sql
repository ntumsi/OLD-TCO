

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[GFEBSAggregateData] @PayPlan NVARCHAR(3)
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO load_GFEBS.Processed
    (
        PayPlan,
        OccupationalGroupNumber,
        OccupationalSeriesNumber,
        StateCountry,
        FunctionalAreaCode,
        CostCenterCode,
        ActivityTypeCode,
        GradeLevel,
        Step,
        PayPeriodEndDate,
        PersonnelNumber,
        CostElementCode,
        PostalCode1,
        AmountPaid,
        PaidHours,
        ActualHourlyRate
    )
    SELECT PayPlan,
           OccupationalGroupNumber,
           OccupationalSeriesNumber,
           StateCountry,
           FunctionalAreaCode,
           CostCenterCode,
           ActivityTypeCode,
           GradeLevel,
           Step,
           PayPeriodEndDate,
           PersonnelNumber,
           CostElementCode,
           PostalCode1,
           SUM(AmountPaid) AS AmountPaid,
           SUM(PaidHours) AS PaidHours,
           MAX(ActualHourlyRate) AS ActualHourlyRate
    FROM load_GFEBS.Cleaned
    WHERE PayPlan = @PayPlan
    GROUP BY PayPlan,
             OccupationalGroupNumber,
             OccupationalSeriesNumber,
             StateCountry,
             FunctionalAreaCode,
             CostCenterCode,
             ActivityTypeCode,
             GradeLevel,
             Step,
             PayPeriodEndDate,
             PersonnelNumber,
             CostElementCode,
             PostalCode1;

END;