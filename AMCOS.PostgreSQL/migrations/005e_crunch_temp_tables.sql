-- crunch_temp STAGING tables (crunch_temp.*).
--
-- These are the staging / scratch tables consumed and populated by the Phase-3
-- cost procedures ported from the legacy SQL Server crunch engine:
-- CostOfTraining, CostOfRecruiting, CostOfOfficerAcquisition,
-- CostOfSelectiveRetentionBonus, and the recursive helper functions.
--
-- Every table is EMPTY until those procs run; they are TRUNCATEd and repopulated
-- on each crunch. The crunch_temp schema already exists (see 000_schemas.sql).
--
-- T-SQL -> PG conversions applied throughout: NVARCHAR(n)/VARCHAR(n)->varchar(n),
-- NCHAR(n)->char(n), TINYINT->smallint, INT->integer, BIGINT->bigint,
-- FLOAT(53)->double precision, MONEY->numeric(19,4), SMALLDATETIME/DATETIME->timestamp,
-- NUMERIC(p,s) kept, PRIMARY KEY CLUSTERED->PRIMARY KEY, COLLATE / DF_ default
-- constraint names dropped, nonclustered/clustered indexes omitted. Table and
-- column names are lowercased and unquoted. Column names containing spaces,
-- slashes or hyphens are normalised to underscores (e.g. [Modal Grade]->modal_grade).

-- Source: crunch_temp/Tables/ATRM.sql
CREATE TABLE IF NOT EXISTS crunch_temp.atrm (
    schoolcode        varchar(25),
    coursenumber      varchar(50),
    coursetitle       varchar(100),
    activity          varchar(100),
    courselengthweeks numeric(18, 4),
    egrads            numeric(18, 4),
    modal_grade       varchar(10),
    frequency         numeric(18, 4),
    flying_hours      numeric(18, 4),
    tmw_egrad         numeric(18, 4),
    mpa               numeric(18, 4),
    oma_civ           numeric(18, 4),
    oma_non_pay       numeric(18, 4),
    other             numeric(18, 4),
    amcosversionid    integer
);

-- Source: crunch_temp/Tables/ATRRS.sql
CREATE TABLE IF NOT EXISTS crunch_temp.atrrs (
    cpbranch         char(1),
    schoolcode       varchar(5),
    schoolname       varchar(50),
    crsph            varchar(30),
    coursetitle      varchar(100),
    pgrad            varchar(2),
    pmosen4          varchar(10),
    crmgof           char(2),
    crstype          char(2),
    numberofstudents integer,
    amcosversionid   integer
);

-- Source: crunch_temp/Tables/ATRRSOfficerBranchCodes.sql
CREATE TABLE IF NOT EXISTS crunch_temp.atrrsofficerbranchcodes (
    cmf            varchar(3),
    branch         varchar(3),
    definition     varchar(255),
    amcosversionid integer
);

-- Source: crunch_temp/Tables/ATRRS_ATRM_Raw.sql
CREATE TABLE IF NOT EXISTS crunch_temp.atrrs_atrm_raw (
    exception              varchar(50),
    atrm_other             numeric(18, 4),
    atrm_oma               numeric(18, 4),
    atrm_mpa               numeric(18, 4),
    atrm_tmw_egrd          numeric(18, 4),
    atrm_flying_hrs        numeric(18, 4),
    atrm_frequency         numeric(18, 4),
    atrm_modal_grade       varchar(10),
    atrm_egrads            numeric(18, 4),
    atrm_courselengthweeks numeric(18, 4),
    atrm_activity          varchar(100),
    atrm_coursetitle       varchar(100),
    atrm_coursenumber      varchar(50),
    atrm_schoolcode        varchar(25),
    atrm_versionid         integer,
    atrm_key               varchar(50),
    atrrs_key              varchar(50),
    amcosversionid         integer,
    atrrs_versionid        integer,
    atrrs_schoolcode       varchar(255),
    atrrs_coursenumber     varchar(255),
    atrrs_component        varchar(255),
    atrrs_school           varchar(255),
    atrrs_coursetitle      varchar(255),
    atrrs_gradelevel       varchar(255),
    atrrs_mos              varchar(255),
    atrrs_branch           varchar(255),
    atrrs_crstype          varchar(2),
    atrrs_numberofstudents numeric(18, 4)
);

-- Source: crunch_temp/Tables/AtrrsAtrmCourseMos.sql
CREATE TABLE IF NOT EXISTS crunch_temp.atrrsatrmcoursemos (
    atrrs_numberofstudents   integer,
    atrrs_crstype            varchar(255),
    atrrs_branch             varchar(255),
    atrrs_mos                varchar(255),
    atrrs_gradelevel         varchar(255),
    atrrs_coursetitle        varchar(255),
    atrrs_school             varchar(255),
    atrrs_component          varchar(255),
    atrrs_coursenumber       varchar(255),
    atrrs_schoolcode         varchar(255),
    atrrs_versionid          integer,
    amcosversionid           integer,
    atrrs_key                varchar(50),
    atrm_key                 varchar(50),
    atrm_versionid           integer,
    atrm_schoolcode          varchar(25),
    atrm_coursenumber        varchar(50),
    atrm_coursetitle         varchar(100),
    atrm_activity            varchar(100),
    atrm_courselengthweeks   numeric(18, 4),
    atrm_egrads              numeric(18, 4),
    atrm_modal_grade         varchar(10),
    atrm_frequency           numeric(18, 4),
    atrm_flying_hrs          numeric(18, 4),
    atrm_tmw_egrd            numeric(18, 4),
    atrm_mpa                 numeric(18, 4),
    atrm_oma                 numeric(18, 4),
    atrm_other               numeric(18, 4),
    exception                varchar(50),
    crs_type_o               varchar(4),
    crs_type_e               varchar(4),
    weaponsystemname         varchar(50),
    aoc                      varchar(8),
    womos                    varchar(8),
    mos                      varchar(8),
    o_gradelevel_floor       integer,
    o_gradelevel_ceiling     integer,
    w_gradelevel_floor       integer,
    w_gradelevel_ceiling     integer,
    e_gradelevel_floor       integer,
    e_gradelevel_ceiling     integer,
    coursetypefinal          varchar(10),
    mosfinal                 varchar(10),
    branchfinal              varchar(10),
    gradefinal               varchar(10),
    gradetypefinal           varchar(10),
    gradelevelfinal          varchar(10),
    payplan                  varchar(10),
    atrrs_tot_students       integer,
    numberofstudentsadjusted numeric(18, 4),
    running_adj_students     numeric(18, 4),
    inventory                integer,
    inventoryadjustment      numeric(18, 4),
    total_inv_add            numeric(18, 4),
    final_adj_inv            numeric(18, 4),
    final_adj_students       numeric(18, 4)
);

-- Source: crunch_temp/Tables/BonusCaps.sql
CREATE TABLE IF NOT EXISTS crunch_temp.bonuscaps (
    mos            varchar(3)     NOT NULL,
    cap            numeric(16, 2),
    amcosversionid integer        NOT NULL
);

-- Source: crunch_temp/Tables/CostGFEBS.sql
CREATE TABLE IF NOT EXISTS crunch_temp.costgfebs (
    payplan                  varchar(3),
    occupationalgroupnumber  varchar(4),
    occupationalseriesnumber varchar(4)     NOT NULL,
    statecountry             varchar(50)    NOT NULL,
    functionalareacode       varchar(50)    NOT NULL,
    costcentercode           varchar(50)    NOT NULL,
    gradelevel               smallint       NOT NULL,
    step                     smallint,
    personnelnumber          varchar(10)    NOT NULL,
    actualhourlyrate         numeric(18, 4),
    costelementid            integer        NOT NULL,
    amount                   numeric(18, 4) NOT NULL,
    crunchtime               timestamp
);

-- Source: crunch_temp/Tables/CostOfOfficerAcquisitionByAoc.sql
CREATE TABLE IF NOT EXISTS crunch_temp.costofofficeracquisitionbyaoc (
    payplan              varchar(3)     NOT NULL,
    categorygroupcode    varchar(4)     NOT NULL,
    categorysubgroupcode varchar(4)     NOT NULL,
    gradetype            varchar(3)     NOT NULL,
    gradelevel           smallint       NOT NULL,
    inv                  integer,
    cglainventory        numeric(16, 2),
    ofc_acq_mpa          numeric(16, 2),
    ofc_acq_oma          numeric(16, 2),
    bonus_mpa            numeric(16, 2),
    cgla_bonus_mpa       numeric(16, 2)
);

-- Source: crunch_temp/Tables/CostOfOfficerAcquisitionTotal.sql
CREATE TABLE IF NOT EXISTS crunch_temp.costofofficeracquisitiontotal (
    payplan varchar(3),
    mpa     numeric(16, 2),
    oma     numeric(16, 2)
);

-- Source: crunch_temp/Tables/CostOfRecruiting.sql
CREATE TABLE IF NOT EXISTS crunch_temp.costofrecruiting (
    payplan                   varchar(3)     NOT NULL,
    categorygroupcode         varchar(4)     NOT NULL,
    categorysubgroupcode      varchar(4)     NOT NULL,
    gradetype                 varchar(3)     NOT NULL,
    gradelevel                smallint       NOT NULL,
    inventory                 integer,
    bonusaverageannualpay     numeric(16, 2),
    bonus_avg_annual_payments numeric(16, 2),
    bonuspaycap               numeric(16, 2),
    bonus_capped_amt          numeric(16, 2),
    cglainventory             numeric(16, 2),
    cgla_bonus                numeric(16, 2),
    mpa_recruiting            numeric(16, 2),
    oma_recruiting            numeric(16, 2),
    mpa_total                 numeric(16, 2)
);

-- Source: crunch_temp/Tables/CostOfSelectiveRetentionBonus.sql
CREATE TABLE IF NOT EXISTS crunch_temp.costofselectiveretentionbonus (
    payplan              varchar(3)     NOT NULL,
    categorygroupcode    varchar(4)     NOT NULL,
    categorysubgroupcode varchar(4)     NOT NULL,
    gradetype            varchar(3)     NOT NULL,
    gradelevel           smallint       NOT NULL,
    inventory            integer        NOT NULL,
    cglainventory        integer        NOT NULL,
    averageannualpay     numeric(16, 2) NOT NULL,
    paycap               numeric(16, 2) NOT NULL,
    cgla_mpa_pay         numeric(16, 2) NOT NULL
);

-- Source: crunch_temp/Tables/DMDCBonus.sql
CREATE TABLE IF NOT EXISTS crunch_temp.dmdcbonus (
    paytype             varchar(50),
    payplan             varchar(3),
    cmf                 varchar(2),
    subgrp              varchar(4),
    gradetype           varchar(2),
    gradelevel          varchar(2),
    avg_cost            double precision,
    amcosversionid      integer,
    avg_annual_pay      double precision,
    avg_annual_payments double precision,
    pay_cap             double precision,
    capped_avg_mpa_pay  double precision
);

-- Source: crunch_temp/Tables/DMDCPayProcessed.sql
CREATE TABLE IF NOT EXISTS crunch_temp.dmdcpayprocessed (
    paytype              varchar(50),
    payplan              varchar(3),
    categorygroupcode    varchar(4),
    categorysubgroupcode varchar(4),
    gradetype            varchar(3),
    gradelevel           smallint,
    avg_cost             numeric(16, 2),
    amcosversionid       integer,
    avg_annual_pay       numeric(16, 2),
    avg_annual_payments  numeric(16, 2),
    pay_cap              numeric(16, 2),
    capped_avg_mpa_pay   numeric(16, 2)
);

-- Source: crunch_temp/Tables/MOSAOC_Validation.sql
CREATE TABLE IF NOT EXISTS crunch_temp.mosaoc_validation (
    mos            varchar(4),
    gradetype      varchar(3),
    gradelevel     smallint,
    value          char(1),
    amcosversionid integer
);

-- Source: crunch_temp/Tables/MilitaryConversions.sql
CREATE TABLE IF NOT EXISTS crunch_temp.militaryconversions (
    oldmos         varchar(4),
    grade          varchar(1),
    newmos         varchar(4),
    gradelevel     varchar(2),
    amcosversionid integer
);

-- Source: crunch_temp/Tables/MilitarySRBCaps.sql
CREATE TABLE IF NOT EXISTS crunch_temp.militarysrbcaps (
    mos            varchar(3)     NOT NULL,
    gradelevel     varchar(2)     NOT NULL,
    tier           integer        NOT NULL,
    amcosversionid integer        NOT NULL,
    bonuscap       numeric(16, 2)
);

-- Source: crunch_temp/Tables/SOCTransaction.sql
CREATE TABLE IF NOT EXISTS crunch_temp.soctransaction (
    payplan      varchar(3),
    grade        varchar(255),
    soc          varchar(255),
    soc_name     varchar(255),
    number       double precision,
    mypercent    double precision,
    mpa_cost     double precision,
    oma_cost     double precision,
    pp_inventory double precision,
    avg_mpa      double precision,
    avg_oma      double precision
);

-- Source: crunch_temp/Tables/SOCTransactionGL.sql
CREATE TABLE IF NOT EXISTS crunch_temp.soctransactiongl (
    payplan    varchar(3),
    grade      varchar(255),
    gradelevel varchar(255),
    soc        varchar(255),
    soc_name   varchar(255),
    total      double precision
);

-- Source: crunch_temp/Tables/SRBPay.sql
CREATE TABLE IF NOT EXISTS crunch_temp.srbpay (
    payplan              varchar(3)     NOT NULL,
    categorygroupcode    varchar(4)     NOT NULL,
    categorysubgroupcode varchar(4)     NOT NULL,
    gradetype            varchar(3)     NOT NULL,
    gradelevel           smallint       NOT NULL,
    inventory            integer        NOT NULL,
    cglainventory        integer        NOT NULL,
    avg_annual_pay       numeric(16, 2) NOT NULL,
    pay_cap              numeric(16, 2) NOT NULL,
    cgla_mpa_pay         numeric(16, 2) NOT NULL
);

-- Source: crunch_temp/Tables/SelectiveRetentionBonusCaps.sql
CREATE TABLE IF NOT EXISTS crunch_temp.selectiveretentionbonuscaps (
    mos            varchar(3)     NOT NULL,
    gradelevel     varchar(2)     NOT NULL,
    tier           integer        NOT NULL,
    bonuscap       numeric(16, 2),
    amcosversionid integer        NOT NULL
);

-- Source: crunch_temp/Tables/TrainingCosts.sql
CREATE TABLE IF NOT EXISTS crunch_temp.trainingcosts (
    weaponsystemname     varchar(50),
    coursetype           varchar(10),
    payplan              varchar(3)     NOT NULL,
    categorygroupcode    varchar(4)     NOT NULL,
    categorysubgroupcode varchar(4)     NOT NULL,
    gradetype            varchar(3)     NOT NULL,
    gradelevel           smallint       NOT NULL,
    inventory            integer,
    mpa_mos              numeric(18, 4),
    oma_mos              numeric(18, 4),
    other_mos            numeric(18, 4),
    mpa_cmf              numeric(18, 4),
    oma_cmf              numeric(18, 4),
    other_cmf            numeric(18, 4),
    mpa_pp               numeric(18, 4),
    oma_pp               numeric(18, 4),
    other_pp             numeric(18, 4),
    cgla_mos_inv         numeric(18, 4),
    cgla_cmf_inv         numeric(18, 4),
    cgla_pp_inv          numeric(18, 4),
    cgla_mpa             numeric(18, 4),
    cgla_oma             numeric(18, 4),
    cgla_other           numeric(18, 4),
    rpa_ngpa             numeric(18, 4),
    omar_omng            numeric(18, 4),
    weaponsystemid       integer
);

-- Source: crunch_temp/Tables/TrainingCostsAverage.sql
CREATE TABLE IF NOT EXISTS crunch_temp.trainingcostsaverage (
    weaponsystemname     varchar(50),
    coursetypefinal      varchar(10),
    mosfinal             varchar(10),
    gradetypefinal       varchar(10),
    gradelevelfinal      varchar(10),
    payplan              varchar(10),
    inventory            integer,
    mpa_total_avg_cost   numeric(18, 4),
    oma_total_avg_cost   numeric(18, 4),
    other_total_avg_cost numeric(18, 4),
    mpa_adj              numeric(18, 4),
    oma_adj              numeric(18, 4),
    other_adj            numeric(18, 4)
);

-- Source: crunch_temp/Tables/TrainingCostsByVersion.sql
CREATE TABLE IF NOT EXISTS crunch_temp.trainingcostsbyversion (
    amcosversionid           integer,
    atrm_key                 varchar(50),
    atrrs_key                varchar(50),
    atrm_coursetitle         varchar(100),
    atrm_mpa                 numeric(18, 4),
    atrm_oma                 numeric(18, 4),
    atrm_other               numeric(18, 4),
    inventory                integer,
    payplan                  varchar(10),
    mosfinal                 varchar(10),
    coursetypefinal          varchar(10),
    weaponsystemname         varchar(50),
    gradetypefinal           varchar(10),
    gradelevelfinal          varchar(10),
    numberofstudentsadjusted numeric(18, 4),
    mpa_total_cost           numeric(18, 4),
    oma_total_cost           numeric(18, 4),
    other_total_cost         numeric(18, 4)
);

-- Source: crunch_temp/Tables/Training_xwalk_atrrs_atrm.sql
CREATE TABLE IF NOT EXISTS crunch_temp.training_xwalk_atrrs_atrm (
    atrm_key       varchar(50) NOT NULL,
    atrrs_key      varchar(50) NOT NULL,
    amcosversionid integer     NOT NULL,
    CONSTRAINT pk_temptraining_xwalk_atrrs_atrm PRIMARY KEY (atrm_key, atrrs_key, amcosversionid)
);

-- Source: crunch_temp/Tables/Training_xwalk_atrrs_crstype_mos.sql
CREATE TABLE IF NOT EXISTS crunch_temp.training_xwalk_atrrs_crstype_mos (
    atrrs_schoolcode     varchar(255),
    atrrs_coursenumber   varchar(255),
    crs_type_o           varchar(4),
    crs_type_e           varchar(4),
    weaponsystemname     varchar(50),
    aoc                  varchar(8),
    womos                varchar(8),
    mos                  varchar(8),
    o_gradelevel_floor   integer,
    o_gradelevel_ceiling integer,
    w_gradelevel_floor   integer,
    w_gradelevel_ceiling integer,
    e_gradelevel_floor   integer,
    e_gradelevel_ceiling integer,
    amcosversionid       integer
);
