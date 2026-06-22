



CREATE VIEW [data].[PaySchedules]
AS
SELECT PayPlan,
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       [GradeType],
       PayBand AS [GradeLevel],
       Step AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PaySchedule_CivilianDemonstration
UNION ALL
SELECT [PayPlan],
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       [GradeType],
       [GradeLevel],
       [Step] AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PayScheduleGG
UNION ALL
SELECT [PayPlan],
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       [GradeType],
       [GradeLevel],
       [Step] AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PayScheduleGL
UNION ALL
SELECT 'GP' AS PayPlan,
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       'GP' AS GradeType,
       [GradeLevel],
       [Step] AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PaySchedule_GS
UNION ALL
SELECT [PayPlan],
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       [GradeType],
       [GradeLevel],
       [Step] AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PaySchedule_GS
UNION ALL
SELECT [PayPlan],
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       [SpecialRateTableNumber] AS SpecialRateTableNumber,
       [GradeType],
       [GradeLevel],
       [Step] AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PaySchedule_GSS
UNION ALL
SELECT [PayPlan],
       NULL AS OccupationalSeriesNumber,
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       [GradeType],
       [GradeLevel],
       [YOS] AS Step_YOS,
       [DateEffective],
       [RateType],
       [Rate]
FROM load_payschedule.PaySchedule_Military
UNION ALL
SELECT [PayPlan],
       [OccupationalSeriesNumber],
       NULL AS WageArea,
       NULL AS SpecialRateTableNumber,
       [GradeType],
       [GradeLevel],
       [Step],
       [DateEffective],
       [RateType],
       [Rate]
FROM [load_payschedule].PaySchedule_SES
UNION ALL
SELECT Wage.[PayPlan],
       NULL AS OccupationalSeriesNumber,
       Wage.[WageArea],
       NULL AS SpecialRateTableNumber,
       Wage.[GradeType],
       Wage.[GradeLevel],
       Wage.[Step],
       Wage.[DateEffective],
       Wage.RateType,
       Wage.Rate
FROM load_payschedule.PaySchedule_Wage Wage
    INNER JOIN
    (
        SELECT [PayPlan],
               [WageArea],
               [GradeType],
               [GradeLevel],
               [Step],
               MAX([DateEffective]) AS RecentDateEffective
        FROM [load_payschedule].[PaySchedule_Wage]
        GROUP BY [PayPlan],
                 [WageArea],
                 [GradeType],
                 [GradeLevel],
                 [Step]
    ) MostRecent
        ON MostRecent.PayPlan = Wage.PayPlan
           AND MostRecent.WageArea = Wage.WageArea
           AND MostRecent.GradeType = Wage.GradeType
           AND MostRecent.GradeLevel = Wage.GradeLevel
           AND MostRecent.Step = Wage.Step
           AND MostRecent.RecentDateEffective = Wage.DateEffective;