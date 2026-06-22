
CREATE VIEW [analysis].[Outlier_Payschedules]
AS
--exec crunch.CalculatePayPlanMinMax @amcosversionid=202101

SELECT SUM(Costs.Amount) AS Amt,
       b.MinRate,
       b.MaxRate,
       Costs.PayPlan,
       Costs.CategoryGroupCode,
       Costs.CategorySubgroupCode,
       d.CategoryGroupDescription,
       d.CategorySubgroupDescription,
       Costs.CareerProgramNumber,
       Costs.LocationId,
       Location.DisplayName,
       Costs.Strl,
       Costs.GradeType,
       Costs.GradeLevel,
       Costs.AmcosVersionId
FROM data.Costs AS Costs
    LEFT OUTER JOIN crunch.PayScheduleMinMax AS b
        ON Costs.PayPlan = b.PayPlan
           AND Costs.CategoryGroupCode = b.CategoryGroupCode
           AND Costs.CategorySubgroupCode = b.CategorySubgroupCode
           AND b.CareerProgramNumber = Costs.CareerProgramNumber
           AND b.GradeLevel = Costs.GradeLevel
           AND b.LocationId = Costs.LocationId
           AND b.STRL = Costs.Strl
           AND b.AmcosVersionId = Costs.AmcosVersionId
    LEFT OUTER JOIN warehouse.Location AS Location
        ON Costs.LocationId = Location.LocationId
    LEFT OUTER JOIN data.CategorySubgroup AS d
        ON Costs.CategorySubgroupCode = d.CategorySubgroupCode
           AND Costs.PayPlan = d.PayPlan
WHERE Costs.AmcosVersionId = 202101
      AND Costs.CostElementId IN
          (
              SELECT CostElementId
              FROM lookup.CostElement
              WHERE CostElementName LIKE '%base pay%'
                    OR CostElementName LIKE '%civ locality%'
          )
GROUP BY b.MinRate,
         b.MaxRate,
         Costs.PayPlan,
         Costs.CategoryGroupCode,
         Costs.CategorySubgroupCode,
         Costs.CareerProgramNumber,
         Costs.LocationId,
         Location.DisplayName,
         Costs.Strl,
         Costs.GradeType,
         Costs.GradeLevel,
         d.CategoryGroupDescription,
         d.CategorySubgroupDescription,
         Costs.AmcosVersionId
HAVING (
           SUM(Costs.Amount) > b.MaxRate
           OR SUM(Costs.Amount) < b.MinRate
       );