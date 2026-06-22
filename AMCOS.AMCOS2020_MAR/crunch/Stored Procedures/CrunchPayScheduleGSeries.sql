
CREATE PROCEDURE [crunch].[CrunchPayScheduleGSeries]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    DECLARE @SalaryLimit NUMERIC(17, 2) = crunch.GetMaximumGSPayLimit(@AmcosVersionId);

    DROP TABLE IF EXISTS #PaySchedule;
    CREATE TABLE #PaySchedule
    (
        ScheduleType NVARCHAR(20) NOT NULL,
        PayPlan NVARCHAR(2) NOT NULL,
        OccupationalSeriesNumberOriginal NVARCHAR(4) NOT NULL,
        OccupationalSeriesNumberNew NVARCHAR(5) NULL,
        LocationId INT NULL,
        LocationName NVARCHAR(150) NULL,
        LocalityCode NVARCHAR(6) NULL,
        StateCode NVARCHAR(2) NULL,
        CityCode NVARCHAR(4) NULL,
        CountyCode NVARCHAR(3) NULL,
        GradeLevel INT NOT NULL,
        Step INT NOT NULL,
        Rate NUMERIC(18, 2) NOT NULL,
        MaxRate NUMERIC(18, 2) NULL,
        AmcosVersionId INT NOT NULL,
        WorkRoleCode NVARCHAR(3) NULL
            DEFAULT ('-1') --added 7/17/2023 to support cyber work codes
    );

    /* GS, GL */
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        OccupationalSeriesNumberNew,
        GradeLevel,
        Step,
        Rate,
        LocalityCode,
        AmcosVersionId
    )
    SELECT 'Regular',
           a.PayPlan,
           '-1',
           '-1',
           a.GradeLevel,
           a.Step,
           a.Rate * ((b.LocalityRate) / 100 + 1),
           b.LocalityCode,
           a.AmcosVersionId
    FROM PaySchedule.PaySchedule_G_Series_raw AS a
        CROSS JOIN PaySchedule.LocalityPay AS b
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.AmcosVersionId = @AmcosVersionId
          AND a.RateType = 'Annual'
          AND a.Rate > 0;

    /* GG */
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        OccupationalSeriesNumberNew,
        GradeLevel,
        Step,
        Rate,
        LocalityCode,
        AmcosVersionId,
        WorkRoleCode
    )
    SELECT 'Regular',
           'GG',
           -1,
           -1,
           b.GradeLevel,
           b.Step,
           b.Rate,
           b.LocalityCode,
           @AmcosVersionId,
           b.WorkRoleCode
    FROM lookup.GS_OccupationalSeries AS a
        CROSS JOIN
        (
            SELECT a.WorkRoleCode,
                   a.GradeLevel,
                   a.Step,
                   a.Rate,
                   a.TLMSPayTable,
                   b.LocalityCode
            FROM PaySchedule.CyberExceptedService AS a
                INNER JOIN xwalk.TLMSPayTableToLocalityPayArea AS b
                    ON a.TLMSPayTable = b.TLMSPayTable
            WHERE @AmcosVersionId = b.AmcosVersionId
                  AND @AmcosVersionId = a.AmcosVersionId
                  AND b.LocalityCode <> 'FoL' -- no foreign locations
        ) AS b
    WHERE @AmcosVersionId
          BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
          AND a.OccupationalSeriesNumber IN
              (
                  SELECT OccupationalSeriesNumber
                  FROM lookup.GS_OccupationalSeries
                  WHERE WorkRoleCodeRequired = 1
              );

    --the below can be added back in once we add work codes to our costs, otherwise it would cause no costs to be generated 
    /*
	--anytime we have now have a pay scenario for non work code and a work code the work code record reigns so find these scenarios and get rid of them
	delete from #PaySchedule where payplan='GG' and workcode='-1' and concat(payplan,gradelevel,step,OccupationalSeriesNumberOriginal,LocalityCode) 
	in 
	(select concat(payplan,gradelevel,step,OccupationalSeriesNumberOriginal,LocalityCode) where payplan='GG' and workcode<>'-1')
	*/

    /* cap pay */
    UPDATE #PaySchedule
    SET Rate = @SalaryLimit
    WHERE Rate > @SalaryLimit;

    /* Add rows for special rates for GS */
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        StateCode,
        CityCode,
        CountyCode,
        LocationName,
        LocalityCode,
        GradeLevel,
        Step,
        Rate,
        AmcosVersionId
    )
    /* once for GS */
    SELECT 'Special',
           'GS',
           c.OccupationalSeriesNumber,
           d.StateCode,
           d.CityCode,
           d.CountyCode,
           d.LocationName + ', ' + d.State,
           d.LocalityCode,
           a.GradeLevel,
           a.Step,
           a.Rate,
           a.AmcosVersionId
    FROM PaySchedule.OpmSpecialRates AS a
        INNER JOIN xwalk.SpecialRateTablesByAgency AS b
            ON a.SpecialRateTableNumber = b.TableNumber
               AND b.AmcosVersionId = a.AmcosVersionId
        INNER JOIN xwalk.SpecialRateTablesByOccupation AS c
            ON b.TableNumber = c.TableNumber
               AND c.AmcosVersionId = b.AmcosVersionId
        INNER JOIN xwalk.SpecialRateTablesByLocation AS d
            ON c.TableNumber = d.TableNumber
               AND d.AmcosVersionId = c.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND
          (
              b.Title = 'DEPARTMENT OF THE ARMY'
              OR b.Title = 'ALL FEDERAL GOVERNMENT AGENCIES'
          )

    --again for GL
    UNION
    SELECT 'Special',
           'GL',
           c.OccupationalSeriesNumber,
           d.StateCode,
           d.CityCode,
           d.CountyCode,
           d.LocationName + ', ' + d.State,
           d.LocalityCode,
           a.GradeLevel,
           a.Step,
           a.Rate,
           a.AmcosVersionId
    FROM PaySchedule.OpmSpecialRates AS a
        INNER JOIN xwalk.SpecialRateTablesByAgency AS b
            ON a.SpecialRateTableNumber = b.TableNumber
               AND b.AmcosVersionId = a.AmcosVersionId
        INNER JOIN xwalk.SpecialRateTablesByOccupation AS c
            ON b.TableNumber = c.TableNumber
               AND c.AmcosVersionId = b.AmcosVersionId
        INNER JOIN xwalk.SpecialRateTablesByLocation AS d
            ON c.TableNumber = d.TableNumber
               AND d.AmcosVersionId = c.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND
          (
              b.Title = 'DEPARTMENT OF THE ARMY'
              OR b.Title = 'ALL FEDERAL GOVERNMENT AGENCIES'
          )
          --but we only want special pay for subgroups GL is actually using so for example
          --we don't show a dentist special pay for GL which is clearly incorrect
          --the policy on this is not hard and fast though so we are making what appears to be a reasonable assumption
          AND c.OccupationalSeriesNumber IN
              (
                  SELECT DISTINCT
                         CategorySubgroupCode
                  FROM data.KnownInventory
                  WHERE AmcosVersionId = @AmcosVersionId
                        AND PayPlan = 'GL'
              );
    --GG doesn't apply

    --update the special pay records by bringing in their 'AMCOS' subgroup number
    UPDATE #PaySchedule
    SET OccupationalSeriesNumberNew = b.OccupationalSeriesNumber
    FROM #PaySchedule AS a
        INNER JOIN lookup.GS_OccupationalSeries AS b
            ON LEFT(b.OccupationalSeriesNumber, 4) = a.OccupationalSeriesNumberOriginal
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND a.ScheduleType = 'Special';
    --don't touch the regular records since we only have special series numbers for unique special pay series titles

    --If we have an unidentified subgroup we need to call that out
    IF EXISTS
    (
        SELECT *
        FROM #PaySchedule
        WHERE OccupationalSeriesNumberNew IS NULL
              AND OccupationalSeriesNumberOriginal <> 'XXXX'
    )
    BEGIN
        SELECT 'these records have invalid groups/subgroups 1) add the special pay record as a sub series 2) or rename the existing series if close enough';

        SELECT DISTINCT
               a.ScheduleType,
               a.OccupationalSeriesNumberOriginal,
               b.OccupationalSeriesNumber "Matchingsubgroup",
               b.SeriesTitle "PossibleMatch"
        FROM #PaySchedule AS a
            LEFT OUTER JOIN lookup.GS_OccupationalSeries AS b
                ON a.OccupationalSeriesNumberOriginal = LEFT(b.OccupationalSeriesNumber, 4)
        WHERE a.OccupationalSeriesNumberNew IS NULL
              AND
            -- added 1/11/23 XXXX applies to all series so we grant an error exception and was put in place as a result of the OPM $15 min wage decision 
            (a.OccupationalSeriesNumberOriginal <> 'XXXX')
        ORDER BY a.OccupationalSeriesNumberOriginal;


        RAISERROR('Invalid group/subgroup codes', 18, 1);
        RETURN;
    END;

    -- handle the Hawaii special pay record against the Hawaii locality codes
    -- to do that we need to take the general Hawaii record and spawn it against all the Hawaii locality areas
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        OccupationalSeriesNumberNew,
        LocationId,
        LocationName,
        LocalityCode,
        StateCode,
        CityCode,
        CountyCode,
        GradeLevel,
        Step,
        Rate,
        MaxRate,
        AmcosVersionId
    )
    SELECT a.ScheduleType,
           a.PayPlan,
           a.OccupationalSeriesNumberOriginal,
           a.OccupationalSeriesNumberNew,
           a.LocationId,
           a.LocationName,
           c.LocalityCode,
           a.StateCode,
           a.CityCode,
           a.CountyCode,
           a.GradeLevel,
           a.Step,
           a.Rate,
           a.MaxRate,
           a.AmcosVersionId
    FROM #PaySchedule AS a
        INNER JOIN xwalk.LocalityPayAreaToFips AS b
            ON a.StateCode = b.StateCode
        INNER JOIN PaySchedule.LocalityPay AS c
            ON b.LocalityCode = c.LocalityCode
    WHERE (
              a.StateCode = '15'
              AND a.CountyCode = '000'
              AND a.CityCode = '0000'
          )
          OR (
                 a.StateCode = 'X'
                 AND a.LocationName LIKE '%Hawaii%'
             )
             AND b.StateCode = '15';

    --immediately delete the now orphaned Hawaii record(s)
    DELETE FROM #PaySchedule
    WHERE (
              (
                  StateCode = '15'
                  AND CountyCode = '000'
                  AND CityCode = '0000'
              )
              OR
              (
                  StateCode = 'X'
                  AND LocationName LIKE '%Hawaii%'
              )
          )
          AND LocalityCode IS NULL;

    -- handle the Alaska special pay record against the Alaska locality codes
    -- to do that we need to take the general Alaska record and spawn it against all the Alaska locality areas
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        OccupationalSeriesNumberNew,
        LocationId,
        LocationName,
        LocalityCode,
        StateCode,
        CityCode,
        CountyCode,
        GradeLevel,
        Step,
        Rate,
        MaxRate,
        AmcosVersionId
    )
    SELECT a.ScheduleType,
           a.PayPlan,
           a.OccupationalSeriesNumberOriginal,
           a.OccupationalSeriesNumberNew,
           a.LocationId,
           a.LocationName,
           c.LocalityCode,
           a.StateCode,
           a.CityCode,
           a.CountyCode,
           a.GradeLevel,
           a.Step,
           a.Rate,
           a.MaxRate,
           a.AmcosVersionId
    FROM #PaySchedule AS a
        INNER JOIN xwalk.LocalityPayAreaToFips AS b
            ON a.StateCode = b.StateCode
        INNER JOIN PaySchedule.LocalityPay AS c
            ON b.LocalityCode = c.LocalityCode
    WHERE (
              a.StateCode = '02'
              AND a.CountyCode = '000'
              AND a.CityCode = '0000'
          )
          OR (
                 a.StateCode = 'X'
                 AND a.LocationName LIKE '%ALASKA%'
             )
             AND b.StateCode = '02';

    --immediately delete the now orphaned Alaska record(s)
    DELETE FROM #PaySchedule
    WHERE (
              (
                  StateCode = '02'
                  AND CountyCode = '000'
                  AND CityCode = '0000'
              )
              OR
              (
                  StateCode = 'X'
                  AND LocationName LIKE '%Alaska%'
              )
          )
          AND LocalityCode IS NULL;


    /* Bring in locality pay area name */
    UPDATE #PaySchedule
    SET LocationName = b.LocalityPayArea
    FROM #PaySchedule AS a
        INNER JOIN lookup.LocalityPayArea AS b
            ON a.LocalityCode = b.LocalityCode
               AND a.AmcosVersionId = b.AmcosVersionId;

    /* Handle Rest of US locations */
    UPDATE #PaySchedule
    SET LocalityCode = 'RUS'
    WHERE LocationName LIKE '%rest of u.s.%'
          AND LocalityCode IS NULL;

    /* Bring in the locationid */
    UPDATE #PaySchedule
    SET LocationId = b.LocationId
    FROM #PaySchedule AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocalityCode = b.SourceSystemCode
    WHERE b.LocationType = 'Locality Pay Area';

    UPDATE #PaySchedule
    SET LocationId = b.LocationId
    FROM #PaySchedule AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationName = b.SourceSystemCode
    WHERE b.LocationType = 'OPM Special Pay Locations'
          AND a.LocationId IS NULL;



    /* 4/1/2020 the last thing we do is generate BASE pay with no locality, AMCOS doesn't generate any costs for it but the payschedule screen needs it */
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        OccupationalSeriesNumberNew,
        LocationId,
        LocationName,
        LocalityCode,
        StateCode,
        CityCode,
        CountyCode,
        GradeLevel,
        Step,
        Rate,
        MaxRate,
        AmcosVersionId
    )
    SELECT 'Regular',
           PayPlan,
           '-1',
           '-1',
           -1,
           'none',
           '-1',
           '',
           '',
           '',
           GradeLevel,
           Step,
           Rate,
           Rate,
           @AmcosVersionId
    FROM PaySchedule.PaySchedule_G_Series_raw
    WHERE RateType = 'Annual'
          AND AmcosVersionId = @AmcosVersionId;


    /* 1/11/2023 join special pay which applies worldwide against all our other pay records */
    INSERT INTO #PaySchedule
    (
        ScheduleType,
        PayPlan,
        OccupationalSeriesNumberOriginal,
        OccupationalSeriesNumberNew,
        LocationId,
        LocationName,
        LocalityCode,
        StateCode,
        CityCode,
        CountyCode,
        GradeLevel,
        Step,
        Rate,
        MaxRate,
        AmcosVersionId
    )
    SELECT a.ScheduleType,
           a.PayPlan,
           a.OccupationalSeriesNumberOriginal,
           a.OccupationalSeriesNumberNew,
           a.LocationId,
           a.LocationName,
           a.LocalityCode,
           a.StateCode,
           a.CityCode,
           a.CountyCode,
           a.GradeLevel,
           a.Step,
           b.Rate,
           b.Rate AS MaxRate,
           a.AmcosVersionId
    FROM #PaySchedule AS a
        INNER JOIN
        (
            SELECT GradeLevel,
                   Step,
                   Rate
            FROM #PaySchedule
            WHERE LocationName LIKE '%UNITED STATES%TERRITORIES%'
                  AND OccupationalSeriesNumberOriginal = 'XXXX'
        ) AS b
            ON b.GradeLevel = a.GradeLevel
               AND b.Step = a.Step;

    /* Get rid of these records now so they don't trigger a missing location warning below,
	since they are not actually a location but a global thing we don't need to account for the location itself
    1/5/2024 added the catch for foreign areas */
    DELETE FROM #PaySchedule
    WHERE (
              LocationName LIKE '%UNITED STATES%TERRITORIES%'
              OR LocationName LIKE '%FOREIGN AREAS%'
          )
          AND OccupationalSeriesNumberOriginal = 'XXXX';


    UPDATE #PaySchedule
    SET MaxRate = Rate;
    /*
		  --1/11/2023 commented this code out as the worldwide change and the later max group by that was already in this crunch should take care of this, in fact this concept of maxrate is 
		  --probably obsolute but leaving it in for now

    --Finally, there are some special pay cases which are broadly applicable across numerous locations, sometimes being above and sometimes being below the regular pay
    --we need to remove instances where special pay is less than regular pay

    UPDATE #PaySchedule
    SET MaxRate = b.Rate
    FROM #PaySchedule AS a
        INNER JOIN
        (
            SELECT *
            FROM #PaySchedule
            WHERE ScheduleType = 'Regular'
                  AND OccupationalSeriesNumberOriginal = '-1'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND b.GradeLevel = a.GradeLevel
               AND b.Step = a.Step
               AND b.AmcosVersionId = a.AmcosVersionId
               AND b.LocationId = a.LocationId
    WHERE a.ScheduleType = 'Special';
	
    DELETE FROM #PaySchedule
    WHERE MaxRate > Rate
          AND ScheduleType = 'Special';
		  */

    IF @Debug = 1
    BEGIN
        SELECT 'payschedule';
        SELECT *
        FROM #PaySchedule;

    END;

    /* If we have an unidentified location we need to call that out */
    IF EXISTS (SELECT * FROM #PaySchedule WHERE LocationId IS NULL)
    BEGIN
        SELECT 'these records have locations not in the warehouse location table';

        SELECT *
        FROM #PaySchedule
        WHERE LocationId IS NULL
        ORDER BY LocationName;


        RAISERROR('Missing location data', 18, 1);
        RETURN;
    END;

    IF @Debug = 0
    BEGIN
        DELETE FROM PaySchedule.PaySchedule_G_Series
        WHERE AmcosVersionId = @AmcosVersionId;

        /* The group by and max is because sometimes there are two rates for the same location nomen because they are for different FIPS, we don't go to that level of detail
        in amcos so just take the highest */
        INSERT INTO PaySchedule.PaySchedule_G_Series
        (
            PayPlan,
            GradeType,
            GradeLevel,
            Step,
            Rate,
            AmcosVersionId,
            LocationId,
            CategoryGroupCode,
            CategorySubgroupCode,
            WorkRoleCode
        )
        SELECT PayPlan,
               PayPlan,
               GradeLevel,
               Step,
               MAX(Rate),
               AmcosVersionId,
               LocationId,
               CASE
                   WHEN OccupationalSeriesNumberNew = 'All'
                        OR OccupationalSeriesNumberNew = '-1' THEN
                       '-1'
                   ELSE
                       LEFT(OccupationalSeriesNumberNew, 2) + '00'
               END,
               CASE
                   WHEN OccupationalSeriesNumberNew = 'All' THEN
                       '-1'
                   ELSE
                       OccupationalSeriesNumberNew
               END,
               WorkRoleCode
        FROM #PaySchedule
        WHERE Rate > 0
        GROUP BY PayPlan,
                 PayPlan,
                 GradeLevel,
                 Step,
                 AmcosVersionId,
                 LocationId,
                 OccupationalSeriesNumberNew,
                 WorkRoleCode;
    END;
END;