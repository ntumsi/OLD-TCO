



CREATE VIEW [quicksight].[PPWalkMilitaryLocation]
AS

--military using MHA to our installation zip code
SELECT DISTINCT
       -1 AS LocationId,
       'Non Location Specific' AS LocationType,
       installation
FROM quicksight.MilitaryInstallationNameZip
UNION

--military using MHA to our installation zip code
SELECT DISTINCT
       y.LocationId,
       y.LocationType,
       z.installation
FROM xwalk.ZIPToMHA AS a
    INNER JOIN warehouse.Location AS y
        ON y.SourceSystemCode = a.MHA
    INNER JOIN quicksight.MilitaryInstallationNameZip AS z
        ON z.zipcode = a.ZIPCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = a.AmcosVersionId
AND y.LocationType = 'CONUS Military Housing Area'
UNION

/* All CIV  Military Installations non-Rest of US*/

SELECT DISTINCT
       y.LocationId,
       y.LocationType,
       z.installation
FROM lookup.FIPS_ZIP AS a
    INNER JOIN xwalk.LocalityPayAreaToFips AS b
        ON a.FIPSCode = b.StateCode + b.CountyCode
    INNER JOIN PaySchedule.LocalityPay AS c
        ON c.LocalityCode = b.LocalityCode
    INNER JOIN warehouse.Location AS y
        ON y.SourceSystemCode = c.LocalityCode
    INNER JOIN quicksight.MilitaryInstallationNameZip AS z
        ON z.zipcode = a.ZIPCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = b.AmcosVersionId
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = c.AmcosVersionId
UNION
/* All CIV  Military Installations Rest of US*/



SELECT DISTINCT
       y.LocationId,
       y.LocationType,
       z.installation
FROM warehouse.Location AS y
    CROSS JOIN
    (
        SELECT *
        FROM quicksight.MilitaryInstallationNameZip
        WHERE zipcode NOT IN
              (
                  SELECT a.ZIPCode
                  FROM lookup.FIPS_ZIP AS a
                      INNER JOIN xwalk.LocalityPayAreaToFips AS b
                          ON a.FIPSCode = b.StateCode + b.CountyCode
                  WHERE
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )
                  BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                  AND
                  (
                      SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
                  )   = b.AmcosVersionId
              )
    ) AS z
WHERE y.SourceSystemCode = 'RUS'
      AND y.LocationType = 'Locality Pay Area'
UNION


--/* AF Wage Schedules - Schedule Area by Installation*/
SELECT DISTINCT
       y.LocationId,
       y.LocationType,
       z.installation
FROM xwalk.FIPS_WageArea AS a
    INNER JOIN lookup.FIPS_ZIP AS b
        ON a.FIPS = b.FIPSCode
    INNER JOIN lookup.WageArea AS c
        ON c.ScheduleArea = a.Wage_schedule
           AND a.FundType = c.FundType
    INNER JOIN warehouse.Location AS y
        ON y.SourceSystemCode = c.ScheduleArea
    INNER JOIN quicksight.MilitaryInstallationNameZip AS z
        ON z.zipcode = b.ZIPCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = a.AmcosVersionId
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd
AND a.FundType = 'AF'
AND y.LocationType IN ( 'AF Wage Schedule' )
UNION

--/* NAF Wage Schedules - Schedule Area by Installation*/
SELECT DISTINCT
       y.LocationId,
       y.LocationType,
       z.installation
FROM xwalk.FIPS_WageArea AS a
    INNER JOIN lookup.FIPS_ZIP AS b
        ON a.FIPS = b.FIPSCode
    INNER JOIN lookup.WageArea AS c
        ON c.ScheduleArea = a.Wage_schedule
           AND a.FundType = c.FundType
    INNER JOIN warehouse.Location AS y
        ON y.SourceSystemCode = c.ScheduleArea
    INNER JOIN quicksight.MilitaryInstallationNameZip AS z
        ON z.zipcode = b.ZIPCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = a.AmcosVersionId
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd
AND a.FundType = 'NAF'
AND y.LocationType IN ( 'NAF Wage Schedule' )
UNION
/******************             NF                  ********************/
--unlike all the other wage plans, NF is more general in that area are defined at the wage AREA level, not the wage SCHEDULE level
--so all those joins above on wage schedule need to be done at the wage area level for NF thus the separate processing steps here


--/* NF Wage Schedule - Schedule Area by Installation*/

--10/18/2021 there is a known issue with this as the addition of a other wage schedules for NF will impact non NF pay plans so this view really needs to incorporate PPs
--into it but as of this date that hasn't been done for simplicity purposes to get the application running

SELECT DISTINCT
       y.LocationId,
       y.LocationType,
       z.installation
FROM xwalk.FIPS_WageArea AS a
    INNER JOIN lookup.FIPS_ZIP AS b
        ON a.FIPS = b.FIPSCode
    INNER JOIN lookup.WageArea AS c
        ON c.WageArea = a.Wage_area --here is the difference in NF, join on the overarching wage area
           AND a.FundType = c.FundType
    INNER JOIN warehouse.Location AS y
        ON y.SourceSystemCode = c.ScheduleArea
    INNER JOIN quicksight.MilitaryInstallationNameZip AS z
        ON z.zipcode = b.ZIPCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = a.AmcosVersionId
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd
AND a.FundType = 'NAF'
AND y.LocationType IN ( 'NAF Wage Schedule' )
UNION

--/* CCE Locations by Installation*/
SELECT DISTINCT
       y.LocationId,
       --this needs to be changed/improved in the future
       y.LocationType,
       z.installation
FROM xwalk.MetropolitanStatisticalAreaToFips AS a
    LEFT OUTER JOIN lookup.FIPS_ZIP AS b
        ON a.StateCode + a.CountyCode = b.FIPSCode
    INNER JOIN warehouse.Location AS y
        ON y.SourceSystemCode = a.MSACode
    INNER JOIN quicksight.MilitaryInstallationNameZip AS z
        ON z.zipcode = b.ZIPCode
WHERE
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)   = a.AmcosVersionId
AND
(
    SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
)
BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;