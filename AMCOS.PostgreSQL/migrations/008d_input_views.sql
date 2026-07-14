-- ============================================================================
-- 008d_input_views.sql
-- AMCOS cost-engine port: input/lookup VIEWs (SQL Server -> PostgreSQL).
--
-- Ported from SQL Server sources under AMCOS.AMCOS2020_MAR/:
--   data.categorygroup        <- data/Views/CategoryGroup.sql   (dependency of the two below)
--   data.categorysubgroup     <- data/Views/CategorySubgroup.sql
--   data.costswithdescriptions <- data/Views/CostsWithDescriptions.sql
--   xwalk.payplantype         <- xwalk/Views/PayPlanType.sql
--   xwalk.ppxwalkgradelevel   <- xwalk/Views/PPXwalkGradeLevel.sql
--
-- All identifiers lowercase/unquoted; schemas schema-qualified. Quoted-capital
-- schema "PaySchedule" per project convention. No SET search_path.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- data.categorygroup
-- Latest-nomenclature category group per (payplan, code): union of military
-- CMF/branch/FA (E/O/W), GS & Wage occupational groups, and SOC major groups.
-- Consumed by data.categorysubgroup and data.costswithdescriptions below.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW data.categorygroup AS
WITH cte AS (
    SELECT b.payplan,
           a.code        AS categorygroupcode,
           a.description AS categorygroupdescription,
           a.amcosversionidstart,
           a.amcosversionidend
    FROM lookup.cmf_branch_fa a
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Enlisted')) b
    WHERE a.gradetype = 'E'
    UNION ALL
    SELECT b.payplan, a.code, a.description, a.amcosversionidstart, a.amcosversionidend
    FROM lookup.cmf_branch_fa a
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Officer')) b
    WHERE a.gradetype = 'O'
    UNION ALL
    SELECT b.payplan, a.code, a.description, a.amcosversionidstart, a.amcosversionidend
    FROM lookup.cmf_branch_fa a
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Warrant')) b
    WHERE a.gradetype = 'W'
    UNION ALL
    SELECT b.payplan,
           og.occupationalgroupnumber AS categorygroupcode,
           og.grouptitle              AS categorygroupdescription,
           og.amcosversionidstart,
           og.amcosversionidend
    FROM lookup.gs_occupationalgroup og
        CROSS JOIN (
            SELECT payplan FROM analysis.getpayplans('Acq')
            UNION SELECT payplan FROM analysis.getpayplans('Lab Demo')
            UNION SELECT payplan FROM analysis.getpayplans('G')
            UNION SELECT payplan FROM analysis.getpayplans('SES')
            UNION SELECT 'CY' UNION SELECT 'AD' UNION SELECT 'CA' UNION SELECT 'EE'
            UNION SELECT 'EF' UNION SELECT 'EX' UNION SELECT 'IE' UNION SELECT 'IP'
            UNION SELECT 'IG' UNION SELECT 'SL' UNION SELECT 'ST' UNION SELECT 'ZZ'
            UNION SELECT 'NF'
        ) b
    UNION ALL
    SELECT b.payplan,
           a.occupationalgroupnumber AS categorygroupcode,
           a.grouptitle              AS categorygroupdescription,
           a.amcosversionidstart,
           a.amcosversionidend
    FROM lookup.wage_occupationalgroup a
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Wage')) b
    UNION ALL
    SELECT 'CCE'::varchar       AS payplan,
           occupationcode       AS categorygroupcode,
           occupationtitle      AS categorygroupdescription,
           amcosversionidstart,
           amcosversionidend
    FROM lookup.socstructure
    WHERE grouplevel = 'Major'
)
SELECT a.payplan, a.categorygroupcode, a.categorygroupdescription
FROM cte a
    INNER JOIN (
        SELECT categorygroupcode, MAX(amcosversionidend) AS amcosversionidmax
        FROM cte
        GROUP BY categorygroupcode
    ) b ON a.amcosversionidend = b.amcosversionidmax
       AND a.categorygroupcode = b.categorygroupcode;


-- ----------------------------------------------------------------------------
-- data.categorysubgroup
-- One row per (payplan, subgroup code) with the latest nomenclature description,
-- decorated with its parent category group. Union of military MOS/AOC/WOMOS,
-- GS occupational series, wage series, and SOC (contractor) structures.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW data.categorysubgroup AS
WITH cte AS (
    SELECT b.payplan                              AS payplan,
           mos.mos                                AS categorysubgroupcode,
           mos.description                        AS categorysubgroupdescription,
           mos.amcosversionidstart,
           mos.amcosversionidend
    FROM lookup.mos mos
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Enlisted')) AS b
    UNION ALL
    SELECT b.payplan,
           aoc.aoc                                AS categorysubgroupcode,
           aoc.description                        AS categorysubgroupdescription,
           aoc.amcosversionidstart,
           aoc.amcosversionidend
    FROM lookup.aoc AS aoc
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Officer')) AS b
    UNION ALL
    SELECT b.payplan,
           womos.womos                            AS categorysubgroupcode,
           womos.description                      AS categorysubgroupdescription,
           womos.amcosversionidstart,
           womos.amcosversionidend
    FROM lookup.womos womos
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Warrant')) AS b
    UNION ALL
    SELECT b.payplan,
           gs_occupationalseries.occupationalseriesnumber AS categorysubgroupcode,
           gs_occupationalseries.seriestitle              AS categorysubgroupdescription,
           gs_occupationalseries.amcosversionidstart,
           gs_occupationalseries.amcosversionidend
    FROM lookup.gs_occupationalseries AS gs_occupationalseries
        CROSS JOIN (
            SELECT payplan FROM analysis.getpayplans('Acq')
            UNION
            SELECT payplan FROM analysis.getpayplans('Lab Demo')
            UNION
            SELECT payplan FROM analysis.getpayplans('G')
            UNION
            SELECT payplan FROM analysis.getpayplans('SES')
            UNION SELECT 'CY'
            UNION SELECT 'AD'
            UNION SELECT 'CA'
            UNION SELECT 'EE'
            UNION SELECT 'EF'
            UNION SELECT 'EX'
            UNION SELECT 'IE'
            UNION SELECT 'IP'
            UNION SELECT 'IG'
            UNION SELECT 'SL'
            UNION SELECT 'ST'
            UNION SELECT 'ZZ'
            UNION SELECT 'NF'
        ) AS b
    UNION ALL
    SELECT b.payplan,
           a.occupationalseriesnumber,
           a.seriestitle,
           a.amcosversionidstart,
           a.amcosversionidend
    FROM lookup.wage_occupationalseries AS a
        CROSS JOIN (SELECT payplan FROM analysis.getpayplans('Wage')) AS b
    UNION ALL
    SELECT 'CCE',
           socstructure.occupationcode            AS categorysubgroupcode,
           socstructure.occupationtitle           AS categorysubgroupdescription,
           socstructure.amcosversionidstart,
           socstructure.amcosversionidend
    FROM lookup.socstructure socstructure
    WHERE socstructure.grouplevel = 'Detailed'
)
SELECT subgrp.payplan,
       subgrp.categorysubgroupcode,
       subgrp.categorysubgroupdescription,
       categorygroup.categorygroupcode,
       categorygroup.categorygroupdescription
FROM cte AS subgrp
    INNER JOIN (
        -- when displaying the nomenclatures we only care about the latest name
        SELECT categorysubgroupcode,
               MAX(amcosversionidend) AS amcosversionidmax
        FROM cte
        GROUP BY categorysubgroupcode
    ) AS b
        ON subgrp.amcosversionidend = b.amcosversionidmax
           AND subgrp.categorysubgroupcode = b.categorysubgroupcode
    LEFT OUTER JOIN data.categorygroup AS categorygroup
        ON left(subgrp.categorysubgroupcode, 2) = left(categorygroup.categorygroupcode, 2)
           AND subgrp.payplan = categorygroup.payplan;


-- ----------------------------------------------------------------------------
-- data.costswithdescriptions
-- data.costs joined to its human-readable descriptions (group, subgroup, career
-- program, location, weapon system). Latest-version weapon system / career
-- program names picked via MAX(amcosversionidend).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW data.costswithdescriptions AS
SELECT costs.payplan,
       costs.categorygroupcode,
       COALESCE(categorygroup.categorygroupdescription, 'Average')       AS categorygroupdescription,
       costs.categorysubgroupcode,
       COALESCE(categorysubgroup.categorysubgroupdescription, 'Average') AS categorysubgroupdescription,
       costs.careerprogramnumber,
       COALESCE(cp.title, 'None')                                       AS cp_title,
       costs.strl,
       costs.locationid,
       COALESCE(loc.displayname, 'Average')                             AS location_name,
       costs.dependentstatus,
       costs.numberofdependents,
       costs.costelementid,
       costs.appropriationgroup,
       costs.appn,
       costs.costelementcategory,
       costs.costelementname,
       costs.description,
       costs.armycestitle,
       costs.osdcapecestitle,
       costs.showorder,
       costs.gradetype,
       costs.gradelevel,
       weaponsystem.weaponsystemname,
       costs.weaponsystemid,
       costs.amount,
       costs.amcosversionid
FROM data.costs costs
    LEFT OUTER JOIN data.categorysubgroup categorysubgroup
        ON categorysubgroup.payplan = costs.payplan
           AND categorysubgroup.categorysubgroupcode = costs.categorysubgroupcode
    LEFT OUTER JOIN data.categorygroup categorygroup
        ON categorygroup.categorygroupcode = costs.categorygroupcode
           AND costs.payplan = categorygroup.payplan
    LEFT OUTER JOIN (
        SELECT a.weaponsystemid,
               a.weaponsystemname
        FROM lookup.weaponsystem AS a
            INNER JOIN (
                SELECT weaponsystemid,
                       MAX(amcosversionidend) AS maxversion
                FROM lookup.weaponsystem
                GROUP BY weaponsystemid
            ) AS b
                ON a.weaponsystemid = b.weaponsystemid
                   AND a.amcosversionidend = b.maxversion
    ) AS weaponsystem
        ON weaponsystem.weaponsystemid = costs.weaponsystemid
    LEFT OUTER JOIN (
        SELECT a.careerprogramnumber,
               a.title
        FROM lookup.armycareerprogram AS a
            INNER JOIN (
                SELECT careerprogramnumber,
                       MAX(amcosversionidend) AS maxversion
                FROM lookup.armycareerprogram
                GROUP BY careerprogramnumber
            ) AS b
                ON a.careerprogramnumber = b.careerprogramnumber
                   AND a.amcosversionidend = b.maxversion
    ) AS cp
        ON costs.careerprogramnumber = cp.careerprogramnumber
    LEFT OUTER JOIN warehouse.location AS loc
        ON loc.locationid = costs.locationid;


-- ----------------------------------------------------------------------------
-- xwalk.payplantype
-- Classifies each current pay plan into E / O / W / CTR / CIV.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW xwalk.payplantype AS
SELECT payplan,
       CASE
           WHEN payplan IN ('AE', 'RE', 'NE')   THEN 'E'
           WHEN payplan IN ('AO', 'RO', 'NO')   THEN 'O'
           WHEN payplan IN ('AWO', 'RWO', 'NWO') THEN 'W'
           WHEN payplan = 'CCE'                 THEN 'CTR'
           ELSE 'CIV'
       END AS payplantype
FROM lookup.payplan
WHERE displaytitle IS NOT NULL
      AND (SELECT MAX(amcosversionid) FROM lookup.amcosversion)
          BETWEEN amcosversionidstart AND amcosversionidend;


-- ----------------------------------------------------------------------------
-- xwalk.ppxwalkgradelevel
-- Crosswalk of GS/SES pay-plan + grade level to target pay plan / pay band.
-- Grade levels are compared and produced as TEXT (BETWEEN is lexicographic, as
-- in the SQL Server source); the outer select truncates to 2 chars.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW xwalk.ppxwalkgradelevel AS
SELECT gs_ses_payplan,
       CAST(gs_ses_gradelevel AS varchar(2)) AS gs_ses_gradelevel,
       topayplan,
       togradelevelpayband,
       strl
FROM (
    SELECT DISTINCT
           b.payplan          AS gs_ses_payplan,
           b.gradelevel       AS gs_ses_gradelevel,
           a.targetpayplan    AS topayplan,
           a.targetgradelevel AS togradelevelpayband,
           CAST('Not Applicable' AS varchar(20)) AS strl
    FROM xwalk.gradelevel AS a
        INNER JOIN (
            SELECT DISTINCT
                   payplan,
                   gradelevel
            FROM data.costs
            WHERE payplan IN ('GS', 'SES')
        ) AS b
            ON a.basepayplan = b.payplan
               -- data.costs.gradelevel is smallint; band bounds are varchar grade codes.
               -- Source (SQL Server) compared via implicit varchar->int conversion (numeric),
               -- so cast the bounds to smallint here to preserve numeric ordering.
               AND b.gradelevel BETWEEN a.basegradelevel_low::smallint AND a.basegradelevel_high::smallint
    WHERE (SELECT MAX(amcosversionid) FROM lookup.amcosversion)
          BETWEEN a.amcosversionidstart AND a.amcosversionidend

    UNION
    -- CY
    SELECT b.frompayplan,
           b.fromgradelevel,
           a.payplan,
           a.payband::varchar,   -- payband is smallint; output payband column is varchar (warehouse.ppxwalk.targetgradelevel)
           'Not Applicable' AS strl
    FROM "PaySchedule".payschedule_cy_xwalk AS a
        INNER JOIN (
            SELECT DISTINCT
                   payplan    AS frompayplan,
                   gradelevel AS fromgradelevel
            FROM data.costs
            WHERE payplan IN ('GS')
        ) AS b
            ON b.fromgradelevel BETWEEN a.min_gs_gl::smallint AND a.max_gs_gl::smallint
    WHERE (SELECT MAX(amcosversionid) FROM lookup.amcosversion)
          BETWEEN a.amcosversionidstart AND a.amcosversionidend

    UNION
    -- D series
    SELECT b.frompayplan,
           b.fromgradelevel,
           a.targetpayplan,
           a.targetgradelevel,
           a.targetstrl
    FROM (
        SELECT CASE
                   WHEN a.min_gs_gl = 'SES' AND a.max_gs_gl = 'SES' THEN 'SES'
                   ELSE 'GS'
               END AS payplan,
               CASE
                   WHEN a.min_gs_gl = 'SES' THEN '1'
                   ELSE a.min_gs_gl
               END AS gs_ses_basegradelevel_low,
               CASE
                   WHEN a.max_gs_gl = 'SES' THEN '3'
                   ELSE a.max_gs_gl
               END AS gs_ses_basegradelevel_high,
               payplan  AS targetpayplan,
               payband::varchar AS targetgradelevel,
               strl     AS targetstrl
        FROM "PaySchedule".payschedule_dseries_xwalk AS a
        WHERE (SELECT MAX(amcosversionid) FROM lookup.amcosversion)
              BETWEEN amcosversionidstart AND amcosversionidend
    ) AS a
        INNER JOIN (
            SELECT DISTINCT
                   payplan    AS frompayplan,
                   gradelevel AS fromgradelevel
            FROM data.costs
            WHERE payplan IN ('GS', 'SES')
        ) AS b
            ON a.payplan = b.frompayplan
               AND b.fromgradelevel BETWEEN a.gs_ses_basegradelevel_low::smallint AND a.gs_ses_basegradelevel_high::smallint

    UNION
    -- N series
    SELECT b.frompayplan,
           b.fromgradelevel,
           a.targetpayplan,
           a.targetgradelevel,
           'Not Applicable' AS strl
    FROM (
        SELECT CASE
                   WHEN a.min_gs_gl = 'SES' AND a.max_gs_gl = 'SES' THEN 'SES'
                   ELSE 'GS'
               END AS payplan,
               CASE
                   WHEN a.min_gs_gl = 'SES' THEN '1'
                   ELSE a.min_gs_gl
               END AS gs_ses_basegradelevel_low,
               CASE
                   WHEN a.max_gs_gl = 'SES' THEN '3'
                   ELSE a.max_gs_gl
               END AS gs_ses_basegradelevel_high,
               payplan  AS targetpayplan,
               payband::varchar AS targetgradelevel
        FROM "PaySchedule".payschedule_nseries_xwalk AS a
        WHERE (SELECT MAX(amcosversionid) FROM lookup.amcosversion)
              BETWEEN amcosversionidstart AND amcosversionidend
    ) AS a
        INNER JOIN (
            SELECT DISTINCT
                   payplan    AS frompayplan,
                   gradelevel AS fromgradelevel
            FROM data.costs
            WHERE payplan IN ('GS', 'SES')
        ) AS b
            ON a.payplan = b.frompayplan
               AND b.fromgradelevel BETWEEN a.gs_ses_basegradelevel_low::smallint AND a.gs_ses_basegradelevel_high::smallint

    -- G and SES series, they just join on themselves
    UNION
    SELECT DISTINCT
           'GS' AS payplan,
           gradelevel,
           payplan,
           gradelevel::varchar,   -- payband column is text across the UNION (D/N/CY paybands are alphanumeric)
           'Not Applicable'
    FROM data.costs
    WHERE payplan IN ('GS', 'GL', 'GG', 'GP')

    UNION
    SELECT DISTINCT
           'SES' AS payplan,
           gradelevel,
           payplan,
           gradelevel::varchar,   -- payband column is text across the UNION (D/N/CY paybands are alphanumeric)
           'Not Applicable'
    FROM data.costs
    WHERE payplan IN ('SES')
) AS a;
