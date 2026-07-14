-- ============================================================================
-- 002c_xwalk_tables.sql
-- Purpose: Port the xwalk crosswalk INPUT/staging tables from the SQL Server
--          source (AMCOS.AMCOS2020_MAR/xwalk/Tables/*.sql) to PostgreSQL so the
--          crunch engine + warehouse-populate procs (006e/006f/006i/006j) can run.
-- Schema : lowercase, unquoted `xwalk`.
-- Notes  : Types translated per DDL_PORT_CONVENTIONS.md. IDENTITY / CLUSTERED /
--          filegroup / FK noise dropped; PKs kept; identifiers lowercased/unquoted.
--          The 2 xwalk *views* (PayPlanType, PPXwalkGradeLevel) are handled
--          elsewhere. xwalk.wageareatofips (no source table) is defined as a
--          reverse-naming VIEW over fips_wagearea at the END of this file.
-- ============================================================================

-- xwalk.atrrsatrmcrosswalk  <- xwalk/Tables/ATRRSATRMCrosswalk.sql
CREATE TABLE IF NOT EXISTS xwalk.atrrsatrmcrosswalk (
    atrrs_key       varchar(200) NOT NULL,
    atrm_key        varchar(200) NOT NULL,
    amcosversionid  integer      NOT NULL,
    CONSTRAINT pk_atrrsatrmcrosswalk PRIMARY KEY (atrrs_key, atrm_key, amcosversionid)
);

-- xwalk.dloctodos  <- xwalk/Tables/DLOCtoDoS.sql
CREATE TABLE IF NOT EXISTS xwalk.dloctodos (
    dloc                 varchar(9) NOT NULL,
    doslocation          varchar(5) NOT NULL,
    amcosversionidstart  integer    NOT NULL,
    amcosversionidend    integer    NOT NULL,
    CONSTRAINT pk_dloctodos PRIMARY KEY (dloc, doslocation, amcosversionidend)
);

-- xwalk.fips_wagearea  <- xwalk/Tables/FIPS_WageArea.sql
-- NOTE (version-column reconciliation): the sqlproj Tables DDL declares a single
-- AmcosVersionId, but every consumer disagrees with it AND with each other:
--   * fips_wagearea readers (006e phase-2, and the source CrunchDMDCVantageInventory
--     SP itself) filter `@version BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd`;
--   * the wageareatofips view readers (006j) filter `= amcosversionid` (single).
-- Every other versioned crosswalk here (fips_zip, dloctodos, ziptodos, ...) uses
-- start/end, so the single-version sqlproj DDL is almost certainly stale. Rather than
-- pick one and break the other, we carry BOTH schemes as a superset (start/end
-- nullable); this makes all consumers plan-clean. TRUE scheme must be reconciled
-- against the live production table when real ETL data is loaded (see #6).
CREATE TABLE IF NOT EXISTS xwalk.fips_wagearea (
    fundtype             varchar(3) NOT NULL,
    wage_area            varchar(3) NOT NULL,
    wage_schedule        varchar(4) NOT NULL,
    fips                 varchar(5) NOT NULL,
    amcosversionid       integer    NOT NULL,
    amcosversionidstart  integer    NULL,
    amcosversionidend    integer    NULL,
    CONSTRAINT pk_fips_wagearea PRIMARY KEY (fundtype, wage_area, wage_schedule, fips, amcosversionid)
);

-- xwalk.gradelevel  <- xwalk/Tables/GradeLevel.sql
-- Grade-band crosswalk (base pay-plan/grade range -> target pay-plan/grade).
-- gradelevel columns are TEXT (compared lexicographically via BETWEEN by
-- xwalk.ppxwalkgradelevel) — do NOT cast to numeric. Referenced only by that view.
CREATE TABLE IF NOT EXISTS xwalk.gradelevel (
    basepayplan          varchar(3)   NOT NULL,
    basegradelevel_low   varchar(10)  NOT NULL,
    basegradelevel_high  varchar(10)  NOT NULL,
    targetpayplan        varchar(3)   NOT NULL,
    targetgradelevel     varchar(10)  NOT NULL,
    source               varchar(500) NOT NULL,
    amcosversionidstart  integer      NOT NULL,
    amcosversionidend    integer      NOT NULL,
    CONSTRAINT pk_xwalkgradelevel PRIMARY KEY (basepayplan, basegradelevel_low, basegradelevel_high, targetpayplan, targetgradelevel, amcosversionidend)
);

-- xwalk.localitypayareatofips  <- xwalk/Tables/LocalityPayAreaToFips.sql
CREATE TABLE IF NOT EXISTS xwalk.localitypayareatofips (
    localitycode    varchar(6)   NOT NULL,
    statecode       varchar(2)   NOT NULL,
    countycode      varchar(3)   NOT NULL,
    citycode        varchar(4)   NOT NULL,
    placename       varchar(200) NULL,
    amcosversionid  integer      NOT NULL,
    CONSTRAINT pk_localitypayareatofips PRIMARY KEY (localitycode, statecode, countycode, citycode, amcosversionid)
);

-- xwalk.metropolitanstatisticalareatofips  <- xwalk/Tables/MetropolitanStatisticalAreaToFips.sql
-- (no PK in source)
CREATE TABLE IF NOT EXISTS xwalk.metropolitanstatisticalareatofips (
    msacode              varchar(7) NOT NULL,
    statecode            char(2)    NOT NULL,
    countycode           char(3)    NOT NULL,
    amcosversionidstart  integer    NULL,
    amcosversionidend    integer    NULL,
    amcosversionid       integer    NULL
);

-- xwalk.occupationalseriestocareerprogram  <- xwalk/Tables/OccupationalSeriesToCareerProgram.sql
CREATE TABLE IF NOT EXISTS xwalk.occupationalseriestocareerprogram (
    occupationalseriesnumber  varchar(4) NOT NULL,
    careerprogramnumber       char(2)    NOT NULL,
    amcosversionidstart       integer    NULL,
    amcosversionidend         integer    NULL,
    CONSTRAINT pk_occupationalseriestocareerprogram PRIMARY KEY (occupationalseriesnumber, careerprogramnumber)
);

-- xwalk.onetsubgroupcrosswalk  <- xwalk/Tables/OnetSubgroupCrosswalk.sql
CREATE TABLE IF NOT EXISTS xwalk.onetsubgroupcrosswalk (
    onet_code            varchar(20)  NOT NULL,
    onetcodetrimmed      varchar(20)  NULL,
    subgroupcode         varchar(5)   NOT NULL,
    sortindex            integer      NOT NULL,
    payplantype          varchar(3)   NOT NULL,
    mingradelevel        integer      NOT NULL,
    source               varchar(300) NOT NULL,
    amcosversionidstart  integer      NOT NULL,
    amcosversionidend    integer      NOT NULL,
    CONSTRAINT pk_onetsubgroupcrosswalk PRIMARY KEY (onet_code, subgroupcode, payplantype, amcosversionidend)
);

-- xwalk.seriestosoc  <- xwalk/Tables/SeriestoSOC.sql
-- NOTE: the sqlproj Tables/SeriestoSOC.sql DDL is stale — it declares a column
-- `Series`, but every consumer (the source PopulateUnitPersonnel SP and the ported
-- 006j) reads `OccupationalSeriesNumber` (and the source SP also reads `SeriesTitle`).
-- The live production table clearly carries those richer names; matching consumers.
CREATE TABLE IF NOT EXISTS xwalk.seriestosoc (
    soc                     varchar(7)   NOT NULL,
    occupationalseriesnumber varchar(5)  NOT NULL,
    seriestitle             varchar(200) NULL,   -- read by the source SP's missing-entry report; not used by 006j
    amcosversionidstart     integer      NOT NULL,
    amcosversionidend       integer      NOT NULL,
    CONSTRAINT pk_seriestosoc PRIMARY KEY (soc, occupationalseriesnumber, amcosversionidend)
);

-- xwalk.specialratetablesbyagency  <- xwalk/Tables/SpecialRateTablesByAgency.sql
CREATE TABLE IF NOT EXISTS xwalk.specialratetablesbyagency (
    agency          varchar(50)  NULL,
    subelement      varchar(50)  NULL,
    title           varchar(200) NOT NULL,
    tablenumber     varchar(4)   NOT NULL,
    amcosversionid  integer      NOT NULL,
    CONSTRAINT pk_specialratetablesbyagency PRIMARY KEY (title, tablenumber, amcosversionid)
);

-- xwalk.specialratetablesbylocation  <- xwalk/Tables/SpecialRateTablesByLocation.sql
-- (no PK in source)
CREATE TABLE IF NOT EXISTS xwalk.specialratetablesbylocation (
    locationname    varchar(100) NOT NULL,
    localitycode    varchar(6)   NULL,
    state           varchar(2)   NOT NULL,
    statecode       varchar(2)   NOT NULL,
    countycode      varchar(3)   NOT NULL,
    citycode        varchar(4)   NOT NULL,
    tablenumber     varchar(4)   NOT NULL,
    amcosversionid  integer      NOT NULL
);

-- xwalk.specialratetablesbyoccupation  <- xwalk/Tables/SpecialRateTablesByOccupation.sql
CREATE TABLE IF NOT EXISTS xwalk.specialratetablesbyoccupation (
    occupationalseriesnumber  varchar(4)   NOT NULL,
    seriestitle               varchar(100) NOT NULL,
    tablenumber               varchar(4)   NOT NULL,
    amcosversionid            integer      NOT NULL,
    CONSTRAINT pk_specialratetablesbyoccupation PRIMARY KEY (occupationalseriesnumber, seriestitle, tablenumber, amcosversionid)
);

-- xwalk.tlmspaytabletolocalitypayarea  <- xwalk/Tables/TLMSPayTableToLocalityPayArea.sql
CREATE TABLE IF NOT EXISTS xwalk.tlmspaytabletolocalitypayarea (
    tlmspaytable    varchar(2) NOT NULL,
    localitycode    varchar(6) NOT NULL,
    amcosversionid  integer    NOT NULL,
    CONSTRAINT pk_tlmspaytabletolocalitypayarea PRIMARY KEY (tlmspaytable, localitycode, amcosversionid)
);

-- xwalk.uictostrl  <- xwalk/Tables/UICToSTRL.sql
CREATE TABLE IF NOT EXISTS xwalk.uictostrl (
    uic                  varchar(6)   NOT NULL,
    strl                 varchar(20)  NULL,
    strlname             varchar(200) NULL,
    amcosversionidstart  integer      NOT NULL,
    amcosversionidend    integer      NOT NULL,
    CONSTRAINT pk_uictostrl PRIMARY KEY (uic, amcosversionidstart, amcosversionidend)
);

-- xwalk.ziptodos  <- xwalk/Tables/ZiptoDoS.sql
CREATE TABLE IF NOT EXISTS xwalk.ziptodos (
    zipcode              varchar(5) NOT NULL,
    doslocation          varchar(5) NOT NULL,
    amcosversionidstart  integer    NOT NULL,
    amcosversionidend    integer    NOT NULL,
    CONSTRAINT pk_ziptodos PRIMARY KEY (zipcode, doslocation, amcosversionidend)
);

-- xwalk.ziptomha  <- xwalk/Tables/ZIPToMHA.sql
CREATE TABLE IF NOT EXISTS xwalk.ziptomha (
    zipcode         varchar(5) NOT NULL,
    mha             varchar(5) NOT NULL,
    amcosversionid  integer    NOT NULL,
    CONSTRAINT pk_ziptomha PRIMARY KEY (zipcode, mha, amcosversionid)
);

-- ============================================================================
-- xwalk.wageareatofips  (VIEW — no source table)
-- The procs (006e/006f/006j) reference xwalk.wageareatofips as the reverse
-- naming of fips_wagearea. It must expose the columns used in the joins:
--   statecode, countycode  -> split of fips_wagearea.fips (state 2 + county 3),
--                             so `statecode || countycode = fipscode` matches.
--   schedulearea           -> fips_wagearea.wage_schedule (both join to
--                             warehouse.location.sourcesystemcode and to
--                             lookup.wagearea.schedulearea).
--   fundtype, amcosversionid -> passthrough.
-- ============================================================================
CREATE OR REPLACE VIEW xwalk.wageareatofips AS
SELECT
    substr(fips, 1, 2)  AS statecode,
    substr(fips, 3, 3)  AS countycode,
    wage_schedule       AS schedulearea,
    fundtype,
    amcosversionid
FROM xwalk.fips_wagearea;
