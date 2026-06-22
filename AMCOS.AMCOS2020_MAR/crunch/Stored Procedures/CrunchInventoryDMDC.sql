
-- =============================================
-- Author:		Dan Hogan
-- Create date: 01/08/2020
-- Description:	Converts raw DMDC data into the correct inventory format and conducts necessary data checks/conversions
-- =============================================

/*
NOTE: as of the 2020 release we don't use the RCC code, but if we did here are the codes:
MIL
1 - Selected Reserve
2 - Activated Guard/Reserve (AG)R
3 - Not used
4 - Inactive Guard/Inactive Reserve (IRR/ING)
5 - Standby Reserve
6 - Retired Reserve
CIV
0 - Not a Mil Tech
1 - Guard Mil Tech
2 - Reserve Mil Tech

the above comes from an email from Scott Seggerman at DMDC on 1/22/2020
*/
CREATE PROCEDURE [crunch].[CrunchInventoryDMDC]
    @AmcosVersionId INT = -1,
    @Debug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #DMDCRaw
    (
        [CivType] NVARCHAR(3) NULL,
        [PayPlan] NVARCHAR(3) NULL,
        [myGROUP] VARCHAR(4) NULL,
        [CategorySubgroup] NVARCHAR(4) NULL,
        [ValidCategorySubgroup] VARCHAR(4) NULL,
        [GradeType] NVARCHAR(2) NULL,
        [GradeLevel] NVARCHAR(2) NULL,
        [Step] NVARCHAR(2) NULL,
        [UIC] NCHAR(6) NULL,
        [UicZipCode] VARCHAR(5) NULL,
        [UicDrrsZipCodeState] VARCHAR(50) NULL,
        [DutyLocationCode] NCHAR(9) NULL,
        [DutyStationCity] VARCHAR(200) NULL,
        [DutyStationCounty] VARCHAR(200) NULL,
        [DutyStationState] VARCHAR(200) NULL,
        [DutyStationCountry] VARCHAR(200) NULL,
        [DutyStationZIPCode] VARCHAR(5) NULL,
        [LocationId] INT NULL,
        [LocationName] VARCHAR(150) NULL,
        [LocationType] VARCHAR(150) NULL,
        [PayPlanType] VARCHAR(100) NULL,
        [YOS] [SMALLINT] NULL,
        [Inventory] SMALLINT NULL,
        [AmcosVersionId] INT NULL
    );
    INSERT INTO #DMDCRaw
    (
        [CivType],
        [PayPlan],
        [CategorySubgroup],
        [GradeType],
        [GradeLevel],
        [Step],
        [UIC],
        DutyLocationCode,
        [YOS],
        Inventory,
        AmcosVersionId
    )
    SELECT CivType,
           PayPlan,
           CategorySubgroup,
           GradeType,
           GradeLevel,
           Step,
           UIC,
           DutyLocationCode,
           YOS,
           SUM([Count]),
           AmcosVersionId
    FROM load_inventory.DMDC_Raw
    WHERE AmcosVersionId = @AmcosVersionId
    GROUP BY CivType,
             PayPlan,
             CategorySubgroup,
             GradeType,
             GradeLevel,
             Step,
             UIC,
             DutyLocationCode,
             YOS,
             AmcosVersionId;

    --04/18/2022 - for reasons not yet known, military grade level 0s are coming in from dmdc
    --these don't make any sense so we get rid of them
    --DELETE FROM #DMDCRaw
    --WHERE PayPlan IN
    --      (
    --          SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'military'
    --      )
    --      AND GradeLevel <= 0;

	--09/17/2025 Grade level 0 is being added because they are either west point cadets or ROTC cadets.

    /* For reference bring in what the duty station identifies says is the location
    many locations use something other than the dloc so this allows us to keep an eye on the ultimate location name
    and that of the DutyLocationCode */
    UPDATE #DMDCRaw
    SET DutyStationCity = DutyStation.City,
        DutyStationCounty = DutyStation.County,
        DutyStationState = DutyStation.State,
        DutyStationCountry = DutyStation.Country
    FROM #DMDCRaw AS a
        INNER JOIN lookup.DutyStation DutyStation
            ON a.DutyLocationCode = DutyStation.DutyStationCode;

    /* Fill in missing grade types */
    UPDATE #DMDCRaw
    SET GradeType = 'W'
    WHERE PayPlan IN ( 'AWO', 'RWO', 'NWO' );
    UPDATE #DMDCRaw
    SET GradeType = 'O'
    WHERE PayPlan IN ( 'AO', 'RO', 'NO' );
    UPDATE #DMDCRaw
    SET GradeType = 'E'
    WHERE PayPlan IN ( 'AE', 'RE', 'NE' );

    -- Assign a pay plan type which we will use later

    UPDATE #DMDCRaw
    SET PayPlanType = 'AF White Collar'
    WHERE GradeType NOT IN ( 'E', 'O', 'W' )
          AND PayPlan NOT LIKE 'X%'
          AND PayPlan NOT IN ( 'NA', 'NL', 'NS' )
          AND PayPlan NOT IN ( 'NF' )
          AND PayPlan NOT LIKE 'W%';
    --CY is technically a NAF White Collar plan but it uses the GS locations so for location purposes we treat it as one

    UPDATE #DMDCRaw
    SET PayPlanType = 'NAF White Collar'
    WHERE PayPlan IN ( 'NF' );

    UPDATE #DMDCRaw
    SET PayPlanType = 'AF Blue Collar'
    WHERE GradeType NOT IN ( 'E', 'O', 'W' )
          AND
          (
              PayPlan LIKE 'X%'
              OR PayPlan LIKE 'W%'
          );
    UPDATE #DMDCRaw
    SET PayPlanType = 'Military'
    WHERE GradeType IN ( 'W', 'O', 'E' );

    UPDATE #DMDCRaw
    SET PayPlanType = 'NAF Blue Collar'
    WHERE GradeType NOT IN ( 'E', 'O', 'W' )
          AND PayPlan IN ( 'NA', 'NL', 'NS');

	 --UPDATE #DMDCRaw
  --  SET PayPlanType = 'NAF Blue Collar'
  --  WHERE GradeType NOT IN ( 'E', 'O', 'W' )
  --        AND PayPlan IN ( 'WB','WK','WU')		  
		--  AND CategorySubgroup in (
		--	'2604'
		--	,'2810'
		--	,'4701'
		--	,'2604'
		--	,'4742'
		--	,'5788'
		--	,'8801'
		--	,'8852'
		--	,'2602'
		--	,'3414'
		--	,'3806'
		--	,'4818'
		--	,'2810'
		--	,'5352'
		--	,'5407'
		--  );


    -- ######################################### Military
    UPDATE #DMDCRaw
    SET Step = -1
    WHERE PayPlan IN ( 'AWO', 'RWO', 'NWO', 'AO', 'RO', 'NO', 'AE', 'RE', 'NE' );



    --#### Process WOMOS Conversions
    UPDATE #DMDCRaw
    SET ValidCategorySubgroup = CategorySubgroup
    WHERE GradeType = 'W'
          AND CategorySubgroup IN
              (
                  SELECT WOMOS
                  FROM lookup.WOMOS
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = b.WOMOSNew
    FROM #DMDCRaw AS a
        INNER JOIN lookup.WOMOSConversion AS b
            ON a.CategorySubgroup = b.WOMOSOld
               AND b.AmcosVersionId = @AmcosVersionId
               AND a.GradeType = 'W'
               AND a.GradeLevel = b.GradeLevel;

    --#### Process MOS Conversions
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = CategorySubgroup
    WHERE GradeType = 'E'
          AND CategorySubgroup IN
              (
                  SELECT MOS
                  FROM lookup.MOS
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = b.MOSNew
    FROM #DMDCRaw AS a
        INNER JOIN lookup.MOSConversion AS b
            ON a.CategorySubgroup = b.MOSOld
               AND b.AmcosVersionId = @AmcosVersionId
               AND a.GradeType = 'E'
               AND a.GradeLevel = b.GradeLevel;

    --#### Process AOC Conversions
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = CategorySubgroup
    WHERE GradeType = 'O'
          AND CategorySubgroup IN
              (
                  SELECT AOC
                  FROM lookup.AOC
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = b.AOCNew
    FROM #DMDCRaw AS a
        INNER JOIN lookup.AOCConversion AS b
            ON a.CategorySubgroup = b.AOCOld
               AND b.AmcosVersionId = @AmcosVersionId
               AND a.GradeType = 'O'
               AND a.GradeLevel = b.GradeLevel;


    /* Convert unknown steps/gradelevels to 99 which is the universal unknown */
    UPDATE #DMDCRaw
    SET Step = '99'
    WHERE PayPlanType IN ( 'NAF White Collar', 'AF White Collar', 'AF Blue Collar', 'NAF Blue Collar' )
          AND Step = '42';
    UPDATE #DMDCRaw
    SET GradeLevel = '99'
    WHERE PayPlanType IN ( 'NAF White Collar', 'AF White Collar', 'AF Blue Collar', 'NAF Blue Collar' )
          AND GradeLevel = '42';


    -- ######################################### OPM White Collar
    -- ##### Only allow in subgroups we have in our DB
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = CategorySubgroup
    WHERE PayPlanType IN ( 'AF White Collar', 'NAF White Collar' )
          AND CategorySubgroup IN
              (
                  SELECT OccupationalSeriesNumber
                  FROM lookup.GS_OccupationalSeries
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    --CY comes in as unknown but per DODI 1400.25-V1407 dated 1/6/2012 the only valid subgroup is 1702
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = '1702',
        myGROUP = '1700',
        Step = -1 --step has no meaning in pay bands and we only get 99s which for other pay plans is considered unknown so change to -1
    WHERE PayPlan IN ( 'CY' );


    -- ######################################### OPM Blue COllar
    -- ##### Only allow in subgroups we have in our DB
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = CategorySubgroup
    WHERE PayPlanType IN ( 'AF Blue Collar', 'NAF Blue Collar' )
          AND CategorySubgroup IN
              (
                  SELECT OccupationalSeriesNumber
                  FROM lookup.Wage_OccupationalSeries
                  WHERE @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    --these pay plan gets a pass since they don't have group/subgroups
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = 'ZZZZ',
        myGROUP = 'ZZZZ'
    WHERE PayPlan IN ( 'ZZ' );


    --these pay plan gets a pass since they don't have group/subgroups
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = 'ZZZZ',
        myGROUP = 'ZZZZ'
    WHERE CategorySubgroup IN ( '0000' );


    --Mark all the unknown subgroups as the same unknown code
    UPDATE #DMDCRaw
    SET [ValidCategorySubgroup] = 'ZZZZ'
    WHERE CategorySubgroup LIKE 'ZZZ%';




    --set our group codes
    --military group codes are 2 digits, all others are 4 digits with the last two being 00
    UPDATE #DMDCRaw
    SET myGROUP = LEFT(ValidCategorySubgroup, 2)
    WHERE PayPlanType = 'Military';
    UPDATE #DMDCRaw
    SET myGROUP = LEFT(ValidCategorySubgroup, 2) + '00'
    WHERE PayPlanType <> 'Military';

    --If we have an unidentified subgroup we need to call that out
    IF EXISTS
    (
        SELECT *
        FROM #DMDCRaw
        WHERE ValidCategorySubgroup IS NULL
              OR ValidCategorySubgroup = '-1'
              OR myGROUP IS NULL
              OR myGROUP = '-1'
    )
    BEGIN
        SELECT 'these records have invalid groups/subgroups which is not allowed';

        SELECT *
        FROM #DMDCRaw
        WHERE ValidCategorySubgroup IS NULL
              OR ValidCategorySubgroup = '-1'
              OR myGROUP IS NULL
              OR myGROUP = '-1';


        RAISERROR('Invalid group/subgroup codes', 18, 1);
        RETURN;
    END;
    -- ################## Bring in UIC data as backup
    UPDATE #DMDCRaw
    SET UicZipCode = LEFT(b.ZIP, 5),
        UicDrrsZipCodeState = b.State
    FROM #DMDCRaw AS a
        INNER JOIN lookup.UICLocation AS b
            ON a.UIC = b.UIC
			and b.EffectiveDate = (Select Max(EffectiveDate) from lookup.UICLocation c where c.UIC = b.UIC)


    -- ################## Location Map FIPS to Zip
    UPDATE #DMDCRaw
    SET DutyStationZIPCode = b.ZIPCode
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON LEFT(a.DutyLocationCode, 2) + RIGHT(a.DutyLocationCode, 3) = b.FIPSCode
    WHERE @AmcosVersionId
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    --####### Military Location (MHA)
    --DutyLocationCode is the primary location field so do those first
    UPDATE #DMDCRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName,
        LocationType = c.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN xwalk.ZIPToMHA AS b
            ON a.DutyStationZIPCode = b.ZIPCode
        INNER JOIN warehouse.Location AS c
            ON b.MHA = c.SourceSystemCode
    WHERE @AmcosVersionId = b.AmcosVersionId
          AND c.LocationType = 'CONUS Military Housing Area'
          AND a.PayPlanType = 'Military';

    --Use the UIC Zip as backup
    UPDATE #DMDCRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName,
        LocationType = c.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN xwalk.ZIPToMHA AS b
            ON a.UicZipCode = b.ZIPCode
        INNER JOIN warehouse.Location AS c
            ON b.MHA = c.SourceSystemCode
    WHERE @AmcosVersionId = b.AmcosVersionId
          AND c.LocationType = 'CONUS Military Housing Area'
          AND a.PayPlanType = 'Military'
          AND a.LocationId IS NULL;

    --##################### Overseas
    --map civilians to Department of State overseas areas, by DutyLocationCode first
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN xwalk.DLOCtoDoS AS b
            ON b.DLOC = a.DutyLocationCode
        INNER JOIN lookup.DosLocations AS c
            ON c.LocationCode = b.DOSLocation
        INNER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.LocationCode
    WHERE a.LocationId IS NULL -- only update locationids we don't already know
          AND @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId
          BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd
          AND a.PayPlanType <> 'Military' --CIVs are goverened by dep of state, military though have overseas MHAs so this doesn't apply to them
          AND d.LocationType = 'Civilian Overseas'; --don't want the DoS location id inadvertanly matching another location's ID

    --map civs to zip next in case the dloc didn't map
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN xwalk.ZiptoDoS AS b
            ON b.ZIPCode = LEFT(a.UicZipCode, 5)
        INNER JOIN lookup.DosLocations AS c
            ON c.LocationCode = b.DOSLocation
        INNER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.LocationCode
    WHERE a.LocationId IS NULL -- only update locationids we don't already know
          AND @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId
          BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd
          AND a.PayPlanType <> 'Military' --CIVs are goverened by dep of state, military though have overseas MHAs so this doesn't apply to them
          AND d.LocationType = 'Civilian Overseas'; --don't want the DoS location id inadvertanly matching another location's ID




    --##################### White Collar (Locality Area OR Special Pay area
    -- Special Pay locations first using DutyLocationCode
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.DutyStationZIPCode = b.ZIPCode
        INNER JOIN xwalk.SpecialRateTablesByLocation AS c
            ON b.FIPSCode = c.State + c.CountyCode
        INNER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.LocationName
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND d.LocationType = 'OPM Special Pay Locations'
          AND a.PayPlanType = 'AF White Collar'
          AND a.PayPlan IN ( 'GS', 'GL' ); --special pay only applies to these pay plans

    -- Special Pay locations first using UIC
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.UicZipCode = b.ZIPCode
        INNER JOIN xwalk.SpecialRateTablesByLocation AS c
            ON b.FIPSCode = c.State + c.CountyCode
        INNER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.LocationName
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND d.LocationType = 'OPM Special Pay Locations'
          AND a.PayPlanType = 'AF White Collar'
          AND a.PayPlan IN ( 'GS', 'GL' ) --special pay only applies to these pay plans
          AND a.LocationId IS NULL; ---don't overwrite anything done above



    -- non-RUS next using DutyLocationCode
    UPDATE #DMDCRaw
    SET LocationId = e.LocationId,
        LocationName = e.DisplayName,
        LocationType = e.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.DutyStationZIPCode = b.ZIPCode
        INNER JOIN xwalk.LocalityPayAreaToFips AS c
            ON b.FIPSCode = c.StateCode + c.CountyCode
        INNER JOIN PaySchedule.LocalityPay AS d
            ON c.LocalityCode = d.LocalityCode
        INNER JOIN warehouse.Location AS e
            ON e.SourceSystemCode = d.LocalityCode
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND @AmcosVersionId = d.AmcosVersionId
          AND e.LocationType = 'Locality Pay Area'
          AND a.PayPlanType = 'AF White Collar'
          AND a.LocationId IS NULL; ---don't overwrite anything done above



    --non-rus for certain US territories
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   z.LocationId,
                   z.LocationType,
                   z.SourceSystemCode,
                   z.DisplayName,
                   CASE
                       WHEN SourceSystemCode = 'PR' THEN
                           'RQ'
                       WHEN SourceSystemCode = 'USVI' THEN
                           'VQ'
                       WHEN SourceSystemCode = 'GNM' THEN
                           'GQ'
                       ELSE
                           '!!'
                   END AS dloc2
            FROM warehouse.Location AS z
            WHERE LocationType = 'Locality Pay Area'
        ) AS b
            ON LEFT(a.DutyLocationCode, 2) = b.dloc2
    WHERE a.PayPlanType = 'AF White Collar'
          AND a.LocationId IS NULL; ---don't overwrite anything done above

    -- non-RUS next using UIC
    UPDATE #DMDCRaw
    SET LocationId = e.LocationId,
        LocationName = e.DisplayName,
        LocationType = e.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.UicZipCode = b.ZIPCode
        INNER JOIN xwalk.LocalityPayAreaToFips AS c
            ON b.FIPSCode = c.StateCode + c.CountyCode
        INNER JOIN PaySchedule.LocalityPay AS d
            ON c.LocalityCode = d.LocalityCode
        INNER JOIN warehouse.Location AS e
            ON e.SourceSystemCode = d.LocalityCode
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND @AmcosVersionId = d.AmcosVersionId
          AND e.LocationType = 'Locality Pay Area'
          AND a.PayPlanType = 'AF White Collar'
          AND a.LocationId IS NULL; ---don't overwrite anything done above


    --now assign RUS
    UPDATE #DMDCRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName,
        LocationType = c.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.DutyStationZIPCode = b.ZIPCode
        CROSS JOIN
        (
            SELECT *
            FROM warehouse.Location
            WHERE LocationType = 'Locality Pay Area'
                  AND SourceSystemCode = 'RUS'
        ) AS c
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND a.PayPlanType = 'AF White Collar'
          AND b.State NOT IN ( 'AA', 'AE', '' ) -- don't include foreign countries so we don't assign them RUS
          AND a.LocationId IS NULL; --don't include anything that already has a location assigned


    --assign RUS for incorrect DutyLocationCode based on zip
    UPDATE #DMDCRaw
    SET LocationId = c.LocationId,
        LocationName = c.DisplayName,
        LocationType = c.LocationType
    FROM #DMDCRaw AS a
        CROSS JOIN
        (
            SELECT *
            FROM warehouse.Location
            WHERE LocationType = 'Locality Pay Area'
                  AND SourceSystemCode = 'RUS'
        ) AS c
    WHERE a.PayPlanType = 'AF White Collar'
          AND a.UicDrrsZipCodeState NOT IN ( 'AA', 'AE', '' ) -- don't include foreign countries so we don't assign them RUS
          AND a.LocationId IS NULL; --don't include anything that already has a location assigned

    --##################### Blue Collar (Federal Wage System AF)
    --DutyLocationCode zip first
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.DutyStationZIPCode = b.ZIPCode
        INNER JOIN xwalk.WageAreaToFips AS c
            ON b.FIPSCode = CONCAT(c.StateCode, c.CountyCode)
        INNER JOIN warehouse.Location AS d
            ON c.ScheduleArea = d.SourceSystemCode
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND c.FundType = 'AF'
          AND d.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar';



    --UIC zip next
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.UicZipCode = b.ZIPCode
        INNER JOIN xwalk.WageAreaToFips AS c
            ON b.FIPSCode = CONCAT(c.StateCode, c.CountyCode)
        INNER JOIN warehouse.Location AS d
            ON c.ScheduleArea = d.SourceSystemCode
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND d.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND c.FundType = 'AF'
          AND a.LocationId IS NULL; -- don't overwrite anything above

    --Regardles of the UIC's location the following payplans are only for schedule area 124
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        CROSS JOIN warehouse.Location AS b
    WHERE b.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND b.SourceSystemCode = '124' --mehpis TN, on 1/13/2020 Dan Hogan noticed that DMDC to UIC lists them elsewhere which don't have a payschedule
          AND a.PayPlan IN ( 'XR', 'XT', 'XU' );

    --non-rus for certain US territories
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   z.DisplayName,
                   z.SourceSystemCode,
                   z.LocationType,
                   z.LocationId,
                   CASE
                       WHEN SourceSystemCode = '151' THEN
                           'RQ'
                       WHEN SourceSystemCode = '903' THEN
                           'VQ'
                       WHEN SourceSystemCode = '901' THEN
                           'GQ'
                       ELSE
                           '!!'
                   END AS dloc2
            FROM warehouse.Location AS z
            WHERE LocationType = 'Federal Wage System AF'
        ) AS b
            ON LEFT(a.DutyLocationCode, 2) = b.dloc2
    WHERE a.PayPlanType = 'AF Blue Collar'
          AND a.LocationId IS NULL; ---don't overwrite anything done above

	UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType		
    FROM #DMDCRaw AS a
        CROSS JOIN warehouse.Location AS b
    WHERE b.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND b.SourceSystemCode = '151' --mehpis TN, on 1/13/2020 Dan Hogan noticed that DMDC to UIC lists them elsewhere which don't have a payschedule
          AND a.PayPlan IN ( 'WU', 'WR', 'WQ' );

 --   --Regardles of the UIC's location the following payplans are only for schedule area 151
 --   UPDATE #DMDCRaw
 --   SET LocationId = b.LocationId,
 --       LocationName = b.DisplayName,
 --       LocationType = b.LocationType,
	--	PayPlanType = 'NAF Blue Collar'
 --   FROM #DMDCRaw AS a
 --       CROSS JOIN warehouse.Location AS b
 --   WHERE b.LocationType = 'Federal Wage System NAF'
 --         AND a.PayPlanType = 'AF Blue Collar'
 --         AND b.SourceSystemCode in ('151','112', '078', '034') --mehpis TN, on 1/13/2020 Dan Hogan noticed that DMDC to UIC lists them elsewhere which don't have a payschedule
 --         AND a.PayPlan IN ( 'WU', 'WR', 'WQ', 'WB', 'WK' );

	

    -- handle special locations for Blue Collar
    -- 	guam is zip code 969xx -> FIPS GQ000 (wage schedule 901)
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        CROSS JOIN warehouse.Location AS b
    WHERE b.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND a.DutyStationZIPCode LIKE '969%'
          AND b.SourceSystemCode = '901';

    -- 	america samoa is 96799 -> AQ000 (schedule 904)
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        CROSS JOIN warehouse.Location AS b
    WHERE b.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND a.DutyStationZIPCode = '96799'
          AND b.SourceSystemCode = '904';

    -- 	virgina islands 
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        CROSS JOIN warehouse.Location AS b
    WHERE b.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND a.DutyStationZIPCode LIKE '008%'
          AND b.SourceSystemCode = '903';



    -- Then there are zip codes that for some reason aren't in the fips zip table, we try and map them by cutting off the last digit
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN
        (
            --for some reason the uic location table gives some zip codes which suposedly don't exist, we try and remedy that by returning the lowest fips code corresponding to zip4s
            --note the aggregate functions so that we only have one fips for each zip, otherwise the join would duplicate inventory records which would not be good
            SELECT MIN(FIPSCode) AS fipscode,
                   MIN(LEFT(ZIPCode, 4)) AS zip4
            FROM lookup.FIPS_ZIP
            WHERE @AmcosVersionId
            BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
            GROUP BY LEFT(ZIPCode, 4)
        ) AS b
            ON LEFT(a.DutyStationZIPCode, 4) = b.zip4
        INNER JOIN xwalk.WageAreaToFips AS c
            ON b.fipscode = CONCAT(c.StateCode, c.CountyCode)
        INNER JOIN warehouse.Location AS d
            ON c.ScheduleArea = d.SourceSystemCode
    WHERE @AmcosVersionId = c.AmcosVersionId
          AND d.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND c.FundType = 'AF'
          AND a.LocationId IS NULL;

        


    --then there are some which even the zip digit trick doesn't resolve so we try and match on city and state
    UPDATE #DMDCRaw
    SET LocationId = e.LocationId,
        LocationName = e.DisplayName,
        LocationType = e.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.UICLocation AS b
            ON a.DutyStationZIPCode = b.ZIP
			AND b.EffectiveDate = (Select Max(EffectiveDate) From lookup.UICLocation uic WHERE uic.UIC = b.UIC)
        INNER JOIN
        (
            SELECT MIN(FIPSCode) AS fipscode,
                   MIN(City) AS city,
                   MIN(State) AS state
            FROM lookup.FIPS_ZIP
            WHERE @AmcosVersionId
            BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
            GROUP BY City,
                     State
        ) AS c
            ON b.CITY = c.city
               AND b.STATE = c.state
        INNER JOIN xwalk.WageAreaToFips AS d
            ON c.fipscode = CONCAT(d.StateCode, d.CountyCode)
        INNER JOIN warehouse.Location AS e
            ON d.ScheduleArea = e.SourceSystemCode
    WHERE @AmcosVersionId = d.AmcosVersionId
          AND e.LocationType = 'Federal Wage System AF'
          AND a.PayPlanType = 'AF Blue Collar'
          AND a.LocationId IS NULL;

    --anything with an APO DRRSZIPCDSTATE is a foreign area
    --commented out 9/1/2020 when we implemented Dep of State locations
    --  UPDATE #DMDCRaw
    --  SET LocationId = b.LocationId,
    --      LocationName = b.DisplayName,
    --LocationType=b.LocationType
    --  FROM #DMDCRaw AS a
    --      CROSS JOIN warehouse.Location AS b
    --  WHERE b.LocationType = 'Federal Wage System AF'
    --        AND a.payplantype = 'AFBlue Collar'
    --        AND a.LocationId IS NULL
    --        AND b.SourceSystemCode = '900'
    --        AND a.UicDrrsZipCodeState IN ( 'AA', 'AE', 'AP' )
    --        AND LocationId IS NULL;


    --##################### Blue Collar (Federal Wage System NAF) and White Collar NAF (also under the Federal Wage System NAF
    --DutyLocationCode zip first
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.DutyStationZIPCode = b.ZIPCode
        INNER JOIN xwalk.WageAreaToFips AS c
            ON b.FIPSCode = CONCAT(c.StateCode, c.CountyCode)
        INNER JOIN warehouse.Location AS d
            ON c.ScheduleArea = d.SourceSystemCode
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND c.FundType = 'NAF'
          AND d.LocationType = 'Federal Wage System NAF'
          AND a.PayPlanType IN ( 'NAF Blue Collar', 'NAF White Collar' );

    --non-rus for certain US territories
    UPDATE #DMDCRaw
    SET LocationId = b.LocationId,
        LocationName = b.DisplayName,
        LocationType = b.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN
        (
            SELECT DISTINCT
                   LocationId,
                   SourceSystemCode,
                   LocationType,
                   DisplayName,
                   CASE
                       WHEN SourceSystemCode = '155' THEN
                           'RQ'
                       WHEN SourceSystemCode = '!!' THEN
                           'VQ' --no Virgin island schedule like AF
                       WHEN SourceSystemCode = '150' THEN
                           'GQ'
                       ELSE
                           '!!'
                   END AS dloc2
            FROM warehouse.Location
            WHERE LocationType = 'Federal Wage System NAF'
        ) AS b
            ON LEFT(a.DutyLocationCode, 2) = b.dloc2
    WHERE a.PayPlanType IN ( 'NAF Blue Collar', 'NAF White Collar' )
          AND a.LocationId IS NULL; ---don't overwrite anything done above


    --UIC zip next
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId,
        LocationName = d.DisplayName,
        LocationType = d.LocationType
    FROM #DMDCRaw AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.UicZipCode = b.ZIPCode
        INNER JOIN xwalk.WageAreaToFips AS c
            ON b.FIPSCode = CONCAT(c.StateCode, c.CountyCode)
        INNER JOIN warehouse.Location AS d
            ON c.ScheduleArea = d.SourceSystemCode
    WHERE @AmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @AmcosVersionId = c.AmcosVersionId
          AND c.FundType = 'NAF'
          AND d.LocationType = 'Federal Wage System NAF'
          AND a.PayPlanType IN ( 'NAF Blue Collar', 'NAF White Collar' )
          AND a.LocationId IS NULL; -- don't overwrite anything above




    --at this point anything that remains is really an unknown from an automated data linking stand point
    --we could match on 4 digit uic but we shouldn't because that level of aggregation is only reliable when all of the unit's downtrace are in
    --the same area which is def not the case many times







    --what remains is unknown/overseas and is not yet handled by AMCOS yet so we'll just give it a label but no id
    UPDATE #DMDCRaw
    SET LocationName = 'Unknown/Overseas',
        LocationId = -1
    WHERE PayPlanType = 'AF White Collar'
          AND LocationId IS NULL;


    --so anything that doesn't have a LocationId gets a -1 and is unknown
    UPDATE #DMDCRaw
    SET LocationId = -1
    WHERE LocationId IS NULL;

    --any YOS that is not an integer gets an unknown
    UPDATE #DMDCRaw
    SET Step = 99
    WHERE Step = 'YO';


    --3/16/2021 we noticed that floating plants have fewer wage schedules as the broader wage pay plans so we need to resolve them to the closest wage schedule
    --we noticed this first at Norfolk VA where 140 schedule and payschedule is no longer but 340 is
    --in those cases we error back to assigning those people to a location in that wage area with another schedule which does have a valid and active payschedule

    --start by settign up a CTE for payschedule which we are going to use multiple times
    WITH payscheduleCTE
    AS (SELECT a.*,
               c.WageArea,
               c.ScheduleArea
        FROM data.PaySchedules AS a
            LEFT OUTER JOIN warehouse.Location AS b
                ON a.LocationId = b.LocationId
            LEFT OUTER JOIN lookup.WageArea AS c
                ON b.SourceSystemCode = c.ScheduleArea
        WHERE b.LocationType = 'Federal Wage System AF'
              AND c.FundType = 'AF'
              AND a.PayPlan IN ( 'XF', 'XG', 'XH' ))
    UPDATE #DMDCRaw
    SET LocationId = d.LocationId
    FROM #DMDCRaw AS a
        LEFT OUTER JOIN
        ( --we need wage schedule and area to do the compare so bring them in for our base table

            SELECT *
            FROM warehouse.Location AS a
                INNER JOIN lookup.WageArea AS b
                    ON b.ScheduleArea = a.SourceSystemCode
                       AND b.FundType = 'AF'
                       AND a.LocationType = 'Federal Wage System AF'
        ) AS b
            ON a.LocationId = b.LocationId
        --bring in location payschedules so we can later check if we are missing any
        LEFT OUTER JOIN payscheduleCTE AS c
            ON a.GradeLevel = c.GradeLevel
               AND a.AmcosVersionId = c.AmcosVersionId
               AND a.LocationId = c.LocationId
               AND a.PayPlan = c.PayPlan
               AND a.Step = c.Step
        --bring in other options for payschedule locations
        LEFT OUTER JOIN payscheduleCTE AS d
            --we want the same wage area but another applicable wage schedulearea using the last 2 digits 
            ON a.GradeLevel = d.GradeLevel
               AND a.AmcosVersionId = d.AmcosVersionId
               AND b.WageArea = d.WageArea
               AND b.ScheduleArea <> d.ScheduleArea
               AND RIGHT(b.ScheduleArea, 2) = RIGHT(d.ScheduleArea, 2)
               AND a.PayPlan = d.PayPlan
    WHERE a.PayPlan IN ( 'XF', 'XG', 'XH' )
          AND c.LocationId IS NULL --only do this for locations without a corresponding payschedule
          AND d.LocationId IS NOT NULL; --if we found a payplan in that wage area then we're going to use it






    SELECT 'these entries are missing a location which means they are unknown';
    SELECT *
    FROM #DMDCRaw AS a
        LEFT JOIN lookup.UICLocation AS b
            ON a.UIC = b.UIC
			AND b.EffectiveDate = (Select Max(EffectiveDate) From lookup.UICLocation uic WHERE uic.UIC = b.UIC)
    WHERE a.LocationId = -1
          AND a.PayPlanType <> 'Military'
    ORDER BY a.PayPlan,
             a.DutyStationZIPCode;


    IF @Debug = 1
    BEGIN
        SELECT 'these entries are missing a location which means they are unknown';
        SELECT *
        FROM #DMDCRaw AS a
            LEFT JOIN lookup.UICLocation AS b
                ON a.UIC = b.UIC
				AND b.EffectiveDate = (SELECT MAX(EffectiveDate) FROM lookup.UICLocation uic WHERE uic.UIC = b.UIC)
        WHERE a.LocationId = -1
              AND a.PayPlanType <> 'Military'
        ORDER BY a.PayPlan,
                 a.DutyStationZIPCode; --  payplan='WS' AND (zip='29207' OR zip='09263') ORDER BY zip
                                       --MIL, AE, 19, 19K, -1, 574, 8, E, 06, 202101).
    /* SELECT 'table for insert';
        SELECT *
        FROM #DMDCRaw
        WHERE PayPlan = 'AE'
              AND
              (
                  ValidCategorySubgroup = 'X'
                  OR CategorySubgroup = 'X'
                  OR ValidCategorySubgroup = 'x'
                  OR CategorySubgroup = 'x'
              )
        ORDER BY PayPlanType,
                 PayPlan,
                 myGROUP,
                 ValidCategorySubgroup;
				 */
    END;


    IF @Debug = 1
    BEGIN
	SELECT 'Count from all', Count(*)
        FROM (
		SELECT CivType,
               PayPlan,
               myGROUP,
               ValidCategorySubgroup,
               GradeType,
               GradeLevel,
               Step,
               LocationId,
               YOS,
               SUM(Inventory) as Inventory,
               AmcosVersionId
        FROM #DMDCRaw
        GROUP BY CivType,
                 PayPlan,
                 myGROUP,
                 ValidCategorySubgroup,
                 GradeType,
                 GradeLevel,
                 Step,
                 LocationId,
                 YOS,
                 AmcosVersionId
		) a 

		
        SELECT 'Count of Last Years RO', Count(*)
            FROM crunch.InventoryDMDC
            WHERE PayPlan = 'RO'
                  AND GradeLevel = 9
                  AND AmcosVersionId = @AmcosVersionId - 100;

        SELECT 'Count of RWO, NWO', COUNT(*)
        FROM (
		SELECT CivType,
               PayPlan,
               myGROUP,
               ValidCategorySubgroup,
               GradeType,
               GradeLevel,
               Step,
               LocationId,
               YOS,
               SUM(Inventory) AS Inventory,
               AmcosVersionId
        FROM #DMDCRaw
        GROUP BY CivType,
                 PayPlan,
                 myGROUP,
                 ValidCategorySubgroup,
                 GradeType,
                 GradeLevel,
                 Step,
                 LocationId,
                 YOS,
                 AmcosVersionId
		) a 
		WHERE PayPlan IN ('rwo','nwo')
        
    END;

    IF @Debug = 0
    BEGIN

        --#### Delete and Insert
        DELETE FROM crunch.InventoryDMDC
        WHERE AmcosVersionId = @AmcosVersionId;

        --sum up to the location and subgroup level
        INSERT INTO crunch.InventoryDMDC
        (
            CivType,
            PayPlan,
            CategoryGroup,
            CategorySubgroup,
            GradeType,
            GradeLevel,
            Step,
            LocationId,
            YOS,
            Inventory,
            AmcosVersionId
        )
        SELECT CivType,
               PayPlan,
               myGROUP,
               ValidCategorySubgroup,
               GradeType,
               GradeLevel,
               Step,
               LocationId,
               YOS,
               SUM(Inventory),
               AmcosVersionId
        FROM #DMDCRaw
        GROUP BY CivType,
                 PayPlan,
                 myGROUP,
                 ValidCategorySubgroup,
                 GradeType,
                 GradeLevel,
                 Step,
                 LocationId,
                 YOS,
                 AmcosVersionId;


        --we check to make sure we have the Chief of the Army Reserve (LTG), if not we add them from last year
        IF NOT EXISTS
        (
            SELECT *
            FROM crunch.InventoryDMDC
            WHERE PayPlan = 'RO'
                  AND GradeLevel = 9
                  AND AmcosVersionId = @AmcosVersionId
        )
        BEGIN
            INSERT INTO crunch.InventoryDMDC
            (
                CivType,
                PayPlan,
                CategoryGroup,
                CategorySubgroup,
                GradeType,
                GradeLevel,
                Step,
                LocationId,
                YOS,
                Inventory,
                AmcosVersionId
            )
            SELECT CivType,
                   PayPlan,
                   CategoryGroup,
                   CategorySubgroup,
                   GradeType,
                   GradeLevel,
                   Step,
                   LocationId,
                   YOS,
                   Inventory,
                   @AmcosVersionId
            FROM crunch.InventoryDMDC
            WHERE PayPlan = 'RO'
                  AND GradeLevel = 9
                  AND AmcosVersionId = @AmcosVersionId - 100;
        END;
    END;
END;