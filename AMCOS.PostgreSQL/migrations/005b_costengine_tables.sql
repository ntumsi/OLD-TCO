-- Cost-engine base tables (crunch / BLS_OES / dataload) consumed by the web layer.
--
-- These hold the OUTPUT of the cost-crunch engine and are POPULATED BY THE PYTHON ETL
-- (etl/). The migrations only define the schema so the data.* views and web.* cost
-- functions resolve; the tables are empty until the ETL runs. See MIGRATION_PARITY_AUDIT.md
-- (Tier B). Runs after 005 (warehouse) and before 006/008 so the data.* views can build.
--
-- Scope is the WEB-needed subset only: the 15 crunch.Costs_* tables (data.Costs), the three
-- inventory tables (data.Inventory), per-diem (Civilian PCS), and BLS OES (data.CostsCCE /
-- CCE inventory). The PaySchedule.* and pay-processing crunch tables are crunch-engine
-- internals not read by the web app and are intentionally omitted.

------------------------------------------------------------------------------
-- crunch.Costs_* (source for the data.Costs union view)
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_AE.sql
CREATE TABLE crunch.costs_ae (
    payplan varchar(3) NOT NULL,
    cmf char(2) NOT NULL,
    mos varchar(3) NOT NULL,
    mha varchar(5) DEFAULT '-1' NOT NULL,
    locationid integer NOT NULL,
    dependentstatus varchar(25) DEFAULT '-1' NOT NULL,
    weaponsystemid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    costelementid integer NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_ae PRIMARY KEY (payplan, cmf, mos, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_AO.sql
CREATE TABLE crunch.costs_ao (
    payplan varchar(3) NOT NULL,
    cmf char(2) NOT NULL,
    aoc varchar(3) NOT NULL,
    mha varchar(5) DEFAULT '-1' NOT NULL,
    locationid integer NOT NULL,
    dependentstatus varchar(25) DEFAULT '-1' NOT NULL,
    weaponsystemid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    costelementid integer NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_ao PRIMARY KEY (payplan, cmf, aoc, mha, dependentstatus, locationid, costelementid, gradetype, gradelevel, weaponsystemid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_AWO.sql
CREATE TABLE crunch.costs_awo (
    payplan varchar(3) NOT NULL,
    branch char(2) NOT NULL,
    womos varchar(4) NOT NULL,
    mha varchar(5) DEFAULT '-1' NOT NULL,
    locationid integer NOT NULL,
    dependentstatus varchar(25) DEFAULT '-1' NOT NULL,
    weaponsystemid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    costelementid integer NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_awo PRIMARY KEY (payplan, branch, womos, mha, dependentstatus, locationid, costelementid, gradetype, gradelevel, weaponsystemid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_CY.sql
CREATE TABLE crunch.costs_cy (
    payplan varchar(3) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(5) NOT NULL,
    locationid integer NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    payband smallint NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_cy PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid, locationid, gradetype, payband, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_G.sql
CREATE TABLE crunch.costs_g (
    payplan varchar(3) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(5) NOT NULL,
    careerprogramnumber char(2) NOT NULL,
    locationid integer NOT NULL,
    numberofdependents integer DEFAULT -1 NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_g PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, locationid, numberofdependents, costelementid, gradetype, gradelevel, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_GFEBS.sql
CREATE TABLE crunch.costs_gfebs (
    payplan varchar(2) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(4) NOT NULL,
    careerprogramnumber char(2) NOT NULL,
    localitycode varchar(6) NOT NULL,
    country varchar(50) NOT NULL,
    locationid integer NOT NULL,
    strl varchar(20) NOT NULL,
    costelementid integer NOT NULL,
    gradelevel smallint NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_gfebs PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, costelementid, gradelevel, country, localitycode, locationid, strl, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_NE.sql
CREATE TABLE crunch.costs_ne (
    payplan varchar(3) NOT NULL,
    cmf char(2) NOT NULL,
    mos varchar(3) NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    weaponsystemid integer NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_ne PRIMARY KEY (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_NF.sql
CREATE TABLE crunch.costs_nf (
    payplan varchar(3) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(5) NOT NULL,
    locationid integer NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    payband smallint NOT NULL,
    amount numeric(16, 2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_nf PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid, locationid, gradetype, payband, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_NO.sql
CREATE TABLE crunch.costs_no (
    payplan varchar(3) NOT NULL,
    cmf char(2) NOT NULL,
    aoc varchar(3) NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    weaponsystemid integer NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_no PRIMARY KEY (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_NWO.sql
CREATE TABLE crunch.costs_nwo (
    payplan varchar(3) NOT NULL,
    branch char(2) NOT NULL,
    womos varchar(4) NOT NULL,
    weaponsystemid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    costelementid integer NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_nwo PRIMARY KEY (payplan, branch, womos, weaponsystemid, gradetype, gradelevel, costelementid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_RE.sql
CREATE TABLE crunch.costs_re (
    payplan varchar(3) NOT NULL,
    cmf char(2) NOT NULL,
    mos varchar(3) NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    weaponsystemid integer NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_re PRIMARY KEY (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_RO.sql
CREATE TABLE crunch.costs_ro (
    payplan varchar(3) NOT NULL,
    cmf char(2) NOT NULL,
    aoc varchar(3) NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    weaponsystemid integer NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_ro PRIMARY KEY (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_RWO.sql
CREATE TABLE crunch.costs_rwo (
    payplan varchar(3) NOT NULL,
    branch char(2) NOT NULL,
    womos varchar(4) NOT NULL,
    weaponsystemid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    costelementid integer NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_rwo PRIMARY KEY (payplan, branch, womos, weaponsystemid, gradetype, gradelevel, costelementid, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_SES.sql
CREATE TABLE crunch.costs_ses (
    payplan varchar(3) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(4) NOT NULL,
    locationid integer NOT NULL,
    numberofdependents integer NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_ses PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid, gradetype, gradelevel, locationid, numberofdependents, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_Wage.sql
CREATE TABLE crunch.costs_wage (
    payplan varchar(3) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(4) NOT NULL,
    wagearea varchar(3) NOT NULL,
    wageschedule varchar(4) NOT NULL,
    locationid integer NOT NULL,
    numberofdependents integer NOT NULL,
    costelementid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    amount numeric(16,2) NOT NULL,
    crunchtime timestamp NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_costs_wage PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule, locationid, numberofdependents, costelementid, gradetype, gradelevel, amcosversionid)
);

------------------------------------------------------------------------------
-- crunch inventory tables (source for the data.Inventory union view)
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/InventoryProcessed.sql
CREATE TABLE crunch.inventoryprocessed (
    civtype varchar(3) NOT NULL,
    payplan varchar(3) NOT NULL,
    categorygroup varchar(20) NOT NULL,
    categorysubgroup varchar(5) NOT NULL,
    gradetype varchar(2) NOT NULL,
    gradelevel varchar(2) NOT NULL,
    step varchar(2) NOT NULL,
    locationid integer NOT NULL,
    yos smallint NOT NULL,
    inventory integer NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_inventoryprocessed PRIMARY KEY (civtype, payplan, categorygroup, categorysubgroup, step, locationid, yos, gradetype, gradelevel, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Inventory_GFEBS.sql
CREATE TABLE crunch.inventory_gfebs (
    payplan varchar(3) NOT NULL,
    occupationalgroupnumber varchar(4) NOT NULL,
    occupationalseriesnumber varchar(4) NOT NULL,
    locationid integer NOT NULL,
    strl varchar(20) NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    step integer NOT NULL,
    yos integer NULL,
    inventory integer NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_inventory_gfebs PRIMARY KEY (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid, strl, gradetype, gradelevel, step, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/WASS_Processed.sql
CREATE TABLE crunch.wass_processed (
    payplan varchar(3) NOT NULL,
    "group" varchar(20) NOT NULL,
    subgroup varchar(4) NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel varchar(2) NOT NULL,
    step varchar(2) NOT NULL,
    locationid integer NOT NULL,
    inventory integer NOT NULL,
    amcosversionid integer NOT NULL,
    avgpay numeric(18,2) NULL,
    CONSTRAINT pk_wass_processed PRIMARY KEY (payplan, "group", subgroup, step, locationid, gradetype, gradelevel, amcosversionid)
);

------------------------------------------------------------------------------
-- per-diem (Civilian PCS) + BLS OES (CCE costs/inventory)
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/GSAPerDiem.sql
CREATE TABLE crunch.gsaperdiem (
    zipcode varchar(5) NOT NULL,
    fiscalyear smallint NOT NULL,
    maximumlodgingrate integer NOT NULL,
    maximummealsandincidentalsrate integer NOT NULL,
    dateeffective timestamp NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_gsaperdiem PRIMARY KEY (zipcode, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/dataload/Tables/DoSPerDiem.sql
CREATE TABLE dataload.dosperdiem (
    locationcode varchar(50) NOT NULL,
    seasonbegin varchar(50) NOT NULL,
    seasonend varchar(50) NOT NULL,
    maximumlodgingrate integer NOT NULL,
    m_ierate integer NOT NULL,
    _maximumperdiemrate integer NOT NULL,
    effectivedate varchar(50) NOT NULL,
    amcosversionid integer DEFAULT 202101 NOT NULL,
    CONSTRAINT pk_dosperdiem PRIMARY KEY (locationcode, seasonbegin, seasonend, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/BLS_OES/Tables/OccupationalEmploymentStatisticsMetro.sql
CREATE TABLE "BLS_OES".occupationalemploymentstatisticsmetro (
    soc varchar(7) NOT NULL,
    msacode char(7) NOT NULL,
    tot_emp integer NOT NULL,
    emp_prse numeric(5,2) NOT NULL,
    a_mean numeric(18) NOT NULL,
    mean_prse numeric(5,2) NOT NULL,
    a_pct10 numeric(18) NOT NULL,
    a_pct25 numeric(18) NOT NULL,
    a_median numeric(18) NOT NULL,
    a_pct75 numeric(18) NOT NULL,
    a_pct90 numeric(18) NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_occupationalemploymentstatisticsmetro PRIMARY KEY (soc, msacode, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/BLS_OES/Tables/OccupationalEmploymentStatisticsNational.sql
CREATE TABLE "BLS_OES".occupationalemploymentstatisticsnational (
    soc varchar(7) NOT NULL,
    tot_emp integer NOT NULL,
    emp_prse numeric(5,2) NOT NULL,
    a_mean numeric(18) NOT NULL,
    mean_prse numeric(5,2) NOT NULL,
    a_pct10 numeric(18) NOT NULL,
    a_pct25 numeric(18) NOT NULL,
    a_median numeric(18) NOT NULL,
    a_pct75 numeric(18) NOT NULL,
    a_pct90 numeric(18) NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_occupationalemploymentstatisticsnational PRIMARY KEY (soc, amcosversionid)
);

------------------------------------------------------------------------------
-- Additional crunch tables read directly by web.* cost functions.
-- NOTE: the source SQL Server PKs reference columns absent from their own column
-- lists (a data-project inconsistency), so these are created without those PKs.
------------------------------------------------------------------------------

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/PayScheduleMinMax.sql  (web.getminmaxpay)
CREATE TABLE crunch.payscheduleminmax (
    payplan varchar(3) NOT NULL,
    categorygroupcode varchar(4) NOT NULL,
    categorysubgroupcode varchar(5) NOT NULL,
    locationid integer NOT NULL,
    strl varchar(20) NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    minrate numeric(18, 2) NOT NULL,
    maxrate numeric(18, 2) NOT NULL,
    amcosversionid integer NOT NULL,
    appropriation varchar(25) DEFAULT '-1' NOT NULL
);

-- Source: AMCOS.AMCOS2020_MAR/crunch/Tables/Costs_1ActiveDay.sql  (web.pmcostsbypayplanreservecomponents)
CREATE TABLE crunch.costs_1activeday (
    payplan varchar(3) NOT NULL,
    categorysubgroupcode varchar(4) NOT NULL,
    weaponsystemid integer NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    costelementid integer NOT NULL,
    amount numeric(16, 2) NOT NULL,
    amcosversionid integer NOT NULL
);