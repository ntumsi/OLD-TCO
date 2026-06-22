
-- =============================================
-- Author:		Dan Hogan
-- Create date: 1/7/2021
-- Description:	Every base pay element must be inside the defined min/max pay as determined by crunch.PayPlanMinMax
-- =============================================
CREATE PROCEDURE [test].[MinMaxPay] @AmcosVersionId INT = -1
AS
BEGIN

    SELECT 'summary of pp outside min/max';
    SELECT Costs.PayPlan,
           COUNT(Costs.Amount) AS number
    FROM data.Costs Costs
        LEFT OUTER JOIN crunch.PayScheduleMinMax PayScheduleMinMax
            ON PayScheduleMinMax.AmcosVersionId = Costs.AmcosVersionId
               AND PayScheduleMinMax.CareerProgramNumber = Costs.CareerProgramNumber
               AND PayScheduleMinMax.CategoryGroupCode = Costs.CategoryGroupCode
               AND PayScheduleMinMax.CategorySubgroupCode = Costs.CategorySubgroupCode
               AND PayScheduleMinMax.GradeLevel = Costs.GradeLevel
               AND PayScheduleMinMax.LocationId = Costs.LocationId
               AND PayScheduleMinMax.PayPlan = Costs.PayPlan
               AND PayScheduleMinMax.STRL = Costs.Strl
               AND PayScheduleMinMax.AmcosVersionId = Costs.AmcosVersionId
        LEFT OUTER JOIN warehouse.Location Location
            ON Location.LocationId = Costs.LocationId
    WHERE Costs.AmcosVersionId = @AmcosVersionId
          AND Costs.CostElementName LIKE '%base%pay%'
          AND Costs.Amount NOT
          BETWEEN PayScheduleMinMax.MinRate AND PayScheduleMinMax.MaxRate
    GROUP BY Costs.PayPlan
    ORDER BY Costs.PayPlan;

    SELECT 'detail of base pay outside min/max';
    SELECT Costs.PayPlan,
           Costs.Amount,
           PayScheduleMinMax.MinRate,
           PayScheduleMinMax.MaxRate,
           Costs.GradeLevel,
           Costs.CategorySubgroupCode,
           Costs.CategoryGroupCode,
           Costs.LocationId,
           Location.DisplayName,
           Costs.CareerProgramNumber,
           Costs.Strl,
           Costs.CostElementName,
           Costs.AmcosVersionId
    FROM data.Costs Costs
        LEFT OUTER JOIN crunch.PayScheduleMinMax PayScheduleMinMax
            ON PayScheduleMinMax.AmcosVersionId = Costs.AmcosVersionId
               AND PayScheduleMinMax.CareerProgramNumber = Costs.CareerProgramNumber
               AND PayScheduleMinMax.CategoryGroupCode = Costs.CategoryGroupCode
               AND PayScheduleMinMax.CategorySubgroupCode = Costs.CategorySubgroupCode
               AND PayScheduleMinMax.GradeLevel = Costs.GradeLevel
               AND PayScheduleMinMax.LocationId = Costs.LocationId
               AND PayScheduleMinMax.PayPlan = Costs.PayPlan
               AND PayScheduleMinMax.STRL = Costs.Strl
               AND PayScheduleMinMax.AmcosVersionId = Costs.AmcosVersionId
        LEFT OUTER JOIN warehouse.Location Location
            ON Location.LocationId = Costs.LocationId
    WHERE Costs.AmcosVersionId = @AmcosVersionId
          AND Costs.CostElementName LIKE '%base%pay%'
          AND Costs.Amount NOT
          BETWEEN PayScheduleMinMax.MinRate AND PayScheduleMinMax.MaxRate
    ORDER BY Costs.CategorySubgroupCode DESC,
             Costs.LocationId,
             Costs.PayPlan;
END;