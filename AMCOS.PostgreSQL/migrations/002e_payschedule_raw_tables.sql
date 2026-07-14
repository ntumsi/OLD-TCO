-- 002e_payschedule_raw_tables.sql
-- Purpose: Port of the referenced-but-uncreated PaySchedule raw/staging + crosswalk
--          input tables (SQL Server -> PostgreSQL) so the crunch pay-schedule procs
--          (006f/006e/006j) can read their source data.
-- Source DDL: AMCOS.AMCOS2020_MAR/PaySchedule/Tables/*.sql
--   CyberExceptedService.sql, DCPASNfRaw.sql,
--   NonforeignAreaCostOfLivingAllowances.sql, OpmCaRaw.sql, OpmExRaw.sql,
--   OpmIgRaw.sql, OpmSpecialRates.sql, PaySchedule_CY_Xwalk.sql,
--   PaySchedule_DSeries_Xwalk.sql, PaySchedule_NSeries_Xwalk.sql,
--   PaySchedule_Wage_Raw.sql
-- All objects live in the quoted, capitalized "PaySchedule" schema; table + column
-- identifiers are lowercase/unquoted. IDENTITY/CLUSTERED/filegroup/storage-option
-- noise dropped; PKs kept; FKs omitted (staging load order).

------------------------------------------------------------------------------
-- "PaySchedule".cyberexceptedservice  <- CyberExceptedService.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".cyberexceptedservice (
    gradelevel      smallint       NOT NULL,
    step            integer        NOT NULL,
    ratetype        varchar(50)    NOT NULL,
    rate            numeric(10, 2) NOT NULL,
    workrolecode    varchar(3)     NOT NULL,
    tlmspaytable    varchar(2)     NOT NULL,
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_cyberexceptedservice PRIMARY KEY (gradelevel, step, workrolecode, tlmspaytable, amcosversionid)
);

------------------------------------------------------------------------------
-- "PaySchedule".dcpasnfraw  <- DCPASNfRaw.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".dcpasnfraw (
    payband        smallint        NOT NULL,
    payminannual   numeric(18, 2)  NOT NULL,
    payminhourly   numeric(18, 2)  NOT NULL,
    paymaxannual   numeric(18, 2)  NOT NULL,
    paymaxhourly   numeric(18, 2)  NOT NULL,
    wageschedule   varchar(3)      NOT NULL,
    effectivedate  date            NOT NULL,
    link           varchar(150)    NOT NULL,
    CONSTRAINT pk_payschedule_dcpasnfraw PRIMARY KEY (payband, wageschedule, effectivedate, link)
);

------------------------------------------------------------------------------
-- "PaySchedule".nonforeignareacostoflivingallowances  <- NonforeignAreaCostOfLivingAllowances.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".nonforeignareacostoflivingallowances (
    nonforeignareacode  varchar(10)    NOT NULL,
    colarate            numeric(5, 2)  NOT NULL,
    amcosversionid      integer        NOT NULL,
    CONSTRAINT pk_nonforeignareacostoflivingallowances PRIMARY KEY (nonforeignareacode, amcosversionid)
);

------------------------------------------------------------------------------
-- "PaySchedule".opmcaraw  <- OpmCaRaw.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".opmcaraw (
    payplan         varchar(3)     NOT NULL,
    level           varchar(15)    NOT NULL,
    dateeffective   date           NOT NULL,
    ratetype        varchar(25)    NOT NULL,
    rate            numeric(10, 2) NULL,
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_payschedule_ca_series_raw PRIMARY KEY (payplan, level, ratetype, amcosversionid)
);

------------------------------------------------------------------------------
-- "PaySchedule".opmexraw  <- OpmExRaw.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".opmexraw (
    payplan         varchar(3)     NOT NULL,
    level           varchar(15)    NOT NULL,
    dateeffective   date           NOT NULL,
    ratetype        varchar(25)    NOT NULL,
    rate            numeric(10, 2) NULL,
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_payschedule_ex_series_raw PRIMARY KEY (payplan, level, ratetype, amcosversionid)
);

------------------------------------------------------------------------------
-- "PaySchedule".opmigraw  <- OpmIgRaw.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".opmigraw (
    payplan         varchar(3)     NOT NULL,
    level           varchar(15)    NOT NULL,
    dateeffective   date           NOT NULL,
    ratetype        varchar(25)    NOT NULL,
    rate            numeric(10, 2) NULL,
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_payschedule_ig_series_raw PRIMARY KEY (payplan, level, ratetype, amcosversionid)
);

------------------------------------------------------------------------------
-- "PaySchedule".opmspecialrates  <- OpmSpecialRates.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".opmspecialrates (
    payplan                 varchar(3)     NOT NULL,
    specialratetablenumber  varchar(4)     NOT NULL,
    gradetype               varchar(3)     NOT NULL,
    gradelevel              smallint       NOT NULL,
    step                    smallint       NOT NULL,
    dateeffective           timestamp      NOT NULL,
    ratetype                varchar(25)    NULL,
    rate                    numeric(8, 2)  NULL,
    amcosversionid          integer        NOT NULL,
    CONSTRAINT pk_opmspecialrates PRIMARY KEY (payplan, specialratetablenumber, gradetype, gradelevel, step, dateeffective, amcosversionid)
);

------------------------------------------------------------------------------
-- "PaySchedule".payschedule_cy_xwalk  <- PaySchedule_CY_Xwalk.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_cy_xwalk (
    payplan               varchar(3)  NOT NULL,
    gradetype             varchar(3)  NOT NULL,
    payband               smallint    NOT NULL,
    min_gs_gl             varchar(3)  NOT NULL,
    max_gs_gl             varchar(3)  NOT NULL,
    amcosversionidstart   integer     NOT NULL,
    amcosversionidend     integer     NOT NULL,
    CONSTRAINT pk_payschedule_cy_xwalk PRIMARY KEY (payplan, gradetype, payband, amcosversionidend)
);

------------------------------------------------------------------------------
-- "PaySchedule".payschedule_dseries_xwalk  <- PaySchedule_DSeries_Xwalk.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_dseries_xwalk (
    payplan               varchar(3)      NOT NULL,
    strl                  varchar(20)     NOT NULL,
    gradetype             varchar(3)      NOT NULL,
    payband               smallint        NOT NULL,
    min_gs_gl             varchar(3)      NOT NULL,
    max_gs_gl             varchar(3)      NOT NULL,
    additional            numeric(18, 2)  NULL,
    dateeffective         date            NOT NULL,
    amcosversionidstart   integer         NOT NULL,
    amcosversionidend     integer         NOT NULL,
    CONSTRAINT pk_payschedule_dseries PRIMARY KEY (payplan, strl, gradetype, payband, amcosversionidend)
);

------------------------------------------------------------------------------
-- "PaySchedule".payschedule_nseries_xwalk  <- PaySchedule_NSeries_Xwalk.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_nseries_xwalk (
    payplan               varchar(3)      NOT NULL,
    gradetype             varchar(3)      NOT NULL,
    payband               smallint        NOT NULL,
    min_gs_gl             varchar(3)      NOT NULL,
    max_gs_gl             varchar(3)      NOT NULL,
    additional            numeric(18, 2)  NULL,
    dateeffective         date            NOT NULL,
    amcosversionidstart   integer         NOT NULL,
    amcosversionidend     integer         NOT NULL,
    CONSTRAINT pk_payschedule_nseries PRIMARY KEY (payplan, gradetype, payband, amcosversionidend)
);

------------------------------------------------------------------------------
-- "PaySchedule".payschedule_wage_raw  <- PaySchedule_Wage_Raw.sql
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_wage_raw (
    areacode       varchar(3)      NOT NULL,
    typedata       varchar(1)      NOT NULL,
    surveynumber   varchar(50)     NOT NULL,
    typeschedule   varchar(1)      NOT NULL,
    level          varchar(1)      NOT NULL,
    grade          smallint        NOT NULL,
    rate1          numeric(18, 2)  NOT NULL,
    ind1           varchar(50)     NULL,
    rate2          numeric(18, 2)  NOT NULL,
    ind2           varchar(50)     NULL,
    rate3          numeric(18, 2)  NOT NULL,
    ind3           varchar(50)     NULL,
    rate4          numeric(18, 2)  NULL,
    ind4           varchar(50)     NULL,
    rate5          numeric(18, 2)  NULL,
    ind5           varchar(50)     NULL,
    effectivedate  date            NOT NULL,
    fundtype       varchar(50)     NOT NULL,
    link           varchar(100)    NOT NULL,
    CONSTRAINT pk_payschedule_wage_raw PRIMARY KEY (areacode, typedata, surveynumber, typeschedule, level, grade, effectivedate, fundtype, link)
);
