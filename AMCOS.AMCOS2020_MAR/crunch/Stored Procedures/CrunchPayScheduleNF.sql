-- Stored Procedure

/*
 Author:		Dan Hogan
 Create date: 04/21/2021
 Description:	Convert raw NF wage pay plan data into payschedules
 */
CREATE PROCEDURE [crunch].[CrunchPayScheduleNF]
    @AmcosVersionId INT = -1,
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @AmcosVersionId <
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01')
        FROM lookup.PayPlan
        WHERE PayPlan = 'NF'
    )
    BEGIN
        PRINT (CAST(@AmcosVersionId AS NVARCHAR(6)) + ' is before creation date of pay plan NF, crunch skipped');
        RETURN 0;
    END;

    -- cast a wider range for the start since the max will get the right value based on the end date below
    DECLARE @StartDate DATETIME = DATEFROMPARTS(LEFT(@AmcosVersionId, 4) - 2, 1, 1);

    -- the end date is always going to be the last day of the year of the amcosversion
    DECLARE @EndDate DATETIME = DATEFROMPARTS(LEFT(@AmcosVersionId, 4), 12, 31);

    DROP TABLE IF EXISTS #PaySchedule;
    CREATE TABLE #PaySchedule
    (
        WageArea NVARCHAR(3) NOT NULL,
        ScheduleNumber NVARCHAR(4) NOT NULL,
        ScheduleName NVARCHAR(50) NULL,
        Payband TINYINT NOT NULL,
        DateEffective DATE NULL,
        PaybandMin NUMERIC(17, 2) NULL,
        PaybandMax NUMERIC(17, 2) NULL,
        AmcosVersionId INT NOT NULL,
        GSLocationId INT NULL,
        GSLocationName NVARCHAR(150) NULL,
        LocationId INT NULL
    );
    INSERT INTO #PaySchedule
    (
        WageArea,
        ScheduleNumber,
        ScheduleName,
        Payband,
        DateEffective,
        PaybandMin,
        PaybandMax,
        AmcosVersionId,
        LocationId
    )
    SELECT a.WageArea,
           a.ScheduleArea,
           a.AreaName,
           b.Payband,
           c.EffectiveDate,
           c.PayMinAnnual,
           c.PayMaxAnnual,
           @AmcosVersionId,
           z.LocationId
    FROM lookup.WageArea AS a
        LEFT OUTER JOIN warehouse.Location AS z
            ON a.ScheduleArea = z.SourceSystemCode
        /* cross join because we want to make sure have all payband levels
        some levels (namely 6) don't have costs generated for them from DCPAS due to 
        an overarching rule which we'll fill in for later */
        CROSS JOIN
        (
            SELECT 1 AS Payband
            UNION
            SELECT 2 AS Payband
            UNION
            SELECT 3 AS Payband
            UNION
            SELECT 4 AS Payband
            UNION
            SELECT 5 AS Payband
            UNION
            SELECT 6 AS Payband
        ) AS b
        LEFT OUTER JOIN
        (
            SELECT PayBand,
                   MAX(PayMinAnnual) AS PayMinAnnual,
                   MAX(PayMaxAnnual) AS PayMaxAnnual,
                   WageSchedule,
                   MAX(EffectiveDate) AS EffectiveDate
            FROM PaySchedule.DCPASNfRaw
            WHERE EffectiveDate
            BETWEEN @StartDate AND @EndDate
            GROUP BY PayBand,
                     WageSchedule
        ) AS c
            ON a.ScheduleArea = c.WageSchedule
               AND b.Payband = c.Payband
    WHERE z.LocationType = 'FWS NAF';

    SELECT *
    INTO #XWalk
    FROM
    (
        /* In order to set the pay later for specific scenarios we need to crosswalk wage to OPM locality (GS)
        so we can bring in the comparable pay */
        SELECT a.WageArea,
               a.ScheduleArea,
               a.StateCode,
               a.CountyCode,
               a.CityCode,
               c.LocalityRate,
               c.LocalityCode,
               e.Rate,
               e.Step,
               e.GradeLevel,
               e.LocationId,
               'unknown' AS MyStatus
        FROM xwalk.WageAreaToFips AS a
            INNER JOIN xwalk.LocalityPayAreaToFips AS b
                ON a.StateCode = b.StateCode
                   AND a.CountyCode = b.CountyCode
                   AND b.AmcosVersionId = a.AmcosVersionId
            LEFT OUTER JOIN PaySchedule.LocalityPay AS c
                ON c.LocalityCode = b.LocalityCode
                   AND c.AmcosVersionId = b.AmcosVersionId
            LEFT OUTER JOIN warehouse.Location AS d
                ON d.SourceSystemCode = c.LocalityCode
            LEFT OUTER JOIN PaySchedule.PaySchedule_G_Series AS e
                ON e.LocationId = d.LocationId
        WHERE a.AmcosVersionId = @AmcosVersionId
              AND a.FundType = 'NAF'
              AND e.PayPlan = 'GS'
              AND e.CategorySubgroupCode = '-1'
              AND e.Step = 1
              AND e.GradeLevel = 15
              AND e.AmcosVersionId = @AmcosVersionId
    ) AS a;

    /* narrow things down so we only have the maximum pay per wage schedule 
    a wage schedule could potentially span multiple pay areas and we need to handle that
    by selecting the maximum */
    UPDATE #XWalk
    SET MyStatus = 'keep'
    FROM #XWalk AS a
        LEFT OUTER JOIN
        (
            SELECT ScheduleArea,
                   MAX(Rate) AS myrate
            FROM #XWalk
            GROUP BY ScheduleArea
        ) AS b
            ON a.WageArea = b.ScheduleArea
               AND a.Rate = b.myrate;

    -- bring in the GS info which we'll need for pay setting later
    UPDATE #PaySchedule
    SET GSLocationId = b.LocationId,
        GSLocationName = b.LocalityCode
    FROM #PaySchedule AS a
        LEFT OUTER JOIN #XWalk AS b
            ON a.ScheduleNumber = b.WageArea
    WHERE b.MyStatus = 'keep';

    DECLARE @PayBand6MaximumPay NUMERIC(17, 2) =
            (
                SELECT Rate
                FROM PaySchedule.OpmExRaw
                WHERE PayPlan = 'EX'
                      AND Level = 'Level II'
                      AND RateType = 'Annual'
                      AND AmcosVersionId = @AmcosVersionId
            );

    DECLARE @PayBand6MinimumFactor NUMERIC(6, 4) = crunch.GetSingleValue('NF', 'Level6MinFactor', @AmcosVersionId);


    DECLARE @PayBand6MinimumPay NUMERIC(17, 2) =
            (
                SELECT Rate * @PayBand6MinimumFactor
                FROM data.PaySchedules
                WHERE PayPlan = 'GS'
                      AND CategorySubgroupCode = '-1'
                      AND GradeLevel = '15'
                      AND Step = '1'
                      AND AmcosVersionId = 202401
                      AND RateType = 'Annual'
                      AND LocationId = -1
            );

    /* Set the effective date for pay band 6 when we don't already have that info */
    UPDATE #PaySchedule
    SET DateEffective = @StartDate
    WHERE Payband = 6
          AND DateEffective IS NULL;

    /* Set the minimum pay for pay band 6 when we don't already have that info */
    UPDATE #PaySchedule
    SET PaybandMin = @PayBand6MinimumPay
    WHERE Payband = 6
          AND
          (
              PaybandMin IS NULL
              OR PaybandMin = 0
          );

    -- Set the maximum pay for pay band 6 when we don't already have that info
    UPDATE #PaySchedule
    SET PaybandMax = @PayBand6MaximumPay
    WHERE Payband = 6
          AND
          (
              PaybandMax IS NULL
              OR PaybandMax = 0
          );

    -- check that all prime locations have a payschedule
    IF EXISTS
    (
        SELECT *
        FROM #PaySchedule
        WHERE PaybandMin IS NULL
              AND PaybandMax IS NULL
              AND WageArea = ScheduleNumber
    )
    BEGIN
        SELECT 'the following prime (area=schedule) locations are missing a payschedule which should not be';

        SELECT *
        FROM #PaySchedule
        WHERE PaybandMin IS NULL
              AND PaybandMax IS NULL
              AND WageArea = ScheduleNumber
        ORDER BY WageArea,
                 ScheduleNumber;


    -- RAISERROR('missing data', 18, 1);
    -- RETURN;
    END;

    IF @Debug = 1
    BEGIN
        SELECT 'the following non prime (area!=schedule) locations are missing a payschedule which is ok but information';
        SELECT *
        FROM #PaySchedule
        WHERE PaybandMin IS NULL
              AND PaybandMax IS NULL
              AND WageArea <> ScheduleNumber
        ORDER BY WageArea,
                 ScheduleNumber;

        SELECT 'the following locations are complete and ready for insert';
        SELECT *
        FROM #PaySchedule
        WHERE WageArea = ScheduleNumber
        ORDER BY ScheduleName;
    END;

    IF @Debug = 1
    BEGIN
        SELECT 'null min/max values we remove due lack of pay data';
        -- this can occur because not every non prime location has a payschedule
        SELECT *
        FROM #PaySchedule
        WHERE PaybandMin IS NULL
              OR PaybandMax IS NULL;
    END;

    DELETE FROM #PaySchedule
    WHERE PaybandMin IS NULL
          OR PaybandMax IS NULL;

    IF @Debug = 0
    BEGIN
        DELETE FROM crunch.NfPayProcessed
        WHERE AmcosVersionId = @AmcosVersionId;
        INSERT INTO crunch.NfPayProcessed
        (
            PayPlan,
            GradeType,
            PayBand,
            MinPay,
            MaxPay,
            LocationId,
            AmcosVersionId
        )
        SELECT 'NF',
               'NF',
               Payband,
               PaybandMin,
               PaybandMax,
               LocationId,
               AmcosVersionId
        FROM #PaySchedule
        /* for NF the 'sub' wage schedules are not used by DCPAS so we only generate pay for the 'prime' wage areas where the area and schedule number are the same */
        WHERE WageArea = ScheduleNumber;
    END;
END;
GO
