-- Stored Procedure

CREATE PROC [warehouse].[PopulateLocationByCategory]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    TRUNCATE TABLE warehouse.LocationByCategory;

    DROP TABLE IF EXISTS #MilitaryInstallations;
    CREATE TABLE #MilitaryInstallations
    (
        DisplayBase VARCHAR(500),
        ZipCode VARCHAR(5)
    );
    INSERT INTO #MilitaryInstallations
    (
        DisplayBase,
        ZipCode
    )
    SELECT UPPER(   CASE
                        WHEN BaseName = 'OTHER LOCATIONS' THEN
                            RTRIM(StationName)
                        WHEN BaseCode = STACO
                             OR BaseName = InstallationName THEN
                            RTRIM(BaseName)
                        ELSE
                            RTRIM(BaseName) + ' (' + RTRIM(InstallationName) + ')'
                    END + ' [' + Service + '] (' + State + ') '
                ) AS installation,
           LEFT(ZIPCode, 5)
    FROM lookup.MilitaryInstallation
    WHERE @AmcosVersionId
    BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd;

    /* Military Installation */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Installation
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           -1, --CareerProgramNumber doesn't apply to military
           b.LocationId,
           c.DisplayBase + '- ' + b.SourceSystemCode
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.ZIPCode,
                   a.MHA,
                   b.DisplayBase
            FROM xwalk.ZIPToMHA AS a
                INNER JOIN #MilitaryInstallations AS b
                    ON a.ZIPCode = b.ZipCode
            WHERE @AmcosVersionId = a.AmcosVersionId
        ) AS c
            ON b.SourceSystemCode = c.MHA
        LEFT OUTER JOIN lookup.MilitaryHousingArea AS d
            ON d.MHA = b.SourceSystemCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND @AmcosVersionId = d.AmcosVersionId
          AND c.DisplayBase IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             b.LocationId,
             c.DisplayBase,
             b.SourceSystemCode,
             b.LocationType,
             d.DisplayName;


    /* Military Housing Area */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        OconusMHA,
        ConusMHA
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           -1, --CareerProgramNumber doesn't apply to military
           b.LocationId,
           CASE
               WHEN b.LocationType = 'OCONUS Military Housing Area' THEN
                   d.DisplayName + ' - ' + b.SourceSystemCode
               ELSE
                   NULL
           END,
           CASE
               WHEN b.LocationType = 'CONUS Military Housing Area' THEN
                   d.DisplayName + ' - ' + b.SourceSystemCode
               ELSE
                   NULL
           END
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.ZIPCode,
                   a.MHA,
                   b.DisplayBase
            FROM xwalk.ZIPToMHA AS a
                INNER JOIN #MilitaryInstallations AS b
                    ON a.ZIPCode = b.ZipCode
            WHERE @AmcosVersionId = a.AmcosVersionId
        ) AS c
            ON b.SourceSystemCode = c.MHA
        LEFT OUTER JOIN lookup.MilitaryHousingArea AS d
            ON d.MHA = b.SourceSystemCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND @AmcosVersionId = d.AmcosVersionId
          AND b.LocationType IN ( 'OCONUS Military Housing Area', 'CONUS Military Housing Area' )
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             b.LocationId,
             c.DisplayBase,
             b.SourceSystemCode,
             b.LocationType,
             d.DisplayName;

    --/*  STRL */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        STRL
    )
    SELECT DISTINCT
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           CareerProgramNumber,
           LocationId,
           a.Strl --+ ' - ' + b.STRLName
    FROM data.Costs AS a
    --INNER JOIN 
    --(SELECT DISTINCT  STRL,STRLName FROM xwalk.UICToSTRL) AS b
    --ON a.STRL=b.STRL
    WHERE PayPlan LIKE 'D%'
          AND a.AmcosVersionId = @AmcosVersionId;

    /* All CIV  Military Installations non-Rest of US*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Installation
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           b.LocationId,
           c.DisplayBase + ' - ' + c.LocalityCode
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.LocalityCode,
                   b.DisplayBase
            FROM lookup.FIPS_ZIP AS a
                INNER JOIN #MilitaryInstallations AS b
                    ON a.ZIPCode = b.ZipCode
                INNER JOIN xwalk.LocalityPayAreaToFips AS c
                    ON a.FIPSCode = c.StateCode + c.CountyCode
                INNER JOIN PaySchedule.LocalityPay AS d
                    ON c.LocalityCode = d.LocalityCode
            WHERE @AmcosVersionId
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND @AmcosVersionId = c.AmcosVersionId
                  AND @AmcosVersionId = d.AmcosVersionId
        ) AS c
            ON b.SourceSystemCode = c.LocalityCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType = 'Locality Pay Area'
          AND c.DisplayBase IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             b.LocationId,
             c.DisplayBase,
             c.LocalityCode;

    /* All CIV  Military Installations Rest of US*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Installation
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.DisplayBase + ' - RUS'
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        CROSS JOIN
        (
            SELECT *
            FROM #MilitaryInstallations
            WHERE ZipCode NOT IN
                  (
                      SELECT a.ZIPCode
                      FROM lookup.FIPS_ZIP AS a
                          INNER JOIN xwalk.LocalityPayAreaToFips AS b
                              ON a.FIPSCode = b.StateCode + b.CountyCode
                      WHERE @AmcosVersionId
                            BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                            AND @AmcosVersionId = b.AmcosVersionId
                  )
        ) AS c
    WHERE b.SourceSystemCode = 'RUS'
          AND b.LocationType = 'Locality Pay Area'
          AND a.AmcosVersionId = @AmcosVersionId;

    --/* CIV Locality */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        LocalityPayArea
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           b.LocationId,
           c.LocalityPayArea + ' (' + c.LocalityCode + ')'
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.LocalityCode,
                   --b.DisplayBase,
                   e.LocalityPayArea
            FROM lookup.FIPS_ZIP AS a
                -- INNER JOIN #MilitaryInstallations AS b
                --     ON a.ZIPCode = b.ZipCode
                INNER JOIN xwalk.LocalityPayAreaToFips c
                    ON a.FIPSCode = c.StateCode + c.CountyCode
                INNER JOIN PaySchedule.LocalityPay d
                    ON d.LocalityCode = c.LocalityCode
                       AND d.AmcosVersionId = c.AmcosVersionId
                INNER JOIN lookup.LocalityPayArea e
                    ON e.LocalityCode = c.LocalityCode
                       AND e.AmcosVersionId = c.AmcosVersionId
            WHERE @AmcosVersionId
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND @AmcosVersionId = c.AmcosVersionId
        ) AS c
            ON b.SourceSystemCode = c.LocalityCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType = 'Locality Pay Area'
          AND c.LocalityPayArea IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             b.LocationId,
             --DisplayBase,
             c.LocalityCode,
             c.LocalityPayArea;

    /* All CIV   Localities Rest of US*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        LocalityPayArea
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           b.DisplayName + ' (' + b.SourceSystemCode + ')'
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE b.SourceSystemCode = 'RUS'
          AND b.LocationType = 'Locality Pay Area'
          AND a.AmcosVersionId = @AmcosVersionId;

    --/* CIV Special Areas */
    /* they DO NOT link to a military installation, that could create a one to many relationship
    with an installation linking to a locality area AND a special pay area
    instead we call out special area for users so they can deliberately select those 
    separate from a locality area */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        SpecialPayArea
    )
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           b.LocationId,
           b.DisplayName
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE b.LocationType = 'OPM Special Pay Locations'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             b.LocationId,
             b.DisplayName;

    --/* Civilian Overseas */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        CivOverseas
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           b.LocationId,
           b.DisplayName
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType = 'Civilian Overseas'
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             b.LocationId,
             b.DisplayName;

    /* Civilian Countries (GFEBS) */
    /* they DO NOT link to a military installation at this time */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Country
    )
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           b.LocationId,
           b.DisplayName
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
    WHERE b.LocationType = 'GFEBS Country'
          AND a.AmcosVersionId = @AmcosVersionId
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             b.LocationId,
             b.DisplayName;

    /* Federal Wage System AF - Schedule Area by Installation*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Installation
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.DisplayBase + ' - ' + c.ScheduleArea
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.DisplayBase,
                   d.ScheduleArea,
                   d.AreaName
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON a.StateCode + a.CountyCode = b.FIPSCode
                INNER JOIN #MilitaryInstallations AS c
                    ON b.ZIPCode = c.ZipCode
                INNER JOIN lookup.WageArea AS d
                    ON d.ScheduleArea = a.ScheduleArea
                       AND a.FundType = d.FundType
            WHERE @AmcosVersionId = a.AmcosVersionId
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  AND a.FundType = 'AF'
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System AF' )
          AND PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
              )
          AND c.DisplayBase IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.DisplayBase,
             c.ScheduleArea,
             c.AreaName;

    /* Federal Wage System NAF - Schedule Area by Installation*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Installation
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.DisplayBase + ' - ' + c.ScheduleArea
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.DisplayBase,
                   d.ScheduleArea,
                   d.AreaName
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON a.StateCode + a.CountyCode = b.FIPSCode
                INNER JOIN #MilitaryInstallations AS c
                    ON b.ZIPCode = c.ZipCode
                INNER JOIN lookup.WageArea AS d
                    ON d.ScheduleArea = a.ScheduleArea
                       AND a.FundType = d.FundType
            WHERE @AmcosVersionId = a.AmcosVersionId
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  AND a.FundType = 'NAF'
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' )
          AND PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND a.PayPlan <> 'NF' --handled separately
          AND c.DisplayBase IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.DisplayBase,
             c.ScheduleArea,
             c.AreaName;

    /* Federal Wage System AF - Schedule Area */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        WageSchedule
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.AreaName + ' - ' + c.ScheduleArea
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.ScheduleArea,
                   d.AreaName
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.WageArea AS d
                    ON d.ScheduleArea = a.ScheduleArea
                       AND a.FundType = d.FundType
            WHERE a.AmcosVersionId = @AmcosVersionId
                  AND a.FundType = 'AF'
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System AF' )
          AND PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
              )
          AND c.ScheduleArea IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.ScheduleArea,
             c.AreaName;

    /* Federal Wage System NAF - Schedule Area */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        WageSchedule
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.AreaName + ' - ' + c.ScheduleArea
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.ScheduleArea,
                   d.AreaName
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.WageArea AS d
                    ON d.ScheduleArea = a.ScheduleArea
                       AND a.FundType = d.FundType
            WHERE a.AmcosVersionId = @AmcosVersionId
                  AND a.FundType = 'NAF'
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' )
          AND c.ScheduleArea IS NOT NULL
          AND PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND a.PayPlan <> 'NF' --handled separately
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.ScheduleArea,
             c.AreaName;

    --/* Federal Wage System AF - County, state */
    /* Users may not know what areas a wage schedule encompass we make it a little easier for them by 
    providing a county/state selection, but we don't need to tie that to a installation since those were
    already handled above */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        CityCounty
    )
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.citycountyname
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.ScheduleArea,
                   --if the county doesn't exist because its null or blank then we need the city instead
                   CASE
                       WHEN b.County IN ( '', NULL ) THEN
                           b.City
                       ELSE
                           b.County
                   END + ', ' + b.State AS citycountyname
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON a.StateCode + a.CountyCode = b.FIPSCode
            WHERE a.FundType = 'AF'
                  AND a.AmcosVersionId = @AmcosVersionId
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System AF' )
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.citycountyname;

    --/* Federal Wage System NAF - County, state */
    -- because users may not know what areas a wage schedule encompass we make it a little easier for them by 
    --providing a county/state selection, but we don't need to tie that to a installation since those were
    --already handled above
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        CityCounty
    )
    SELECT a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.citycountyname
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.ScheduleArea,
                   --if the county doesn't exist because its null or blank then we need the city instead
                   CASE
                       WHEN b.County IN ( '', NULL ) THEN
                           b.City
                       ELSE
                           b.County
                   END + ', ' + b.State AS citycountyname
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON a.StateCode + a.CountyCode = b.FIPSCode
            WHERE a.FundType = 'NAF'
                  AND a.AmcosVersionId = @AmcosVersionId
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' )
          AND a.PayPlan <> 'NF' --handled later
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.citycountyname;

    /* NF Pay Plan */
    /* Unlike all the other wage plans, NF is more general in that area are defined at the wage AREA level, not the wage SCHEDULE level
    so all those joins above on wage schedule need to be done at the wage area level for NF thus the separate processing steps here */

    --/* NF Pay Plan - Schedule Area by Installation*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        Installation
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.DisplayBase + ' - ' + c.ScheduleArea
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.DisplayBase,
                   d.ScheduleArea,
                   d.AreaName
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON a.StateCode + a.CountyCode = b.FIPSCode
                INNER JOIN #MilitaryInstallations AS c
                    ON b.ZIPCode = c.ZipCode
                INNER JOIN lookup.WageArea AS d
                    ON d.WageArea = a.WageArea --here is the difference in NF, join on the overarching wage area
                       AND a.FundType = d.FundType
            WHERE @AmcosVersionId = a.AmcosVersionId
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  AND a.FundType = 'NAF'
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' )
          AND a.PayPlan = 'NF'
          AND c.DisplayBase IS NOT NULL
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.DisplayBase,
             c.ScheduleArea,
             c.AreaName;

    --/* NF Pay Plan - Schedule Area */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        WageSchedule
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.AreaName + ' - ' + c.ScheduleArea
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.ScheduleArea,
                   d.AreaName
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.WageArea AS d
                    ON d.WageArea = a.WageArea --here is the difference in NF, join on the overarching wage area
                       AND a.FundType = d.FundType
            WHERE a.AmcosVersionId = @AmcosVersionId
                  AND a.FundType = 'NAF'
        ) AS c
            ON b.SourceSystemCode = c.ScheduleArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' )
          AND c.ScheduleArea IS NOT NULL
          AND a.PayPlan = 'NF'
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.ScheduleArea,
             c.AreaName;

    --/* Federal Wage System NAF - County, state */
    -- because users may not know what areas a wage schedule encompass we make it a little easier for them by 
    --providing a county/state selection, but we don't need to tie that to a installation since those were
    --already handled above
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId,
        CityCounty
    )
    SELECT DISTINCT
           a.PayPlan,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CareerProgramNumber,
           a.LocationId,
           c.citycountyname
    FROM data.Costs AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
        LEFT OUTER JOIN lookup.WageArea AS z
            ON b.SourceSystemCode = z.ScheduleArea
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.WageArea,
                   --if the county doesn't exist because its null or blank then we need the city instead
                   CASE
                       WHEN b.County IN ( '', NULL ) THEN
                           b.City
                       ELSE
                           b.County
                   END + ', ' + b.State AS citycountyname
            FROM xwalk.WageAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON a.StateCode + a.CountyCode = b.FIPSCode
            WHERE a.FundType = 'NAF'
                  AND a.AmcosVersionId = @AmcosVersionId
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS c
            ON z.WageArea = c.WageArea
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType IN ( 'Federal Wage System NAF' )
          AND a.PayPlan = 'NF'
          AND z.FundType = 'NAF'
    GROUP BY a.PayPlan,
             a.CategoryGroupCode,
             a.CategorySubgroupCode,
             a.CareerProgramNumber,
             a.LocationId,
             c.citycountyname;

    /* CCE Locations by Installation */
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        Installation,
        LocationId
    )
    SELECT DISTINCT
           'CCE',
           a.SOC,
           a.SOC,
           -1,
           c.DisplayBase,
           b.LocationId
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.MSACode = b.SourceSystemCode
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.DisplayBase,
                   m.MSAName,
                   a.MSACode
            FROM xwalk.MetropolitanStatisticalAreaToFips AS a
                INNER JOIN lookup.MetropolitanStatisticalArea m
                    ON m.MSACode = a.MSACode
                       AND m.AmcosVersionId = a.AmcosVersionId
                LEFT OUTER JOIN lookup.FIPS_ZIP AS b
                    ON CONCAT(a.StateCode, a.CountyCode) = b.FIPSCode
                LEFT OUTER JOIN #MilitaryInstallations AS c
                    ON b.ZIPCode = c.ZipCode
            WHERE @AmcosVersionId
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND @AmcosVersionId
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS c
            ON a.MSACode = c.MSACode
    WHERE c.DisplayBase IS NOT NULL
          AND @AmcosVersionId = a.AmcosVersionId
          AND b.LocationType = 'MSA'
    GROUP BY a.SOC,
             c.DisplayBase,
             c.MSAName,
             b.LocationId;

    --/* CCE Locations by MSA*/
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        MSA,
        LocationId
    )
    SELECT DISTINCT
           'CCE',
           a.SOC,
           a.SOC,
           -1,
           b.DisplayName,
           b.LocationId
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro AS a
        LEFT OUTER JOIN warehouse.Location AS b
            ON a.MSACode = b.SourceSystemCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.LocationType = 'MSA'
    GROUP BY a.SOC,
             b.DisplayName,
             b.LocationId;

    UPDATE warehouse.LocationByCategory
    SET CategoryGroupCode = SUBSTRING(CategoryGroupCode, 1, 2) + '-0000'
    WHERE PayPlan = 'CCE'
          AND SUBSTRING(CategoryGroupCode, 3, 5) <> '-0000';

    UPDATE warehouse.LocationByCategory
    SET CategorySubgroupCode = '-1'
    WHERE PayPlan = 'CCE'
          AND SUBSTRING(CategorySubgroupCode, 3, 5) = '-0000';

    --/* Location non-specific values */
    -- we need to make sure location agnostic values are inserted as options
    INSERT INTO warehouse.LocationByCategory
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CareerProgramNumber,
        LocationId
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           CareerProgramNumber,
           LocationId
    FROM data.Costs
    WHERE LocationId = -1
          AND AmcosVersionId = @AmcosVersionId
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             CareerProgramNumber,
             LocationId;
END;
GO
