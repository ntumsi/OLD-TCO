-- ============================================================================
-- data.payschedules  —  PostgreSQL port of SQL Server view [data].[PaySchedules]
-- Source: AMCOS.AMCOS2020_MAR/data/Views/PaySchedules.sql
--
-- Faithful UNION [ALL] translation of the processed "PaySchedule".* pay tables
-- read by the civilian cost crunches. Every UNION vs UNION ALL is preserved
-- exactly (they differ semantically); all literal columns and aliases are
-- preserved (output aliases lowercased). Schema "PaySchedule" is case-sensitive
-- (quoted); lookup/warehouse/dataload/crunch are lowercase/unquoted.
--
-- T-SQL -> PG mappings applied:
--   CAST(x AS NVARCHAR(15))                         -> (x)::varchar(15)
--   ISNULL(x,y)                                     -> COALESCE(x,y)
--   UPPER(LEFT(x,1)) + LOWER(RIGHT(x,LEN(x)-1))     -> upper(left(x,1)) || lower(right(x, length(x)-1))
--   CONCAT(YEAR(OpmStartDate),'01') (int compare)   -> concat(extract(year from opmstartdate)::int,'01')::int
-- ============================================================================

CREATE OR REPLACE VIEW data.payschedules AS
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid AS locationid,
       strl AS strl,
       gradetype,
       payband AS gradelevel,
       1 AS step, /* pay band minimum */
       -1 AS yos,
       minpay AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (payband)::varchar(15) AS gradeleveldescription,
       'Min' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_d_nseries
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid AS locationid,
       strl AS strl,
       gradetype,
       payband AS gradelevel,
       10 AS step, /* pay band maximum */
       -1 AS yos,
       maxpay AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (payband)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_d_nseries
UNION ALL
/* G series pay is just the base pay times the locality payment amount */
SELECT payplan,
       categorygroupcode,
       categorysubgroupcode,
       locationid,
       '-1' AS strl,
       gradetype,
       gradelevel,
       step AS step,
       -1 AS yos,
       rate,
       'Annual' AS ratetype,
       amcosversionid,
       (gradelevel)::varchar(15) AS gradeleveldescription,
       (step)::varchar(15) AS stepdescription,
       workrolecode
FROM "PaySchedule".payschedule_g_series
UNION
-- bring IN hourly AND overtime pay FOR GL AND GS
SELECT a.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       b.locationid,
       '-1' AS strl,
       a.gradetype,
       a.gradelevel,
       a.step AS step,
       -1 AS yos,
                                              --make sure to include COLA and Locality in the calc
                                              --Add COLA from PaySchedule.NonforeignAreaCOLA table
       a.rate * ((b.localityrate / 100) + 1), -- * (ISNULL(b.COLA / 100, 0) + 1),
                                              --make a consistent nomen of first letter capital, all other lowercase
       upper(left(a.ratetype, 1)) || lower(right(a.ratetype, length(a.ratetype) - 1)) AS ratetype,
       a.amcosversionid,
       (a.gradelevel)::varchar(15) AS gradeleveldescription,
       (a.step)::varchar(15) AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_g_series_raw AS a
    INNER JOIN
    (
        SELECT a.locationid,
               a.sourcesystemcode,
               a.locationtype,
               a.displayname,
               p.localityrate,
               p.amcosversionid,
               c.description
        FROM warehouse.location AS a
            INNER JOIN "PaySchedule".localitypay AS p
                ON a.sourcesystemcode = p.localitycode
            CROSS JOIN lookup.amcosversion AS c
        WHERE c.amcosversionid = p.amcosversionid
              AND a.locationtype = 'Locality Pay Area'
    ) AS b
        ON a.amcosversionid = b.amcosversionid
WHERE a.payplan IN ( 'GL', 'GS' )
      AND a.ratetype <> 'ANNUAL'
UNION ALL
/* GP uses GS base pay (no locality increases, not even rest of us, market pay handles locality based pay adustments) */
SELECT 'GP' AS payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       'GP' AS gradetype,
       gradelevel,
       step AS step,
       -1 AS yos,
       rate,
       ratetype,
       amcosversionid,
       (gradelevel)::varchar(15) AS gradeleveldescription,
       (step)::varchar(15) AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_g_series_raw
WHERE payplan = 'GS'
      AND ratetype = 'Annual'
      AND amcosversionid >= 201101 --based on research with Marsha (COR) GP began in 2011 for the DoD so don't allow anything before that in
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       gradetype,
       gradelevel,
       -1 AS step,
       yos AS yos,
       rate,
       ratetype,
       amcosversionid,
       (gradelevel)::varchar(15) AS gradeleveldescription,
       'Not Applicable' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_military
--annualize active military pay
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       gradetype,
       gradelevel,
       -1 AS step,
       yos AS yos,
       rate * 12 AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (gradelevel)::varchar(15) AS gradeleveldescription,
       'Not Applicable' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_military
WHERE ratetype = 'Monthly'
      AND payplan IN ( 'AO', 'AWO', 'AE' )
UNION
-- since we do not crunch military pay we need to calculate this on the fly
--do not change this without also making the same change in crunch.costofbasepay
SELECT a.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       a.gradetype,
       a.gradelevel,
       -1 AS step,
       a.yos AS yos,
       --(a.Pay * @MonthsInAyear) + (b.Rate * @activedays / @DaysInAMonth) AS rate,
       (a.rate * 12) + (b.rate * c.paramvalue / 30) AS rate,
       'Annualized' AS ratetype,
       a.amcosversionid,
       (a.gradelevel)::varchar(15) AS gradeleveldescription,
       'Not Applicable' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_military AS a
    INNER JOIN "PaySchedule".payschedule_military AS b
        ON a.gradetype = b.gradetype
           AND a.gradelevel = b.gradelevel
           AND a.yos = b.yos
           AND b.amcosversionid = a.amcosversionid
    INNER JOIN
    (
        SELECT paramvalue,
               amcosversionid
        FROM dataload.singlevalues
        WHERE paramname = 'activedays'
              AND payplan = 'AA'
    ) AS c
        ON c.amcosversionid = a.amcosversionid
WHERE a.payplan IN ( 'NO', 'NE', 'NWO', 'RE', 'RO', 'RWO' )
      AND a.ratetype = '4 Drills'
      AND b.ratetype = 'Monthly'
      AND b.payplan IN ( 'AO', 'AWO', 'AE' )
--removed 5/25/2022 so that the 'new' SES Raw payschedule could be used instead
--(commented-out PaySchedule.PaySchedule_SES block omitted, matching source)
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid,
       '-1' AS strl,
       gradetype,
       gradelevel,
       step AS step,
       -1 AS yos,
       rate,
       ratetype,
       amcosversionid,
       (gradelevel)::varchar(15) AS gradeleveldescription,
       (step)::varchar(15) AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_wage
WHERE ratetype = 'Hourly'
UNION
SELECT a.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       a.locationid,
       '-1' AS strl,
       a.gradetype,
       a.gradelevel,
       step AS step,
       -1 AS yos,
       --if we don't have data for a given year just assume 2087 which was the value when we started keeping records
       a.rate * COALESCE(b.paramvalue, 2087),
       'Annual' AS ratetype,
       a.amcosversionid,
       (a.gradelevel)::varchar(15) AS gradeleveldescription,
       (a.step)::varchar(15) AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_wage AS a
    LEFT OUTER JOIN
    (
        SELECT *
        FROM dataload.singlevalues
        WHERE paramname = 'annualpaidhours'
              AND payplan = 'GP'
    ) AS b
        ON b.amcosversionid = a.amcosversionid
WHERE a.ratetype = 'Hourly'
UNION ALL
--CY pay plan
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid,
       '-1' AS strl,
       gradetype,
       payband,
       1 AS step, /* pay band minimum */
       -1 AS yos,
       minpay AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (payband)::varchar(15) AS gradeleveldescription,
       'Min' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_cy
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid,
       '-1' AS strl,
       gradetype,
       payband,
       10 AS step, /* pay band maximum */
       -1 AS yos,
       maxpay AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (payband)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_cy
UNION ALL
--NF pay plan
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid,
       '-1' AS strl,
       gradetype,
       payband,
       1 AS step, /* pay band minimum */
       -1 AS yos,
       minpay AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (payband)::varchar(15) AS gradeleveldescription,
       'Min' AS stepdescription,
       '-1' AS workrolecode
FROM crunch.nfpayprocessed
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid,
       '-1' AS strl,
       gradetype,
       payband,
       10 AS step, /* pay band maximum */
       -1 AS yos,
       maxpay AS rate,
       'Annual' AS ratetype,
       amcosversionid,
       (payband)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM crunch.nfpayprocessed
--########
UNION ALL
SELECT b.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       b.payplan,
       0,         --grade level not used
       1 AS step, /* pay band maximum */
       -1 AS yos,
       a.maxpay AS rate,
       'Annual' AS ratetype,
       a.amcosversionid,
       (0)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".opmsesraw AS a
    --these pay plans use the same pasyschedule as SES
    CROSS JOIN
    (SELECT 'IP' AS payplan UNION SELECT 'IE') AS b
UNION ALL
--########
--EF and EE
-- GS15 Step 10 is the maximum
SELECT b.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid AS locationid,
       '-1' AS strl,
       b.payplan,
       0, --grade level not used
       10 AS step,
       -1 AS yos,
       rate AS rate,
       'Annual' AS ratetype,
       a.amcosversionid,
       (0)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".payschedule_g_series AS a
    CROSS JOIN
    (SELECT 'EF' AS payplan UNION SELECT 'EE') AS b
    INNER JOIN
    (
        SELECT concat(extract(year from opmstartdate)::int, '01')::int AS amcosversionidstart,
               payplan
        FROM lookup.payplan
    ) AS c
        ON b.payplan = c.payplan
           AND a.amcosversionid >= c.amcosversionidstart
WHERE a.payplan = 'GS'
      AND categorygroupcode = '-1'
      AND categorysubgroupcode = '-1'
      AND locationid <> -1
      AND a.gradelevel = 15
      AND step = 10
UNION ALL
--#### EX
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       payplan,
       gradelevel, --grade level not used
       -1 AS step,
       -1 AS yos,
       rate AS rate,
       ratetype,
       amcosversionid,
       gradeleveldescription AS gradeleveldescription,
       'Not Applicable' AS stepdescription,
       '-1' AS workrolecode
FROM crunch.opmexprocessed
--#### CA
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       locationid,
       '-1' AS strl,
       payplan,
       gradelevel, --grade level not used
       -1 AS step,
       -1 AS yos,
       rate AS rate,
       ratetype,
       amcosversionid,
       gradeleveldescription AS gradeleveldescription,
       'Not Applicable' AS stepdescription,
       '-1' AS workrolecode
FROM crunch.opmcaprocessed
--#### IG
UNION ALL
SELECT payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       payplan,
       gradelevel, --grade level not used
       -1 AS step,
       -1 AS yos,
       rate AS rate,
       ratetype,
       amcosversionid,
       (0)::varchar(15) AS gradeleveldescription,
       'Not Applicable' AS stepdescription,
       '-1' AS workrolecode
FROM crunch.opmigprocessed
UNION ALL
--### ST SL IE IP all use the EX Level II as their max, as of 5/25/2022 there is no min set in policy although one maybe could infer SES Min is their min but that is far from being official
SELECT b.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       b.payplan,
       0, --grade level not used
       -1 AS step,
       -1 AS yos,
       rate AS rate,
       a.ratetype,
       a.amcosversionid,
       (0)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM crunch.opmexprocessed AS a
    CROSS JOIN
    (
        SELECT 'ST' AS payplan
        UNION
        SELECT 'SL'
        UNION
        SELECT 'IE'
        UNION
        SELECT 'IP'
    ) AS b
    INNER JOIN
    (
        SELECT concat(extract(year from opmstartdate)::int, '01')::int AS amcosversionidstart,
               payplan
        FROM lookup.payplan
    ) AS c
        ON b.payplan = c.payplan
           AND a.amcosversionid >= c.amcosversionidstart
WHERE gradeleveldescription = 'Level II'
UNION ALL
--### SES and IP uses SES - MIN
SELECT b.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       b.payplan,
       0, --grade level not used
       -1 AS step,
       -1 AS yos,
       a.minpay AS rate,
       a.ratetype,
       a.amcosversionid,
       (0)::varchar(15) AS gradeleveldescription,
       'Min' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".opmsesraw AS a
    CROSS JOIN
    (SELECT 'IP' AS payplan UNION SELECT 'SES') AS b
    INNER JOIN
    (
        SELECT concat(extract(year from opmstartdate)::int, '01')::int AS amcosversionidstart,
               payplan
        FROM lookup.payplan
    ) AS c
        ON b.payplan = c.payplan
           AND a.amcosversionid >= c.amcosversionidstart
UNION ALL
--### SES and IP uses SES - MAX
SELECT b.payplan,
       '-1' AS categorygroupcode,
       '-1' AS categorysubgroupcode,
       -1 AS locationid,
       '-1' AS strl,
       b.payplan,
       0, --grade level not used
       -1 AS step,
       -1 AS yos,
       a.maxpay AS rate,
       a.ratetype,
       a.amcosversionid,
       (0)::varchar(15) AS gradeleveldescription,
       'Max' AS stepdescription,
       '-1' AS workrolecode
FROM "PaySchedule".opmsesraw AS a
    CROSS JOIN
    (SELECT 'IP' AS payplan UNION SELECT 'SES') AS b
    INNER JOIN
    (
        SELECT concat(extract(year from opmstartdate)::int, '01')::int AS amcosversionidstart,
               payplan
        FROM lookup.payplan
    ) AS c
        ON b.payplan = c.payplan
           AND a.amcosversionid >= c.amcosversionidstart;
