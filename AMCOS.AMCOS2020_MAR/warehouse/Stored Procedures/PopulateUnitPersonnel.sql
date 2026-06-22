
CREATE PROC [warehouse].[PopulateUnitPersonnel] @CrunchTime AS SMALLDATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    --get the latest versions of FMSWeb data
    DECLARE @SacsAsOf INT =
            (
                SELECT MAX(RUNID)FROM data.FmsWebSacsHeader
            );
    DECLARE @LockpointAsOf INT =
            (
                SELECT MAX(AmcosVersionId)FROM data.FmsWebLockpointTdochdr
            );

    DROP TABLE IF EXISTS #UnitPersonnel;
    SELECT *,
           '0000000' AS CategoryGroupCode,
           -2 AS LocationId,
           CONVERT(NVARCHAR(20), '-1') AS STRL,
           CONVERT(NVARCHAR(10), '-1') AS DependentStatus,
           -1 AS NumberOfDependents,
           CONVERT(NVARCHAR(5), '') AS ZipCode,
           CONVERT(NVARCHAR(100), '') AS LocationText,
           CONVERT(SMALLINT, '-1') AS ActiveDutyDays
    --,CONVERT(FLOAT, '-1') AS OverheadPercent
    INTO #UnitPersonnel
    FROM
    (
        SELECT UICOD AS UIC,
               Display,
               UnitType,
               SUM(Quantity) AS Quantity,
               PayPlan,
               GradeLevel,
               CONVERT(NVARCHAR(7), CategorySubgroupCode) AS CategorySubgroupCode,
               AmcosVersionId AS AsOf,
               'All' AS UnitYear,
               CONVERT(NVARCHAR(8), FORMAT(DEDTE, 'yyyyMMdd')) AS EDate
        FROM
        (
            SELECT a.DEDTE,
                   a.UICOD,
                   REPLACE(a.LNAME_TDH, '  ', '') + CASE
                                                        WHEN TRY_CONVERT(INT, (RIGHT(a.UICOD, 2)))
                                                             BETWEEN 91 AND 99 THEN
                                                            ' Aug TDA'
                                                        WHEN ISNUMERIC(RIGHT(LEFT(UICOD, 2), 1)) = 1 THEN
                                                            ' TDA'
                                                        ELSE
                                                            ' MTOE'
                                                    END AS Display,
                   CASE
                       WHEN TRY_CONVERT(INT, (RIGHT(a.UICOD, 2)))
                            BETWEEN 91 AND 99 THEN
                           'Aug TDA'
                       WHEN ISNUMERIC(RIGHT(LEFT(UICOD, 2), 1)) = 1 THEN
                           'TDA'
                       ELSE
                           'MTOE'
                   END AS UnitType,
                   'Lockpoint' AS DataSource,
                   a.AmcosVersionId,
                   TRY_CONVERT(INT, b.RQSTR) AS Quantity,
                   CASE
                       WHEN b.CIVCC IS NULL THEN --this is a MIL person
                           CASE
                               WHEN RIGHT(LEFT(b.AMSCO, 4), 1) = 'N'
                                    OR RIGHT(LEFT(b.AMSCO, 4), 1) = 'G' THEN
                                   'N' --national guard AMSCO
                               WHEN RIGHT(LEFT(b.AMSCO, 4), 1) = 'R' THEN
                                   'R' --reserve AMCSO
                               ELSE
                                   'A' --everything else is Active, because AMSCO is at the personel level (not uic) this should help with multi-compo UICs
                           END --done determining the beginning of the MIL pay plan
                               --continue with the latter part of the MIL pay plan 
                           + CASE
                                 --before we pull the latter part of the PP from the GL check if we have a general
                                 --and if so then just return O
                                 WHEN GRADE IN ( 'BG', 'MG', 'LG', 'GN' ) THEN
                                     'O'
                                 ELSE
                                     REPLACE(LEFT(b.GRADE, 1), 'W', 'WO') --this is a military person so we need to get their pay plan from the uic and grade type from grade, and convert a simple W to a WO if needed

                             END
                       WHEN b.CIVCC = 'ES' THEN
                           'SES' --DoD likes to use ES to refer to SES but AMCOS brands that SES which is what users are more familiar with seeing
                       WHEN b.CIVCC = 'CC' THEN
                           'CCE' --AMCOS equivalent of what FMSWeb calls contractors
                       WHEN b.CIVCC = 'OO' THEN --these are misc occupations but since FMSWeb calls them OO which is not a valid pay plan even OPM recognizes we just recode them wage which is what we see in other units for this Series
                           'WG'
                       ELSE --this is a CIV so just return their pay plan
                           b.CIVCC
                   END AS PayPlan,
                   CASE
                       WHEN b.CIVCC = 'ES' THEN
                           2                                /* For SES, use the average by default */
                       WHEN b.CIVCC IS NOT NULL THEN
                           CASE
                               WHEN TRY_CONVERT(INT, b.GRADE) IS NOT NULL THEN
                                   CONVERT(INT, b.GRADE)           --civilian 2 digit GL here so conversion lops off any leading 0s
                               WHEN TRY_CONVERT(INT, b.GRADE) IS NULL
                                    AND TRY_CONVERT(INT, LEFT(b.GRADE, 1)) IS NOT NULL THEN
                                   CONVERT(INT, LEFT(b.GRADE, 1))  --some of these CIVs have prefix CHARS, we dont' want those because AMCOS uses tinyint for GL, this may be a problem when we add IC PPs but for now we just deal with it
                               WHEN TRY_CONVERT(INT, b.GRADE) IS NULL
                                    AND TRY_CONVERT(INT, RIGHT(b.GRADE, 1)) IS NOT NULL THEN
                                   CONVERT(INT, RIGHT(b.GRADE, 1)) --some of these CIVs have suffix CHARS, see above for same explanation
                               ELSE
                                   NULL                            --in case we didn't catch any remaining cases
                           END
                       WHEN b.CIVCC IS NULL
                            AND b.GRADE = 'BG' THEN
                           7
                       WHEN b.CIVCC IS NULL
                            AND b.GRADE = 'MG' THEN
                           8
                       WHEN b.CIVCC IS NULL
                            AND b.GRADE = 'LG' THEN
                           9
                       WHEN b.CIVCC IS NULL
                            AND b.GRADE = 'GN' THEN
                           10
                       WHEN b.CIVCC IS NULL
                            AND b.GRADE IN ( 'EM', 'WM', 'OM' ) THEN
                           NULL                             --according to FMSWeb grade lookup table these don't exist and the help file doesn't tell us what they are or ack they even exists so we null it
                       ELSE
                           RIGHT(b.GRADE, LEN(b.GRADE) - 1) --assume all that remains are MIL so lop off the preceeding grade identifier as we only want the level
                   END AS GradeLevel,
                   CASE
                       WHEN b.CIVCC IS NOT NULL THEN
                           RIGHT(b.POSCO, 4) --civ so lop off preceeding 0
                       WHEN b.CIVCC IS NULL
                            AND LEFT(b.GRADE, 1) = 'W' THEN
                           LEFT(b.POSCO, 4)  --warrant so we need 4 places
                       ELSE
                           LEFT(b.POSCO, 3)  --enlisted or officer
                   END AS CategorySubgroupCode
            FROM data.FmsWebLockpointTdochdr AS a
                LEFT OUTER JOIN data.FmsWebLockpointTperdet AS b
                    ON a.DOCNO = b.DOCNO
                       AND a.CCNUM_CHGNR_FY = b.CCNUM_CHGNR_FY
                       AND a.AmcosVersionId = b.AmcosVersionId
                INNER JOIN
                (
                    --we only want the LATEST record for the unit and not anything prior so this join accomplishes that
                    SELECT DOCNO + MAX(CCNUM_CHGNR_FY) + UICOD AS mykey
                    FROM data.FmsWebLockpointTdochdr
                    GROUP BY DOCNO,
                             UICOD
                ) AS c
                    ON a.DOCNO + a.CCNUM_CHGNR_FY + a.UICOD = c.mykey
            WHERE a.AmcosVersionId = @LockpointAsOf
                  --do not allow other service branches in
                  --this is from a decision from the COR (Marsha Popp) on 8/2/2022
                  --codes come from FMSWeb search on their branch table for 'other'
                  --air force, coast guard, marines, navy
                  -- do not need this same filter on the MTOE because only Army servicemembers can go on an MTOE
                  AND
                  (
                      b.BRNCH NOT IN ( 'AF', 'CG', 'MN', 'NV' )
                      OR b.BRNCH IS NULL
                  )
        ) AS a
        WHERE GradeLevel IS NOT NULL
              AND PayPlan IS NOT NULL
              AND GradeLevel IS NOT NULL
              AND AmcosVersionId = @LockpointAsOf
              --this where SHOULD BE unnecessary as the table is only the TDA extract from FMSWeb but including it anyways just in case so we won't accidentily get MTOE units
              AND
              (
                  ISNUMERIC(RIGHT(LEFT(UICOD, 2), 1)) = 1 --only TDAs
                  OR TRY_CONVERT(INT, (RIGHT(UICOD, 2)))
              BETWEEN 91 AND 99 --only Aug TDAs
              )
              AND RIGHT(LEFT(UICOD, 2), 1) <> 'M' --Compo 6, prepositioned stock, doesn't have personnel so avoid those


        GROUP BY a.UICOD,
                 PayPlan,
                 GradeLevel,
                 a.CategorySubgroupCode,
                 a.AmcosVersionId,
                 Display,
                 UnitType,
                 DEDTE
        HAVING SUM(a.Quantity) > 0 --rows without personnel requirements are not valid
        UNION

        --SACS data next



        SELECT UIC,
               Display,
               UnitType,
               SUM(Quantity) AS Quantity,
               PayPlan,
               GradeLevel,
               CategorySubgroupCode,
               AsOf,
               UnitYear,
               EDATEI
        FROM
        (
            SELECT a.EDATEI,
                   a.RUNID AS AsOf,
                   CASE
                       WHEN LEFT(a.EDATEI, 4) = 2050 THEN
                           'OTOE'
                       --edatei is in caledar format YYYYMMDD but we want this in GFY format which means if a month falls Oct-Dec we need to add 1 to it
                       WHEN TRY_CONVERT(INT, RIGHT(LEFT(a.EDATEI, 6), 2)) >= 10 THEN
                           TRY_CONVERT(NVARCHAR(4), LEFT(a.EDATEI, 4) + 1)
                       ELSE
                           TRY_CONVERT(NVARCHAR(4), LEFT(a.EDATEI, 4))
                   END AS UnitYear,
                   CASE
                       WHEN TRY_CONVERT(INT, (RIGHT(a.UIC, 2)))
                            BETWEEN 91 AND 99 THEN
                           'Aug TDA'
                       WHEN ISNUMERIC(RIGHT(LEFT(a.UIC, 2), 1)) = 1 THEN
                           'TDA'
                       ELSE
                           'MTOE'
                   END AS UnitType,
                   b.UNTDS + ' (' + +a.UIC + ') - ' + b.SRC + ' MTOE' AS Display,
                   a.UIC,
                   CASE
                       WHEN COMPO = '2'
                            OR RIGHT(LEFT(a.AMSCO, 4), 1) = 'G' THEN
                           'N'
                       WHEN COMPO = '3'
                            OR RIGHT(LEFT(a.AMSCO, 4), 1) = 'R' THEN
                           'R'
                       ELSE
                           'A' --everything else is Active, because AMSCO is at the personel level (not uic) this should help with multi-compo UICs
                   END --done determining the beginning of the MIL pay plan
                       --continue with the latter part of the MIL pay plan 
                   + REPLACE(LEFT(a.GRADE, 1), 'W', 'WO') --this is a military person so we need to get their pay plan from the uic and grade type from grade, and convert a simple W to a WO if needed

                   AS PayPlan,
                   RIGHT(a.GRADE, LEN(a.GRADE) - 1) AS GradeLevel,
                   CASE
                       WHEN LEFT(a.GRADE, 1) = 'W' THEN
                           LEFT(a.MOS, 4) --warrant so we need 4 places
                       ELSE
                           LEFT(a.MOS, 3) --enlisted or officer
                   END AS CategorySubgroupCode,
                   a.RQSTR AS Quantity
            FROM data.FmsWebSacsPersonnel AS a
                INNER JOIN data.FmsWebSacsHeader AS b
                    ON b.EDATEI = a.EDATEI
                       AND b.RUNID = a.RUNID
                       AND b.UIC = a.UIC
            WHERE a.RUNID = @SacsAsOf
                  AND ISNUMERIC(RIGHT(LEFT(a.UIC, 2), 1)) = 0 --only MTOEs by excluding TDAs
                  AND ISNUMERIC(LEFT(RIGHT(a.UIC, 2), 1)) = 0 --only MTOEs by excluding Aug TDAs
                  AND RIGHT(LEFT(a.UIC, 2), 1) <> 'M' --Compo 6, prepositioned stock, doesn't have personnel so avoid those
                  AND a.RQSTR IS NOT NULL --must have personnel requirements
        ) AS a
        WHERE UnitType = 'MTOE'
        GROUP BY UIC,
                 PayPlan,
                 GradeLevel,
                 a.Display,
                 a.UnitYear,
                 a.UnitType,
                 a.CategorySubgroupCode,
                 AsOf,
                 a.EDATEI
    ) AS a;


    DECLARE @maxAmcosversion INT =
            (
                SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
            );

    --its actually possible for there to be 2 unit records in a given FY for some reason, we just want the latest so delete the others
    DELETE FROM #UnitPersonnel
    WHERE CONCAT(UIC, EDate, UnitYear) NOT IN
          (
              SELECT CONCAT(UIC, MAX(EDate), UnitYear)
              FROM #UnitPersonnel
              GROUP BY UIC,
                       UnitYear
          );

    --delete pay plans that AMCOS doesn't yet track
    --DELETE FROM #UnitPersonnel
    --WHERE PayPlan NOT IN
    --      (
    --          SELECT DISTINCT PayPlan FROM lookup.PayPlanTags
    --      );	

    --TDA CCE data comes in with OPM Series numbers which does us no good, use our custom xwalk to fix that
    UPDATE #UnitPersonnel
    SET CategorySubgroupCode = b.SOC
    FROM #UnitPersonnel AS a
        INNER JOIN xwalk.SeriestoSOC AS b
            ON a.CategorySubgroupCode = b.OccupationalSeriesNumber
    WHERE a.PayPlan = 'CCE'
          AND @maxAmcosversion
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    IF EXISTS
    (
        SELECT DISTINCT
               CategorySubgroupCode
        FROM #UnitPersonnel
        WHERE PayPlan = 'CCE'
              AND LEN(CategorySubgroupCode) < 7
    )
    BEGIN
        --so we failed at converting some CCE Series to SOC which is not allowed, prompt the script runner for action
        SELECT 'the following Series are missing a current entry in xwalk.Seriestosoc';
        SELECT DISTINCT
               a.CategorySubgroupCode,
               b.SeriesTitle
        FROM #UnitPersonnel AS a
            LEFT OUTER JOIN lookup.GS_OccupationalSeries AS b
                ON a.CategorySubgroupCode = b.OccupationalSeriesNumber
        WHERE a.PayPlan = 'CCE'
              AND LEN(a.CategorySubgroupCode) < 7
              AND
              (
                  @maxAmcosversion
              BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
                  OR b.AmcosVersionIdStart IS NULL
              );
        RAISERROR('missing SOC to Series entry see results for more details', 18, 1);
    END;



    --well now we've created a problem in that we could have duplicate CCE rows that need to be consolidated so let's do that
    DROP TABLE IF EXISTS #UnitPersonnelCCE;
    SELECT UIC,
           Display,
           UnitType,
           SUM(Quantity) AS Quantity,
           PayPlan,
           GradeLevel,
           CategorySubgroupCode,
           AsOf,
           UnitYear,
           EDate,
           CategoryGroupCode,
           LocationId,
           STRL,
           DependentStatus,
           NumberOfDependents,
           ZipCode,
           LocationText,
           ActiveDutyDays
    --,OverheadPercent
    INTO #UnitPersonnelCCE
    FROM #UnitPersonnel
    WHERE PayPlan = 'CCE'
    GROUP BY UIC,
             Display,
             UnitType,
             PayPlan,
             GradeLevel,
             CategorySubgroupCode,
             AsOf,
             UnitYear,
             EDate,
             CategoryGroupCode,
             LocationId,
             STRL,
             DependentStatus,
             NumberOfDependents,
             ZipCode,
             LocationText,
             ActiveDutyDays;
    --,             OverheadPercent;

    DELETE FROM #UnitPersonnel
    WHERE PayPlan = 'CCE';
    INSERT INTO #UnitPersonnel
    (
        UIC,
        Display,
        UnitType,
        Quantity,
        PayPlan,
        GradeLevel,
        CategorySubgroupCode,
        AsOf,
        UnitYear,
        EDate,
        CategoryGroupCode,
        LocationId,
        STRL,
        DependentStatus,
        NumberOfDependents,
        ZipCode,
        LocationText,
        ActiveDutyDays
    --,        OverheadPercent
    )
    SELECT UIC,
           Display,
           UnitType,
           Quantity,
           PayPlan,
           GradeLevel,
           CategorySubgroupCode,
           AsOf,
           UnitYear,
           EDate,
           CategoryGroupCode,
           LocationId,
           STRL,
           DependentStatus,
           NumberOfDependents,
           ZipCode,
           LocationText,
           ActiveDutyDays
    -- ,           OverheadPercent
    FROM #UnitPersonnelCCE;

    --now set all our CCE grade levels to 3 which represents the 50th percentile since that's our chosen default salary mark
    UPDATE #UnitPersonnel
    SET GradeLevel = 3
    WHERE PayPlan = 'CCE';

    --set the category group code based on the category subgroup code
    UPDATE #UnitPersonnel
    SET CategoryGroupCode = CASE
                                WHEN PayPlan IN ( 'AO', 'RO', 'NO', 'NE', 'AE', 'RE', 'AWO', 'NWO', 'RWO' ) THEN
                                    LEFT(CategorySubgroupCode, 2)
                                WHEN PayPlan = 'CCE' THEN
                                    LEFT(CategorySubgroupCode, 2) + '-0000'
                                ELSE
                                    LEFT(CategorySubgroupCode, 2) + '00'
                            END;


    --bring in the location information
    UPDATE #UnitPersonnel
    SET ZipCode = LEFT(b.ZIP, 5)
    FROM #UnitPersonnel AS a
        LEFT OUTER JOIN lookup.UICLocation AS b
            ON a.UIC = b.UIC
    --use the latest available data to do the zip lookup
    WHERE EffectiveDate = (Select Max(EffectiveDate) from lookup.UICLocation c where a.UIC = c.UIC)
    

    --some units we don't have have the zip for BUT every unit has an ARLOC code
    --so we are going to assume that a unit at one ARLOC should have the same zip as a unit at the same ARLOC that doesn't have a zip
    --the above assumption isn't actually always the case so we use the below to join on the zip that is most prevalent for any given ARLOC
    DROP TABLE IF EXISTS #tempCTE;
    SELECT *
    INTO #tempCTE
    FROM
    (
        SELECT DISTINCT
               a.UIC,
               b.ZIP,
               COUNT(b.ZIP) OVER (PARTITION BY a.UIC, b.ZIP) AS matchcount
        FROM lookup.UICLocation AS a
            INNER JOIN lookup.UICLocation AS b
                ON a.ARLOC = b.ARLOC
        WHERE (
                  a.ZIP IS NULL
                  OR a.ZIP = ''
              ) --records with missing zips
              AND b.ARLOC <> ''
              AND b.ZIP <> '' --but don't join on records missing our key field
              AND a.EffectiveDate = (Select Max(c.EffectiveDate) from lookup.UICLocation c where a.UIC = c.UIC)
              AND b.EffectiveDate = (Select Max(c.EffectiveDate) from lookup.UICLocation c where b.UIC = c.UIC)
    ) AS a;


    UPDATE #UnitPersonnel
    SET ZipCode = LEFT(b.ZIP, 5)
    FROM #UnitPersonnel AS a
        INNER JOIN
        (
            SELECT a.*
            FROM #tempCTE AS a
                INNER JOIN
                (
                    SELECT UIC,
                           MAX(matchcount) AS matchcount
                    FROM #tempCTE
                    GROUP BY UIC --ORDER BY uic
                ) AS b
                    ON b.matchcount = a.matchcount
                       AND b.UIC = a.UIC
        ) AS b
            ON a.UIC = b.UIC;

    --now bring in military location data for the zips
    UPDATE #UnitPersonnel
    SET LocationId = c.LocationId,
        LocationText = c.DisplayName
    FROM #UnitPersonnel AS a
        LEFT OUTER JOIN xwalk.ZIPToMHA AS b
            ON b.ZIPCode = a.ZipCode
        LEFT OUTER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = b.MHA
    WHERE @maxAmcosversion = b.AmcosVersionId
          AND c.LocationType LIKE '%Military Housing Area'
          --AMCOS doesn't currently cost NG/R positions by location so we ignore them
          AND a.PayPlan NOT IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'NG_R'
              )
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
              )
          AND a.LocationId = -2; --only those locations we haven't already set

    --now bring in NAF wage location data for the zips
    UPDATE #UnitPersonnel
    SET LocationId = d.LocationId,
        LocationText = d.DisplayName
    FROM #UnitPersonnel AS a
        LEFT OUTER JOIN lookup.FIPS_ZIP AS b
            ON b.ZIPCode = a.ZipCode
        LEFT OUTER JOIN xwalk.WageAreaToFips AS c
            ON b.FIPSCode = CONCAT(c.StateCode,c.CountyCode)
        LEFT OUTER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.ScheduleArea
    WHERE @maxAmcosversion
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @maxAmcosversion = c.AmcosVersionId
          AND c.FundType = 'NAF'
          AND d.LocationType = 'Federal Wage System NAF'
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF'
              )
          AND a.LocationId = -2; --don't overwrite anything already done above where we assigned a location

    --now bring in AF wage location data for the zips
    UPDATE #UnitPersonnel
    SET LocationId = d.LocationId,
        LocationText = d.DisplayName
    FROM #UnitPersonnel AS a
        LEFT OUTER JOIN lookup.FIPS_ZIP AS b
            ON b.ZIPCode = a.ZipCode
        LEFT OUTER JOIN xwalk.WageAreaToFips AS c
            ON b.FIPSCode = CONCAT(c.StateCode,c.CountyCode)
        LEFT OUTER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.ScheduleArea
    WHERE @maxAmcosversion
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @maxAmcosversion = c.AmcosVersionId
          AND c.FundType = 'AF'
          AND d.LocationType = 'Federal Wage System AF'
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF'
              )
          AND a.LocationId = -2; --don't overwrite anything already done above where we assigned a location



    --all the above is for CONUS which doesn't have a number of dependents so we don't touch those, leaving them at the default

    --map to CIV overseas locations
    UPDATE #UnitPersonnel
    SET LocationId = c.LocationId,
        LocationText = c.DisplayName,
        NumberOfDependents = 0
    FROM #UnitPersonnel AS a
        INNER JOIN xwalk.ZiptoDoS AS b
            ON a.ZipCode = b.ZIPCode
        INNER JOIN warehouse.Location AS c
            ON b.DOSLocation = c.SourceSystemCode
    WHERE @maxAmcosversion
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND c.LocationType = 'Civilian Overseas'
          AND a.LocationId = -2 --don't overwrite anything already done above where we assigned a location
          AND a.PayPlan NOT IN
              --overseas civilian locations are for all pay plans that are not either
              --1) military OR 2) contractor
              (
                  SELECT DISTINCT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
              )
          AND a.PayPlan <> 'CCE';

    --now bring in matches for all other pay plans which we assume will be locality area based unless otherwise indicated
    UPDATE #UnitPersonnel
    SET LocationId = e.LocationId,
        LocationText = e.DisplayName
    FROM #UnitPersonnel AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON b.ZIPCode = a.ZipCode
        INNER JOIN xwalk.LocalityPayAreaToFips AS c
            ON b.FIPSCode = c.StateCode + c.CountyCode
        INNER JOIN PaySchedule.LocalityPay AS d
            ON c.LocalityCode = d.LocalityCode
        INNER JOIN warehouse.Location AS e
            ON e.SourceSystemCode = d.LocalityCode
    WHERE @maxAmcosversion
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @maxAmcosversion = c.AmcosVersionId
          AND @maxAmcosversion = d.AmcosVersionId
          AND e.LocationType = 'Locality Pay Area'
          AND a.PayPlan IN --only apply to pay plans which use OPM localities
              (
                  SELECT PayPlan
                  FROM lookup.PayPlanTags
                  WHERE Tag IN ( 'Civilian', 'Lab Demo', 'Acq Demo' )
                        AND PayPlan NOT IN ( 'CCE', 'SES' )
              )
          AND a.LocationId = -2; --don't overwrite anything already done above where we assigned a location

    --for all remaining valid ZIP codes that are not FPO/APO/DPO we make them RUS for CIV plans
    DECLARE @LocationId INT =
            (
                SELECT TOP (1)
                       LocationId
                FROM warehouse.Location
                WHERE SourceSystemCode = 'RUS'
                      AND LocationType = 'Locality Pay Area'
                ORDER BY LocationId
            );
    DECLARE @LocationText NVARCHAR(100) =
            (
                SELECT TOP (1)
                       DisplayName
                FROM warehouse.Location
                WHERE SourceSystemCode = 'RUS'
                      AND LocationType = 'Locality Pay Area'
                ORDER BY DisplayName
            );

    UPDATE #UnitPersonnel
    SET LocationId = @LocationId,
        LocationText = @LocationText
    FROM #UnitPersonnel AS a
    WHERE ZipCode IN
          (
              SELECT ZIPCode
              FROM lookup.FIPS_ZIP
              WHERE City NOT IN ( 'APO', 'FPO', 'DPO' )
                    AND @maxAmcosversion
                    BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                    AND FIPSCode NOT IN
                        (
                            --if the fips linked to the zip is a valid locality area then leave the record alone
                            SELECT StateCode + CountyCode
                            FROM xwalk.LocalityPayAreaToFips
                            WHERE @maxAmcosversion
                            BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                        )
                    AND LocationId = -2 --doesn't touch any records we've already resolved
                    AND PayPlan IN
                        --only apply to pay plans which use OPM localities
                        (
                            SELECT PayPlan
                            FROM lookup.PayPlanTags
                            WHERE Tag IN ( 'Civilian', 'Lab Demo', 'Acq Demo' )
                                  AND PayPlan NOT IN ( 'CCE', 'SES' )
                        )
          );

    --resolve CCE locations
    UPDATE #UnitPersonnel
    SET LocationId = b.LocationId,
        LocationText = b.DisplayName
    FROM #UnitPersonnel AS a
        INNER JOIN
        (
            SELECT c.LocationId,
                   b.ZIPCode,
                   c.DisplayName
            FROM xwalk.MetropolitanStatisticalAreaToFips AS a
                INNER JOIN lookup.FIPS_ZIP AS b
                    ON b.FIPSCode = CONCAT(a.StateCode, a.CountyCode)
                INNER JOIN warehouse.Location AS c
                    ON c.SourceSystemCode = a.MSACode
            WHERE @maxAmcosversion = a.AmcosVersionId
                  AND @maxAmcosversion
                  BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        ) AS b
            ON b.ZIPCode = a.ZipCode
    WHERE a.PayPlan = 'CCE';



    --notify that we have a bunch of records that are unresolved in their location which we're going to assign to worldwide average
    --1/19/2022 it was envisioned that we would resolve these manually or in a new automated way at some point in the future
    --but the time was not available to do this initiallty
    SELECT 'PM Unit Addition: these records are an unknown location and will be assigned PP avg (-1)';
    SELECT DISTINCT
           UIC,
           Display,
           UnitType
    FROM #UnitPersonnel
    WHERE LocationId = -2
    ORDER BY UIC;

    UPDATE #UnitPersonnel
    SET LocationId = -1,
        LocationText = 'All'
    WHERE LocationId = -2;


    --for military now with location we assume the average number of dependents
    UPDATE #UnitPersonnel
    SET DependentStatus = 'average'
    WHERE PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military'
          )
          AND LocationId > -1;

    --for D Series plans we need to now assign the proper STRL for that UIC
    UPDATE #UnitPersonnel
    SET STRL = b.STRL
    FROM #UnitPersonnel AS a
        INNER JOIN xwalk.UICToSTRL AS b
            ON LEFT(b.UIC, 4) = LEFT(a.UIC, 4)
    WHERE @maxAmcosversion
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND a.LocationId > -1
          AND a.PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Lab Demo'
              );

    --if we have any lab demo now that don't have an strl that is a serious problem as no costs exist
    --for strl=-1 so we need to kill the entire SP and prompt the DBA for immediate action
    IF EXISTS
    (
        SELECT *
        FROM #UnitPersonnel
        WHERE PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Lab Demo'
              )
              AND STRL = '-1'
    )
    BEGIN
        SELECT 'find the right STRL for these UICs and add their left 4 to xwalk.uictostrl';
        SELECT *
        FROM #UnitPersonnel
        WHERE PayPlan IN
              (
                  SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Lab Demo'
              )
              AND STRL = '-1';
        RAISERROR('check the shown UICs as we are missing an entry for them in xwalk.uictostrl', 18, 1);
    END;


    --no CCE at this time so we skip doing anything to that column and thus use the default
    --OverheadPercent

    --active duty days need to be set to 15 for Reserve forces
    UPDATE #UnitPersonnel
    SET ActiveDutyDays = 15
    WHERE PayPlan IN
          (
              SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'NG_R'
          );

    SELECT 'list of locations that still do not have a valid location';
    SELECT DISTINCT
           UIC,
           Display,
           ZipCode
    FROM #UnitPersonnel
    WHERE LocationId = -2
    ORDER BY ZipCode;

    --*****************  INSERT AREA **************
    --clear out the table so we can do a fresh insert
    TRUNCATE TABLE warehouse.UnitPersonnel;

    INSERT INTO warehouse.UnitPersonnel
    (
        UIC,
        UICTitle,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        LocationId,
        LocationText,
        STRL,
        GradeLevel,
        DependentStatus,
        NumberOfDependents,
        ActiveDutyDays,
        --OverheadPercent,
        Inventory,
        UnitYear,
        AsOf,
        AuthorizationDocument
    )
    SELECT UIC,
           Display,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           LocationId,
           LocationText,
           STRL,
           GradeLevel,
           DependentStatus,
           NumberOfDependents,
           ActiveDutyDays,
           --OverheadPercent,
           Quantity,
           UnitYear,
           AsOf,
           UnitType
    FROM #UnitPersonnel;

    SELECT 'the follow records, if any, we do not have costs for - check and take any necessary action';
    SELECT DISTINCT
           CategorySubgroupCode
    FROM warehouse.UnitPersonnel
    WHERE CategorySubgroupCode NOT IN
          (
              SELECT DISTINCT
                     CategorySubgroupCode
              FROM data.Costs
              WHERE AmcosVersionId = @maxAmcosversion
          )
    ORDER BY CategorySubgroupCode;

--exec warehouse.populateunitpersonnel
/*
	SELECT * FROM data.FmsWebSacsHeader WHERE uic IS NULL
    SELECT * FROM data.FmsWebSacsPersonnel WHERE uic IS NULL
    SELECT * FROM data.FmsWebLockpointTdochdr WHERE UICOD IS NULL
    SELECT * FROM data.FmsWebLockpointTperdet WHERE   IS null
	SELECT *
	FROM data.FmsWebLockpointTdochdr AS a LEFT OUTER JOIN data.fmsweblockpointtperdet AS b ON
a.DOCNO=b.DOCNO AND a.CCNUM_CHGNR_FY=b.CCNUM_CHGNR_FY AND a.AsOf=b.AsOf
WHERE a.UICOD IS NULL

SELECT * FROM    data.FmsWebSacsPersonnel AS a INNER JOIN data.FmsWebSacsHeader AS b ON
 b.EDATEI = a.EDATEI AND b.RUNID = a.RUNID AND b.UIC = a.UIC
 WHERE b.UIC ='WACAAA'
 */

END;