
CREATE PROCEDURE [warehouse].[UpdateLocationId]
    @AmcosVersionId INT = -1,
    @Debug INT = 1
AS
BEGIN
    --in each case we do two operations:
    -- 1) determine which location records are new and thus need to be added
    -- 2) update the nomenclatures of all locations with the latest nomen
    /* SRID should be the same across all geo instances in the DB, this is the default value */
    DECLARE @SRID AS INT = 4326;

    CREATE TABLE #MyLocations
    (
        LocationCode NVARCHAR(100) NOT NULL,
        LocationName NVARCHAR(250) NOT NULL,
        LocationType NVARCHAR(100) NOT NULL,
        Geometry GEOMETRY NULL,
        Coordinates GEOGRAPHY NULL
    );

    /* Military Housing Area */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           MHA AS LocationCode,
           Description AS LocationName,
           Location + ' Military Housing Area' AS LocationType
    FROM lookup.MilitaryHousingArea
    WHERE MHA IS NOT NULL
          AND AmcosVersionId = @AmcosVersionId
    ORDER BY MHA;

    /* ##### Military Overseas missing from MHA ##### */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           a.LOCCODE,
           a.LOCNAME + ', ' + a.Country_Code,
           'OCONUS Military Housing Area'
    FROM dataload.MilitaryOverseasHousingAllowance AS a
        INNER JOIN
        (
            --when displaying the nomenclatures we only care about the latest nomenclature name
            SELECT LOCCODE,
                   MAX(AmcosVersionId) AS amcosversionidmax
            FROM dataload.MilitaryOverseasHousingAllowance
            GROUP BY LOCCODE
        ) AS b
            ON a.AmcosVersionId = b.amcosversionidmax
               AND a.LOCCODE = b.LOCCODE
    WHERE a.LOCCODE IS NOT NULL
          AND a.LOCCODE NOT IN
              (
                  SELECT DISTINCT LocationCode FROM #MyLocations
              )
    ORDER BY a.LOCCODE;

    /* Nonforeign Areas (white-collar civilian Federal employees in Alaska, Hawaii, Guam and the Northern Mariana Islands, Puerto Rico, and the U.S. Virgin Islands) */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT a.NonforeignAreaCode AS LocationCode,
           b.NonforeignAreaName AS LocationName,
           'Nonforeign Area' AS LocationType
    FROM PaySchedule.NonforeignAreaCostOfLivingAllowances AS a
        INNER JOIN lookup.NonforeignArea AS b
            ON b.NonforeignAreaCode = a.NonforeignAreaCode
               AND b.AmcosVersionId = a.AmcosVersionId
    WHERE a.AmcosVersionId = @AmcosVersionId
    ORDER BY b.NonforeignAreaName;

    /* Locality Pay Area */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT a.LocalityCode AS LocationCode,
           b.LocalityPayArea AS LocationName,
           'Locality Pay Area' AS LocationType
    FROM PaySchedule.LocalityPay a
        INNER JOIN lookup.LocalityPayArea b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.LocalityCode = a.LocalityCode
    WHERE a.AmcosVersionId = @AmcosVersionId
    ORDER BY a.LocalityCode;

    /* General Schedule (GS) Special Rates */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           a.LocationName + ', ' + a.State AS LocationCode,
           a.LocationName + ', ' + a.State AS LocationName,
           'OPM Special Pay Locations' AS LocationType
    FROM xwalk.SpecialRateTablesByLocation AS a
        INNER JOIN
        (
            --when displaying the nomenclatures we only care about the latest nomenclature name
            SELECT LocationName + ', ' + State AS loc,
                   MAX(AmcosVersionId) AS AmcosVersionIdMax
            FROM xwalk.SpecialRateTablesByLocation
            GROUP BY LocationName + ', ' + State
        ) AS b
            ON a.AmcosVersionId = b.AmcosVersionIdMax
               AND a.LocationName + ', ' + a.State = b.loc
    WHERE --state <> 'X' Puerto Rico has no state so we need those records
          --AND
        a.StateCode <> 'X'
        AND a.CountyCode <> 'X'
        AND a.CityCode <> 'X'
    ORDER BY a.LocationName + ', ' + a.State;

    /* Civilian Overseas Areas */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType,
        Coordinates
    )
    SELECT a.LocationCode,
           a.Location + ', ' + a.Country,
           'Civilian Overseas',
           geography::STPointFromText(
                                         'POINT(' + CAST(a.Longitude AS NVARCHAR(MAX)) + ' '
                                         + CAST(a.Latitude AS NVARCHAR(MAX)) + ')',
                                         @SRID
                                     ) AS Coordinates
    FROM lookup.DosLocations AS a
        INNER JOIN
        (
            --when displaying the nomenclatures we only care about the latest nomenclature name
            SELECT LocationCode,
                   MAX(AmcosVersionIdEnd) AS amcosversionidmax
            FROM lookup.DosLocations
            GROUP BY LocationCode
        ) AS b
            ON a.AmcosVersionIdEnd = b.amcosversionidmax
               AND a.LocationCode = b.LocationCode
    GROUP BY a.LocationCode,
             a.Location,
             a.Country,
             a.Latitude,
             a.Longitude
    ORDER BY a.LocationCode;

    /* GFEBS Countries */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           a.Country AS LocationCode,
           a.Country AS LocationName,
           'GFEBS Country' AS LocationType
    FROM load_GFEBS.Cleaned AS a
        INNER JOIN
        (
            --when displaying the nomenclatures we only care about the latest nomenclature name
            SELECT Country,
                   MAX(AmcosVersionId) AS AmcosVersionId
            FROM load_GFEBS.Cleaned
            GROUP BY Country
        ) AS b
            ON a.AmcosVersionId = b.AmcosVersionId
               AND a.Country = b.Country
    ORDER BY a.Country;

    /* Federal Wage System; Appropriated Fund */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           ScheduleArea AS LocationCode,
           AreaName AS LocationName,
           'Federal Wage System AF' AS LocationType
    FROM lookup.WageArea
    WHERE ScheduleArea NOT IN ( '900', '901', '902', '903', '904', '905' )
          AND FundType = 'AF';

    /* Federal Wage System; Appropriated Fund Overseas */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT ScheduleArea AS LocationCode,
           AreaName AS LocationName,
           'Federal Wage System AF Overseas' AS LocationType
    FROM lookup.WageArea
    WHERE ScheduleArea IN ( '900', '901', '902', '903', '904', '905' )
          AND FundType = 'AF';

    /* Federal Wage System; Nonappropriated Fund */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           ScheduleArea AS LocationCode,
           AreaName AS LocationName,
           'Federal Wage System NAF' AS LocationType
    FROM lookup.WageArea
    WHERE ScheduleArea <> '170'
          AND FundType = 'NAF';

    /* Federal Wage System; Nonappropriated Fund Overseas */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT DISTINCT
           ScheduleArea AS LocationCode,
           AreaName AS LocationName,
           'Federal Wage System NAF Overseas' AS LocationType
    FROM lookup.WageArea
    WHERE ScheduleArea = '170'
          AND FundType = 'NAF';

    /* Metropolitan and Nonmetropolitan area */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType
    )
    SELECT 
        a.Msacode AS LocationCode,
        a.MsaName AS LocationName,
        'MSA' AS LocationType
    FROM lookup.MetropolitanStatisticalArea a
    JOIN
    (
        SELECT 
            MSACode,
            MAX(AMCOSVersionId) AS AmcosVersionId
        FROM lookup.MetropolitanStatisticalArea 
        GROUP BY MSACode
    ) b ON a.MSACode = b.MSACode AND a.AmcosVersionId = b.AmcosVersionId
    ORDER BY a.MsaCode


    /* City/Counties */
    INSERT INTO #MyLocations
    (
        LocationCode,
        LocationName,
        LocationType,
        Coordinates
    )
    SELECT ZIPCode AS LocationCode,
           City + ', ' + State AS LocationName,
           'Zip' AS LocationType,
           geography::STPointFromText(
                                         'POINT(' + CAST(Longitude AS NVARCHAR(MAX)) + ' '
                                         + CAST(Latitude AS NVARCHAR(MAX)) + ')',
                                         @SRID
                                     ) AS Coordinates
    FROM lookup.FIPS_ZIP
    WHERE AmcosVersionIdEnd IN
          (
              SELECT MAX(AmcosVersionIdEnd)FROM lookup.FIPS_ZIP
          )
          AND City NOT IN ( 'APO', 'DPO', 'FPO', 'Parcel Return Service' ) --no admin locations and no overseas locations, overseas are handled by Dep of State
          AND Latitude <> 0
          AND Longitude <> 0 --places without a known lat/long are not allowed
    GROUP BY ZIPCode,
             City,
             State,
             Longitude,
             Latitude;

    IF @Debug = 1
    BEGIN
        SELECT 'inserts';
        SELECT a.LocationCode,
               a.LocationType
        FROM #MyLocations AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.LocationCode = b.SourceSystemCode
                   AND a.LocationType = b.LocationType
        WHERE b.LocationId IS NULL;

        SELECT 'updates';
        SELECT *
        FROM warehouse.Location AS a
            INNER JOIN #MyLocations AS b
                ON a.SourceSystemCode = b.LocationCode
                   AND a.LocationType = b.LocationType
        WHERE a.DisplayName <> b.LocationName OR (a.DisplayName IS NULL AND b.LocationName IS NOT NULL);
    END;

    IF @Debug = 0
    BEGIN
        -- ## now we insert values that weren't already there in the table 
        INSERT INTO warehouse.Location
        (
            SourceSystemCode,
            LocationType
        )
        SELECT a.LocationCode,
               a.LocationType
        FROM #MyLocations AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.LocationCode = b.SourceSystemCode
                   AND a.LocationType = b.LocationType
        WHERE b.LocationId IS NULL;

        --## now we update all the nomens to the latest
        UPDATE warehouse.Location
        SET DisplayName = b.LocationName,
            Coordinates = b.Coordinates
        FROM warehouse.Location AS a
            INNER JOIN #MyLocations AS b
                ON a.SourceSystemCode = b.LocationCode
                   AND a.LocationType = b.LocationType
        WHERE a.DisplayName <> b.LocationName OR (a.DisplayName IS NULL AND b.LocationName IS NOT NULL);
    END;
END;