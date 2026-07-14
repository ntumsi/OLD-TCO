-- Cost-crunch PHASE 2 Wave 4 — pay-schedule processing procedures (crunch.*).
--
-- Ports the 9 crunch.CrunchPaySchedule* procedures + the CopyValues utility from
-- AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/. These read the ETL-loaded
-- "PaySchedule".*_raw / OPM raw inputs and produce the PROCESSED pay tables the
-- civilian cost crunches (006e) consume: "PaySchedule".payschedule_{g_series,cy,
-- wage,d_nseries} (created in 005d) and crunch.{NfPayProcessed, Opm{Ca,Ex,Ig}Processed}
-- (005c). data.payschedules (008b) unions the processed "PaySchedule".* tables.
--
-- CREATE PROCEDURE, LANGUAGE plpgsql (CALL-invoked by CrunchAll in Phase 4;
-- p_debug=true is a dry run). Runs after 006e. Conventions: see the Phase-1
-- header (006d) and scratchpad PORT_CONVENTIONS.md.


-- =============================================================================
-- crunch.crunchpayschedulegseries  — Build the processed G-series (GS/GL/GG)
--   pay schedule (base + locality + OPM special-rate pay, incl. Hawaii/Alaska
--   and worldwide-territory record spawning) into
--   "PaySchedule".payschedule_g_series.
--
-- Faithful PostgreSQL port of [crunch].[CrunchPayScheduleGSeries]
-- (AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchPayScheduleGSeries.sql).
--
-- Port conventions (Phase 2):
--   * Source has NO @CrunchTime and the destination table has no crunchtime
--     column, so no time parameter/column is added. @Debug BIT -> p_debug
--     boolean DEFAULT false. p_debug = true is a DRY RUN: the source performs
--     its final DELETE + INSERT into PaySchedule.PaySchedule_G_Series only under
--     "IF @Debug = 0", so that write block is guarded by "IF NOT p_debug". The
--     "IF @Debug = 1" result-set dump is dropped (no runtime effect).
--   * The two data-validation guards (invalid group/subgroup, missing location)
--     sit BEFORE the @Debug = 0 write block, so they run in BOTH modes; their
--     RAISERROR + RETURN is ported as RAISE EXCEPTION (the interactive SELECT
--     diagnostic dumps that preceded each RAISERROR are dropped).
--   * #PaySchedule -> CREATE TEMP TABLE payschedule (DROP IF EXISTS first + at
--     end). The workrolecode DEFAULT '-1' is preserved so the inserts that omit
--     it (all but the GG insert) get '-1', exactly as the source.
--   * "UPDATE #PaySchedule SET .. FROM #PaySchedule a JOIN other b" ->
--     "UPDATE payschedule t SET .. FROM other b WHERE .." (PG forbids re-aliasing
--     the UPDATE target in FROM). None are self-joins; every updated column
--     starts NULL, so the inner-join rewrite matches the T-SQL inner-join UPDATE
--     (unmatched rows keep their prior/NULL value in both engines).
--   * SQL Server is case-insensitive; every LIKE is ported as ILIKE to preserve
--     matching (this also reconciles the source's '%ALASKA%' insert vs its
--     '%Alaska%' delete casing).
--   * BIT test "WorkRoleCodeRequired = 1" -> boolean "= true"
--     (workrolecoderequired is boolean in PG).
--   * Integer literals -1 that SQL Server implicitly cast into the NVARCHAR
--     OccupationalSeriesNumber columns are written as text '-1'.
--   * string '+' -> '||'; LEFT() -> left(); TINYINT -> smallint; NVARCHAR ->
--     varchar. Case-corrected schema names: "PaySchedule".* (quoted);
--     crunch.*, lookup.*, xwalk.*, data.*, warehouse.* lowercase-unquoted.
-- =============================================================================
CREATE OR REPLACE PROCEDURE crunch.crunchpayschedulegseries(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_salarylimit numeric(17, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    v_salarylimit := crunch.getmaximumgspaylimit(p_amcosversionid);

    DROP TABLE IF EXISTS payschedule;
    CREATE TEMP TABLE payschedule (
        scheduletype                     varchar(20)    NOT NULL,
        payplan                          varchar(2)     NOT NULL,
        occupationalseriesnumberoriginal varchar(4)     NOT NULL,
        occupationalseriesnumbernew      varchar(5)     NULL,
        locationid                       integer        NULL,
        locationname                     varchar(150)   NULL,
        localitycode                     varchar(6)     NULL,
        statecode                        varchar(2)     NULL,
        citycode                         varchar(4)     NULL,
        countycode                       varchar(3)     NULL,
        gradelevel                       integer        NOT NULL,
        step                             integer        NOT NULL,
        rate                             numeric(18, 2) NOT NULL,
        maxrate                          numeric(18, 2) NULL,
        amcosversionid                   integer        NOT NULL,
        workrolecode                     varchar(3)     DEFAULT '-1'  -- added 7/17/2023 to support cyber work codes
    );

    /* GS, GL */
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, occupationalseriesnumbernew,
         gradelevel, step, rate, localitycode, amcosversionid)
    SELECT 'Regular',
           a.payplan,
           '-1',
           '-1',
           a.gradelevel,
           a.step,
           a.rate * ((b.localityrate) / 100 + 1),
           b.localitycode,
           a.amcosversionid
    FROM "PaySchedule".payschedule_g_series_raw AS a
        CROSS JOIN "PaySchedule".localitypay AS b
    WHERE a.amcosversionid = p_amcosversionid
          AND b.amcosversionid = p_amcosversionid
          AND a.ratetype = 'Annual'
          AND a.rate > 0;

    /* GG */
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, occupationalseriesnumbernew,
         gradelevel, step, rate, localitycode, amcosversionid, workrolecode)
    SELECT 'Regular',
           'GG',
           '-1',
           '-1',
           b.gradelevel,
           b.step,
           b.rate,
           b.localitycode,
           p_amcosversionid,
           b.workrolecode
    FROM lookup.gs_occupationalseries AS a
        CROSS JOIN
        (
            SELECT a.workrolecode,
                   a.gradelevel,
                   a.step,
                   a.rate,
                   a.tlmspaytable,
                   b.localitycode
            FROM "PaySchedule".cyberexceptedservice AS a
                INNER JOIN xwalk.tlmspaytabletolocalitypayarea AS b
                    ON a.tlmspaytable = b.tlmspaytable
            WHERE p_amcosversionid = b.amcosversionid
                  AND p_amcosversionid = a.amcosversionid
                  AND b.localitycode <> 'FoL'  -- no foreign locations
        ) AS b
    WHERE p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
          AND a.occupationalseriesnumber IN
              (
                  SELECT occupationalseriesnumber
                  FROM lookup.gs_occupationalseries
                  WHERE workrolecoderequired = true
              );

    /* cap pay */
    UPDATE payschedule
    SET rate = v_salarylimit
    WHERE rate > v_salarylimit;

    /* Add rows for special rates for GS (once for GS, again for GL) */
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, statecode, citycode,
         countycode, locationname, localitycode, gradelevel, step, rate, amcosversionid)
    SELECT 'Special',
           'GS',
           c.occupationalseriesnumber,
           d.statecode,
           d.citycode,
           d.countycode,
           d.locationname || ', ' || d.state,
           d.localitycode,
           a.gradelevel,
           a.step,
           a.rate,
           a.amcosversionid
    FROM "PaySchedule".opmspecialrates AS a
        INNER JOIN xwalk.specialratetablesbyagency AS b
            ON a.specialratetablenumber = b.tablenumber
               AND b.amcosversionid = a.amcosversionid
        INNER JOIN xwalk.specialratetablesbyoccupation AS c
            ON b.tablenumber = c.tablenumber
               AND c.amcosversionid = b.amcosversionid
        INNER JOIN xwalk.specialratetablesbylocation AS d
            ON c.tablenumber = d.tablenumber
               AND d.amcosversionid = c.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND
          (
              b.title = 'DEPARTMENT OF THE ARMY'
              OR b.title = 'ALL FEDERAL GOVERNMENT AGENCIES'
          )

    UNION
    SELECT 'Special',
           'GL',
           c.occupationalseriesnumber,
           d.statecode,
           d.citycode,
           d.countycode,
           d.locationname || ', ' || d.state,
           d.localitycode,
           a.gradelevel,
           a.step,
           a.rate,
           a.amcosversionid
    FROM "PaySchedule".opmspecialrates AS a
        INNER JOIN xwalk.specialratetablesbyagency AS b
            ON a.specialratetablenumber = b.tablenumber
               AND b.amcosversionid = a.amcosversionid
        INNER JOIN xwalk.specialratetablesbyoccupation AS c
            ON b.tablenumber = c.tablenumber
               AND c.amcosversionid = b.amcosversionid
        INNER JOIN xwalk.specialratetablesbylocation AS d
            ON c.tablenumber = d.tablenumber
               AND d.amcosversionid = c.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND
          (
              b.title = 'DEPARTMENT OF THE ARMY'
              OR b.title = 'ALL FEDERAL GOVERNMENT AGENCIES'
          )
          -- only special pay for subgroups GL is actually using
          AND c.occupationalseriesnumber IN
              (
                  SELECT DISTINCT categorysubgroupcode
                  FROM data.knowninventory
                  WHERE amcosversionid = p_amcosversionid
                        AND payplan = 'GL'
              );

    -- update the special pay records by bringing in their 'AMCOS' subgroup number
    -- (rewritten: PG forbids re-aliasing the UPDATE target in FROM; join to the
    --  lookup table directly. occupationalseriesnumbernew starts NULL for Special
    --  rows, so the inner-join UPDATE matches the source's inner-join semantics.)
    UPDATE payschedule t
    SET occupationalseriesnumbernew = b.occupationalseriesnumber
    FROM lookup.gs_occupationalseries AS b
    WHERE left(b.occupationalseriesnumber, 4) = t.occupationalseriesnumberoriginal
          AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
          AND t.scheduletype = 'Special';

    -- If we have an unidentified subgroup we need to call that out
    -- (XXXX applies to all series and is granted an error exception)
    IF EXISTS
    (
        SELECT 1
        FROM payschedule
        WHERE occupationalseriesnumbernew IS NULL
              AND occupationalseriesnumberoriginal <> 'XXXX'
    ) THEN
        RAISE EXCEPTION 'Invalid group/subgroup codes';
    END IF;

    -- handle the Hawaii special pay record against the Hawaii locality codes:
    -- take the general Hawaii record and spawn it against all Hawaii locality areas
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, occupationalseriesnumbernew,
         locationid, locationname, localitycode, statecode, citycode, countycode,
         gradelevel, step, rate, maxrate, amcosversionid)
    SELECT a.scheduletype,
           a.payplan,
           a.occupationalseriesnumberoriginal,
           a.occupationalseriesnumbernew,
           a.locationid,
           a.locationname,
           c.localitycode,
           a.statecode,
           a.citycode,
           a.countycode,
           a.gradelevel,
           a.step,
           a.rate,
           a.maxrate,
           a.amcosversionid
    FROM payschedule AS a
        INNER JOIN xwalk.localitypayareatofips AS b
            ON a.statecode = b.statecode
        INNER JOIN "PaySchedule".localitypay AS c
            ON b.localitycode = c.localitycode
    WHERE (
              a.statecode = '15'
              AND a.countycode = '000'
              AND a.citycode = '0000'
          )
          OR (
                 a.statecode = 'X'
                 AND a.locationname ILIKE '%Hawaii%'
             )
             AND b.statecode = '15';

    -- immediately delete the now orphaned Hawaii record(s)
    DELETE FROM payschedule
    WHERE (
              (
                  statecode = '15'
                  AND countycode = '000'
                  AND citycode = '0000'
              )
              OR
              (
                  statecode = 'X'
                  AND locationname ILIKE '%Hawaii%'
              )
          )
          AND localitycode IS NULL;

    -- handle the Alaska special pay record against the Alaska locality codes:
    -- take the general Alaska record and spawn it against all Alaska locality areas
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, occupationalseriesnumbernew,
         locationid, locationname, localitycode, statecode, citycode, countycode,
         gradelevel, step, rate, maxrate, amcosversionid)
    SELECT a.scheduletype,
           a.payplan,
           a.occupationalseriesnumberoriginal,
           a.occupationalseriesnumbernew,
           a.locationid,
           a.locationname,
           c.localitycode,
           a.statecode,
           a.citycode,
           a.countycode,
           a.gradelevel,
           a.step,
           a.rate,
           a.maxrate,
           a.amcosversionid
    FROM payschedule AS a
        INNER JOIN xwalk.localitypayareatofips AS b
            ON a.statecode = b.statecode
        INNER JOIN "PaySchedule".localitypay AS c
            ON b.localitycode = c.localitycode
    WHERE (
              a.statecode = '02'
              AND a.countycode = '000'
              AND a.citycode = '0000'
          )
          OR (
                 a.statecode = 'X'
                 AND a.locationname ILIKE '%ALASKA%'
             )
             AND b.statecode = '02';

    -- immediately delete the now orphaned Alaska record(s)
    DELETE FROM payschedule
    WHERE (
              (
                  statecode = '02'
                  AND countycode = '000'
                  AND citycode = '0000'
              )
              OR
              (
                  statecode = 'X'
                  AND locationname ILIKE '%Alaska%'
              )
          )
          AND localitycode IS NULL;

    /* Bring in locality pay area name
       (rewritten: UPDATE target re-alias removed; join lookup table in FROM.) */
    UPDATE payschedule t
    SET locationname = b.localitypayarea
    FROM lookup.localitypayarea AS b
    WHERE t.localitycode = b.localitycode
          AND t.amcosversionid = b.amcosversionid;

    /* Handle Rest of US locations */
    UPDATE payschedule
    SET localitycode = 'RUS'
    WHERE locationname ILIKE '%rest of u.s.%'
          AND localitycode IS NULL;

    /* Bring in the locationid (rewritten: UPDATE target re-alias removed) */
    UPDATE payschedule t
    SET locationid = b.locationid
    FROM warehouse.location AS b
    WHERE t.localitycode = b.sourcesystemcode
          AND b.locationtype = 'Locality Pay Area';

    UPDATE payschedule t
    SET locationid = b.locationid
    FROM warehouse.location AS b
    WHERE t.locationname = b.sourcesystemcode
          AND b.locationtype = 'OPM Special Pay Locations'
          AND t.locationid IS NULL;

    /* 4/1/2020 last thing: generate BASE pay with no locality. AMCOS generates
       no costs for it but the payschedule screen needs it */
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, occupationalseriesnumbernew,
         locationid, locationname, localitycode, statecode, citycode, countycode,
         gradelevel, step, rate, maxrate, amcosversionid)
    SELECT 'Regular',
           payplan,
           '-1',
           '-1',
           -1,
           'none',
           '-1',
           '',
           '',
           '',
           gradelevel,
           step,
           rate,
           rate,
           p_amcosversionid
    FROM "PaySchedule".payschedule_g_series_raw
    WHERE ratetype = 'Annual'
          AND amcosversionid = p_amcosversionid;

    /* 1/11/2023 join special pay which applies worldwide against all other pay records */
    INSERT INTO payschedule
        (scheduletype, payplan, occupationalseriesnumberoriginal, occupationalseriesnumbernew,
         locationid, locationname, localitycode, statecode, citycode, countycode,
         gradelevel, step, rate, maxrate, amcosversionid)
    SELECT a.scheduletype,
           a.payplan,
           a.occupationalseriesnumberoriginal,
           a.occupationalseriesnumbernew,
           a.locationid,
           a.locationname,
           a.localitycode,
           a.statecode,
           a.citycode,
           a.countycode,
           a.gradelevel,
           a.step,
           b.rate,
           b.rate AS maxrate,
           a.amcosversionid
    FROM payschedule AS a
        INNER JOIN
        (
            SELECT gradelevel,
                   step,
                   rate
            FROM payschedule
            WHERE locationname ILIKE '%UNITED STATES%TERRITORIES%'
                  AND occupationalseriesnumberoriginal = 'XXXX'
        ) AS b
            ON b.gradelevel = a.gradelevel
               AND b.step = a.step;

    /* Get rid of these records now so they don't trigger a missing-location
       warning below; they are a global thing, not an actual location.
       1/5/2024 added the catch for foreign areas */
    DELETE FROM payschedule
    WHERE (
              locationname ILIKE '%UNITED STATES%TERRITORIES%'
              OR locationname ILIKE '%FOREIGN AREAS%'
          )
          AND occupationalseriesnumberoriginal = 'XXXX';

    UPDATE payschedule
    SET maxrate = rate;

    /* If we have an unidentified location we need to call that out */
    IF EXISTS (SELECT 1 FROM payschedule WHERE locationid IS NULL) THEN
        RAISE EXCEPTION 'Missing location data';
    END IF;

    IF NOT p_debug THEN
        DELETE FROM "PaySchedule".payschedule_g_series
        WHERE amcosversionid = p_amcosversionid;

        /* The GROUP BY + MAX is because sometimes there are two rates for the
           same location nomen (different FIPS); AMCOS doesn't go to that level of
           detail so just take the highest. */
        INSERT INTO "PaySchedule".payschedule_g_series
            (payplan, gradetype, gradelevel, step, rate, amcosversionid, locationid,
             categorygroupcode, categorysubgroupcode, workrolecode)
        SELECT payplan,
               payplan,
               gradelevel,
               step,
               MAX(rate),
               amcosversionid,
               locationid,
               CASE
                   WHEN occupationalseriesnumbernew = 'All'
                        OR occupationalseriesnumbernew = '-1' THEN
                       '-1'
                   ELSE
                       left(occupationalseriesnumbernew, 2) || '00'
               END,
               CASE
                   WHEN occupationalseriesnumbernew = 'All' THEN
                       '-1'
                   ELSE
                       occupationalseriesnumbernew
               END,
               workrolecode
        FROM payschedule
        WHERE rate > 0
        GROUP BY payplan,
                 payplan,
                 gradelevel,
                 step,
                 amcosversionid,
                 locationid,
                 occupationalseriesnumbernew,
                 workrolecode;
    END IF;

    DROP TABLE IF EXISTS payschedule;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CrunchPayScheduleWage  (port of AMCOS.AMCOS2020_MAR/crunch/Stored
--   Procedures/CrunchPayScheduleWage.sql — Dan Hogan, 10/28/2019)
-- Convert raw Federal Wage System pay-plan data ("PaySchedule".payschedule_wage_raw)
-- into finished wage payschedules ("PaySchedule".payschedule_wage).
--   * Source rate1..rate5 columns UNPIVOTed to one row per step (T-SQL UNPIVOT
--     drops NULL measures -> replicated with a LATERAL VALUES scan + "amount IS
--     NOT NULL" filter). RIGHT(step,1) -> step number 1..5.
--   * PayPlan derived from FundType + TypeSchedule + Level via CASE (AF / NAF).
--   * WD / WN synthesised as grade-shifted copies of WS (AF only).
--   * LocationId back-filled from warehouse.location by area code.
--   * Collapses duplicate releases to MAX(effectivedate)/MAX(rate) per key, then
--     replaces the amcosversion's rows in "PaySchedule".payschedule_wage.
-- p_debug = true is a DRY RUN (the final DELETE/INSERT are skipped); the source's
-- IF @Debug=1 result-set dumps have no runtime effect and are dropped. The
-- missing-locationid guard runs in every mode, matching the source.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayschedulewage(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_year      integer;
    v_startdate timestamp;
    v_enddate   timestamp;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- year of the amcosversion (LEFT(@AmcosVersionId,4) in the source)
    v_year := left(p_amcosversionid::text, 4)::integer;

    -- cast a wider range for the start; MAX() below picks the right value by end date
    v_startdate := make_date(v_year - 2, 1, 1)::timestamp;
    -- the end date is always the last day of the amcosversion year
    v_enddate   := make_date(v_year, 12, 31)::timestamp;

    DROP TABLE IF EXISTS payschedulework;
    CREATE TEMP TABLE payschedulework (
        payplan       varchar(2),
        areacode      varchar(3),
        typedata      varchar(1)  NOT NULL,
        typeschedule  integer     NOT NULL,
        level         integer     NOT NULL,
        grade         integer     NOT NULL,
        step          integer     NOT NULL,
        effectivedate timestamp   NOT NULL,
        rate          numeric(18, 2) NOT NULL,
        amcosversionid integer    NOT NULL,
        locationid    integer     NOT NULL,
        fundtype      varchar(50) NOT NULL,
        link          varchar(150) NOT NULL
    );

    -- UNPIVOT rate1..rate5 -> one row per step; T-SQL UNPIVOT drops NULL measures.
    INSERT INTO payschedulework
        (areacode, typedata, typeschedule, level, grade, step, effectivedate,
         rate, amcosversionid, locationid, fundtype, link)
    SELECT a.areacode,
           a.typedata,
           a.typeschedule::integer,
           a.level::integer,
           a.grade,
           right(unpvt.step, 1)::integer AS step,
           a.effectivedate::timestamp,
           unpvt.amount,
           p_amcosversionid,
           -1 AS locationid,
           a.fundtype,
           a.link
    FROM "PaySchedule".payschedule_wage_raw a
    CROSS JOIN LATERAL (VALUES
        ('rate1', a.rate1),
        ('rate2', a.rate2),
        ('rate3', a.rate3),
        ('rate4', a.rate4),
        ('rate5', a.rate5)
    ) AS unpvt(step, amount)
    WHERE a.typedata = 'R'
      AND unpvt.amount IS NOT NULL
      AND a.effectivedate BETWEEN v_startdate AND v_enddate;

    /* AF */
    UPDATE payschedulework
    SET payplan = CASE
                      WHEN typeschedule = 5 AND level = 3 THEN 'WA'
                      WHEN (typeschedule = 1 OR typeschedule = 2) AND level = 1 THEN 'WG'
                      WHEN (typeschedule = 1 OR typeschedule = 2) AND level = 2 THEN 'WL'
                      WHEN typeschedule = 5 AND level = 2 THEN 'WO'
                      WHEN (typeschedule = 1 OR typeschedule = 2) AND level = 3 THEN 'WS'
                      WHEN typeschedule = 5 AND level = 1 THEN 'WY'
                      WHEN typeschedule = 3 AND level = 1 THEN 'XF'
                      WHEN typeschedule = 3 AND level = 2 THEN 'XG'
                      WHEN typeschedule = 3 AND level = 3 THEN 'XH'
                      WHEN typeschedule = 7 AND level = 1 THEN 'XR'
                      WHEN typeschedule = 7 AND level = 2 THEN 'XT'
                      WHEN typeschedule = 7 AND level = 3 THEN 'XU'
                      ELSE '-1'
                  END
    WHERE fundtype = 'AF';

    /* NAF */
    UPDATE payschedulework
    SET payplan = CASE
                      WHEN (typeschedule = 1 OR typeschedule = 2) AND level = 1 THEN 'NA'
                      WHEN (typeschedule = 1 OR typeschedule = 2) AND level = 2 THEN 'NL'
                      WHEN (typeschedule = 1 OR typeschedule = 2) AND level = 3 THEN 'NS'
                      ELSE '-1'
                  END
    WHERE fundtype = 'NAF';

    /* WD is a grade-shifted duplicate of WS (AF only) */
    INSERT INTO payschedulework
        (payplan, areacode, typedata, typeschedule, level, grade, step,
         effectivedate, rate, amcosversionid, locationid, fundtype, link)
    SELECT 'WD', areacode, typedata, typeschedule, level, grade - 2, step,
           effectivedate, rate, amcosversionid, -1, fundtype, link
    FROM payschedulework
    WHERE payplan = 'WS'
      AND grade BETWEEN 3 AND 13
      AND fundtype = 'AF';

    /* WN is a grade-shifted duplicate of WS (AF only) */
    INSERT INTO payschedulework
        (payplan, areacode, typedata, typeschedule, level, grade, step,
         effectivedate, rate, amcosversionid, locationid, fundtype, link)
    SELECT 'WN', areacode, typedata, typeschedule, level, grade - 6, step,
           effectivedate, rate, amcosversionid, -1, fundtype, link
    FROM payschedulework
    WHERE payplan = 'WS'
      AND grade BETWEEN 7 AND 15
      AND fundtype = 'AF';

    /* Bring in the locationid field for AF */
    UPDATE payschedulework t
    SET locationid = b.locationid
    FROM warehouse.location b
    WHERE t.areacode = b.sourcesystemcode
      AND b.locationtype IN ('Federal Wage System AF', 'Federal Wage System AF Overseas')
      AND t.fundtype = 'AF';

    /* Bring in the locationid field for NAF */
    UPDATE payschedulework t
    SET locationid = b.locationid
    FROM warehouse.location b
    WHERE t.areacode = b.sourcesystemcode
      AND b.locationtype IN ('Federal Wage System NAF', 'Federal Wage System NAF Overseas')
      AND t.fundtype = 'NAF';

    /* Collapse many releases per effective date to the max */
    DROP TABLE IF EXISTS payschedulefinal;
    CREATE TEMP TABLE payschedulefinal (
        payplan       varchar(2)  NOT NULL,
        areacode      varchar(3)  NOT NULL,
        gradelevel    integer     NOT NULL,
        step          integer     NOT NULL,
        effectivedate timestamp   NOT NULL,
        rate          numeric(18, 2) NOT NULL,
        fundtype      varchar(3)  NOT NULL,
        amcosversionid integer    NOT NULL,
        locationid    integer     NULL
    );

    INSERT INTO payschedulefinal
        (payplan, areacode, gradelevel, step, effectivedate, rate, fundtype,
         locationid, amcosversionid)
    SELECT payplan,
           areacode,
           grade,
           step,
           MAX(effectivedate) AS maxeffectivedate,
           MAX(rate)          AS maxrate,
           fundtype,
           locationid,
           amcosversionid
    FROM payschedulework
    WHERE areacode IS NOT NULL
    GROUP BY payplan, areacode, grade, step, fundtype, locationid, amcosversionid;

    /* Call out any unidentified locationid (runs in every mode, per source) */
    IF EXISTS (SELECT 1 FROM payschedulefinal WHERE locationid IS NULL) THEN
        RAISE EXCEPTION 'Invalid location codes';
    END IF;

    /* If we aren't debugging then execute the delete and insert */
    IF NOT p_debug THEN
        DELETE FROM "PaySchedule".payschedule_wage
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO "PaySchedule".payschedule_wage
            (payplan, areacode, gradetype, gradelevel, step, ratetype,
             dateeffective, rate, fundtype, locationid, amcosversionid)
        SELECT payplan,
               areacode,
               payplan,
               gradelevel,
               step,
               'Hourly',
               effectivedate,
               rate,
               fundtype,
               locationid,
               amcosversionid
        FROM payschedulefinal;
    END IF;

    DROP TABLE IF EXISTS payschedulework;
    DROP TABLE IF EXISTS payschedulefinal;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchpayschedulenf
--   Convert raw NF (non-appropriated fund wage) pay-plan data into pay schedules
--   and load crunch.nfpayprocessed for the prime wage areas.
--
--   Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
--   CrunchPayScheduleNF.sql (Dan Hogan, 2021-04-21).
--
--   Reads: lookup.payplan, lookup.wagearea, warehouse.location,
--          "PaySchedule".dcpasnfraw, "PaySchedule".localitypay,
--          "PaySchedule".opmexraw, "PaySchedule".payschedule_g_series,
--          xwalk.wageareatofips, xwalk.localitypayareatofips,
--          data.payschedules.  Writes: crunch.nfpayprocessed.
--
--   Conventions (see 006d phase-1 template):
--     * @Debug -> p_debug boolean DEFAULT false; p_debug = true is a DRY RUN
--       (the DELETE/INSERT into crunch.nfpayprocessed is guarded by IF NOT p_debug).
--     * IF @Debug = 1 result-set dump blocks and the informational "missing prime
--       payschedule" SELECT dump are dropped (no runtime effect; RAISERROR was
--       already commented out in the source).
--     * #temp -> CREATE TEMP TABLE; UPDATE..FROM self-join rewritten (see below).
--     * schema case: "PaySchedule" quoted; lookup/warehouse/xwalk/data/crunch lower.
--     * every numeric/string literal preserved verbatim (incl. the hard-coded
--       amcosversionid = 202401 in the pay-band-6 minimum-pay lookup — a source
--       quirk, kept as-is).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayschedulenf(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nfcreation            integer;
    v_startdate             date;
    v_enddate               date;
    v_payband6maximumpay    numeric(17, 2);
    v_payband6minimumfactor numeric(6, 4);
    v_payband6minimumpay    numeric(17, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- skip if the requested version predates the creation of pay plan NF
    SELECT extract(year FROM opmstartdate)::integer * 100 + 1
    INTO v_nfcreation
    FROM lookup.payplan
    WHERE payplan = 'NF';

    IF p_amcosversionid < v_nfcreation THEN
        RAISE NOTICE '% is before creation date of pay plan NF, crunch skipped', p_amcosversionid;
        RETURN;
    END IF;

    -- cast a wider range for the start since the max will get the right value based on the end date below
    v_startdate := make_date(left(p_amcosversionid::text, 4)::integer - 2, 1, 1);
    -- the end date is always going to be the last day of the year of the amcosversion
    v_enddate := make_date(left(p_amcosversionid::text, 4)::integer, 12, 31);

    DROP TABLE IF EXISTS payschedule;
    CREATE TEMP TABLE payschedule (
        wagearea       varchar(3)     NOT NULL,
        schedulenumber varchar(4)     NOT NULL,
        schedulename   varchar(50)    NULL,
        payband        smallint       NOT NULL,
        dateeffective  date           NULL,
        paybandmin     numeric(17, 2) NULL,
        paybandmax     numeric(17, 2) NULL,
        amcosversionid integer        NOT NULL,
        gslocationid   integer        NULL,
        gslocationname varchar(150)   NULL,
        locationid     integer        NULL
    );

    INSERT INTO payschedule
        (wagearea, schedulenumber, schedulename, payband, dateeffective,
         paybandmin, paybandmax, amcosversionid, locationid)
    SELECT a.wagearea,
           a.schedulearea,
           a.areaname,
           b.payband,
           c.effectivedate,
           c.payminannual,
           c.paymaxannual,
           p_amcosversionid,
           z.locationid
    FROM lookup.wagearea AS a
        LEFT OUTER JOIN warehouse.location AS z
            ON a.schedulearea = z.sourcesystemcode
        /* cross join because we want to make sure have all payband levels
           some levels (namely 6) don't have costs generated for them from DCPAS due to
           an overarching rule which we'll fill in for later */
        CROSS JOIN
        (
            SELECT 1 AS payband
            UNION
            SELECT 2
            UNION
            SELECT 3
            UNION
            SELECT 4
            UNION
            SELECT 5
            UNION
            SELECT 6
        ) AS b
        LEFT OUTER JOIN
        (
            SELECT payband,
                   MAX(payminannual) AS payminannual,
                   MAX(paymaxannual) AS paymaxannual,
                   wageschedule,
                   MAX(effectivedate) AS effectivedate
            FROM "PaySchedule".dcpasnfraw
            WHERE effectivedate BETWEEN v_startdate AND v_enddate
            GROUP BY payband, wageschedule
        ) AS c
            ON a.schedulearea = c.wageschedule
               AND b.payband = c.payband
    WHERE z.locationtype = 'FWS NAF';

    /* In order to set the pay later for specific scenarios we need to crosswalk wage to OPM
       locality (GS) so we can bring in the comparable pay */
    DROP TABLE IF EXISTS xwalktemp;
    CREATE TEMP TABLE xwalktemp AS
    SELECT *
    FROM
    (
        SELECT a.wagearea,
               a.schedulearea,
               a.statecode,
               a.countycode,
               a.citycode,
               c.localityrate,
               c.localitycode,
               e.rate,
               e.step,
               e.gradelevel,
               e.locationid,
               'unknown' AS mystatus
        FROM xwalk.wageareatofips AS a
            INNER JOIN xwalk.localitypayareatofips AS b
                ON a.statecode = b.statecode
                   AND a.countycode = b.countycode
                   AND b.amcosversionid = a.amcosversionid
            LEFT OUTER JOIN "PaySchedule".localitypay AS c
                ON c.localitycode = b.localitycode
                   AND c.amcosversionid = b.amcosversionid
            LEFT OUTER JOIN warehouse.location AS d
                ON d.sourcesystemcode = c.localitycode
            LEFT OUTER JOIN "PaySchedule".payschedule_g_series AS e
                ON e.locationid = d.locationid
        WHERE a.amcosversionid = p_amcosversionid
              AND a.fundtype = 'NAF'
              AND e.payplan = 'GS'
              AND e.categorysubgroupcode = '-1'
              AND e.step = 1
              AND e.gradelevel = 15
              AND e.amcosversionid = p_amcosversionid
    ) AS a;

    /* narrow things down so we only have the maximum pay per wage schedule.
       Source: UPDATE #XWalk SET MyStatus='keep' FROM #XWalk a LEFT JOIN
       (SELECT ScheduleArea, MAX(Rate) FROM #XWalk GROUP BY ScheduleArea) b
       ON a.WageArea=b.ScheduleArea AND a.Rate=b.myrate.  MyStatus starts 'unknown'
       (not NULL), so per port rule this is rewritten as a correlated subquery that
       marks 'keep' ONLY the matched (max-rate) rows -- matching the comment's intent
       rather than the literal self-join-with-no-WHERE (which would mark every row). */
    UPDATE xwalktemp t
    SET mystatus = 'keep'
    WHERE t.rate = (SELECT MAX(b.rate)
                    FROM xwalktemp b
                    WHERE b.schedulearea = t.wagearea);

    -- bring in the GS info which we'll need for pay setting later
    -- (WHERE b.MyStatus='keep' collapses the source LEFT JOIN to an inner join;
    --  gslocationid/gslocationname start NULL so a PG inner-join UPDATE..FROM matches.)
    UPDATE payschedule t
    SET gslocationid = b.locationid,
        gslocationname = b.localitycode
    FROM xwalktemp b
    WHERE t.schedulenumber = b.wagearea
      AND b.mystatus = 'keep';

    SELECT rate
    INTO v_payband6maximumpay
    FROM "PaySchedule".opmexraw
    WHERE payplan = 'EX'
          AND level = 'Level II'
          AND ratetype = 'Annual'
          AND amcosversionid = p_amcosversionid;

    v_payband6minimumfactor := crunch.getsinglevalue('NF', 'Level6MinFactor', p_amcosversionid);

    SELECT rate * v_payband6minimumfactor
    INTO v_payband6minimumpay
    FROM data.payschedules
    WHERE payplan = 'GS'
          AND categorysubgroupcode = '-1'
          AND gradelevel = '15'
          AND step = '1'
          AND amcosversionid = 202401
          AND ratetype = 'Annual'
          AND locationid = -1;

    /* Set the effective date for pay band 6 when we don't already have that info */
    UPDATE payschedule
    SET dateeffective = v_startdate
    WHERE payband = 6
          AND dateeffective IS NULL;

    /* Set the minimum pay for pay band 6 when we don't already have that info */
    UPDATE payschedule
    SET paybandmin = v_payband6minimumpay
    WHERE payband = 6
          AND (paybandmin IS NULL OR paybandmin = 0);

    -- Set the maximum pay for pay band 6 when we don't already have that info
    UPDATE payschedule
    SET paybandmax = v_payband6maximumpay
    WHERE payband = 6
          AND (paybandmax IS NULL OR paybandmax = 0);

    -- null min/max values we remove due to lack of pay data
    DELETE FROM payschedule
    WHERE paybandmin IS NULL
          OR paybandmax IS NULL;

    IF NOT p_debug THEN
        DELETE FROM crunch.nfpayprocessed
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.nfpayprocessed
            (payplan, gradetype, payband, minpay, maxpay, locationid, amcosversionid)
        SELECT 'NF',
               'NF',
               payband,
               paybandmin,
               paybandmax,
               locationid,
               amcosversionid
        FROM payschedule
        /* for NF the 'sub' wage schedules are not used by DCPAS so we only generate pay
           for the 'prime' wage areas where the area and schedule number are the same */
        WHERE wagearea = schedulenumber;
    END IF;

    DROP TABLE IF EXISTS payschedule;
    DROP TABLE IF EXISTS xwalktemp;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CrunchPayScheduleCA  -> crunch.crunchpayscheduleca
--
-- Ports AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchPayscheduleCA.sql.
-- Builds the CA (Compensation for Members of Boards/Commissions, exec pay plan)
-- pay schedule for every Locality Pay Area: each CA level's base rate escalated
-- by the locality rate, capped at the Level III executive-schedule salary limit
-- (5 U.S.C 5304(g)(2)), written per warehouse location to crunch.opmcaprocessed.
--
-- Reads "PaySchedule".opmcaraw (base rates), "PaySchedule".localitypay (locality
-- rate), warehouse.location (locality-area locations), "PaySchedule".opmexraw
-- (salary limit), lookup.payplan (CA creation date).
--
-- Source has only @AmcosVersionId (no @Debug, no @CrunchTime) so the ported proc
-- keeps just p_amcosversionid; there is no dry-run guard because the source has
-- none. The "before creation date" skip PRINT+RETURN is preserved (RAISE NOTICE
-- + RETURN). Reverse grade numbering (Chairman=1 highest) preserved verbatim.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayscheduleca(
    p_amcosversionid integer DEFAULT -1)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ca_creation_version integer;
    v_salarylimit         numeric(17, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- CA cannot be crunched before the version it was introduced.
    -- Source: @AmcosVersionId < CONCAT(YEAR(OpmStartDate), '01') for pay plan CA.
    -- CONCAT(YEAR(d),'01') == YEAR(d)*100 + 1 (e.g. 2020 -> '202001' -> 202001).
    SELECT (date_part('year', opmstartdate)::integer * 100 + 1)
    INTO v_ca_creation_version
    FROM lookup.payplan
    WHERE payplan = 'CA';

    IF p_amcosversionid < v_ca_creation_version THEN
        RAISE NOTICE '% is before creation date of pay plan CA, crunch skipped', p_amcosversionid;
        RETURN;
    END IF;

    -- CA is limited to the rate for level III of the executive schedule per
    -- 5 U.S.C 5304(g)(2).
    SELECT rate
    INTO v_salarylimit
    FROM "PaySchedule".opmexraw
    WHERE p_amcosversionid = amcosversionid
      AND ratetype = 'Annual'
      AND level = 'Level III';

    --################ Create Pay Schedules
    DELETE FROM crunch.opmcaprocessed
    WHERE amcosversionid = p_amcosversionid;

    INSERT INTO crunch.opmcaprocessed
        (payplan, gradelevel, gradeleveldescription, locationid, ratetype, rate, amcosversionid)
    SELECT a.payplan,
           -- unlike all other pay plans, the gradelevel goes in reverse so 1 is
           -- the highest paid and 3 is the lowest
           CASE
               WHEN a.level = 'Chairman'       THEN 1
               WHEN a.level = 'Vice Chairman'  THEN 2
               WHEN a.level = 'Other Members'  THEN 3
               ELSE NULL
           END,
           a.level,
           c.locationid,
           a.ratetype,
           CASE
               WHEN a.rate * ((b.localityrate / 100) + 1) > v_salarylimit
                   THEN v_salarylimit
               ELSE a.rate * ((b.localityrate / 100) + 1)
           END,
           b.amcosversionid
    FROM "PaySchedule".opmcaraw AS a
        CROSS JOIN "PaySchedule".localitypay AS b
        LEFT OUTER JOIN warehouse.location AS c
            ON c.sourcesystemcode = b.localitycode
    WHERE a.amcosversionid = p_amcosversionid
      AND b.amcosversionid = p_amcosversionid
      AND c.locationtype = 'Locality Pay Area';
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchpayscheduleex
--   Port of [crunch].[CrunchPayScheduleEX] (Dan Hogan, 5/23/2022).
--   Generates the EX (Executive Schedule) pay schedule: reads the raw OPM
--   Executive-level rates from "PaySchedule".opmexraw and lands them in
--   crunch.opmexprocessed, mapping the textual "Level I..V" to a reversed
--   numeric gradelevel (Level I = highest paid = 5, Level V = lowest = 1).
--   The source guards against running before pay plan EX exists (its OPM start
--   year); reproduced here. Source proc has ONLY @AmcosVersionId (no @CrunchTime,
--   no @Debug), so no dry-run guard is added.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayscheduleex(
    p_amcosversionid integer DEFAULT -1)
LANGUAGE plpgsql
AS $$
DECLARE
    v_minversion integer;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- earliest amcosversionid EX can be crunched for = CONCAT(YEAR(OpmStartDate), '01')
    -- e.g. OpmStartDate year 2023 -> 202301 (year * 100 + 01).
    SELECT (EXTRACT(YEAR FROM opmstartdate)::integer * 100 + 1)
    INTO v_minversion
    FROM lookup.payplan
    WHERE payplan = 'EX';

    -- If EX has no OpmStartDate row, v_minversion is NULL and the comparison is
    -- NULL/false, so the crunch proceeds -- matching the T-SQL behavior.
    IF p_amcosversionid < v_minversion THEN
        RAISE NOTICE '% is before creation date of pay plan EX, crunch skipped', p_amcosversionid;
        RETURN;
    END IF;

    --################ Create Pay Schedules
    DELETE FROM crunch.opmexprocessed
    WHERE amcosversionid = p_amcosversionid;

    INSERT INTO crunch.opmexprocessed
        (payplan, gradelevel, gradeleveldescription, ratetype, rate, amcosversionid)
    SELECT payplan,
           -- unlike all other pay plans the gradelevel is reversed: 1 is the
           -- highest paid and 5 the lowest, so Level I -> 5 ... Level V -> 1
           CASE
               WHEN level = 'Level I'   THEN 5
               WHEN level = 'Level II'  THEN 4
               WHEN level = 'Level III' THEN 3
               WHEN level = 'Level IV'  THEN 2
               WHEN level = 'Level V'   THEN 1
               ELSE NULL
           END,
           level,
           ratetype,
           rate,
           amcosversionid
    FROM "PaySchedule".opmexraw
    WHERE amcosversionid = p_amcosversionid;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchpayscheduleig  — IG (Inspector General, single-rate) pay schedule.
--
-- Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchPayScheduleIG.sql.
-- Builds crunch.opmigprocessed from "PaySchedule".opmigraw: after validating the
-- version and confirming raw data is present, it clears the version's rows and
-- inserts a single (TOP 1 / LIMIT 1) Annual rate at gradelevel 0.
--
-- Conventions: source has no @Debug and no @CrunchTime, so neither is added
-- (matches the sibling crunchcy port). @AmcosVersionId -> p_amcosversionid.
-- The version-predates-pay-plan guard (CONCAT(YEAR(OpmStartDate),'01')) is ported
-- verbatim; PRINT -> RAISE NOTICE, RAISERROR('missing version') -> RAISE EXCEPTION.
-- Destination crunch.opmigprocessed columns (payplan, gradelevel, ratetype, rate,
-- amcosversionid) match the source INSERT column list exactly.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayscheduleig(
    p_amcosversionid integer DEFAULT -1)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ig_start_version integer;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- skip if this version predates the creation of pay plan IG
    SELECT CONCAT(EXTRACT(YEAR FROM opmstartdate)::int, '01')::int
    INTO v_ig_start_version
    FROM lookup.payplan
    WHERE payplan = 'IG';

    IF p_amcosversionid < v_ig_start_version THEN
        RAISE NOTICE '% is before creation date of pay plan IG, crunch skipped', p_amcosversionid;
        RETURN;
    END IF;

    -- raw IG pay must be loaded for this version before the crunch can run
    IF NOT EXISTS (
        SELECT 1
        FROM "PaySchedule".opmigraw
        WHERE amcosversionid = p_amcosversionid
    ) THEN
        RAISE EXCEPTION 'Cannot run IG crunch until version % is added to OpmExRaw', p_amcosversionid;
    END IF;

    --################ Create Pay Schedules

    DELETE FROM crunch.opmigprocessed
    WHERE amcosversionid = p_amcosversionid;

    INSERT INTO crunch.opmigprocessed
        (payplan, gradelevel, ratetype, rate, amcosversionid)
    SELECT payplan,
           0,
           ratetype,
           rate,
           amcosversionid
    FROM "PaySchedule".opmigraw
    WHERE amcosversionid = p_amcosversionid
      AND ratetype = 'Annual'
    LIMIT 1;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchpayschedulecy
-- Builds the CY (civilian pay-band) pay schedule from the CY xwalk and the
-- G-series (GS) schedule: MinPay = GS step-1 rate at Min_GS_GL, MaxPay = GS
-- step-10 rate at Max_GS_GL, matched within the same LocationId.
-- Source default @Debug = 0 (writes) -> p_debug DEFAULT false (same semantics).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayschedulecy(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    IF NOT p_debug THEN
        DELETE FROM "PaySchedule".payschedule_cy
        WHERE amcosversionid = p_amcosversionid;

        -- Pay schedule is based on the G-series plan and the CY xwalk that
        -- equates the appropriate GS grade level for each pay band.
        INSERT INTO "PaySchedule".payschedule_cy
            (payplan, gradetype, payband, minpay, maxpay, locationid, amcosversionid)
        SELECT 'CY',
               'CY',
               a.payband,
               b.rate AS minpay,
               c.rate AS maxpay,
               b.locationid,
               p_amcosversionid
        FROM "PaySchedule".payschedule_cy_xwalk AS a
            INNER JOIN "PaySchedule".payschedule_g_series AS b
                ON a.min_gs_gl = b.gradelevel
            INNER JOIN "PaySchedule".payschedule_g_series AS c
                ON a.max_gs_gl = c.gradelevel
                   AND b.locationid = c.locationid
        WHERE p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
              AND b.amcosversionid = p_amcosversionid
              AND c.amcosversionid = p_amcosversionid
              AND b.categorysubgroupcode = '-1'
              AND c.categorysubgroupcode = '-1'
              AND b.payplan = 'GS'
              AND c.payplan = 'GS'
              AND b.step = 1
              AND c.step = 10
              AND b.locationid <> -1
              AND c.locationid <> -1;
    END IF;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchpayschedulegp
-- Derives the GP pay plan rows from the GS annual raw schedule (grade >= 12),
-- writing them back into PaySchedule_G_Series with GP payplan/gradetype and
-- sentinel location/category codes.
-- Source default @Debug = -1 (BIT -> 1 = DRY RUN); ported to p_debug DEFAULT
-- false per convention, so the DEFAULT-invocation behavior differs (see RISKS).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayschedulegp(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    IF NOT p_debug THEN
        DELETE FROM "PaySchedule".payschedule_g_series
        WHERE amcosversionid = p_amcosversionid
              AND payplan = 'GP';

        INSERT INTO "PaySchedule".payschedule_g_series
            (payplan, gradetype, gradelevel, step, rate, amcosversionid, locationid, categorygroupcode, categorysubgroupcode)
        SELECT 'GP',
               'GP',
               gradelevel,
               step,
               rate,
               amcosversionid,
               -1 AS locationid,
               '-1' AS categorygroupcode,
               '-1' AS categorysubgroupcode
        FROM "PaySchedule".payschedule_g_series_raw
        WHERE payplan = 'GS'
              AND ratetype = 'Annual'
              AND gradelevel >= 12
              AND amcosversionid = p_amcosversionid;
    END IF;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchpayscheduledseriesnseries
-- Converts the D-series and N-series pay-schedule crosswalks into real
-- PaySchedule_D_NSeries data. Cross-joins each xwalk row against every locality
-- (LocalityPay + GFEBS-country overseas localities @ 0% locality), fills MinPay
-- from GS step-1 and MaxPay from GS step-10 (+ Additional) grossed up by the
-- locality rate, overrides SES min/max from OpmSesRaw, then writes real rows
-- (joined to a real location) plus BASE PAY rows (locationid -1).
-- Source default @Debug = -1 (BIT -> 1 = DRY RUN); ported to p_debug DEFAULT
-- false per convention, so the DEFAULT-invocation behavior differs (see RISKS).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchpayscheduledseriesnseries(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS mastertable;
    CREATE TEMP TABLE mastertable (
        payplan      varchar(2)  NOT NULL,
        strl         varchar(50) NOT NULL,
        payband      integer     NOT NULL,
        min_gs_gl    varchar(3)  NOT NULL,
        max_gs_gl    varchar(3)  NOT NULL,
        additional   numeric(17, 2),
        localitycode varchar(50) NOT NULL,
        localityrate numeric(17, 2) NOT NULL,
        minpay       numeric(17, 2),
        maxpay       numeric(17, 2)
    );

    INSERT INTO mastertable
        (payplan, strl, payband, min_gs_gl, max_gs_gl, additional, localitycode, localityrate, minpay, maxpay)
    SELECT a.payplan,
           a.strl,
           a.payband,
           a.min_gs_gl,
           a.max_gs_gl,
           a.additional,
           b.localitycode,
           b.localityrate,
           0.0 AS minpay,
           0.0 AS maxpay
    FROM (
        SELECT payplan, strl, payband, min_gs_gl, max_gs_gl, additional
        FROM "PaySchedule".payschedule_dseries_xwalk
        WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        UNION
        SELECT payplan, '-1', payband, min_gs_gl, max_gs_gl, additional
        FROM "PaySchedule".payschedule_nseries_xwalk
        WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
    ) AS a
    CROSS JOIN (
        SELECT localitycode, localityrate, amcosversionid
        FROM "PaySchedule".localitypay
        UNION
        -- overseas pay is based on the OPM GS base schedule (0% locality)
        SELECT sourcesystemcode AS localitycode,
               0 AS localityrate,
               p_amcosversionid AS amcosversionid
        FROM warehouse.location
        WHERE locationtype = 'GFEBS Country'
              AND sourcesystemcode <> '-1'
    ) AS b
    WHERE p_amcosversionid = b.amcosversionid;

    -- bring in minimums which are step 1s
    -- (source re-aliases the UPDATE target #MasterTable as "a" in FROM; PG forbids
    --  that, so we drop it and reference the target columns directly. Inner join +
    --  minpay pre-seeded to 0.0 -> unmatched rows keep 0.0 in both engines.)
    UPDATE mastertable
    SET minpay = b.rate * (1 + mastertable.localityrate / 100)
    FROM "PaySchedule".payschedule_g_series_raw AS b
    WHERE mastertable.min_gs_gl = CAST(b.gradelevel AS varchar(3))
          AND b.step = 1
          AND b.amcosversionid = p_amcosversionid
          AND b.payplan = 'GS'
          AND b.ratetype = 'Annual';

    -- bring in maximums which are step 10s + any additional amount
    UPDATE mastertable
    SET maxpay = b.rate * (1 + mastertable.localityrate / 100) + COALESCE(mastertable.additional, 0)
    FROM "PaySchedule".payschedule_g_series_raw AS b
    WHERE mastertable.max_gs_gl = CAST(b.gradelevel AS varchar(3))
          AND b.step = 10
          AND b.amcosversionid = p_amcosversionid
          AND b.payplan = 'GS'
          AND b.ratetype = 'Annual';

    -- bring in min ses pay (scalar subquery; source assumes a single OpmSesRaw row)
    UPDATE mastertable
    SET minpay = (
        SELECT minpay
        FROM "PaySchedule".opmsesraw
        WHERE ratetype = 'Annual'
              AND amcosversionid = p_amcosversionid
    )
    WHERE min_gs_gl = 'SES';

    -- bring in max ses pay (TOP (1) ORDER BY MaxPay -> LIMIT 1)
    UPDATE mastertable
    SET maxpay = (
        SELECT maxpay
        FROM "PaySchedule".opmsesraw
        WHERE ratetype = 'Annual'
              AND amcosversionid = p_amcosversionid
        ORDER BY maxpay
        LIMIT 1
    )
    WHERE max_gs_gl = 'SES';

    IF NOT p_debug THEN
        DELETE FROM "PaySchedule".payschedule_d_nseries
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO "PaySchedule".payschedule_d_nseries
            (payplan, strl, gradetype, payband, minpay, maxpay, locationid, amcosversionid)
        SELECT a.payplan,
               a.strl,
               a.payplan,
               a.payband,
               a.minpay,
               a.maxpay,
               b.locationid,
               p_amcosversionid
        FROM mastertable AS a
            INNER JOIN warehouse.location AS b
                ON a.localitycode = b.sourcesystemcode
        UNION
        -- base pay which doesn't have a real locationid
        SELECT a.payplan,
               a.strl,
               a.payplan,
               a.payband,
               a.minpay,
               a.maxpay,
               -1,
               p_amcosversionid
        FROM mastertable AS a
        WHERE a.localitycode = 'BASE PAY';
    END IF;

    DROP TABLE IF EXISTS mastertable;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CopyValues  (utility — bulk-copy every AmcosVersionId-partitioned table
--                     from one version to another).
--
-- Ports AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CopyValues.sql to
-- PostgreSQL. Facilitates running the next version's crunches before all of the
-- next version's data exists, by cloning a prior version's rows under a new
-- AmcosVersionId.
--
-- Faithful structural port:
--   * The T-SQL OUTER CURSOR over INFORMATION_SCHEMA (every table in the listed
--     schemas that carries an "amcosversionid" column and is not a view) becomes
--     a "FOR rec IN (SELECT ...) LOOP". The table-discovery query is preserved
--     verbatim (same schema list, same column filter, same non-view subquery,
--     same ORDER BY) — no hardcoded table list.
--   * The T-SQL INNER CURSOR that walked each table's columns to build the
--     INSERT/SELECT column lists (skipping IDENTITY columns, substituting the
--     new version literal for the amcosversionid column) is rewritten set-based
--     with string_agg over information_schema.columns. Both lists are aggregated
--     with the SAME ORDER BY (ordinal_position) so the INSERT and SELECT column
--     positions stay aligned — reproducing the exact generated INSERT...SELECT.
--   * Dynamic EXEC(@sql) becomes EXECUTE of a string built with format(), using
--     %I for schema/table identifiers so the CASE-SENSITIVE schemas ("DMDC",
--     "PaySchedule", "BLS_OES", "BLS_ECT", "load_GFEBS") are correctly quoted in
--     the generated SQL (the source concatenated raw "schema.table", which would
--     fold-to-lowercase and fail in PostgreSQL).
--   * @Debug is a DRY RUN: the source always PRINTs each statement and only
--     EXECs it when @Debug = 0. We RAISE NOTICE every statement (preserving the
--     "print the statements to be run" behavior) and guard the EXECUTE with
--     "IF NOT p_debug". Source @Debug default is 1 (print only), so p_debug
--     DEFAULT true preserves the safe dry-run default.
--   * RAISERROR(..., 18, 1) -> RAISE EXCEPTION (aborts the call, so the source's
--     ELSE wrapper is unnecessary).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.copyvalues(
    p_amcosversionidnew integer DEFAULT -1,     -- the new version of data you want to create
    p_amcosversionidprior integer DEFAULT -1,   -- the version of data you want to copy
    p_debug boolean DEFAULT false)               -- true = only print the statements; false = execute them
LANGUAGE plpgsql
AS $$
DECLARE
    rec           record;
    v_insertcols  text;
    v_selectcols  text;
    v_deletesql   text;
    v_finalsql    text;
BEGIN
    IF p_amcosversionidnew <= p_amcosversionidprior THEN
        RAISE EXCEPTION 'copy to (new) must be greater than the prior versionid';
    END IF;

    -- get a list of all tables with the amcosversionid column for particular schemas
    FOR rec IN
        SELECT c.table_schema, c.table_name
        FROM information_schema.columns c
        WHERE c.table_schema IN ('crunch', 'dataload', 'data', 'DMDC', 'load_inventory', 'PaySchedule',
                                 'load_training', 'lookup', 'xwalk', 'BLS_OES', 'BLS_ECT', 'load_GFEBS')
          AND c.column_name = 'amcosversionid'
          -- don't try to do an insert on a view
          AND c.table_name IN (
                  SELECT t.table_name
                  FROM information_schema.tables t
                  WHERE t.table_type <> 'VIEW'
              )
        ORDER BY c.table_schema, c.table_name
    LOOP
        -- first step is to clear out any data already there for the new version
        v_deletesql := format('DELETE FROM %I.%I WHERE amcosversionid = %s',
                              rec.table_schema, rec.table_name, p_amcosversionidnew);
        RAISE NOTICE '%', v_deletesql;
        IF NOT p_debug THEN
            EXECUTE v_deletesql;
        END IF;

        -- build the insert/select column lists from the table's columns.
        -- IDENTITY columns are excluded (no identity inserts, matching the
        -- source COLUMNPROPERTY IsIdentity check); for the amcosversionid column
        -- we don't copy last year's value, we substitute the new version.
        SELECT
            string_agg(quote_ident(cc.column_name), ', ' ORDER BY cc.ordinal_position),
            string_agg(
                CASE WHEN cc.column_name = 'amcosversionid'
                     THEN p_amcosversionidnew::text
                     ELSE quote_ident(cc.column_name)
                END, ', ' ORDER BY cc.ordinal_position)
        INTO v_insertcols, v_selectcols
        FROM information_schema.columns cc
        WHERE cc.table_schema = rec.table_schema
          AND cc.table_name = rec.table_name
          AND cc.is_identity = 'NO';

        -- nothing insertable (all columns identity) -> skip
        CONTINUE WHEN v_insertcols IS NULL;

        -- finalize the insert (copy prior version's rows under the new version)
        v_finalsql := format('INSERT INTO %I.%I (%s) SELECT %s FROM %I.%I WHERE amcosversionid = %s',
                            rec.table_schema, rec.table_name, v_insertcols, v_selectcols,
                            rec.table_schema, rec.table_name, p_amcosversionidprior);
        RAISE NOTICE '%', v_finalsql;
        IF NOT p_debug THEN
            EXECUTE v_finalsql;
        END IF;
    END LOOP;
END;
$$;
