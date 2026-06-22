
CREATE VIEW [load_GFEBS].[GPStep]
AS
SELECT DISTINCT
       c.GradeLevel,
       c.Step,
       c.Rate,
       c.AmcosVersionId
FROM
(
    SELECT PayPlan,
           PersonnelNumber,
           GradeLevel,
           AmcosVersionId,
           MAX(ActualHourlyRate) * 2087 AS Rate
    FROM load_GFEBS.Cleaned
    WHERE PayPlan = 'GP'
          AND CostElementCode = '6100.11B1'
    GROUP BY PayPlan,
             PersonnelNumber,
             GradeLevel,
             AmcosVersionId
) AS GFEBS
    CROSS APPLY
(
    SELECT TOP (1)
           PaySchedule.GradeLevel,
           PaySchedule.Step,
           PaySchedule.Rate,
           PaySchedule.AmcosVersionId
    FROM PaySchedule.PaySchedule_G_Series AS PaySchedule
    ORDER BY ABS(GFEBS.Rate - PaySchedule.Rate)
) AS c;