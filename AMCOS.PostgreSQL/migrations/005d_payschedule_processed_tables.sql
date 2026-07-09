-- Processed pay-schedule tables ("PaySchedule".*) — Phase-2 crunch outputs.
--
-- These hold the PROCESSED pay schedules produced by the crunch.CrunchPaySchedule*
-- procedures (from the ETL-loaded "PaySchedule".*_raw inputs). They are read back
-- by the civilian cost crunches via the data.payschedules view (008). Created here
-- (after 005c) so those procs and the view resolve; empty until the crunch runs.
--
-- Source DDL: AMCOS.AMCOS2020_MAR/PaySchedule/Tables/*.sql. Schema "PaySchedule" is
-- case-sensitive (created quoted in 000_schemas.sql). T-SQL->PG: NVARCHAR->varchar,
-- TINYINT->smallint, PRIMARY KEY CLUSTERED->PRIMARY KEY, DF_ constraint names dropped.

-- Source: PaySchedule/Tables/PaySchedule_G_Series.sql  (GS/GL/GP base + locality pay)
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_g_series (
    payplan              varchar(3)     NOT NULL,
    categorygroupcode    varchar(4)     NOT NULL,
    categorysubgroupcode varchar(5)     NOT NULL,
    workrolecode         varchar(3)     DEFAULT '-1' NOT NULL,
    locationid           integer        NOT NULL,
    gradetype            varchar(3)     NOT NULL,
    gradelevel           smallint       NOT NULL,
    step                 smallint       NOT NULL,
    rate                 numeric(10, 2) NOT NULL,
    amcosversionid       integer        NOT NULL,
    CONSTRAINT pk_payschedule_g_series PRIMARY KEY
        (payplan, categorygroupcode, categorysubgroupcode, workrolecode, locationid, gradetype, gradelevel, step, amcosversionid)
);

-- Source: PaySchedule/Tables/PaySchedule_CY.sql  (CY / China-Lake pay bands)
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_cy (
    payplan        varchar(3)     NOT NULL,
    gradetype      varchar(3)     NOT NULL,
    payband        smallint       NOT NULL,
    minpay         numeric(18, 2) NOT NULL,
    maxpay         numeric(18, 2) NOT NULL,
    locationid     integer        NOT NULL,
    amcosversionid integer        NOT NULL,
    CONSTRAINT pk_payschedule_cy PRIMARY KEY (payplan, gradetype, payband, locationid, amcosversionid)
);

-- Source: PaySchedule/Tables/PaySchedule_Wage.sql  (Federal Wage System WG/WL/WS)
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_wage (
    payplan        varchar(3)     NOT NULL,
    fundtype       varchar(3)     NOT NULL,
    areacode       varchar(4)     NOT NULL,
    gradetype      varchar(3)     NOT NULL,
    gradelevel     smallint       NOT NULL,
    step           smallint       NOT NULL,
    ratetype       varchar(25)    NOT NULL,
    dateeffective  date           NOT NULL,
    rate           numeric(18, 2) NOT NULL,
    locationid     integer        NOT NULL,
    amcosversionid integer        NOT NULL,
    wagearea       varchar(3),
    CONSTRAINT pk_payschedule_wage PRIMARY KEY
        (payplan, fundtype, areacode, gradetype, gradelevel, step, ratetype, dateeffective, locationid, amcosversionid)
);

-- Source: PaySchedule/Tables/PaySchedule_D_NSeries.sql  (Acq/Lab-demo D & N series pay bands)
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_d_nseries (
    payplan        varchar(3)     NOT NULL,
    strl           varchar(20)    NOT NULL,
    gradetype      varchar(3)     NOT NULL,
    payband        smallint       NOT NULL,
    minpay         numeric(18, 2) NOT NULL,
    maxpay         numeric(18, 2) NOT NULL,
    locationid     integer        NOT NULL,
    amcosversionid integer        NOT NULL,
    CONSTRAINT pk_payschedule_d_nseries PRIMARY KEY (payplan, strl, gradetype, payband, locationid, amcosversionid)
);

-- ---------------------------------------------------------------------------
-- Raw pay inputs the data.payschedules view unions alongside the processed
-- tables above. These are ETL-loaded (empty until then); defined here because a
-- VIEW resolves its relations at CREATE time, so 008b's data.payschedules cannot
-- be created until they exist. Source DDL: PaySchedule/Tables/*.sql.
-- ---------------------------------------------------------------------------

-- Source: PaySchedule/Tables/PaySchedule_G_Series_raw.sql
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_g_series_raw (
    payplan        varchar(3)     NOT NULL,
    gradetype      varchar(3)     NOT NULL,
    gradelevel     smallint       NOT NULL,
    step           smallint       NOT NULL,
    dateeffective  date           NOT NULL,
    ratetype       varchar(25)    NOT NULL,
    rate           numeric(10, 2),
    amcosversionid integer        NOT NULL
);

-- Source: PaySchedule/Tables/PaySchedule_Military.sql
CREATE TABLE IF NOT EXISTS "PaySchedule".payschedule_military (
    payplan        varchar(3)     NOT NULL,
    gradetype      varchar(3)     NOT NULL,
    gradelevel     smallint       NOT NULL,
    yos            smallint       NOT NULL,
    dateeffective  date           NOT NULL,
    ratetype       varchar(25),
    rate           numeric(18, 2) NOT NULL,
    amcosversionid integer        NOT NULL
);

-- Source: PaySchedule/Tables/OpmSesRaw.sql
CREATE TABLE IF NOT EXISTS "PaySchedule".opmsesraw (
    payplan        varchar(3)    NOT NULL,
    dateeffective  date          NOT NULL,
    ratetype       varchar(25)   NOT NULL,
    maxpay         numeric(8, 2) NOT NULL,
    minpay         numeric(8, 2) NOT NULL,
    amcosversionid integer       NOT NULL
);

-- Source: PaySchedule/Tables/LocalityPay.sql
CREATE TABLE IF NOT EXISTS "PaySchedule".localitypay (
    localitycode   varchar(6)    NOT NULL,
    localityrate   numeric(5, 2) NOT NULL,
    amcosversionid integer       NOT NULL
);
