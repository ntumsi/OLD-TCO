-- AMCOS cost-engine INPUT / staging tables (SQL Server -> PostgreSQL port).
--
-- These are referenced-but-uncreated load/staging tables that the crunch engine
-- and ETL read from. They are EMPTY until the ETL / load steps populate them.
-- Ported from the legacy SQL Server source under AMCOS.AMCOS2020_MAR/.
--
-- Schema casing (matches 000_schemas.sql) is deliberate:
--   "DMDC", "load_GFEBS"      -> quoted, capitalized
--   load_inventory, load_training -> lowercase, unquoted
--
-- T-SQL -> PG conversions applied throughout: NVARCHAR(n)->varchar(n),
-- NCHAR(n)->char(n), TINYINT->smallint, INT->integer, SMALLINT->smallint,
-- NUMERIC(p,s)->numeric(p,s), DATE->date. Dropped: IDENTITY, PRIMARY KEY
-- CLUSTERED->PRIMARY KEY, NONCLUSTERED/CLUSTERED indexes, DF_ constraint names
-- (defaults kept), filegroup/ON [PRIMARY]. Table/column identifiers lowercased,
-- unquoted. Runs after 002 data tables.

------------------------------------------------------------------------------
-- Schema "DMDC"
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/DMDC/Tables/MembersAndDependents.sql
CREATE TABLE IF NOT EXISTS "DMDC".membersanddependents (
    amcosversionid           integer      NOT NULL,
    payplan                  varchar(3)   NOT NULL,
    gradetype                varchar(3)   NOT NULL,
    gradelevel               smallint     NOT NULL,
    totalmembers             integer,
    memberswithdependents    integer,
    memberswithoutdependents integer,
    numberofdependents       integer,
    CONSTRAINT pk_membersanddependents PRIMARY KEY (amcosversionid, payplan, gradetype, gradelevel)
);

-- Source: AMCOS.AMCOS2020_MAR/DMDC/Tables/MilitaryAcqSourceOfCommission.sql
CREATE TABLE IF NOT EXISTS "DMDC".militaryacqsourceofcommission (
    id                  integer      GENERATED ALWAYS AS IDENTITY,
    component           varchar(25),
    paygrade            varchar(3),
    transactiontypecode varchar(3),
    sourceofcommission  varchar(2),
    cmf                 varchar(2),
    aoc                 varchar(4),
    total               integer,
    amcosversionid      integer,
    CONSTRAINT pk_militaryacqsourceofcommission PRIMARY KEY (id)
);

-- Source: AMCOS.AMCOS2020_MAR/DMDC/Tables/Pay.sql
CREATE TABLE IF NOT EXISTS "DMDC".pay (
    filedate                     varchar(10)    NOT NULL,
    payplan                      varchar(3)     NOT NULL,
    gradetype                    varchar(3)     NOT NULL,
    gradelevel                   smallint       NOT NULL,
    paytype                      varchar(300)   NOT NULL,
    primaryserviceoccupationcode varchar(20)    NOT NULL,
    count                        integer,
    totalpayamount               numeric(18,2),
    amcosversionid               integer        NOT NULL,
    CONSTRAINT pk_pay PRIMARY KEY (filedate, payplan, gradetype, gradelevel, paytype, primaryserviceoccupationcode, amcosversionid)
);

------------------------------------------------------------------------------
-- Schema "load_GFEBS"
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/load_GFEBS/Tables/Cleaned.sql
CREATE TABLE IF NOT EXISTS "load_GFEBS".cleaned (
    payplan                  varchar(3)     NOT NULL,
    occupationalgroupnumber  varchar(4)     NOT NULL,
    occupationalseriesnumber varchar(4)     NOT NULL,
    statecountry             varchar(50)    NOT NULL,
    functionalareacode       varchar(50)    NOT NULL,
    costcentercode           varchar(50)    NOT NULL,
    country                  varchar(50)    DEFAULT '-1' NOT NULL,
    localitycode             varchar(6)     DEFAULT '-1' NOT NULL,
    activitytypecode         varchar(50),
    fundscentercode          varchar(50),
    fund                     varchar(50),
    uicucformanpower         varchar(50),
    postalcode1              varchar(10),
    postalcode2              varchar(10),
    gradelevel               smallint       NOT NULL,
    step                     smallint,
    civiliantypecode         char(3)        NOT NULL,
    payperiodenddate         date           NOT NULL,
    personnelnumber          varchar(10)    NOT NULL,
    costelementcode          varchar(50)    NOT NULL,
    grc_typehourcode         char(2)        NOT NULL,
    amountpaid               numeric(18,4),
    paidhours                numeric(18,4),
    actualhourlyrate         numeric(10,2),
    amcosversionid           integer        NOT NULL,
    CONSTRAINT pk_cleaned PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, statecountry, functionalareacode, costcentercode, country, localitycode, gradelevel, payperiodenddate, civiliantypecode, personnelnumber, costelementcode, grc_typehourcode, amcosversionid)
);

------------------------------------------------------------------------------
-- Schema load_inventory
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/load_inventory/Tables/DMDC_Raw.sql
CREATE TABLE IF NOT EXISTS load_inventory.dmdc_raw (
    civtype          varchar(4),
    payplan          varchar(3),
    categorygroup    varchar(20),
    categorysubgroup varchar(4),
    quality          char(1),
    gradetype        varchar(2),
    gradelevel       varchar(2),
    step             varchar(2),
    uic              char(6),
    yos              smallint,
    count            smallint,
    dutylocationcode char(9),
    rcc              char(1),
    amcosversionid   integer
);

-- Source: AMCOS.AMCOS2020_MAR/load_inventory/Tables/Vantage_Staged.sql
CREATE TABLE IF NOT EXISTS load_inventory.vantage_staged (
    civtype          varchar(3),
    payplan          varchar(3),
    categorygroup    varchar(20),
    categorysubgroup varchar(4),
    quality          char(1),
    gradetype        varchar(2),
    gradelevel       varchar(2),
    step             varchar(2),
    uic              varchar(20),
    yos              smallint,
    count            smallint,
    dutylocationcode char(9),
    rcc              char(1),
    amcosversionid   integer
);

-- Source: AMCOS.AMCOS2020_MAR/load_inventory/Tables/WASS_Raw.sql
CREATE TABLE IF NOT EXISTS load_inventory.wass_raw (
    id                       integer         GENERATED ALWAYS AS IDENTITY,
    payplan                  varchar(3)      NOT NULL,
    occupationalseriesnumber varchar(5)      NOT NULL,
    sal_wag                  numeric(16,2),
    gradelevel               varchar(2)      NOT NULL,
    step                     varchar(2)      NOT NULL,
    citycode                 varchar(4)      NOT NULL,
    countycode               varchar(3)      NOT NULL,
    statecode                varchar(2)      NOT NULL,
    sex                      varchar(50)     NOT NULL,
    paybasis                 varchar(50),
    paybasisdescription      varchar(50),
    payratedeterm            varchar(50),
    payratedetermdesc        varchar(100),
    st_trans                 varchar(50),
    count                    integer         NOT NULL,
    amcosversionid           integer         NOT NULL
);

------------------------------------------------------------------------------
-- Schema load_training
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/load_training/Tables/ATRM.sql
CREATE TABLE IF NOT EXISTS load_training.atrm (
    id             integer         GENERATED ALWAYS AS IDENTITY,
    schoolcode     varchar(25)     NOT NULL,
    coursenumber   varchar(50)     NOT NULL,
    coursetitle    varchar(100)    NOT NULL,
    location       varchar(100)    NOT NULL,
    activity       varchar(100)    NOT NULL,
    length_weeks   numeric(18,4)   NOT NULL,
    egrads         numeric(18,4)   NOT NULL,
    modalgrade     varchar(10)     NOT NULL,
    frequency      numeric(18,4),
    flyinghours    numeric(18,4),
    ich            numeric(18,4),
    mpa_cost       numeric(18,4)   DEFAULT 0,
    omacivpay_cost numeric(18,4)   DEFAULT 0,
    omanonpay_cost numeric(18,4)   DEFAULT 0,
    other_cost     numeric(18,4)   DEFAULT 0,
    amcosversionid integer         NOT NULL,
    CONSTRAINT pk_atrm PRIMARY KEY (id)
);

-- Source: AMCOS.AMCOS2020_MAR/load_training/Tables/ATRRS.sql
CREATE TABLE IF NOT EXISTS load_training.atrrs (
    id               integer        GENERATED ALWAYS AS IDENTITY,
    cpbranch         char(1)        NOT NULL,
    schoolcode       varchar(5)     NOT NULL,
    schoolname       varchar(50)    NOT NULL,
    coursenumber     varchar(30)    NOT NULL,
    coursetitle      varchar(100)   NOT NULL,
    pgrad            varchar(2)     NOT NULL,
    pmosen4          varchar(10)    NOT NULL,
    crmgof           char(2)        NOT NULL,
    crstype          char(2)        NOT NULL,
    numberofstudents integer,
    amcosversionid   integer        NOT NULL,
    CONSTRAINT pk_atrrs PRIMARY KEY (id)
);
