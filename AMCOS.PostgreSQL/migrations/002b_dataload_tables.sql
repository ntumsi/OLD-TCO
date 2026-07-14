-- =====================================================================
-- 002b_dataload_tables.sql
--
-- Purpose: Input/staging tables in the lowercase `dataload` schema that the
-- ported AMCOS cost-crunch engine (006*.sql) reads from but that were not yet
-- created by earlier migrations. Ported from the SQL Server source under
-- AMCOS.AMCOS2020_MAR/dataload/Tables/.
--
-- Conventions (see DDL_PORT_CONVENTIONS.md):
--   * All identifiers lowercase & unquoted, except columns that collide with
--     PG reserved words ("group", "dec"), which are quoted to match proc usage.
--   * T-SQL types translated: NVARCHAR->varchar, NCHAR->char, TINYINT->smallint,
--     BIT->boolean, FLOAT(53)->double precision, NUMERIC preserved, INT->integer.
--   * IDENTITY / CLUSTERED / filegroup / storage options / FKs dropped; PKs kept.
--
-- Source files:
--   dataload/Tables/ArmyBudget.sql, ArmyBudgetManualValues.sql, BAHRates.sql,
--   ConusCola.sql, ConusColaLocations.sql, DoDOCONUSPerDiem_Raw.sql,
--   DoSLivingAllowance.sql, DoSPostAllowance.sql, GSAPerDiem_Raw.sql,
--   MilitaryAnnualComp.sql, MilitaryEnlistmentBonusCap.sql,
--   MilitaryOverseasHousingAllowance.sql, MilitarySpendableIncome.sql,
--   MilitarySRBCaps.sql, NonLocalityBAHRates.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- dataload.armybudget  <- dataload/Tables/ArmyBudget.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.armybudget (
    id                      integer      NOT NULL,
    position                varchar(255),
    fy                      smallint,
    amount                  numeric(18),
    bo                      varchar(1),
    bo_desc                 varchar(255),
    appn                    varchar(5),
    appn_desc               varchar(255),
    tc                      varchar(50),
    appn_cat_abbr           varchar(255),
    appn_cat_desc           varchar(255),
    compo                   varchar(255),
    rc                      varchar(5),
    rc_desc                 varchar(255),
    rc_type                 varchar(255),
    ape                     varchar(10),
    ape_pt_desc             varchar(255),
    amsco                   varchar(255),
    sag                     varchar(255),
    sag_desc                varchar(255),
    ba                      varchar(50),
    ba_desc                 varchar(255),
    spc                     varchar(50),
    roll_ssn                varchar(255),
    roll_ssn_desc           varchar(255),
    mdep                    varchar(255),
    mdep_desc               varchar(255),
    peg                     varchar(255),
    peg_desc                varchar(255),
    roc                     varchar(4),
    roc_desc                varchar(255),
    cmd                     varchar(2),
    cmd_desc                varchar(255),
    ctype                   varchar(255),
    ctype_desc              varchar(255),
    fsc                     varchar(255),
    fsc_desc                varchar(255),
    uic                     varchar(6),
    uic_desc                varchar(255),
    dp99_desc               varchar(255),
    dp99                    varchar(255),
    reimc                   varchar(255),
    reims                   varchar(255),
    osdpe                   varchar(255),
    osdpe_desc              varchar(255),
    osdseqno                varchar(255),
    ric                     varchar(5),
    ric_desc                varchar(255),
    pid                     varchar(50),
    pid_desc                varchar(255),
    jca_portfolio           varchar(255),
    mhc                     varchar(50),
    mhc_desc                varchar(255),
    fic                     varchar(255),
    fic_desc                varchar(255),
    objective_id            char(1),
    objective               varchar(255),
    subobjective_id         varchar(5),
    subobjective            varchar(255),
    task_id                 varchar(255),
    task                    varchar(255),
    ii_bin                  varchar(255),
    ee_root                 varchar(255),
    ee_bos                  varchar(255),
    tt_group                varchar(255),
    ss_program              varchar(255),
    dollar_type             varchar(255),
    dollar_type_desc        varchar(255),
    ape6                    varchar(255),
    ape_desc                varchar(255),
    ape_pt                  varchar(255),
    bsa                     varchar(255),
    ctc                     varchar(255),
    cwoc                    varchar(255),
    cycle_code              varchar(255),
    dmc                     varchar(255),
    memo                    varchar(255),
    mor                     varchar(255),
    mor_desc                varchar(255),
    oma_bin                 varchar(255),
    org                     varchar(255),
    osdpe_pid               varchar(255),
    osdpe_pid_desc          varchar(255),
    position_pub_date       varchar(255),
    rag                     varchar(255),
    tac                     varchar(255),
    date_eff                date,
    amcosversionid          integer,
    osd_location            varchar(75),
    osd_location_desc       varchar(75),
    facility_category       varchar(75),
    facility_category_desc  varchar(75),
    osd_state_country       varchar(75),
    osd_state_country_desc  varchar(75),
    installation_name       varchar(75),
    bli                     varchar(50),
    subtask                 varchar(255),
    subtask_id              varchar(50),
    osdpe_pid_group         varchar(50),
    osd_pid_group_desc      varchar(255),
    osd_pid_group           varchar(255),
    CONSTRAINT pk_armybudget PRIMARY KEY (id)
);


-- ---------------------------------------------------------------------
-- dataload.armybudgetmanualvalues  <- dataload/Tables/ArmyBudgetManualValues.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.armybudgetmanualvalues (
    paytype         varchar(50)    NOT NULL,
    gradetype       varchar(1)     NOT NULL,
    gradelevel      integer        NOT NULL,
    amount          numeric(18, 2) NOT NULL,
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_armybudgetmanualvalues PRIMARY KEY (gradelevel, paytype, gradetype, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.bahrates  <- dataload/Tables/BAHRates.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.bahrates (
    mha             varchar(5)     NOT NULL,
    gradetype       varchar(3)     NOT NULL,
    gradelevel      smallint       NOT NULL,
    withdependents  boolean        NOT NULL,
    amount          numeric(7, 2),
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_bahrates PRIMARY KEY (mha, gradetype, gradelevel, withdependents, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.conuscola  <- dataload/Tables/ConusCola.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.conuscola (
    gradetype       varchar(3)     NOT NULL,
    gradelevel      smallint       NOT NULL,
    yos             varchar(255)   NOT NULL,
    withdependents  boolean        NOT NULL,
    amount          numeric(3),
    amcosversionid  integer        NOT NULL,
    CONSTRAINT pk_conuscola PRIMARY KEY (gradetype, gradelevel, yos, withdependents, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.conuscolalocations  <- dataload/Tables/ConusColaLocations.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.conuscolalocations (
    zipcode          varchar(5)    NOT NULL,
    dutystationindex char(2)       NOT NULL,
    mhadescription   varchar(50),
    amcosversionid   integer       NOT NULL,
    CONSTRAINT pk_conuscolalocations PRIMARY KEY (zipcode, dutystationindex, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.dodoconusperdiem_raw  <- dataload/Tables/DoDOCONUSPerDiem_Raw.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.dodoconusperdiem_raw (
    statecounty           varchar(100) NOT NULL,
    location              varchar(200) NOT NULL,
    seasonbegin           varchar(50)  NOT NULL,
    seasonend             varchar(5)   NOT NULL,
    lodging               integer,
    localmealrate         integer,
    proportionalmealrate  integer,
    localincidental       integer,
    maximumperdiem        integer,
    effectivedate         date         NOT NULL,
    amcosversionid        integer      NOT NULL,
    CONSTRAINT pk_dodoconusperdiem_raw PRIMARY KEY (statecounty, location, seasonbegin, seasonend, effectivedate, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.doslivingallowance  <- dataload/Tables/DoSLivingAllowance.sql
-- Note: "group" is a PG reserved word; procs reference it as b."group".
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.doslivingallowance (
    locationcode    varchar(50)    NOT NULL,
    amt             numeric(18, 2) NOT NULL,
    family          integer        NOT NULL,
    "group"         integer        NOT NULL,
    amcosversionid  integer        NOT NULL DEFAULT 202101,
    CONSTRAINT doslivingallowancepk PRIMARY KEY (locationcode, amcosversionid, family, "group")
);


-- ---------------------------------------------------------------------
-- dataload.dospostallowance  <- dataload/Tables/DoSPostAllowance.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.dospostallowance (
    locationcode    varchar(50)    NOT NULL,
    postallowance   numeric(5, 4),
    hardship        numeric(5, 4),
    dangerpay       numeric(5, 4),
    amcosversionid  integer        NOT NULL DEFAULT 202101,
    CONSTRAINT dosdospostallowancepk PRIMARY KEY (locationcode, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.gsaperdiem_raw  <- dataload/Tables/GSAPerDiem_Raw.sql
-- Note: "dec" is a PG reserved word; procs reference it as MAX("dec").
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.gsaperdiem_raw (
    id               integer          NOT NULL,
    destinationid    double precision NOT NULL,
    name             varchar(50),
    county           varchar(50),
    locationdefined  varchar(500),
    state            varchar(50),
    zip              varchar(5)       NOT NULL,
    fiscalyear       double precision,
    oct              double precision,
    nov              double precision,
    "dec"            double precision,
    jan              double precision,
    feb              double precision,
    mar              double precision,
    apr              double precision,
    may              double precision,
    jun              double precision,
    jul              double precision,
    aug              double precision,
    sep              double precision,
    meals            double precision,
    amcosversionid   integer          DEFAULT (extract(year from now())::integer * 100 + 1),
    CONSTRAINT pk_gsaperdiem_raw PRIMARY KEY (id)
);


-- ---------------------------------------------------------------------
-- dataload.militaryannualcomp  <- dataload/Tables/MilitaryAnnualComp.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.militaryannualcomp (
    grade               varchar(3)     NOT NULL,
    gradelevel          smallint       NOT NULL,
    yos                 integer        NOT NULL,
    hasdependents       boolean        NOT NULL,
    annualcompensation  numeric(16, 2) NOT NULL,
    amcosversionid      integer        NOT NULL,
    CONSTRAINT pk_militaryannualcomp PRIMARY KEY (grade, gradelevel, yos, hasdependents, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.militaryenlistmentbonuscap  <- dataload/Tables/MilitaryEnlistmentBonusCap.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.militaryenlistmentbonuscap (
    mos             varchar(3)       NOT NULL,
    cap             double precision,
    amcosversionid  integer          NOT NULL,
    CONSTRAINT pk_militaryenlistmentbonuscap PRIMARY KEY (mos, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.militaryoverseashousingallowance  <- dataload/Tables/MilitaryOverseasHousingAllowance.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.militaryoverseashousingallowance (
    loccode                       varchar(50)      NOT NULL,
    locname                       varchar(100)     NOT NULL,
    exchdate                      integer          NOT NULL,
    ohaefdat                      integer          NOT NULL,
    keyloc                        varchar(50)      NOT NULL,
    xrat                          double precision NOT NULL,
    ocola_index                   integer          NOT NULL,
    ocola_groupcode               integer          NOT NULL,
    clim                          integer          NOT NULL,
    perc_o_utility_wdep           integer          NOT NULL,
    perc_e_utility_wdep           integer          NOT NULL,
    o_utility_wdep                integer          NOT NULL,
    e_utility_wdep                integer          NOT NULL,
    perc_o_rentalallowance_wodep  integer          NOT NULL,
    perc_e_rentalallowance_wodep  integer          NOT NULL,
    colefdat                      integer          NOT NULL,
    o_miha                        integer          NOT NULL,
    e_miha                        integer          NOT NULL,
    auth_miha_security            integer          NOT NULL,
    country_code                  varchar(50)      NOT NULL,
    currency_code                 varchar(50)      NOT NULL,
    off_curr_name                 varchar(50)      NOT NULL,
    mkt_curr                      varchar(50)      NOT NULL,
    mkt_name                      varchar(50)      NOT NULL,
    grade                         varchar(3)       NOT NULL,
    gradelevel                    smallint         NOT NULL,
    rentalamt_wdep                integer          NOT NULL,
    amcosversionid                integer          NOT NULL,
    CONSTRAINT pk_militaryoverseashousingallowance PRIMARY KEY (loccode, grade, gradelevel, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.militaryspendableincome  <- dataload/Tables/MilitarySpendableIncome.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.militaryspendableincome (
    lowerlimit          integer NOT NULL,
    upperlimit          integer NOT NULL,
    numberofdependents  integer NOT NULL,
    spendableincome     integer NOT NULL,
    amcosversionid      integer NOT NULL,
    CONSTRAINT pk_militaryspendableincome PRIMARY KEY (lowerlimit, upperlimit, numberofdependents, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.militarysrbcaps  <- dataload/Tables/MilitarySRBCaps.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.militarysrbcaps (
    mos             varchar(3)       NOT NULL,
    gradelevel      varchar(2)       NOT NULL,
    tier            integer          NOT NULL,
    amcosversionid  integer          NOT NULL,
    bonuscap        double precision,
    CONSTRAINT pk_militarysrbcaps PRIMARY KEY (mos, gradelevel, tier, amcosversionid)
);


-- ---------------------------------------------------------------------
-- dataload.nonlocalitybahrates  <- dataload/Tables/NonLocalityBAHRates.sql
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataload.nonlocalitybahrates (
    gradetype               varchar(3)     NOT NULL,
    gradelevel              smallint       NOT NULL,
    ratepartial             numeric(7, 2),
    ratewithoutdependents   numeric(7, 2),
    ratewithdependents      numeric(7, 2),
    ratedifferential        numeric(7, 2),
    amcosversionid          integer        NOT NULL,
    CONSTRAINT pk_nonlocalitybahrates PRIMARY KEY (gradetype, gradelevel, amcosversionid)
);
