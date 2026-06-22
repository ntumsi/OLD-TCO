-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetMinMaxPay]
(
    @PayPlan NVARCHAR(4),
    @WageArea NVARCHAR(7) = '__ALL__',
    @CategorySubGroupCode NVARCHAR(7) = '__ALL__',
    @LocalityId INTEGER = NULL,
    @SpecialRateTableNumber NVARCHAR(4) = NULL
)
RETURNS @Table_Var TABLE
(
    Grade NVARCHAR(5) NOT NULL,
    GradeLevel TINYINT NOT NULL,
    MinimumPay NUMERIC(18, 2) NOT NULL,
    MaximumPay NUMERIC(18, 2) NOT NULL
)
AS
BEGIN
    DECLARE @ActiveDutyDays FLOAT = crunch.GetSingleValue('AA', 'activedays');
    DECLARE @LocalityRate NUMERIC(18, 4) = web.GetLocalityRate(@LocalityId);
    DECLARE @LocalityPayRestOfUS NUMERIC(18, 4) = web.GetLocalityRate(32);
    DECLARE @LocalityPayMaximum NUMERIC(18, 4);
    SET @LocalityPayMaximum =
    (
        SELECT MAX(Amount) FROM lookup.LocalityRates WHERE IsLocalityPayArea = 1
    );

    IF @PayPlan = 'NE'
       OR @PayPlan = 'NO'
       OR @PayPlan = 'NWO'
       OR @PayPlan = 'RE'
       OR @PayPlan = 'RO'
       OR @PayPlan = 'RWO'
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               GradeLevel,
               MIN(Amount) AS MinimumPay,
               MAX(Amount) AS MaximumPay
        FROM crunch.AnnualBasicPayReserveComponents(@PayPlan, @ActiveDutyDays)
        GROUP BY GradeType,
                 GradeLevel;
    IF @PayPlan = 'AE'
       OR @PayPlan = 'AO'
       OR @PayPlan = 'AWO'
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               GradeLevel,
               MIN(Amount) AS MinimumPay,
               MAX(Amount) AS MaximumPay
        FROM crunch.AnnualBasicPayActiveDuty(@PayPlan)
        GROUP BY GradeType,
                 GradeLevel;
    IF @PayPlan = 'GG'
       OR @PayPlan = 'GL'
       OR @PayPlan = 'GS'
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               GradeLevel,
               MIN(Rate * @LocalityRate) AS MinimumPay,
               MAX(Rate * @LocalityRate) AS MaximumPay
        FROM data.PaySchedules
        WHERE PayPlan = @PayPlan
              AND RateType = 'Annual'
        GROUP BY GradeType,
                 GradeLevel;
    IF @PayPlan = 'GSS'
    BEGIN;
        WITH GS_CTE (GradeType, GradeLevel, Step_YOS, DateEffective, RateType, Rate)
        AS (SELECT GradeType,
                   GradeLevel,
                   Step_YOS,
                   DateEffective,
                   RateType,
                   Rate
            FROM data.PaySchedules
            WHERE PayPlan = 'GS'),
             GSS_CTE (SpecialRateTableNumber, GradeType, GradeLevel, Step_YOS, DateEffective, RateType, Rate)
        AS (SELECT SpecialRateTableNumber,
                   GradeType,
                   GradeLevel,
                   Step_YOS,
                   DateEffective,
                   RateType,
                   Rate
            FROM data.PaySchedules
            WHERE PayPlan = 'GSS')
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT CAST('GS' AS NVARCHAR(3)) + CAST(GS.GradeLevel AS NVARCHAR(2)) AS Grade,
               GS.GradeLevel,
               MIN(COALESCE(GSS.Rate, GS.Rate)) * ISNULL(@LocalityRate, 1) AS MinimumPay,
               MAX(COALESCE(GSS.Rate, GS.Rate)) * ISNULL(@LocalityRate, 1) AS MaximumPay
        FROM GS_CTE GS
            LEFT OUTER JOIN GSS_CTE GSS
                ON GSS.GradeLevel = GS.GradeLevel
                   AND GSS.Step_YOS = GS.Step_YOS
                   AND GSS.RateType = GS.RateType
                   AND GSS.DateEffective = GS.DateEffective
                   AND GSS.SpecialRateTableNumber = @SpecialRateTableNumber
        WHERE GS.RateType = 'Annual'
              AND GS.DateEffective = '2019-01-01 00:00:00.000'
        GROUP BY GS.GradeType,
                 GS.GradeLevel;
    END;
    IF @PayPlan = 'GP'
        /*For minimum pay, use lowest rate * rest of U.S. locality pay
		  For maximum pay, use highest rate * highest locality pay    */
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT CAST('GP' AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               GradeLevel,
               MIN(Rate) * @LocalityPayRestOfUS AS MinimumPay,
               MAX(Rate) * @LocalityPayMaximum AS MaximumPay
        FROM data.PaySchedules
        WHERE PayPlan = 'GS'
              AND RateType = 'Annual'
        GROUP BY GradeType,
                 GradeLevel;
    IF @PayPlan = 'DB'
       OR @PayPlan = 'DE'
       OR @PayPlan = 'DJ'
       OR @PayPlan = 'DK'
       OR @PayPlan = 'NH'
       OR @PayPlan = 'NJ'
       OR @PayPlan = 'NK'
       OR @PayPlan = 'SES'
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT Grade = CASE PayPlan
                           WHEN 'SES' THEN
                               CASE GradeLevel
                                   WHEN 1 THEN
                                       'MIN'
                                   WHEN 2 THEN
                                       'AVG'
                                   WHEN 3 THEN
                                       'MAX'
                                   ELSE
                                       CAST(GradeLevel AS NVARCHAR(3))
                               END
                           ELSE
                               CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2))
                       END,
               GradeLevel,
               MIN(Rate) AS MinimumPay,
               MAX(Rate) AS MaximumPay
        FROM data.PaySchedules
        WHERE PayPlan = @PayPlan
              AND RateType = 'Annual'
        GROUP BY PayPlan,
                 GradeType,
                 GradeLevel;
    IF @PayPlan = 'WG'
       OR @PayPlan = 'WL'
       OR @PayPlan = 'WS'
        INSERT INTO @Table_Var
        (
            Grade,
            GradeLevel,
            MinimumPay,
            MaximumPay
        )
        SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) AS Grade,
               GradeLevel,
               MIN(Rate) * 2087 AS MinimumPay,
               MAX(Rate) * 2087 AS MaximumPay
        FROM data.PaySchedules
        WHERE PayPlan = @PayPlan
              AND
              (
                  WageArea = @WageArea
                  OR @WageArea = '__ALL__'
              )
              AND RateType = 'Hourly'
        GROUP BY GradeType,
                 GradeLevel;
    RETURN;
END;