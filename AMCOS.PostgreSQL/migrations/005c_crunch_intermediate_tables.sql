-- Cost-crunch INTERMEDIATE / staging tables (crunch.*).
--
-- Phase 0 of porting the legacy SQL Server cost-crunch engine
-- (AMCOS.AMCOS2020_MAR/crunch/) to PostgreSQL. Where 005b defines the FINAL
-- crunch.Costs_* output tables (read by the web app), this file defines the
-- WORKING tables the crunch procedures write to and read back while computing
-- those outputs: flattened pay (PayProcessed / *Processed), inventory splits
-- (InventoryDMDC / InventoryWASS), scratch accumulators (Costs_CrunchTemp*),
-- time-in-grade, and the Army-budget single-value store.
--
-- These are EMPTY until the ported crunch procedures (later phases) run. Runs
-- after 005b. See CRUNCH_PORT_PLAN.md for the full porting roadmap.
--
-- T-SQL -> PG conversions applied throughout: NVARCHAR(n)->varchar(n),
-- TINYINT->smallint, FLOAT(53)->double precision, INT->integer,
-- PRIMARY KEY CLUSTERED->PRIMARY KEY, COLLATE / DF_ constraint names dropped.

------------------------------------------------------------------------------
-- Scratch cost accumulators (no PK in the source; used as INSERT/SELECT scratch)
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_CrunchTemp.sql
CREATE TABLE IF NOT EXISTS crunch.costs_crunchtemp (
    payplan              varchar(3),
    categorygroupcode    varchar(4),
    categorysubgroupcode varchar(4)   DEFAULT '',
    wagearea             varchar(3)   DEFAULT '',
    stype                varchar(3)   DEFAULT '',
    appn                 varchar(25),
    costelementcategory  varchar(50),
    costelementname      varchar(250),
    amortized            integer,
    model                integer,
    costelementid        integer,
    gradetype            varchar(3),
    gradelevel           smallint,
    amount               double precision,
    amcosversionid       integer
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_CrunchTemp_1AD.sql
CREATE TABLE IF NOT EXISTS crunch.costs_crunchtemp_1ad (
    payplan              varchar(3),
    categorygroupcode    varchar(6),
    categorysubgroupcode varchar(6),
    wagearea             varchar(3),
    stype                varchar(3),
    appn                 varchar(25),
    costelementcategory  varchar(50),
    costelementname      varchar(300),
    amortized            integer,
    model                integer,
    costelementid        integer,
    gradetype            varchar(3),
    gradelevel           smallint,
    amount               double precision,
    amcosversionid       integer
);

------------------------------------------------------------------------------
-- Processed pay tables
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/PayProcessed.sql
CREATE TABLE IF NOT EXISTS crunch.payprocessed (
    payplan              varchar(3)     NOT NULL,
    categorygroupcode    varchar(4)     NOT NULL,
    categorysubgroupcode varchar(4)     NOT NULL,
    gradetype            varchar(3)     NOT NULL,
    gradelevel           smallint       NOT NULL,
    paytype              varchar(300)   NOT NULL,
    avg_cost             numeric(18, 2),
    avg_annual_pay       numeric(18, 2),
    avg_annual_payments  numeric(18, 2),
    amcosversionid       integer        NOT NULL,
    CONSTRAINT pk_payprocessed PRIMARY KEY
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, paytype, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/NfPayProcessed.sql
CREATE TABLE IF NOT EXISTS crunch.nfpayprocessed (
    payplan        varchar(3)     NOT NULL,
    gradetype      varchar(3)     NOT NULL,
    payband        smallint       NOT NULL,
    minpay         numeric(18, 2) NOT NULL,
    maxpay         numeric(18, 2) NOT NULL,
    locationid     integer        NOT NULL,
    amcosversionid integer        NOT NULL,
    CONSTRAINT pk_nfpayprocessed PRIMARY KEY
        (payplan, gradetype, payband, locationid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/OpmCaProcessed.sql
CREATE TABLE IF NOT EXISTS crunch.opmcaprocessed (
    payplan               varchar(3)     NOT NULL,
    gradelevel            smallint       NOT NULL,
    gradeleveldescription varchar(20)    NOT NULL,
    locationid            integer        NOT NULL,
    ratetype              varchar(25)    NOT NULL,
    rate                  numeric(18, 2) NOT NULL,
    amcosversionid        integer        NOT NULL,
    CONSTRAINT pk_opmcaprocessed PRIMARY KEY
        (payplan, gradelevel, locationid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/OpmExProcessed.sql
CREATE TABLE IF NOT EXISTS crunch.opmexprocessed (
    payplan               varchar(3)     NOT NULL,
    gradelevel            smallint       NOT NULL,
    gradeleveldescription varchar(20)    NOT NULL,
    ratetype              varchar(25)    NOT NULL,
    rate                  numeric(10, 2),
    amcosversionid        integer        NOT NULL,
    CONSTRAINT pk_opmexprocessed PRIMARY KEY
        (payplan, gradelevel, ratetype, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/OpmIGProcessed.sql
CREATE TABLE IF NOT EXISTS crunch.opmigprocessed (
    payplan        varchar(3)     NOT NULL,
    gradelevel     smallint       NOT NULL,
    ratetype       varchar(25)    NOT NULL,
    rate           numeric(10, 2),
    amcosversionid integer        NOT NULL,
    CONSTRAINT pk_opmigprocessed PRIMARY KEY
        (payplan, gradelevel, ratetype, amcosversionid)
);

------------------------------------------------------------------------------
-- Processed inventory splits (source rows have no PK)
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/InventoryDMDC.sql
CREATE TABLE IF NOT EXISTS crunch.inventorydmdc (
    civtype          varchar(3)  NOT NULL,
    payplan          varchar(3)  NOT NULL,
    categorygroup    varchar(20) NOT NULL,
    categorysubgroup varchar(5)  NOT NULL,
    gradetype        varchar(2)  NOT NULL,
    gradelevel       smallint    NOT NULL,
    step             varchar(2)  NOT NULL,
    locationid       integer     NOT NULL,
    yos              smallint    NOT NULL,
    inventory        integer     NOT NULL,
    amcosversionid   integer     NOT NULL,
    zip              varchar(5),
    dutystationzip   varchar(5)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/InventoryWASS.sql
CREATE TABLE IF NOT EXISTS crunch.inventorywass (
    payplan                   varchar(3)     NOT NULL,
    occupationalgroupnumber   varchar(4)     NOT NULL,
    occupationalseriesnumber  varchar(4)     NOT NULL,
    gradetype                 varchar(3)     NOT NULL,
    gradelevel                smallint       NOT NULL,
    step                      integer        NOT NULL,
    locationid                integer        NOT NULL,
    inventory                 integer        NOT NULL,
    averagepay                numeric(18, 2),
    amcosversionid            integer        NOT NULL
);

------------------------------------------------------------------------------
-- Time-in-grade + Army-budget single values
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/TimeInGrade.sql
CREATE TABLE IF NOT EXISTS crunch.timeingrade (
    payplan        varchar(3)    NOT NULL,
    gradelevel     integer       NOT NULL,
    medianyos      numeric(6, 1) NOT NULL,
    tig            numeric(6, 1) NOT NULL,
    amcosversionid integer       NOT NULL,
    CONSTRAINT pk_timeingrade PRIMARY KEY (payplan, gradelevel, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/ArmyBudgetSingleValues.sql
CREATE TABLE IF NOT EXISTS crunch.armybudgetsinglevalues (
    parametername  varchar(50) NOT NULL,
    appropriation  varchar(10) NOT NULL,
    fy             varchar(4)  NOT NULL,
    amcosversionid integer     NOT NULL,
    amount         double precision,
    CONSTRAINT pk_armybudgetsinglevalues PRIMARY KEY
        (parametername, appropriation, fy, amcosversionid)
);
