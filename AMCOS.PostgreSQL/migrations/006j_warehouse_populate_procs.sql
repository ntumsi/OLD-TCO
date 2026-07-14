-- Cost-crunch PHASE 4 — warehouse populate procedures (warehouse.*).
--
-- After a crunch run these rebuild the category / location / unit-personnel /
-- pay-plan-crosswalk tables that drive the app's dropdowns and Project Manager:
-- warehouse.UpdateLocationId, PopulateCategory, PopulateLocationByCategory,
-- PopulateUnitPersonnel, PopulatePPXwalk. CREATE PROCEDURE, LANGUAGE plpgsql
-- (CALLed by crunch.CrunchAll in 006k). Runs after 006i. Conventions: 006d header.

------------------------------------------------------------------------------
-- warehouse.UpdateLocationId  ->  warehouse.updatelocationid
--
-- Faithful port of AMCOS.AMCOS2020_MAR/warehouse/Stored Procedures/
-- UpdateLocationId.sql. Builds the canonical set of location records from every
-- pay-geography source (MHA, OCONUS MHA, Nonforeign, Locality, GS Special Rate,
-- Civilian Overseas, GFEBS country, Federal Wage System AF/NAF (+ overseas),
-- MSA, and ZIP city/county) into a temp table, then (1) inserts the rows not yet
-- present in warehouse.location and (2) refreshes DisplayName + Coordinates to
-- the latest nomenclature.
--
-- Port notes:
--   * @Debug INT (source default 1) -> p_debug boolean DEFAULT false. Source only
--     writes under "IF @Debug = 0"; here writes are guarded by "IF NOT p_debug".
--     The "IF @Debug = 1" result-set dump block is dropped (no runtime effect).
--   * #MyLocations -> CREATE TEMP TABLE mylocations (dropped first + at proc end).
--   * PostGIS: source builds Coordinates with geography::STPointFromText(
--       'POINT(lon lat)', 4326). Translated to
--       ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography. Geometry
--       is never populated by the source, so it is left NULL throughout.
--   * The final "UPDATE warehouse.Location .. FROM warehouse.Location a INNER JOIN
--     #MyLocations b" re-aliases the UPDATE target in FROM (forbidden in PG); it
--     is rewritten as UPDATE warehouse.location l SET .. FROM mylocations b WHERE
--     l.sourcesystemcode = b.locationcode AND l.locationtype = b.locationtype AND
--     (<changed-name predicate>).
--   * Non-effecting ORDER BY clauses on INSERT..SELECT into the temp bag are dropped.
--   * Case-sensitive schemas quoted: "PaySchedule", "load_GFEBS".
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE warehouse.updatelocationid(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    -- SRID should be the same across all geo instances in the DB; default value
    v_srid integer := 4326;
BEGIN
    DROP TABLE IF EXISTS mylocations;
    CREATE TEMP TABLE mylocations (
        locationcode varchar(100) NOT NULL,
        locationname varchar(250) NOT NULL,
        locationtype varchar(100) NOT NULL,
        geometry     geometry,
        coordinates  geography
    );

    -- Military Housing Area
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           mha AS locationcode,
           description AS locationname,
           location || ' Military Housing Area' AS locationtype
    FROM lookup.militaryhousingarea
    WHERE mha IS NOT NULL
      AND amcosversionid = p_amcosversionid;

    -- ##### Military Overseas missing from MHA #####
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           a.loccode,
           a.locname || ', ' || a.country_code,
           'OCONUS Military Housing Area'
    FROM dataload.militaryoverseashousingallowance AS a
        INNER JOIN (
            -- only the latest nomenclature name matters
            SELECT loccode,
                   MAX(amcosversionid) AS amcosversionidmax
            FROM dataload.militaryoverseashousingallowance
            GROUP BY loccode
        ) AS b
            ON a.amcosversionid = b.amcosversionidmax
               AND a.loccode = b.loccode
    WHERE a.loccode IS NOT NULL
      AND a.loccode NOT IN (SELECT DISTINCT locationcode FROM mylocations);

    -- Nonforeign Areas (Alaska, Hawaii, Guam, CNMI, Puerto Rico, USVI)
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT a.nonforeignareacode AS locationcode,
           b.nonforeignareaname AS locationname,
           'Nonforeign Area' AS locationtype
    FROM "PaySchedule".nonforeignareacostoflivingallowances AS a
        INNER JOIN lookup.nonforeignarea AS b
            ON b.nonforeignareacode = a.nonforeignareacode
               AND b.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid;

    -- Locality Pay Area
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT a.localitycode AS locationcode,
           b.localitypayarea AS locationname,
           'Locality Pay Area' AS locationtype
    FROM "PaySchedule".localitypay a
        INNER JOIN lookup.localitypayarea b
            ON b.amcosversionid = a.amcosversionid
               AND b.localitycode = a.localitycode
    WHERE a.amcosversionid = p_amcosversionid;

    -- General Schedule (GS) Special Rates
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           a.locationname || ', ' || a.state AS locationcode,
           a.locationname || ', ' || a.state AS locationname,
           'OPM Special Pay Locations' AS locationtype
    FROM xwalk.specialratetablesbylocation AS a
        INNER JOIN (
            -- only the latest nomenclature name matters
            SELECT locationname || ', ' || state AS loc,
                   MAX(amcosversionid) AS amcosversionidmax
            FROM xwalk.specialratetablesbylocation
            GROUP BY locationname || ', ' || state
        ) AS b
            ON a.amcosversionid = b.amcosversionidmax
               AND a.locationname || ', ' || a.state = b.loc
    WHERE -- Puerto Rico has no state, so keep those records (state <> 'X' omitted)
          a.statecode <> 'X'
      AND a.countycode <> 'X'
      AND a.citycode <> 'X';

    -- Civilian Overseas Areas
    INSERT INTO mylocations (locationcode, locationname, locationtype, coordinates)
    SELECT a.locationcode,
           a.location || ', ' || a.country,
           'Civilian Overseas',
           ST_SetSRID(ST_MakePoint(a.longitude, a.latitude), v_srid)::geography AS coordinates
    FROM lookup.doslocations AS a
        INNER JOIN (
            -- only the latest nomenclature name matters
            SELECT locationcode,
                   MAX(amcosversionidend) AS amcosversionidmax
            FROM lookup.doslocations
            GROUP BY locationcode
        ) AS b
            ON a.amcosversionidend = b.amcosversionidmax
               AND a.locationcode = b.locationcode
    GROUP BY a.locationcode,
             a.location,
             a.country,
             a.latitude,
             a.longitude;

    -- GFEBS Countries
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           a.country AS locationcode,
           a.country AS locationname,
           'GFEBS Country' AS locationtype
    FROM "load_GFEBS".cleaned AS a
        INNER JOIN (
            -- only the latest nomenclature name matters
            SELECT country,
                   MAX(amcosversionid) AS amcosversionid
            FROM "load_GFEBS".cleaned
            GROUP BY country
        ) AS b
            ON a.amcosversionid = b.amcosversionid
               AND a.country = b.country;

    -- Federal Wage System; Appropriated Fund
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           schedulearea AS locationcode,
           areaname AS locationname,
           'Federal Wage System AF' AS locationtype
    FROM lookup.wagearea
    WHERE schedulearea NOT IN ('900', '901', '902', '903', '904', '905')
      AND fundtype = 'AF';

    -- Federal Wage System; Appropriated Fund Overseas
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT schedulearea AS locationcode,
           areaname AS locationname,
           'Federal Wage System AF Overseas' AS locationtype
    FROM lookup.wagearea
    WHERE schedulearea IN ('900', '901', '902', '903', '904', '905')
      AND fundtype = 'AF';

    -- Federal Wage System; Nonappropriated Fund
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           schedulearea AS locationcode,
           areaname AS locationname,
           'Federal Wage System NAF' AS locationtype
    FROM lookup.wagearea
    WHERE schedulearea <> '170'
      AND fundtype = 'NAF';

    -- Federal Wage System; Nonappropriated Fund Overseas
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT DISTINCT
           schedulearea AS locationcode,
           areaname AS locationname,
           'Federal Wage System NAF Overseas' AS locationtype
    FROM lookup.wagearea
    WHERE schedulearea = '170'
      AND fundtype = 'NAF';

    -- Metropolitan and Nonmetropolitan area
    INSERT INTO mylocations (locationcode, locationname, locationtype)
    SELECT a.msacode AS locationcode,
           a.msaname AS locationname,
           'MSA' AS locationtype
    FROM lookup.metropolitanstatisticalarea a
        JOIN (
            SELECT msacode,
                   MAX(amcosversionid) AS amcosversionid
            FROM lookup.metropolitanstatisticalarea
            GROUP BY msacode
        ) b
            ON a.msacode = b.msacode
               AND a.amcosversionid = b.amcosversionid;

    -- City/Counties
    INSERT INTO mylocations (locationcode, locationname, locationtype, coordinates)
    SELECT zipcode AS locationcode,
           city || ', ' || state AS locationname,
           'Zip' AS locationtype,
           ST_SetSRID(ST_MakePoint(longitude, latitude), v_srid)::geography AS coordinates
    FROM lookup.fips_zip
    WHERE amcosversionidend IN (SELECT MAX(amcosversionidend) FROM lookup.fips_zip)
      AND city NOT IN ('APO', 'DPO', 'FPO', 'Parcel Return Service')  -- no admin/overseas; overseas handled by Dep of State
      AND latitude <> 0
      AND longitude <> 0  -- places without a known lat/long are not allowed
    GROUP BY zipcode,
             city,
             state,
             longitude,
             latitude;

    IF NOT p_debug THEN
        -- insert values that weren't already present in the table
        INSERT INTO warehouse.location (sourcesystemcode, locationtype)
        SELECT a.locationcode,
               a.locationtype
        FROM mylocations AS a
            LEFT OUTER JOIN warehouse.location AS b
                ON a.locationcode = b.sourcesystemcode
                   AND a.locationtype = b.locationtype
        WHERE b.locationid IS NULL;

        -- update all nomenclatures to the latest
        -- (source re-aliased the UPDATE target in FROM; rewritten as a direct
        --  UPDATE..FROM mylocations with the change predicate in WHERE)
        UPDATE warehouse.location AS l
        SET displayname = b.locationname,
            coordinates = b.coordinates
        FROM mylocations AS b
        WHERE l.sourcesystemcode = b.locationcode
          AND l.locationtype = b.locationtype
          AND (l.displayname <> b.locationname
               OR (l.displayname IS NULL AND b.locationname IS NOT NULL));
    END IF;

    DROP TABLE IF EXISTS mylocations;
END;
$$;

------------------------------------------------------------------------------
-- warehouse.PopulateCategory  ->  warehouse.populatecategory
--
-- Rebuilds the warehouse.category dimension for one AMCOS version. Seeds
-- pay-plan / category-group / subgroup / career-program rows from data.costs
-- (military + civilian), decorates them from data.categorysubgroup and
-- lookup.armycareerprogram, then appends the CCE (contractor / SOC-based)
-- rows from "BLS_OES".occupationalemploymentstatisticsmetro + lookup.socstructure
-- and decorates their major-group titles.
--
-- Faithful structural port of the T-SQL proc. Notes:
--   * Source params kept: @AmcosVersionId -> p_amcosversionid. @CrunchTime is
--     kept as p_crunchtime for signature parity but is DEAD in the source
--     (assigned, never read) so it stays unused here too. No @Debug in source,
--     so there is NO dry-run branch -- every TRUNCATE/INSERT/UPDATE runs.
--   * The three "UPDATE warehouse.Category ... FROM <lookup> INNER JOIN
--     warehouse.Category" statements re-alias the UPDATE target inside FROM,
--     which PG forbids. Rewritten to "UPDATE warehouse.category c SET .. FROM
--     <lookup> WHERE <join>" (target aliased as c, self-reference dropped).
--     The decorated columns all start NULL from the INSERT, so the T-SQL
--     inner-join semantics carry over unchanged.
--   * Case-sensitive schema: "BLS_OES". Lowercase schemas data/lookup/warehouse
--     as-is. All table/column identifiers lowercased.
--   * T-SQL string "+" -> "||" (NULL-propagating in both dialects, so display
--     columns stay NULL when an operand is NULL -- behavior preserved).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE warehouse.populatecategory(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- p_crunchtime is intentionally unreferenced (dead assignment in source).

    TRUNCATE TABLE warehouse.category;

    -- military + civilian seed rows: either a pure career-program row
    -- (group/subgroup = '-1') or a pure group/subgroup row (career program = '-1')
    INSERT INTO warehouse.category
    (
        payplan,
        categorygroupcode,
        categorygroupdescription,
        categorygroupdisplay,
        categorysubgroupcode,
        categorysubgroupdescription,
        categorysubgroupdisplay,
        careerprogramnumber,
        careerprogramdescription,
        careerprogramdisplay
    )
    SELECT payplan,
           categorygroupcode,
           NULL AS categorygroupdescription,
           NULL AS categorygroupdisplay,
           categorysubgroupcode,
           NULL AS categorysubgroupdescription,
           NULL AS categorysubgroupdisplay,
           careerprogramnumber,
           NULL AS careerprogramdescription,
           NULL AS careerprogramdisplay
    FROM data.costs
    WHERE amcosversionid = p_amcosversionid
          AND
          (
              (
                  categorygroupcode = '-1'
                  AND categorysubgroupcode = '-1'
                  AND careerprogramnumber <> '-1'
              )
              OR
              (
                  categorygroupcode <> '-1'
                  AND categorysubgroupcode <> '-1'
                  AND careerprogramnumber = '-1'
              )
          )
    GROUP BY payplan,
             categorygroupcode,
             categorysubgroupcode,
             careerprogramnumber;

    -- decorate group/subgroup descriptions + display strings
    UPDATE warehouse.category c
    SET categorygroupdescription = cs.categorygroupdescription,
        categorygroupdisplay = cs.categorygroupcode || ' - ' || cs.categorygroupdescription,
        categorysubgroupdescription = cs.categorysubgroupdescription,
        categorysubgroupdisplay = cs.categorysubgroupcode || ' - ' || cs.categorysubgroupdescription
    FROM data.categorysubgroup cs
    WHERE c.payplan = cs.payplan
      AND c.categorygroupcode = cs.categorygroupcode
      AND c.categorysubgroupcode = cs.categorysubgroupcode;

    -- decorate career-program descriptions + display strings
    UPDATE warehouse.category c
    SET careerprogramdescription = acp.title,
        careerprogramdisplay = 'CP ' || acp.careerprogramnumber || ' - ' || acp.title
    FROM lookup.armycareerprogram acp
    WHERE c.careerprogramnumber = acp.careerprogramnumber
      AND p_amcosversionid BETWEEN acp.amcosversionidstart AND acp.amcosversionidend;

    -- CCE (contractor) rows: one per detailed SOC occupation, group = SOC major
    INSERT INTO warehouse.category
    (
        payplan,
        categorygroupcode,
        categorygroupdescription,
        categorygroupdisplay,
        categorysubgroupcode,
        categorysubgroupdescription,
        categorysubgroupdisplay,
        careerprogramnumber,
        careerprogramdescription,
        careerprogramdisplay
    )
    SELECT 'CCE' AS payplan,
           substring(oes.soc, 1, 2) || '-0000' AS categorygroupcode,
           NULL AS categorygroupdescription,
           NULL AS categorygroupdisplay,
           oes.soc AS categorysubgroupcode,
           ltrim(soc.occupationtitle) AS categorysubgroupdescription,
           oes.soc || ' - ' || ltrim(soc.occupationtitle) AS categorysubgroupdisplay,
           '-1' AS careerprogramnumber,
           NULL AS careerprogramdescription,
           NULL AS careerprogramdisplay
    FROM "BLS_OES".occupationalemploymentstatisticsmetro oes
        INNER JOIN lookup.socstructure soc
            ON soc.occupationcode = oes.soc
    WHERE soc.grouplevel = 'Detailed'
          AND p_amcosversionid
          BETWEEN soc.amcosversionidstart AND soc.amcosversionidend
          AND oes.amcosversionid = p_amcosversionid
    GROUP BY oes.soc,
             soc.occupationtitle;

    -- decorate the CCE major-group titles (only rows still missing them)
    UPDATE warehouse.category c
    SET categorygroupdescription = soc.occupationtitle,
        categorygroupdisplay = c.categorygroupcode || ' - ' || soc.occupationtitle
    FROM lookup.socstructure soc
    WHERE c.categorygroupcode = soc.occupationcode
      AND c.payplan = 'CCE'
      AND soc.grouplevel = 'Major'
      AND c.categorygroupdescription IS NULL
      AND c.categorygroupdisplay IS NULL;

END;
$$;

------------------------------------------------------------------------------
-- warehouse.PopulateLocationByCategory  ->  warehouse.populatelocationbycategory
--
-- Faithful port of AMCOS.AMCOS2020_MAR/warehouse/Stored Procedures/
-- PopulateLocationByCategory.sql. Rebuilds warehouse.locationbycategory: for the
-- given AMCOS version it TRUNCATEs the table and re-populates one INSERT per
-- location "flavor" (military installation, MHA, STRL, civ locality/RUS, special
-- pay area, civ overseas, GFEBS country, wage AF/NAF schedule + city/county, NF
-- pay plan, CCE by installation/MSA) then normalizes CCE category codes and adds
-- location-agnostic (locationid = -1) rows.
--
-- Port notes:
--   * No @Debug in the source -> no dry-run guard; the proc always writes.
--   * @CrunchTime is declared and set in the source but never referenced by any
--     statement; kept as p_crunchtime for signature parity, otherwise unused.
--   * Schemas are case-sensitive: "PaySchedule", "BLS_OES" are quoted; data,
--     warehouse, lookup, xwalk are lowercase. Table/column names lowercased.
--   * T-SQL string "+" -> "||" (NULL-propagating in both dialects, so the source's
--     "c.DisplayBase IS NOT NULL"-style guards are preserved verbatim).
--   * #MilitaryInstallations -> TEMP TABLE militaryinstallations (dropped first
--     and at proc end).
--   * id is IDENTITY on the destination: never inserted, always defaulted.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE warehouse.populatelocationbycategory(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    TRUNCATE TABLE warehouse.locationbycategory;

    DROP TABLE IF EXISTS militaryinstallations;
    CREATE TEMP TABLE militaryinstallations
    (
        displaybase varchar(500),
        zipcode     varchar(5)
    );

    INSERT INTO militaryinstallations (displaybase, zipcode)
    SELECT UPPER(   CASE
                        WHEN basename = 'OTHER LOCATIONS' THEN
                            RTRIM(stationname)
                        WHEN basecode = staco
                             OR basename = installationname THEN
                            RTRIM(basename)
                        ELSE
                            RTRIM(basename) || ' (' || RTRIM(installationname) || ')'
                    END || ' [' || service || '] (' || state || ') '
                ) AS installation,
           left(zipcode, 5)
    FROM lookup.militaryinstallation
    WHERE p_amcosversionid
          BETWEEN amcosversionidstart AND amcosversionidend;

    /* Military Installation */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        installation
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           -1, --careerprogramnumber doesn't apply to military
           b.locationid,
           c.displaybase || '- ' || b.sourcesystemcode
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.zipcode,
                   a.mha,
                   b.displaybase
            FROM xwalk.ziptomha AS a
                INNER JOIN militaryinstallations AS b
                    ON a.zipcode = b.zipcode
            WHERE p_amcosversionid = a.amcosversionid
        ) AS c
            ON b.sourcesystemcode = c.mha
        LEFT OUTER JOIN lookup.militaryhousingarea AS d
            ON d.mha = b.sourcesystemcode
    WHERE a.amcosversionid = p_amcosversionid
          AND p_amcosversionid = d.amcosversionid
          AND c.displaybase IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             b.locationid,
             c.displaybase,
             b.sourcesystemcode,
             b.locationtype,
             d.displayname;

    /* Military Housing Area */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        oconusmha,
        conusmha
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           -1, --careerprogramnumber doesn't apply to military
           b.locationid,
           CASE
               WHEN b.locationtype = 'OCONUS Military Housing Area' THEN
                   d.displayname || ' - ' || b.sourcesystemcode
               ELSE
                   NULL
           END,
           CASE
               WHEN b.locationtype = 'CONUS Military Housing Area' THEN
                   d.displayname || ' - ' || b.sourcesystemcode
               ELSE
                   NULL
           END
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.zipcode,
                   a.mha,
                   b.displaybase
            FROM xwalk.ziptomha AS a
                INNER JOIN militaryinstallations AS b
                    ON a.zipcode = b.zipcode
            WHERE p_amcosversionid = a.amcosversionid
        ) AS c
            ON b.sourcesystemcode = c.mha
        LEFT OUTER JOIN lookup.militaryhousingarea AS d
            ON d.mha = b.sourcesystemcode
    WHERE a.amcosversionid = p_amcosversionid
          AND p_amcosversionid = d.amcosversionid
          AND b.locationtype IN ( 'OCONUS Military Housing Area', 'CONUS Military Housing Area' )
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             b.locationid,
             c.displaybase,
             b.sourcesystemcode,
             b.locationtype,
             d.displayname;

    --/*  STRL */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        strl
    )
    SELECT DISTINCT
           payplan,
           categorygroupcode,
           categorysubgroupcode,
           careerprogramnumber,
           locationid,
           a.strl --|| ' - ' || b.strlname
    FROM data.costs AS a
    --INNER JOIN
    --(SELECT DISTINCT  strl,strlname FROM xwalk.uictostrl) AS b
    --ON a.strl=b.strl
    WHERE payplan LIKE 'D%'
          AND a.amcosversionid = p_amcosversionid;

    /* All CIV  Military Installations non-Rest of US*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        installation
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           b.locationid,
           c.displaybase || ' - ' || c.localitycode
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.localitycode,
                   b.displaybase
            FROM lookup.fips_zip AS a
                INNER JOIN militaryinstallations AS b
                    ON a.zipcode = b.zipcode
                INNER JOIN xwalk.localitypayareatofips AS c
                    ON a.fipscode = c.statecode || c.countycode
                INNER JOIN "PaySchedule".localitypay AS d
                    ON c.localitycode = d.localitycode
            WHERE p_amcosversionid
                  BETWEEN a.amcosversionidstart AND a.amcosversionidend
                  AND p_amcosversionid = c.amcosversionid
                  AND p_amcosversionid = d.amcosversionid
        ) AS c
            ON b.sourcesystemcode = c.localitycode
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype = 'Locality Pay Area'
          AND c.displaybase IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             b.locationid,
             c.displaybase,
             c.localitycode;

    /* All CIV  Military Installations Rest of US*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        installation
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.displaybase || ' - RUS'
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        CROSS JOIN
        (
            SELECT *
            FROM militaryinstallations
            WHERE zipcode NOT IN
                  (
                      SELECT a.zipcode
                      FROM lookup.fips_zip AS a
                          INNER JOIN xwalk.localitypayareatofips AS b
                              ON a.fipscode = b.statecode || b.countycode
                      WHERE p_amcosversionid
                            BETWEEN a.amcosversionidstart AND a.amcosversionidend
                            AND p_amcosversionid = b.amcosversionid
                  )
        ) AS c
    WHERE b.sourcesystemcode = 'RUS'
          AND b.locationtype = 'Locality Pay Area'
          AND a.amcosversionid = p_amcosversionid;

    --/* CIV Locality */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        localitypayarea
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           b.locationid,
           c.localitypayarea || ' (' || c.localitycode || ')'
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.localitycode,
                   --b.displaybase,
                   e.localitypayarea
            FROM lookup.fips_zip AS a
                -- INNER JOIN militaryinstallations AS b
                --     ON a.zipcode = b.zipcode
                INNER JOIN xwalk.localitypayareatofips c
                    ON a.fipscode = c.statecode || c.countycode
                INNER JOIN "PaySchedule".localitypay d
                    ON d.localitycode = c.localitycode
                       AND d.amcosversionid = c.amcosversionid
                INNER JOIN lookup.localitypayarea e
                    ON e.localitycode = c.localitycode
                       AND e.amcosversionid = c.amcosversionid
            WHERE p_amcosversionid
                  BETWEEN a.amcosversionidstart AND a.amcosversionidend
                  AND p_amcosversionid = c.amcosversionid
        ) AS c
            ON b.sourcesystemcode = c.localitycode
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype = 'Locality Pay Area'
          AND c.localitypayarea IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             b.locationid,
             --displaybase,
             c.localitycode,
             c.localitypayarea;

    /* All CIV   Localities Rest of US*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        localitypayarea
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           b.displayname || ' (' || b.sourcesystemcode || ')'
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
    WHERE b.sourcesystemcode = 'RUS'
          AND b.locationtype = 'Locality Pay Area'
          AND a.amcosversionid = p_amcosversionid;

    --/* CIV Special Areas */
    /* they DO NOT link to a military installation, that could create a one to many relationship
    with an installation linking to a locality area AND a special pay area
    instead we call out special area for users so they can deliberately select those
    separate from a locality area */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        specialpayarea
    )
    SELECT a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           b.locationid,
           b.displayname
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
    WHERE b.locationtype = 'OPM Special Pay Locations'
          AND a.amcosversionid = p_amcosversionid
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             b.locationid,
             b.displayname;

    --/* Civilian Overseas */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        civoverseas
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           b.locationid,
           b.displayname
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype = 'Civilian Overseas'
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             b.locationid,
             b.displayname;

    /* Civilian Countries (GFEBS) */
    /* they DO NOT link to a military installation at this time */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        country
    )
    SELECT a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           b.locationid,
           b.displayname
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
    WHERE b.locationtype = 'GFEBS Country'
          AND a.amcosversionid = p_amcosversionid
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             b.locationid,
             b.displayname;

    /* Federal Wage System AF - Schedule Area by Installation*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        installation
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.displaybase || ' - ' || c.schedulearea
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.displaybase,
                   d.schedulearea,
                   d.areaname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.fips_zip AS b
                    ON a.statecode || a.countycode = b.fipscode
                INNER JOIN militaryinstallations AS c
                    ON b.zipcode = c.zipcode
                INNER JOIN lookup.wagearea AS d
                    ON d.schedulearea = a.schedulearea
                       AND a.fundtype = d.fundtype
            WHERE p_amcosversionid = a.amcosversionid
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
                  AND a.fundtype = 'AF'
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System AF' )
          AND payplan IN
              (
                  SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage AF'
              )
          AND c.displaybase IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.displaybase,
             c.schedulearea,
             c.areaname;

    /* Federal Wage System NAF - Schedule Area by Installation*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        installation
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.displaybase || ' - ' || c.schedulearea
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.displaybase,
                   d.schedulearea,
                   d.areaname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.fips_zip AS b
                    ON a.statecode || a.countycode = b.fipscode
                INNER JOIN militaryinstallations AS c
                    ON b.zipcode = c.zipcode
                INNER JOIN lookup.wagearea AS d
                    ON d.schedulearea = a.schedulearea
                       AND a.fundtype = d.fundtype
            WHERE p_amcosversionid = a.amcosversionid
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
                  AND a.fundtype = 'NAF'
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System NAF' )
          AND payplan IN
              (
                  SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage NAF'
              )
          AND a.payplan <> 'NF' --handled separately
          AND c.displaybase IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.displaybase,
             c.schedulearea,
             c.areaname;

    /* Federal Wage System AF - Schedule Area */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        wageschedule
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.areaname || ' - ' || c.schedulearea
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.schedulearea,
                   d.areaname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.wagearea AS d
                    ON d.schedulearea = a.schedulearea
                       AND a.fundtype = d.fundtype
            WHERE a.amcosversionid = p_amcosversionid
                  AND a.fundtype = 'AF'
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System AF' )
          AND payplan IN
              (
                  SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage AF'
              )
          AND c.schedulearea IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.schedulearea,
             c.areaname;

    /* Federal Wage System NAF - Schedule Area */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        wageschedule
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.areaname || ' - ' || c.schedulearea
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.schedulearea,
                   d.areaname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.wagearea AS d
                    ON d.schedulearea = a.schedulearea
                       AND a.fundtype = d.fundtype
            WHERE a.amcosversionid = p_amcosversionid
                  AND a.fundtype = 'NAF'
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System NAF' )
          AND c.schedulearea IS NOT NULL
          AND payplan IN
              (
                  SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage NAF'
              )
          AND a.payplan <> 'NF' --handled separately
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.schedulearea,
             c.areaname;

    --/* Federal Wage System AF - County, state */
    /* Users may not know what areas a wage schedule encompass we make it a little easier for them by
    providing a county/state selection, but we don't need to tie that to a installation since those were
    already handled above */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        citycounty
    )
    SELECT a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.citycountyname
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.schedulearea,
                   --if the county doesn't exist because its null or blank then we need the city instead
                   CASE
                       WHEN b.county IN ( '', NULL ) THEN
                           b.city
                       ELSE
                           b.county
                   END || ', ' || b.state AS citycountyname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.fips_zip AS b
                    ON a.statecode || a.countycode = b.fipscode
            WHERE a.fundtype = 'AF'
                  AND a.amcosversionid = p_amcosversionid
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System AF' )
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.citycountyname;

    --/* Federal Wage System NAF - County, state */
    -- because users may not know what areas a wage schedule encompass we make it a little easier for them by
    --providing a county/state selection, but we don't need to tie that to a installation since those were
    --already handled above
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        citycounty
    )
    SELECT a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.citycountyname
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.schedulearea,
                   --if the county doesn't exist because its null or blank then we need the city instead
                   CASE
                       WHEN b.county IN ( '', NULL ) THEN
                           b.city
                       ELSE
                           b.county
                   END || ', ' || b.state AS citycountyname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.fips_zip AS b
                    ON a.statecode || a.countycode = b.fipscode
            WHERE a.fundtype = 'NAF'
                  AND a.amcosversionid = p_amcosversionid
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System NAF' )
          AND a.payplan <> 'NF' --handled later
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.citycountyname;

    /* NF Pay Plan */
    /* Unlike all the other wage plans, NF is more general in that area are defined at the wage AREA level, not the wage SCHEDULE level
    so all those joins above on wage schedule need to be done at the wage area level for NF thus the separate processing steps here */

    --/* NF Pay Plan - Schedule Area by Installation*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        installation
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.displaybase || ' - ' || c.schedulearea
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.displaybase,
                   d.schedulearea,
                   d.areaname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.fips_zip AS b
                    ON a.statecode || a.countycode = b.fipscode
                INNER JOIN militaryinstallations AS c
                    ON b.zipcode = c.zipcode
                INNER JOIN lookup.wagearea AS d
                    ON d.wagearea = a.wagearea --here is the difference in NF, join on the overarching wage area
                       AND a.fundtype = d.fundtype
            WHERE p_amcosversionid = a.amcosversionid
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
                  AND a.fundtype = 'NAF'
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System NAF' )
          AND a.payplan = 'NF'
          AND c.displaybase IS NOT NULL
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.displaybase,
             c.schedulearea,
             c.areaname;

    --/* NF Pay Plan - Schedule Area */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        wageschedule
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.areaname || ' - ' || c.schedulearea
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   d.schedulearea,
                   d.areaname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.wagearea AS d
                    ON d.wagearea = a.wagearea --here is the difference in NF, join on the overarching wage area
                       AND a.fundtype = d.fundtype
            WHERE a.amcosversionid = p_amcosversionid
                  AND a.fundtype = 'NAF'
        ) AS c
            ON b.sourcesystemcode = c.schedulearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System NAF' )
          AND c.schedulearea IS NOT NULL
          AND a.payplan = 'NF'
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.schedulearea,
             c.areaname;

    --/* Federal Wage System NAF - County, state */
    -- because users may not know what areas a wage schedule encompass we make it a little easier for them by
    --providing a county/state selection, but we don't need to tie that to a installation since those were
    --already handled above
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid,
        citycounty
    )
    SELECT DISTINCT
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.careerprogramnumber,
           a.locationid,
           c.citycountyname
    FROM data.costs AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.locationid = b.locationid
        LEFT OUTER JOIN lookup.wagearea AS z
            ON b.sourcesystemcode = z.schedulearea
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   a.wagearea,
                   --if the county doesn't exist because its null or blank then we need the city instead
                   CASE
                       WHEN b.county IN ( '', NULL ) THEN
                           b.city
                       ELSE
                           b.county
                   END || ', ' || b.state AS citycountyname
            FROM xwalk.wageareatofips AS a
                INNER JOIN lookup.fips_zip AS b
                    ON a.statecode || a.countycode = b.fipscode
            WHERE a.fundtype = 'NAF'
                  AND a.amcosversionid = p_amcosversionid
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
        ) AS c
            ON z.wagearea = c.wagearea
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype IN ( 'Federal Wage System NAF' )
          AND a.payplan = 'NF'
          AND z.fundtype = 'NAF'
    GROUP BY a.payplan,
             a.categorygroupcode,
             a.categorysubgroupcode,
             a.careerprogramnumber,
             a.locationid,
             c.citycountyname;

    /* CCE Locations by Installation */
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        installation,
        locationid
    )
    SELECT DISTINCT
           'CCE',
           a.soc,
           a.soc,
           -1,
           c.displaybase,
           b.locationid
    FROM "BLS_OES".occupationalemploymentstatisticsmetro AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.msacode = b.sourcesystemcode
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                   c.displaybase,
                   m.msaname,
                   a.msacode
            FROM xwalk.metropolitanstatisticalareatofips AS a
                INNER JOIN lookup.metropolitanstatisticalarea m
                    ON m.msacode = a.msacode
                       AND m.amcosversionid = a.amcosversionid
                LEFT OUTER JOIN lookup.fips_zip AS b
                    ON concat(a.statecode, a.countycode) = b.fipscode
                LEFT OUTER JOIN militaryinstallations AS c
                    ON b.zipcode = c.zipcode
            WHERE p_amcosversionid
                  BETWEEN a.amcosversionidstart AND a.amcosversionidend
                  AND p_amcosversionid
                  BETWEEN b.amcosversionidstart AND b.amcosversionidend
        ) AS c
            ON a.msacode = c.msacode
    WHERE c.displaybase IS NOT NULL
          AND p_amcosversionid = a.amcosversionid
          AND b.locationtype = 'MSA'
    GROUP BY a.soc,
             c.displaybase,
             c.msaname,
             b.locationid;

    --/* CCE Locations by MSA*/
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        msa,
        locationid
    )
    SELECT DISTINCT
           'CCE',
           a.soc,
           a.soc,
           -1,
           b.displayname,
           b.locationid
    FROM "BLS_OES".occupationalemploymentstatisticsmetro AS a
        LEFT OUTER JOIN warehouse.location AS b
            ON a.msacode = b.sourcesystemcode
    WHERE a.amcosversionid = p_amcosversionid
          AND b.locationtype = 'MSA'
    GROUP BY a.soc,
             b.displayname,
             b.locationid;

    UPDATE warehouse.locationbycategory
    SET categorygroupcode = substring(categorygroupcode, 1, 2) || '-0000'
    WHERE payplan = 'CCE'
          AND substring(categorygroupcode, 3, 5) <> '-0000';

    UPDATE warehouse.locationbycategory
    SET categorysubgroupcode = '-1'
    WHERE payplan = 'CCE'
          AND substring(categorysubgroupcode, 3, 5) = '-0000';

    --/* Location non-specific values */
    -- we need to make sure location agnostic values are inserted as options
    INSERT INTO warehouse.locationbycategory
    (
        payplan,
        categorygroupcode,
        categorysubgroupcode,
        careerprogramnumber,
        locationid
    )
    SELECT payplan,
           categorygroupcode,
           categorysubgroupcode,
           careerprogramnumber,
           locationid
    FROM data.costs
    WHERE locationid = -1
          AND amcosversionid = p_amcosversionid
    GROUP BY payplan,
             categorygroupcode,
             categorysubgroupcode,
             careerprogramnumber,
             locationid;

    DROP TABLE IF EXISTS militaryinstallations;
END;
$$;

-- =============================================================================
-- warehouse.PopulateUnitPersonnel  ->  warehouse.populateunitpersonnel
--
-- Faithful port of AMCOS.AMCOS2020_MAR/warehouse/Stored Procedures/
-- PopulateUnitPersonnel.sql. Rebuilds warehouse.unitpersonnel from the two
-- FMSWeb personnel extracts (Lockpoint TDA/Aug-TDA + SACS MTOE), derives pay
-- plan / grade level / subgroup, resolves each UIC's ZIP -> location, then
-- truncates and reloads warehouse.unitpersonnel.
--
-- Conventions (per 006d header / PORT_CONVENTIONS):
--   * Source signature has ONLY @CrunchTime (no @AmcosVersionId, no @Debug), so
--     the target keeps just p_crunchtime; there is no dry-run guard and no
--     crunch.validateamcosversion() call (nothing to validate). All version
--     selection is internal (MAX() over the source tables / lookup.amcosversion),
--     exactly as the source.
--   * #temp -> CREATE TEMP TABLE (unitpers / unitperscce / tempcte), each dropped
--     up front and again at proc end.
--   * "UPDATE #t .. FROM #t a JOIN other b" -> "UPDATE t .. FROM other b WHERE .."
--     (PG forbids re-aliasing the UPDATE target in FROM).
--   * ISNULL->COALESCE, GETDATE()/CONVERT(SMALLDATETIME,..)->now()::timestamp,
--     LEN->length, LEFT/RIGHT->left/right, ISNUMERIC(x)=1 -> x ~ '^[0-9]+$'
--     (matching the 006i convention), TRY_CONVERT(INT,x) -> regex-guarded ::int
--     (NULL on non-numeric), string + -> || / concat(), FORMAT(dt,'yyyyMMdd')
--     -> to_char(dt,'YYYYMMDD'), RAISERROR(sev 18) -> RAISE EXCEPTION.
--   * Interactive result-set dump SELECTs (no runtime effect in a procedure) are
--     dropped; the RAISERROR abort blocks are preserved as RAISE EXCEPTION.
--   * Schema case: data / lookup / xwalk / warehouse are lowercase; "PaySchedule"
--     is quoted.
-- =============================================================================
CREATE OR REPLACE PROCEDURE warehouse.populateunitpersonnel(
    p_crunchtime timestamp DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    -- source computes @CrunchTime but never references it downstream (AsOf comes
    -- from the version id); kept for faithfulness.
    v_crunchtime      timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_sacsasof        integer;
    v_lockpointasof   integer;
    v_maxamcosversion integer;
    v_locationid      integer;
    v_locationtext    varchar(100);
BEGIN
    -- latest versions of the FMSWeb extracts
    v_sacsasof      := (SELECT MAX(runid) FROM data.fmswebsacsheader);
    v_lockpointasof := (SELECT MAX(amcosversionid) FROM data.fmsweblockpointtdochdr);

    -----------------------------------------------------------------------------
    -- build the working set
    -----------------------------------------------------------------------------
    DROP TABLE IF EXISTS unitpers;
    CREATE TEMP TABLE unitpers (
        uic                  varchar(6),
        display              varchar(150),
        unittype             varchar(10),
        quantity             integer,
        payplan              varchar(3),
        gradelevel           integer,
        categorysubgroupcode varchar(7),
        asof                 integer,
        unityear             varchar(4),
        edate                varchar(8),
        categorygroupcode    varchar(10),
        locationid           integer,
        strl                 varchar(20),
        dependentstatus      varchar(25),
        numberofdependents   integer,
        zipcode              varchar(5),
        locationtext         varchar(150),
        activedutydays       smallint
    );

    INSERT INTO unitpers
        (uic, display, unittype, quantity, payplan, gradelevel, categorysubgroupcode,
         asof, unityear, edate, categorygroupcode, locationid, strl, dependentstatus,
         numberofdependents, zipcode, locationtext, activedutydays)
    SELECT u.uic, u.display, u.unittype, u.quantity::int, u.payplan, u.gradelevel,
           u.categorysubgroupcode, u.asof, u.unityear, u.edate,
           '0000000', -2, '-1', '-1', -1, '', '', -1
    FROM (
        --------------------------------------------------------------- Lockpoint
        SELECT
            src.uicod                          AS uic,
            src.display                        AS display,
            src.unittype                       AS unittype,
            SUM(src.quantity)                  AS quantity,
            src.payplan                        AS payplan,
            src.gradelevel                     AS gradelevel,
            src.categorysubgroupcode           AS categorysubgroupcode,
            src.amcosversionid                 AS asof,
            'All'::varchar                     AS unityear,
            to_char(src.dedte, 'YYYYMMDD')     AS edate
        FROM (
            SELECT
                h.dedte,
                h.uicod,
                h.amcosversionid,
                replace(h.lname_tdh, '  ', '') || CASE
                        WHEN (CASE WHEN right(h.uicod, 2) ~ '^[0-9]+$' THEN right(h.uicod, 2)::int END) BETWEEN 91 AND 99 THEN ' Aug TDA'
                        WHEN substring(h.uicod FROM 2 FOR 1) ~ '^[0-9]+$' THEN ' TDA'
                        ELSE ' MTOE'
                    END AS display,
                CASE
                    WHEN (CASE WHEN right(h.uicod, 2) ~ '^[0-9]+$' THEN right(h.uicod, 2)::int END) BETWEEN 91 AND 99 THEN 'Aug TDA'
                    WHEN substring(h.uicod FROM 2 FOR 1) ~ '^[0-9]+$' THEN 'TDA'
                    ELSE 'MTOE'
                END AS unittype,
                (CASE WHEN d.rqstr ~ '^[0-9]+$' THEN d.rqstr::int END) AS quantity,
                CASE
                    WHEN d.civcc IS NULL THEN
                        (CASE
                             WHEN right(left(d.amsco, 4), 1) IN ('N', 'G') THEN 'N'
                             WHEN right(left(d.amsco, 4), 1) = 'R' THEN 'R'
                             ELSE 'A'
                         END)
                        ||
                        (CASE
                             WHEN d.grade IN ('BG', 'MG', 'LG', 'GN') THEN 'O'
                             ELSE replace(left(d.grade, 1), 'W', 'WO')
                         END)
                    WHEN d.civcc = 'ES' THEN 'SES'
                    WHEN d.civcc = 'CC' THEN 'CCE'
                    WHEN d.civcc = 'OO' THEN 'WG'
                    ELSE d.civcc
                END AS payplan,
                CASE
                    WHEN d.civcc = 'ES' THEN 2
                    WHEN d.civcc IS NOT NULL THEN
                        (CASE
                             WHEN d.grade ~ '^[0-9]+$' THEN d.grade::int
                             WHEN d.grade !~ '^[0-9]+$' AND left(d.grade, 1) ~ '^[0-9]+$' THEN left(d.grade, 1)::int
                             WHEN d.grade !~ '^[0-9]+$' AND right(d.grade, 1) ~ '^[0-9]+$' THEN right(d.grade, 1)::int
                             ELSE NULL
                         END)
                    WHEN d.civcc IS NULL AND d.grade = 'BG' THEN 7
                    WHEN d.civcc IS NULL AND d.grade = 'MG' THEN 8
                    WHEN d.civcc IS NULL AND d.grade = 'LG' THEN 9
                    WHEN d.civcc IS NULL AND d.grade = 'GN' THEN 10
                    WHEN d.civcc IS NULL AND d.grade IN ('EM', 'WM', 'OM') THEN NULL
                    ELSE right(d.grade, length(d.grade) - 1)::int
                END AS gradelevel,
                CASE
                    WHEN d.civcc IS NOT NULL THEN right(d.posco, 4)
                    WHEN d.civcc IS NULL AND left(d.grade, 1) = 'W' THEN left(d.posco, 4)
                    ELSE left(d.posco, 3)
                END AS categorysubgroupcode
            FROM data.fmsweblockpointtdochdr h
                LEFT OUTER JOIN data.fmsweblockpointtperdet d
                    ON h.docno = d.docno
                   AND h.ccnum_chgnr_fy = d.ccnum_chgnr_fy
                   AND h.amcosversionid = d.amcosversionid
                INNER JOIN (
                    -- only the LATEST record per doc/unit
                    SELECT docno || MAX(ccnum_chgnr_fy) || uicod AS mykey
                    FROM data.fmsweblockpointtdochdr
                    GROUP BY docno, uicod
                ) c ON h.docno || h.ccnum_chgnr_fy || h.uicod = c.mykey
            WHERE h.amcosversionid = v_lockpointasof
              AND (d.brnch NOT IN ('AF', 'CG', 'MN', 'NV') OR d.brnch IS NULL)
        ) src
        WHERE src.gradelevel IS NOT NULL
          AND src.payplan IS NOT NULL
          AND src.amcosversionid = v_lockpointasof
          AND (substring(src.uicod FROM 2 FOR 1) ~ '^[0-9]+$'
               OR (CASE WHEN right(src.uicod, 2) ~ '^[0-9]+$' THEN right(src.uicod, 2)::int END) BETWEEN 91 AND 99)
          AND substring(src.uicod FROM 2 FOR 1) <> 'M'
        GROUP BY src.uicod, src.payplan, src.gradelevel, src.categorysubgroupcode,
                 src.amcosversionid, src.display, src.unittype, src.dedte
        HAVING SUM(src.quantity) > 0

        UNION

        -------------------------------------------------------------------- SACS
        SELECT
            src2.uic                 AS uic,
            src2.display             AS display,
            src2.unittype            AS unittype,
            SUM(src2.quantity)       AS quantity,
            src2.payplan             AS payplan,
            src2.gradelevel          AS gradelevel,
            src2.categorysubgroupcode AS categorysubgroupcode,
            src2.asof                AS asof,
            src2.unityear            AS unityear,
            src2.edatei::varchar     AS edate
        FROM (
            SELECT
                p.edatei,
                p.runid AS asof,
                CASE
                    WHEN left(p.edatei::text, 4) = '2050' THEN 'OTOE'
                    WHEN (CASE WHEN right(left(p.edatei::text, 6), 2) ~ '^[0-9]+$'
                               THEN right(left(p.edatei::text, 6), 2)::int END) >= 10
                        THEN (left(p.edatei::text, 4)::int + 1)::varchar
                    ELSE left(p.edatei::text, 4)
                END AS unityear,
                CASE
                    WHEN (CASE WHEN right(p.uic, 2) ~ '^[0-9]+$' THEN right(p.uic, 2)::int END) BETWEEN 91 AND 99 THEN 'Aug TDA'
                    WHEN substring(p.uic FROM 2 FOR 1) ~ '^[0-9]+$' THEN 'TDA'
                    ELSE 'MTOE'
                END AS unittype,
                hd.untds || ' (' || p.uic || ') - ' || hd.src || ' MTOE' AS display,
                p.uic,
                (CASE
                     WHEN hd.compo = '2' OR right(left(p.amsco, 4), 1) = 'G' THEN 'N'
                     WHEN hd.compo = '3' OR right(left(p.amsco, 4), 1) = 'R' THEN 'R'
                     ELSE 'A'
                 END) || replace(left(p.grade, 1), 'W', 'WO') AS payplan,
                right(p.grade, length(p.grade) - 1)::int AS gradelevel,
                CASE WHEN left(p.grade, 1) = 'W' THEN left(p.mos, 4) ELSE left(p.mos, 3) END AS categorysubgroupcode,
                p.rqstr AS quantity
            FROM data.fmswebsacspersonnel p
                INNER JOIN data.fmswebsacsheader hd
                    ON hd.edatei = p.edatei
                   AND hd.runid = p.runid
                   AND hd.uic = p.uic
            WHERE p.runid = v_sacsasof
              AND NOT (substring(p.uic FROM 2 FOR 1) ~ '^[0-9]+$')  -- only MTOEs (exclude TDA)
              AND NOT (substring(p.uic FROM 5 FOR 1) ~ '^[0-9]+$')  -- only MTOEs (exclude Aug TDA)
              AND substring(p.uic FROM 2 FOR 1) <> 'M'
              AND p.rqstr IS NOT NULL
        ) src2
        WHERE src2.unittype = 'MTOE'
        GROUP BY src2.uic, src2.payplan, src2.gradelevel, src2.display, src2.unityear,
                 src2.unittype, src2.categorysubgroupcode, src2.asof, src2.edatei
    ) u;

    v_maxamcosversion := (SELECT MAX(amcosversionid) FROM lookup.amcosversion);

    -- keep only the latest FY record per UIC/UnitYear
    DELETE FROM unitpers
    WHERE concat(uic, edate, unityear) NOT IN (
        SELECT concat(uic, MAX(edate), unityear)
        FROM unitpers
        GROUP BY uic, unityear
    );

    -- TDA CCE comes in with OPM Series numbers; xwalk them to SOC.
    -- Inner-join update on the current csc value (not a self-join).
    UPDATE unitpers t
    SET categorysubgroupcode = b.soc
    FROM xwalk.seriestosoc b
    WHERE t.categorysubgroupcode = b.occupationalseriesnumber
      AND t.payplan = 'CCE'
      AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- any CCE Series that failed to map to a 7-char SOC is a hard stop
    IF EXISTS (
        SELECT 1 FROM unitpers
        WHERE payplan = 'CCE' AND length(categorysubgroupcode) < 7
    ) THEN
        RAISE EXCEPTION 'missing SOC to Series entry see results for more details';
    END IF;

    -- SOC remap can create duplicate CCE rows; consolidate them
    DROP TABLE IF EXISTS unitperscce;
    CREATE TEMP TABLE unitperscce AS
    SELECT uic, display, unittype, SUM(quantity) AS quantity, payplan, gradelevel,
           categorysubgroupcode, asof, unityear, edate, categorygroupcode, locationid,
           strl, dependentstatus, numberofdependents, zipcode, locationtext, activedutydays
    FROM unitpers
    WHERE payplan = 'CCE'
    GROUP BY uic, display, unittype, payplan, gradelevel, categorysubgroupcode, asof,
             unityear, edate, categorygroupcode, locationid, strl, dependentstatus,
             numberofdependents, zipcode, locationtext, activedutydays;

    DELETE FROM unitpers WHERE payplan = 'CCE';

    INSERT INTO unitpers
        (uic, display, unittype, quantity, payplan, gradelevel, categorysubgroupcode,
         asof, unityear, edate, categorygroupcode, locationid, strl, dependentstatus,
         numberofdependents, zipcode, locationtext, activedutydays)
    SELECT uic, display, unittype, quantity, payplan, gradelevel, categorysubgroupcode,
           asof, unityear, edate, categorygroupcode, locationid, strl, dependentstatus,
           numberofdependents, zipcode, locationtext, activedutydays
    FROM unitperscce;

    -- CCE grade level -> 3 (50th percentile default salary mark)
    UPDATE unitpers SET gradelevel = 3 WHERE payplan = 'CCE';

    -- category group code from the subgroup code
    UPDATE unitpers
    SET categorygroupcode = CASE
            WHEN payplan IN ('AO', 'RO', 'NO', 'NE', 'AE', 'RE', 'AWO', 'NWO', 'RWO') THEN left(categorysubgroupcode, 2)
            WHEN payplan = 'CCE' THEN left(categorysubgroupcode, 2) || '-0000'
            ELSE left(categorysubgroupcode, 2) || '00'
        END;

    -----------------------------------------------------------------------------
    -- location resolution
    -----------------------------------------------------------------------------
    -- ZIP from latest UICLocation. Source's LEFT JOIN + "WHERE EffectiveDate = MAX"
    -- excludes unmatched rows, so it is an inner-join update; ZipCode starts non-NULL
    -- ('') so PG inner-join UPDATE..FROM is equivalent.
    UPDATE unitpers t
    SET zipcode = left(b.zip, 5)
    FROM lookup.uiclocation b
    WHERE t.uic = b.uic
      AND b.effectivedate = (SELECT MAX(c.effectivedate) FROM lookup.uiclocation c WHERE b.uic = c.uic);

    -- fill missing ZIPs from the most-prevalent ZIP at the same ARLOC
    DROP TABLE IF EXISTS tempcte;
    CREATE TEMP TABLE tempcte AS
    SELECT DISTINCT
           a.uic,
           b.zip,
           COUNT(b.zip) OVER (PARTITION BY a.uic, b.zip) AS matchcount
    FROM lookup.uiclocation a
        INNER JOIN lookup.uiclocation b ON a.arloc = b.arloc
    WHERE (a.zip IS NULL OR a.zip = '')
      AND b.arloc <> ''
      AND b.zip <> ''
      AND a.effectivedate = (SELECT MAX(c.effectivedate) FROM lookup.uiclocation c WHERE a.uic = c.uic)
      AND b.effectivedate = (SELECT MAX(c.effectivedate) FROM lookup.uiclocation c WHERE b.uic = c.uic);

    -- self-referencing subquery moved into FROM (target not re-aliased)
    UPDATE unitpers t
    SET zipcode = left(b.zip, 5)
    FROM (
        SELECT x.*
        FROM tempcte x
            INNER JOIN (
                SELECT uic, MAX(matchcount) AS matchcount
                FROM tempcte
                GROUP BY uic
            ) y ON y.matchcount = x.matchcount AND y.uic = x.uic
    ) b
    WHERE t.uic = b.uic;

    -- military housing area location (source LEFT JOINs are inner via WHERE)
    UPDATE unitpers t
    SET locationid = c.locationid,
        locationtext = c.displayname
    FROM xwalk.ziptomha b
        INNER JOIN warehouse.location c ON c.sourcesystemcode = b.mha
    WHERE b.zipcode = t.zipcode
      AND v_maxamcosversion = b.amcosversionid
      AND c.locationtype LIKE '%Military Housing Area'
      AND t.payplan NOT IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'NG_R')
      AND t.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Military')
      AND t.locationid = -2;

    -- NAF wage location
    UPDATE unitpers t
    SET locationid = d.locationid,
        locationtext = d.displayname
    FROM lookup.fips_zip b
        INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
        INNER JOIN warehouse.location d ON d.sourcesystemcode = c.schedulearea
    WHERE b.zipcode = t.zipcode
      AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND v_maxamcosversion = c.amcosversionid
      AND c.fundtype = 'NAF'
      AND d.locationtype = 'Federal Wage System NAF'
      AND t.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage NAF')
      AND t.locationid = -2;

    -- AF wage location
    UPDATE unitpers t
    SET locationid = d.locationid,
        locationtext = d.displayname
    FROM lookup.fips_zip b
        INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
        INNER JOIN warehouse.location d ON d.sourcesystemcode = c.schedulearea
    WHERE b.zipcode = t.zipcode
      AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND v_maxamcosversion = c.amcosversionid
      AND c.fundtype = 'AF'
      AND d.locationtype = 'Federal Wage System AF'
      AND t.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage AF')
      AND t.locationid = -2;

    -- CIV overseas (DoS) locations
    UPDATE unitpers t
    SET locationid = c.locationid,
        locationtext = c.displayname,
        numberofdependents = 0
    FROM xwalk.ziptodos b
        INNER JOIN warehouse.location c ON b.doslocation = c.sourcesystemcode
    WHERE t.zipcode = b.zipcode
      AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND c.locationtype = 'Civilian Overseas'
      AND t.locationid = -2
      AND t.payplan NOT IN (SELECT DISTINCT payplan FROM lookup.payplantags WHERE tag = 'Military')
      AND t.payplan <> 'CCE';

    -- OPM locality pay areas (all remaining civilian-style plans)
    UPDATE unitpers t
    SET locationid = e.locationid,
        locationtext = e.displayname
    FROM lookup.fips_zip b
        INNER JOIN xwalk.localitypayareatofips c ON b.fipscode = c.statecode || c.countycode
        INNER JOIN "PaySchedule".localitypay d ON c.localitycode = d.localitycode
        INNER JOIN warehouse.location e ON e.sourcesystemcode = d.localitycode
    WHERE b.zipcode = t.zipcode
      AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND v_maxamcosversion = c.amcosversionid
      AND v_maxamcosversion = d.amcosversionid
      AND e.locationtype = 'Locality Pay Area'
      AND t.payplan IN (
          SELECT payplan FROM lookup.payplantags
          WHERE tag IN ('Civilian', 'Lab Demo', 'Acq Demo') AND payplan NOT IN ('CCE', 'SES')
      )
      AND t.locationid = -2;

    -- remaining valid non-FPO/APO/DPO ZIPs -> RUS for CIV plans.
    -- Source nested the (a.LocationId=-2 / a.PayPlan IN ..) correlated predicates
    -- inside the FIPS_ZIP IN-subquery; hoisted them to the UPDATE WHERE (same result).
    v_locationid := (
        SELECT locationid FROM warehouse.location
        WHERE sourcesystemcode = 'RUS' AND locationtype = 'Locality Pay Area'
        ORDER BY locationid LIMIT 1
    );
    v_locationtext := (
        SELECT displayname FROM warehouse.location
        WHERE sourcesystemcode = 'RUS' AND locationtype = 'Locality Pay Area'
        ORDER BY displayname LIMIT 1
    );

    UPDATE unitpers t
    SET locationid = v_locationid,
        locationtext = v_locationtext
    WHERE t.locationid = -2
      AND t.payplan IN (
          SELECT payplan FROM lookup.payplantags
          WHERE tag IN ('Civilian', 'Lab Demo', 'Acq Demo') AND payplan NOT IN ('CCE', 'SES')
      )
      AND t.zipcode IN (
          SELECT zipcode FROM lookup.fips_zip
          WHERE city NOT IN ('APO', 'FPO', 'DPO')
            AND v_maxamcosversion BETWEEN amcosversionidstart AND amcosversionidend
            AND fipscode NOT IN (
                SELECT statecode || countycode FROM xwalk.localitypayareatofips
                WHERE v_maxamcosversion BETWEEN amcosversionidstart AND amcosversionidend
            )
      );

    -- CCE locations via MSA
    UPDATE unitpers t
    SET locationid = b.locationid,
        locationtext = b.displayname
    FROM (
        SELECT c.locationid, b.zipcode, c.displayname
        FROM xwalk.metropolitanstatisticalareatofips a
            INNER JOIN lookup.fips_zip b ON b.fipscode = concat(a.statecode, a.countycode)
            INNER JOIN warehouse.location c ON c.sourcesystemcode = a.msacode
        WHERE v_maxamcosversion = a.amcosversionid
          AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend
    ) b
    WHERE b.zipcode = t.zipcode
      AND t.payplan = 'CCE';

    -- unresolved locations -> worldwide average
    UPDATE unitpers
    SET locationid = -1,
        locationtext = 'All'
    WHERE locationid = -2;

    -- military with a location -> average number of dependents
    UPDATE unitpers
    SET dependentstatus = 'average'
    WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Military')
      AND locationid > -1;

    -- D-series (Lab Demo) plans -> STRL for the UIC
    UPDATE unitpers t
    SET strl = b.strl
    FROM xwalk.uictostrl b
    WHERE left(b.uic, 4) = left(t.uic, 4)
      AND v_maxamcosversion BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND t.locationid > -1
      AND t.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Lab Demo');

    -- any Lab Demo left without an STRL is a hard stop (no costs exist for strl=-1)
    IF EXISTS (
        SELECT 1 FROM unitpers
        WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Lab Demo')
          AND strl = '-1'
    ) THEN
        RAISE EXCEPTION 'check the shown UICs as we are missing an entry for them in xwalk.uictostrl';
    END IF;

    -- Reserve forces -> 15 active duty days
    UPDATE unitpers
    SET activedutydays = 15
    WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'NG_R');

    -----------------------------------------------------------------------------
    -- publish
    -----------------------------------------------------------------------------
    TRUNCATE TABLE warehouse.unitpersonnel;

    INSERT INTO warehouse.unitpersonnel
        (uic, uictitle, payplan, categorygroupcode, categorysubgroupcode, locationid,
         locationtext, strl, gradelevel, dependentstatus, numberofdependents,
         activedutydays, inventory, unityear, asof, authorizationdocument)
    SELECT uic, display, payplan, categorygroupcode, categorysubgroupcode, locationid,
           locationtext, strl, gradelevel::smallint, dependentstatus, numberofdependents,
           activedutydays, quantity, unityear, asof::varchar, unittype
    FROM unitpers;

    DROP TABLE IF EXISTS unitpers;
    DROP TABLE IF EXISTS unitperscce;
    DROP TABLE IF EXISTS tempcte;
END;
$$;

------------------------------------------------------------------------------
-- warehouse.populateppxwalk  (port of warehouse.PopulatePPXwalk)
--
-- Builds the comprehensive pay-plan crosswalk (warehouse.ppxwalk): equates a
-- GS/SES base position to every other pay plan at the subgroup, grade-level and
-- location levels, then adds the CCE (BLS/OES) salary-based equating.
--
-- Faithful structural port. Notable source-specific behaviors preserved:
--   * No p_amcosversionid param / no crunch.validateamcosversion guard — the
--     source derives v_latestamcosversionid := MAX(lookup.amcosversion).
--   * The TRUNCATE + both INSERTs are UNCONDITIONAL in the source (they are NOT
--     wrapped in "IF @Debug = 0"). p_debug only drove PRINT/result-set dump
--     blocks, which have no runtime effect and are dropped. p_debug is therefore
--     effectively a no-op here, retained only to match the source signature.
--   * @CrunchTime is set-if-null in the source but never referenced in the body;
--     v_crunchtime is declared to mirror that, but is likewise unused.
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS before each create and at end).
--   * Schemas quoted per case-sensitive convention: "PaySchedule", "BLS_OES".
--   * String "+" concatenation -> "||"; source CONCAT(...) kept as concat()
--     (the source deliberately mixes the two; both semantics are preserved).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE warehouse.populateppxwalk(
    p_categorysubgroupcode varchar(10) DEFAULT NULL,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime           timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_latestamcosversionid integer;
BEGIN
    v_latestamcosversionid := (SELECT MAX(amcosversionid) FROM lookup.amcosversion);

    /* This is a warehouse table so we start over each time */
    TRUNCATE TABLE warehouse.ppxwalk;

    /* get only the valid cost scenarios we have so we don't create unnecessary
       xwalk scenarios that won't produce costs in the end anyways */
    DROP TABLE IF EXISTS uniquecosts;
    CREATE TEMP TABLE uniquecosts AS
    SELECT DISTINCT
           payplan,
           categorysubgroupcode,
           gradelevel,
           locationid
    FROM data.costs
    WHERE v_latestamcosversionid = amcosversionid
      AND categorysubgroupcode <> '-1';

    /* Step 1 */
    DROP TABLE IF EXISTS gs;
    CREATE TEMP TABLE gs AS
    SELECT DISTINCT
           payplan              AS gs_ses_payplan,
           gradelevel           AS gs_ses_gradelevel,
           categorysubgroupcode AS gs_ses_subgroupcode,
           locationid           AS gs_ses_locationid
    FROM uniquecosts
    WHERE (
              payplan = 'SES'
              OR (payplan = 'GS' AND locationid <> -1)
          );

    -- bring in PP to the ONET table
    DROP TABLE IF EXISTS onet_withpp;
    CREATE TEMP TABLE onet_withpp AS
    SELECT DISTINCT
           a.onet_code,
           a.subgroupcode,
           b.payplan
    FROM xwalk.onetsubgroupcrosswalk a
        INNER JOIN xwalk.payplantype b
            ON b.payplantype = a.payplantype
    WHERE v_latestamcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
      AND (
              p_categorysubgroupcode IS NULL
              OR p_categorysubgroupcode = ''
              OR a.subgroupcode = p_categorysubgroupcode
          ); -- this allows us to test a specific subgroup

    -- filter our ONET table to only costs that exist
    DROP TABLE IF EXISTS onet_final;
    CREATE TEMP TABLE onet_final AS
    SELECT DISTINCT
           a.onet_code,
           a.subgroupcode,
           a.payplan
    FROM onet_withpp a
        INNER JOIN
        (SELECT DISTINCT categorysubgroupcode, payplan FROM uniquecosts) b
            ON a.subgroupcode = b.categorysubgroupcode
           AND a.payplan = b.payplan;

    -- now join the GS temp table to our xwalk
    DROP TABLE IF EXISTS gs_subgroup;
    CREATE TEMP TABLE gs_subgroup AS
    SELECT a.*,
           b.topayplan,
           b.tosubgroupcode
    FROM gs a
        INNER JOIN
        (
            -- self join so we have the left and right AMCOS PP sides with the
            -- ONET as the 'crease' in the middle
            SELECT *
            FROM
            (
                SELECT onet_code    AS fromonet,
                       subgroupcode AS gs_ses_subgroupcode,
                       payplan      AS gs_ses_payplan
                FROM onet_final a
                WHERE payplan IN ('SES', 'GS')
            ) gs_ses_subgroup_xwalk
                INNER JOIN
                (
                    SELECT onet_code    AS toonet,
                           subgroupcode AS tosubgroupcode,
                           payplan      AS topayplan
                    FROM onet_final
                ) subgroup_xwalk
                    ON gs_ses_subgroup_xwalk.fromonet = subgroup_xwalk.toonet
        ) b
            ON b.gs_ses_subgroupcode = a.gs_ses_subgroupcode
           AND a.gs_ses_payplan = b.gs_ses_payplan;

    --## Step 2, add in the grade level cross walk
    DROP TABLE IF EXISTS gradelevel;
    CREATE TEMP TABLE gradelevel AS
    SELECT DISTINCT
           gs_ses_payplan,
           gs_ses_gradelevel,
           topayplan,
           togradelevelpayband,
           strl AS tostrl
    FROM xwalk.ppxwalkgradelevel a;

    -- advance subgrp by adding in now the grade level
    DROP TABLE IF EXISTS gs_subgroup_gl;
    CREATE TEMP TABLE gs_subgroup_gl AS
    SELECT a.*,
           b.togradelevelpayband,
           b.tostrl
    FROM gs_subgroup a
        INNER JOIN gradelevel b
            ON a.gs_ses_payplan = b.gs_ses_payplan
           -- a.gs_ses_gradelevel is smallint (from data.costs via uniquecosts); b comes
           -- from xwalk.ppxwalkgradelevel which casts gs_ses_gradelevel to varchar(2).
           -- Cast back to smallint for a numeric equality match (grades are numeric here).
           AND a.gs_ses_gradelevel = b.gs_ses_gradelevel::smallint
           AND a.topayplan = b.topayplan;

    --## Step 3, add in the location equivalent
    -- start with all active GS locations
    DROP TABLE IF EXISTS gsfips;
    CREATE TEMP TABLE gsfips AS
    SELECT a.locationid AS gs_locationid,
           d.statecode || d.countycode AS gs_fips
    FROM uniquecosts a
        INNER JOIN warehouse.location b
            ON b.locationid = a.locationid
        INNER JOIN "PaySchedule".localitypay c
            ON b.sourcesystemcode = c.localitycode
        INNER JOIN xwalk.localitypayareatofips d
            ON d.localitycode = c.localitycode
    WHERE v_latestamcosversionid = c.amcosversionid
      AND v_latestamcosversionid = d.amcosversionid
      AND b.locationtype = 'Locality Pay Area'
    UNION
    -- RUS locations which are not in the xwalk table
    SELECT DISTINCT
           a.locationid AS gs_locationid,
           c.fipscode   AS gs_fips
    FROM uniquecosts a
        INNER JOIN warehouse.location b
            ON b.locationid = a.locationid
        CROSS JOIN lookup.fips_zip c
    WHERE v_latestamcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND b.locationtype = 'Locality Pay Area'
      AND b.sourcesystemcode = 'RUS'
      AND c.fipscode NOT IN
          (
              -- any FIPS that isn't attached to a specific locality area
              SELECT statecode || countycode
              FROM xwalk.localitypayareatofips
              WHERE v_latestamcosversionid BETWEEN amcosversionidstart AND amcosversionidend
          );

    DROP TABLE IF EXISTS gsloc_xwalk_inital;
    -- AF wage first
    CREATE TEMP TABLE gsloc_xwalk_inital AS
    SELECT DISTINCT
           a.gs_locationid,
           c.locationid AS xwalk_locationid,
           d.payplan    AS targetpayplan
    FROM gsfips a
        INNER JOIN xwalk.wageareatofips b
            ON a.gs_fips = concat(b.statecode, b.countycode)
        INNER JOIN warehouse.location c
            ON b.schedulearea = c.sourcesystemcode
        CROSS JOIN
        (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage AF') d
    WHERE b.fundtype = 'AF'
      AND c.locationtype = 'Federal Wage System AF'
      AND v_latestamcosversionid = b.amcosversionid
    UNION
    -- next NAF wage
    SELECT DISTINCT
           a.gs_locationid,
           c.locationid,
           d.payplan
    FROM gsfips a
        INNER JOIN xwalk.wageareatofips b
            ON a.gs_fips = concat(b.statecode, b.countycode)
        INNER JOIN warehouse.location c
            ON b.schedulearea = c.sourcesystemcode
        CROSS JOIN
        (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage NAF') d
    WHERE b.fundtype = 'NAF'
      AND c.locationtype = 'Federal Wage System NAF'
      AND v_latestamcosversionid = b.amcosversionid
    UNION
    -- then opm special pay
    SELECT DISTINCT
           a.gs_locationid,
           c.locationid,
           d.payplan
    FROM gsfips a
        INNER JOIN xwalk.specialratetablesbylocation b
            ON a.gs_fips = b.statecode || b.countycode
        INNER JOIN warehouse.location c
            ON b.locationname || ', ' || b.state = c.sourcesystemcode
        CROSS JOIN
        (SELECT payplan FROM lookup.payplantags WHERE tag = 'SpecialPay') d
    WHERE c.locationtype = 'OPM Special Pay Locations'
      AND v_latestamcosversionid = b.amcosversionid
    UNION
    -- then locality areas to themselves
    SELECT DISTINCT
           a.gs_locationid,
           a.gs_locationid,
           b.payplan
    FROM gsfips a
        INNER JOIN
        (SELECT DISTINCT locationid, payplan FROM uniquecosts) b
            ON a.gs_locationid = b.locationid
    UNION
    -- now do military
    SELECT DISTINCT
           a.gs_locationid,
           d.locationid,
           e.payplan
    FROM gsfips a
        INNER JOIN lookup.fips_zip b
            ON a.gs_fips = b.fipscode
        INNER JOIN xwalk.ziptomha c
            ON b.zipcode = c.zipcode
        INNER JOIN warehouse.location d
            ON d.sourcesystemcode = c.mha
        CROSS JOIN
        (SELECT payplan FROM lookup.payplantags WHERE tag = 'Military') e
    WHERE d.locationtype = 'CONUS Military Housing Area'
      AND v_latestamcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND v_latestamcosversionid = c.amcosversionid;

    -- now account for SES which is -1 location id: link -1 to all possible locations
    DROP TABLE IF EXISTS gsloc_xwalk;
    CREATE TEMP TABLE gsloc_xwalk AS
    SELECT DISTINCT
           -1 AS gs_locationid,
           xwalk_locationid,
           targetpayplan
    FROM gsloc_xwalk_inital
    UNION
    SELECT -1, -1, 'SES'
    UNION
    SELECT gs_locationid,
           xwalk_locationid,
           targetpayplan
    FROM gsloc_xwalk_inital;

    -- now we finally do the location xwalk
    DROP TABLE IF EXISTS gs_subgroup_gl_location;
    CREATE TEMP TABLE gs_subgroup_gl_location AS
    SELECT DISTINCT
           a.*,
           b.xwalk_locationid
    FROM gs_subgroup_gl a
        INNER JOIN gsloc_xwalk b
            ON a.gs_ses_locationid = b.gs_locationid
           AND a.topayplan = b.targetpayplan;

    INSERT INTO warehouse.ppxwalk
    (
        gs_ses_basepayplan,
        gs_ses_basegradelevel,
        gs_ses_basesubgroupcode,
        gs_ses_baselocationid,
        targetpayplan,
        targetgradelevel,
        targetsubgroupcode,
        targetlocationid,
        targetstrl
    )
    SELECT DISTINCT
           gs_ses_payplan,
           gs_ses_gradelevel,
           gs_ses_subgroupcode,
           gs_ses_locationid,
           topayplan,
           togradelevelpayband,
           tosubgroupcode,
           xwalk_locationid,
           tostrl
    FROM gs_subgroup_gl_location;

    -- nearest neighbors for CCE: translate BLS OES percentile (CCE) to GS grade
    -- levels at the subgroup level, matched by comparing salaries.

    --############## 1 Get GS costs
    DROP TABLE IF EXISTS gscosts;
    CREATE TEMP TABLE gscosts AS
    SELECT payplan,
           categorysubgroupcode,
           categorysubgroupdescription,
           locationid,
           location_name,
           gradelevel,
           SUM(amount) AS basepay
    FROM data.costswithdescriptions
    WHERE payplan = 'GS'                    -- equating to GS only
      AND amcosversionid = v_latestamcosversionid
      AND categorysubgroupcode <> '-1'      -- no group/pp/career-program averages
      AND numberofdependents = -1           -- no overseas (CCE/BLS OES is US only)
      AND locationid <> -1                  -- no location averages
      AND costelementid IN (   275,  -- base pay
                              4894,  -- base pay 2 for firefighters
                              4856   -- non-foreign cola, e.g. AK & HI
                           )
    GROUP BY payplan,
             categorysubgroupcode,
             categorysubgroupdescription,
             locationid,
             location_name,
             gradelevel;

    /* Step 2 Get BLS/CCE costs */
    DROP TABLE IF EXISTS blscosts;
    CREATE TEMP TABLE blscosts AS
    SELECT soc,
           msacode,
           gradelevel,
           -- some values are max value on purpose to indicate the BLS does not
           -- provide salary above a certain amount; we convert that to the BLS' max
           CASE
               WHEN basepay = 9999999 THEN
                   crunch.getsinglevalue('CCE', 'MaxPayFootnote', v_latestamcosversionid)
               ELSE
                   basepay
           END AS basepay,
           amcosversionid
    FROM
    (
        SELECT soc, msacode, '10th' AS gradelevel, a_pct10 AS basepay, amcosversionid
        FROM "BLS_OES".occupationalemploymentstatisticsmetro
        WHERE amcosversionid = v_latestamcosversionid
        UNION
        SELECT soc, msacode, '25th', a_pct25, amcosversionid
        FROM "BLS_OES".occupationalemploymentstatisticsmetro
        WHERE amcosversionid = v_latestamcosversionid
        UNION
        SELECT soc, msacode, '50th', a_median, amcosversionid
        FROM "BLS_OES".occupationalemploymentstatisticsmetro
        WHERE amcosversionid = v_latestamcosversionid
        UNION
        SELECT soc, msacode, '75th', a_pct75, amcosversionid
        FROM "BLS_OES".occupationalemploymentstatisticsmetro
        WHERE amcosversionid = v_latestamcosversionid
        UNION
        SELECT soc, msacode, '90th', a_pct90, amcosversionid
        FROM "BLS_OES".occupationalemploymentstatisticsmetro
        WHERE amcosversionid = v_latestamcosversionid
    ) a
    WHERE basepay <> -1; -- -1 indicates a wage estimate is not available

    /* Step 3: Get GS to BLS xwalk (equate an MSA/CCE location to a GS locality) */
    DROP TABLE IF EXISTS xwalklocalitytomsa;
    CREATE TEMP TABLE xwalklocalitytomsa AS
    SELECT a.msacode,
           d.locationid
    FROM
    (
        SELECT DISTINCT
               a.msacode,
               m.msaname,
               CASE
                   WHEN c.localitycode IS NULL THEN 'RUS'
                   ELSE c.localitycode
               END AS localitycode -- anything not resolving to a locality area = rest of US
        FROM xwalk.metropolitanstatisticalareatofips a
            INNER JOIN lookup.metropolitanstatisticalarea m
                ON m.amcosversionid = a.amcosversionid
               AND m.msacode = a.msacode
            LEFT OUTER JOIN xwalk.localitypayareatofips b
                ON a.statecode || a.countycode = b.statecode || b.countycode
            LEFT OUTER JOIN "PaySchedule".localitypay c
                ON b.localitycode = c.localitycode
        WHERE (v_latestamcosversionid = a.amcosversionid OR a.amcosversionidstart IS NULL)
          AND (v_latestamcosversionid = b.amcosversionid OR b.amcosversionid IS NULL)
          AND (v_latestamcosversionid = c.amcosversionid OR c.amcosversionid IS NULL)
    ) a
        LEFT OUTER JOIN warehouse.location d
            ON a.localitycode = d.sourcesystemcode;

    /* now do GS special pay xwalk (immediate xwalk from an OPM special pay table) */
    INSERT INTO xwalklocalitytomsa
    (
        msacode,
        locationid
    )
    SELECT DISTINCT
           c.msacode,
           b.locationid
    FROM xwalk.specialratetablesbylocation a
        INNER JOIN warehouse.location b
            ON a.locationname || ', ' || a.state = b.sourcesystemcode
        INNER JOIN xwalk.metropolitanstatisticalareatofips c
            ON c.statecode || c.countycode = a.statecode || a.countycode
    WHERE b.locationtype = 'OPM Special Pay Locations'
      -- see warehouse.updateloctionid for this 'handling' code and the comma naming convention
      AND a.statecode <> 'X'
      AND a.countycode <> 'X'
      AND a.citycode <> 'X'
      AND v_latestamcosversionid = a.amcosversionid
      AND v_latestamcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend;

    /* Step 4: Link the costs together and insert them into our table */
    INSERT INTO warehouse.ppxwalk
    (
        gs_ses_basepayplan,
        gs_ses_basegradelevel,
        gs_ses_basesubgroupcode,
        gs_ses_baselocationid,
        targetpayplan,
        targetgradelevel,
        targetsubgroupcode,
        targetlocationid,
        targetstrl
    )
    SELECT DISTINCT
           b.payplan              AS basepayplan,
           b.gradelevel           AS basegradelevel,
           b.categorysubgroupcode AS basesubgroupcode,
           b.locationid           AS baselocationid,
           'CCE'                  AS targetpayplan,
           c.gradelevel           AS targetgradelevel,
           c.soc                  AS targetsubgroupcode,
           e.locationid           AS targetlocationid,
           'Not Applicable'       AS targetstrl
    FROM xwalklocalitytomsa a
        INNER JOIN gscosts b
            ON b.locationid = a.locationid
        INNER JOIN blscosts c
            ON c.msacode = a.msacode
        INNER JOIN xwalk.onetsubgroupcrosswalk d
            ON d.onetcodetrimmed = c.soc
           AND d.subgroupcode = b.categorysubgroupcode
        INNER JOIN warehouse.location e
            ON e.sourcesystemcode = c.msacode
    WHERE v_latestamcosversionid BETWEEN d.amcosversionidstart AND d.amcosversionidend
      AND e.locationtype = 'MSA'
      AND b.basepay / NULLIF(c.basepay, 0) BETWEEN .7 AND 1.3 -- GS 1->10 spread ~30%
      AND d.payplantype = 'CIV'; -- no military links, just GS

    -- clean up temp tables
    DROP TABLE IF EXISTS uniquecosts;
    DROP TABLE IF EXISTS gs;
    DROP TABLE IF EXISTS onet_withpp;
    DROP TABLE IF EXISTS onet_final;
    DROP TABLE IF EXISTS gs_subgroup;
    DROP TABLE IF EXISTS gradelevel;
    DROP TABLE IF EXISTS gs_subgroup_gl;
    DROP TABLE IF EXISTS gsfips;
    DROP TABLE IF EXISTS gsloc_xwalk_inital;
    DROP TABLE IF EXISTS gsloc_xwalk;
    DROP TABLE IF EXISTS gs_subgroup_gl_location;
    DROP TABLE IF EXISTS gscosts;
    DROP TABLE IF EXISTS blscosts;
    DROP TABLE IF EXISTS xwalklocalitytomsa;
END;
$$;
