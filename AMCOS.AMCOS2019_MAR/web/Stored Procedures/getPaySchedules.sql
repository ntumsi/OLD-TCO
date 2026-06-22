CREATE PROCEDURE [web].[getPaySchedules]
    @PayPlan NVARCHAR(3),
    @Filter NVARCHAR(10)
AS
DECLARE @From VARCHAR(1000);
DECLARE @YOS VARCHAR(10);
SET @YOS = 'YOS';

IF (@PayPlan = 'DB')
   OR (@PayPlan = 'DE')
   OR (@PayPlan = 'DJ')
   OR (@PayPlan = 'DK')
   OR (@PayPlan = 'NH')
   OR (@PayPlan = 'NJ')
   OR (@PayPlan = 'NK')
    SET @YOS = 'RateType';

IF (@PayPlan = 'GG')
   OR (@PayPlan = 'GL')
   OR (@PayPlan = 'GS')
   OR (@PayPlan = 'WL')
   OR (@PayPlan = 'WS')
   OR (@PayPlan = 'WG')
    SET @YOS = 'Step';

IF (@PayPlan = 'SES')
    SET @YOS = 'Series';

IF (@Filter = '')
    SET @Filter =
(
    SELECT TOP (1)
           CASE @PayPlan
               WHEN 'SES' THEN
                   OccupationalSeriesNumber
               WHEN 'GSS' THEN
                   SpecialRateTableNumber
               WHEN 'WG' THEN
                   WageArea
               WHEN 'WL' THEN
                   WageArea
               WHEN 'WS' THEN
                   WageArea
           END
    FROM data.PaySchedules
    WHERE PayPlan = @PayPlan
    ORDER BY WageArea
)   ;

--Resultset #1
SELECT DISTINCT
       PayPlan
FROM data.PaySchedules
ORDER BY PayPlan;

--Resultset #2
IF @PayPlan = 'SES'
    SELECT OccupationalSeriesNumber,
           SeriesTitle
    FROM dbo.getGSOccupationalSeriesList()
    WHERE OccupationalSeriesNumber IN
          (
              SELECT OccupationalSeriesNumber
              FROM data.PaySchedules
              WHERE PayPlan = 'SES'
          );

--Resultset #3
IF @PayPlan = 'WG'
   OR @PayPlan = 'WL'
   OR @PayPlan = 'WS'
    SELECT WageArea,
           Description
    FROM dbo.getWageAreaList();

--Resultset #4
SELECT RateType
FROM data.PaySchedules
WHERE PayPlan = @PayPlan
GROUP BY RateType;

IF (@PayPlan = 'DB')
   OR (@PayPlan = 'DE')
   OR (@PayPlan = 'DJ')
   OR (@PayPlan = 'DK')
   OR (@PayPlan = 'NH')
   OR (@PayPlan = 'NJ')
   OR (@PayPlan = 'NK')
   OR (@PayPlan = 'GG')
   OR (@PayPlan = 'GL')
   OR (@PayPlan = 'GS')
   OR (@PayPlan = 'SES')
   OR (@PayPlan = 'WG')
   OR (@PayPlan = 'WL')
   OR (@PayPlan = 'WS')
BEGIN
    IF (@PayPlan = 'DB')
       OR (@PayPlan = 'DE')
       OR (@PayPlan = 'DJ')
       OR (@PayPlan = 'DK')
       OR (@PayPlan = 'NH')
       OR (@PayPlan = 'NJ')
       OR (@PayPlan = 'NK')
        SET @From
            = ' (SELECT CASE Step_YOS WHEN 0 THEN ''MIN'' WHEN 1 THEN ''MAX'' END AS RateType '
              + ', GradeType, GradeLevel, ROUND(Rate,2) as Rate FROM data.PaySchedules WHERE PayPlan = ''' + @PayPlan
              + ''' AND RateType=''Annual'') tblPay ';
    ELSE IF (@PayPlan = 'GG')
            OR (@PayPlan = 'GL')
            OR (@PayPlan = 'GS')
        SET @From
            = ' (SELECT Step_YOS As ' + @YOS
              + ', GradeType, GradeLevel, ROUND(Rate,2) as Rate FROM data.PaySchedules WHERE PayPlan = ''' + @PayPlan
              + ''' AND RateType=''Annual'') tblPay ';
    ELSE IF (@PayPlan = 'SES')
        SET @From
            = ' (SELECT OccupationalSeriesNumber As ' + @YOS
              + ', GradeType, GradeLevel, ROUND(Rate,2) as Rate FROM data.PaySchedules WHERE PayPlan = ''' + @PayPlan
              + ''' AND OccupationalSeriesNumber = ''' + @Filter + ''') tblPay ';
    ELSE
        SET @From
            = ' (SELECT Step_YOS As ' + @YOS
              + ', GradeType, GradeLevel, ROUND(Rate,2) as Rate FROM data.PaySchedules WHERE PayPlan = ''' + @PayPlan
              + ''' AND WageArea = ''' + @Filter + ''') tblPay ';
END;
ELSE
    SET @From
        = ' (SELECT Step_YOS As ' + @YOS
          + ', GradeType, GradeLevel, ROUND(Rate,2) as Rate FROM data.PaySchedules WHERE PayPlan = ''' + @PayPlan
          + ''') tblPay ';

--Resultset #2
EXEC web.spCrossTabGrades @From = @From,                     -- nvarchar(4000)
                          @Select = @YOS,                    -- nvarchar(500)
                          @PivotValueColumn = N'GradeLevel', -- nvarchar(100)
                          @PivotSortColumn = N'GradeLevel',  -- nvarchar(100)
                          @DataColumn = N'Rate',             -- nvarchar(500)
                          @GroupBy = @YOS,                   -- nvarchar(500)
                          @OrderBy = @YOS,                   -- nvarchar(500)
                          @Debug = 0;                        -- bit