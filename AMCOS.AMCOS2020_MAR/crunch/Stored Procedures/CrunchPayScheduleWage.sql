
-- =============================================
-- Author:		Dan Hogan
-- Create date: 10/28/2019
-- Description:	Convert raw wage pay plan data into payschedules
-- =============================================
CREATE PROCEDURE [crunch].[CrunchPayScheduleWage]
    @AmcosVersionId INT = -1,
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    --cast a wider range for the start since the max will get the right value based on the end date below
    DECLARE @StartDate DATETIME = DATEFROMPARTS(LEFT(@AmcosVersionId, 4) - 2, 1, 1);

    --the end date is always going to be the last day of the year of the amcosversion
    DECLARE @EndDate DATETIME = DATEFROMPARTS(LEFT(@AmcosVersionId, 4), 12, 31);

    DROP TABLE IF EXISTS #PayScheduleWork;
    CREATE TABLE #PayScheduleWork
    (
        PayPlan NVARCHAR(2) NULL,
        AreaCode NVARCHAR(3) NULL,
        TypeData NVARCHAR(1) NOT NULL,
        TypeSchedule INT NOT NULL,
        Level INT NOT NULL,
        Grade INT NOT NULL,
        Step INT NOT NULL,
        EffectiveDate DATETIME2 NOT NULL,
        Rate NUMERIC(18, 2) NOT NULL,
        AmcosVersionId INT NOT NULL,
        LocationId INT NOT NULL,
        FundType NVARCHAR(50) NOT NULL,
        Link NVARCHAR(150) NOT NULL
    );
    INSERT INTO #PayScheduleWork
    (
        AreaCode,
        TypeData,
        TypeSchedule,
        Level,
        Grade,
        Step,
        EffectiveDate,
        Rate,
        AmcosVersionId,
        LocationId,
        FundType,
        Link
    )
    SELECT AreaCode,
           TypeData,
           TypeSchedule,
           Level,
           Grade,
           RIGHT(step, 1) AS Step,
           EffectiveDate,
           Amount,
           @AmcosVersionId,
           -1 AS LocationId,
           FundType,
           link
    FROM PaySchedule.PaySchedule_Wage_Raw a
        UNPIVOT
        (
            Amount
            FOR step IN (rate1, rate2, rate3, rate4, rate5)
        ) AS unpvt
    WHERE TypeData = 'R'
          AND EffectiveDate
          BETWEEN @StartDate AND @EndDate;

    /* AF */
    UPDATE #PayScheduleWork
    SET PayPlan = CASE
                      WHEN TypeSchedule = 5
                           AND Level = 3 THEN
                          'WA'
                      WHEN (
                               TypeSchedule = 1
                               OR TypeSchedule = 2
                           )
                           AND Level = 1 THEN
                          'WG'
                      WHEN (
                               TypeSchedule = 1
                               OR TypeSchedule = 2
                           )
                           AND Level = 2 THEN
                          'WL'
                      WHEN TypeSchedule = 5
                           AND Level = 2 THEN
                          'WO'
                      WHEN (
                               TypeSchedule = 1
                               OR TypeSchedule = 2
                           )
                           AND Level = 3 THEN
                          'WS'
                      WHEN TypeSchedule = 5
                           AND Level = 1 THEN
                          'WY'
                      WHEN TypeSchedule = 3
                           AND Level = 1 THEN
                          'XF'
                      WHEN TypeSchedule = 3
                           AND Level = 2 THEN
                          'XG'
                      WHEN TypeSchedule = 3
                           AND Level = 3 THEN
                          'XH'
                      WHEN TypeSchedule = 7
                           AND Level = 1 THEN
                          'XR'
                      WHEN TypeSchedule = 7
                           AND Level = 2 THEN
                          'XT'
                      WHEN TypeSchedule = 7
                           AND Level = 3 THEN
                          'XU'
                      ELSE
                          '-1'
                  END
    WHERE FundType = 'AF';

    /* NAF */
    UPDATE #PayScheduleWork
    SET PayPlan = CASE
                      WHEN (
                               TypeSchedule = 1
                               OR TypeSchedule = 2
                           )
                           AND Level = 1 THEN
                          'NA'
                      WHEN (
                               TypeSchedule = 1
                               OR TypeSchedule = 2
                           )
                           AND Level = 2 THEN
                          'NL'
                      WHEN (
                               TypeSchedule = 1
                               OR TypeSchedule = 2
                           )
                           AND Level = 3 THEN
                          'NS'
                      ELSE
                          '-1'
                  END
    WHERE FundType = 'NAF';

    /* WN and WD are a duplicate of WS with some adjustments */
    INSERT INTO #PayScheduleWork
    (
        PayPlan,
        AreaCode,
        TypeData,
        TypeSchedule,
        Level,
        Grade,
        Step,
        EffectiveDate,
        Rate,
        AmcosVersionId,
        LocationId,
        FundType,
        Link
    )
    SELECT 'WD',
           AreaCode,
           TypeData,
           TypeSchedule,
           Level,
           Grade - 2,
           Step,
           EffectiveDate,
           Rate,
           AmcosVersionId,
           -1 AS LocationId,
           FundType,
           Link
    FROM #PayScheduleWork
    WHERE PayPlan = 'WS'
          AND Grade
          BETWEEN 3 AND 13
          AND FundType = 'AF';

    INSERT INTO #PayScheduleWork
    (
        PayPlan,
        AreaCode,
        TypeData,
        TypeSchedule,
        Level,
        Grade,
        Step,
        EffectiveDate,
        Rate,
        AmcosVersionId,
        LocationId,
        FundType,
        Link
    )
    SELECT 'WN',
           AreaCode,
           TypeData,
           TypeSchedule,
           Level,
           Grade - 6,
           Step,
           EffectiveDate,
           Rate,
           AmcosVersionId,
           -1 AS LocationId,
           FundType,
           Link
    FROM #PayScheduleWork
    WHERE PayPlan = 'WS'
          AND Grade
          BETWEEN 7 AND 15
          AND FundType = 'AF';

    /* Bring in the locationid field for AF */
    UPDATE #PayScheduleWork
    SET LocationId = b.LocationId
    FROM #PayScheduleWork AS a
        INNER JOIN warehouse.Location AS b
            ON a.AreaCode = b.SourceSystemCode
    WHERE b.LocationType IN ( 'Federal Wage System AF', 'Federal Wage System AF Overseas' )
          AND a.FundType = 'AF';

    /* Bring in the locationid field for NAF */
    UPDATE #PayScheduleWork
    SET LocationId = b.LocationId
    FROM #PayScheduleWork AS a
        INNER JOIN warehouse.Location AS b
            ON a.AreaCode = b.SourceSystemCode
    WHERE b.LocationType IN ( 'Federal Wage System NAF', 'Federal Wage System NAF Overseas' )
          AND a.FundType = 'NAF';

    IF @Debug = 1
    BEGIN
        SELECT 'records without a payplan assignment';
        SELECT *
        FROM #PayScheduleWork
        WHERE PayPlan = '-1';

        SELECT 'records without an area code';
        SELECT *
        FROM #PayScheduleWork
        WHERE AreaCode IS NULL
        ORDER BY PayPlan;

        SELECT 'payschedules with payplan designations';
        SELECT *
        FROM #PayScheduleWork
        ORDER BY PayPlan,
                 Grade,
                 Step;
    END;

    /* There are cases where many releases exist for the same effective date so we need to pull only the max for those */
    DROP TABLE IF EXISTS #PayScheduleFinal;
    CREATE TABLE #PayScheduleFinal
    (
        PayPlan NVARCHAR(2) NOT NULL,
        AreaCode NVARCHAR(3) NOT NULL,
        GradeLevel INT NOT NULL,
        Step INT NOT NULL,
        EffectiveDate DATETIME2 NOT NULL,
        Rate NUMERIC(18, 2) NOT NULL,
        FundType NVARCHAR(3) NOT NULL,
        AmcosVersionId INT NOT NULL,
        LocationId INT NULL
    );
    INSERT INTO #PayScheduleFinal
    (
        PayPlan,
        AreaCode,
        GradeLevel,
        Step,
        EffectiveDate,
        Rate,
        FundType,
        LocationId,
        AmcosVersionId
    )
    SELECT PayPlan,
           AreaCode,
           Grade,
           Step,
           MAX(EffectiveDate) AS MaxEffectiveDate,
           MAX(Rate) AS MaxRate,
           FundType,
           LocationId,
           AmcosVersionId
    FROM #PayScheduleWork
    WHERE AreaCode IS NOT NULL
    GROUP BY PayPlan,
             AreaCode,
             Grade,
             Step,
             FundType,
             LocationId,
             AmcosVersionId;

    /* If we have an unidentified locationd we need to call that out */
    IF EXISTS (SELECT * FROM #PayScheduleFinal WHERE LocationId IS NULL)
    BEGIN
        SELECT 'these records are missing a locationid in the warehouse location table';

        SELECT *
        FROM #PayScheduleFinal
        WHERE LocationId IS NULL;

        RAISERROR('Invalid location codes', 18, 1);
        RETURN;
    END;

    IF @Debug = 1
    BEGIN

        SELECT 'payschedules with payplan designations';
        SELECT *
        FROM #PayScheduleFinal
        ORDER BY PayPlan,
                 AreaCode,
                 GradeLevel,
                 Step;
    END;

    /* If we aren't debugging then execute the delete and insert */
    IF @Debug = 0
    BEGIN
        DELETE FROM PaySchedule.PaySchedule_Wage
        WHERE AmcosVersionId = @AmcosVersionId;

        INSERT INTO PaySchedule.PaySchedule_Wage
        (
            PayPlan,
            AreaCode,
            GradeType,
            GradeLevel,
            Step,
            RateType,
            DateEffective,
            Rate,
            FundType,
            LocationId,
            AmcosVersionId
        )
        SELECT PayPlan,
               AreaCode,
               PayPlan,
               GradeLevel,
               Step,
               'Hourly',
               EffectiveDate,
               Rate,
               FundType,
               LocationId,
               AmcosVersionId
        FROM #PayScheduleFinal;

    END;

END;