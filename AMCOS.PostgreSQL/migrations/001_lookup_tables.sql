-- Converted lookup schema tables from AMCOS SQL Server project

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/AMCOSVersion.sql
CREATE TABLE lookup.amcosversion (
    amcosversionid integer NOT NULL,
    description varchar(50) NULL,
    CONSTRAINT pk_amcosversion PRIMARY KEY (amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/AOC.sql
CREATE TABLE lookup.aoc (
    aoc varchar(3) NOT NULL,
    description varchar(250) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_aoc PRIMARY KEY (aoc , amcosversionidend ),
    CONSTRAINT fk_aoc_aoc FOREIGN KEY (aoc, amcosversionidend) REFERENCES lookup.aoc (aoc, amcosversionidend)
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/AOCConversion.sql
CREATE TABLE lookup.aocconversion (
    aocold varchar(3) NOT NULL,
    aocnew varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_aocconversion PRIMARY KEY (aocold , gradelevel , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/ATRRSCourseTypeMOS.sql
CREATE TABLE lookup.atrrscoursetypemos (
    atrrs_schoolcode varchar(4) NOT NULL,
    atrrs_coursenumber varchar(50) NOT NULL,
    crs_type_o varchar(4) NULL,
    crs_type_e varchar(4) NULL,
    weaponsystemname varchar(50) NULL,
    aoc varchar(8) NULL,
    womos varchar(8) NULL,
    mos varchar(8) NULL,
    o_gradelevel_floor integer NULL,
    o_gradelevel_ceiling integer NULL,
    w_gradelevel_floor integer NULL,
    w_gradelevel_ceiling integer NULL,
    e_gradelevel_floor integer NULL,
    e_gradelevel_ceiling integer NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_atrrscoursetypemos PRIMARY KEY (atrrs_schoolcode , atrrs_coursenumber , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/ATRRSOfficerBranchCodes.sql
CREATE TABLE lookup.atrrsofficerbranchcodes (
    id integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    cmf varchar(3) NULL,
    branch varchar(3) NULL,
    definition varchar(255) NULL,
    amcosversionid integer NULL,
    CONSTRAINT pk_atrrsofficerbranchcodes PRIMARY KEY (id )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/ArmyCareerProgram.sql
CREATE TABLE lookup.armycareerprogram (
    careerprogramnumber char(2) NOT NULL,
    title varchar(75) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_careerprogram PRIMARY KEY (careerprogramnumber , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/CMF_Branch_FA.sql
CREATE TABLE lookup.cmf_branch_fa (
    code char(2) NOT NULL,
    gradetype char(1) NOT NULL,
    description varchar(250) NOT NULL,
    codetype varchar(25) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_cmf_branch_fa PRIMARY KEY (code , gradetype , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/CType.sql
CREATE TABLE lookup.ctype (
    code integer NOT NULL,
    description varchar(150) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_ctype PRIMARY KEY (code , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/CensusZIP.sql
CREATE TABLE lookup.censuszip (
    zcta5ce10 varchar(50) NOT NULL,
    geoid10 varchar(50) NULL,
    classfp10 varchar(50) NULL,
    mtfcc10 varchar(50) NULL,
    funcstat10 varchar(50) NULL,
    aland10 varchar(50) NULL,
    awater10 varchar(50) NULL,
    intptlat10 varchar(50) NULL,
    intptlon10 varchar(50) NULL,
    boundary geometry NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_censuszip PRIMARY KEY (zcta5ce10 , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/CostElement.sql
CREATE TABLE lookup.costelement (
    costelementid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    payplan varchar(3) NOT NULL,
    appropriationgroup varchar(50) NULL,
    appn varchar(25) NOT NULL,
    costelementcategory varchar(50) NOT NULL,
    costelementname varchar(250) NOT NULL,
    amort integer NULL,
    model integer NULL,
    locality boolean NULL,
    description varchar(3000) NULL,
    businesslogic varchar(3000) NULL,
    basisofcomputation varchar(3000) NULL,
    source varchar(3000) NULL,
    showorder integer NULL,
    armycestitle varchar(250) NULL,
    osdcapecestitle varchar(250) NULL,
    active boolean NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    applyinflation boolean NULL,
    islocationspecific boolean DEFAULT TRUE NOT NULL,
    CONSTRAINT pk_costelement PRIMARY KEY (costelementid , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/CostSummary.sql
CREATE TABLE lookup.costsummary (
    summaryid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    payplan varchar(3) NOT NULL,
    name varchar(50) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_costsummary PRIMARY KEY (summaryid , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/CostSummaryElement.sql
CREATE TABLE lookup.costsummaryelement (
    summaryid integer NOT NULL,
    costelementid integer NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_summaryelements PRIMARY KEY (summaryid , costelementid , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/DCWFWorkRole.sql
CREATE TABLE lookup.dcwfworkrole (
    workrolecode varchar(3) NOT NULL,
    workrolename varchar(50) NOT NULL,
    tlmspaytablegroup varchar(50) NULL,
    effectivedate date NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_cyberworkcodes PRIMARY KEY (workrolecode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/DosLocations.sql
CREATE TABLE lookup.doslocations (
    locationcode varchar(50) NOT NULL,
    country varchar(50) NOT NULL,
    location varchar(50) NOT NULL,
    amcosversionidstart integer DEFAULT 1 NOT NULL,
    amcosversionidend integer DEFAULT 999999 NOT NULL,
    latitude numeric(7, 4) NULL,
    longitude numeric(7, 4) NULL,
    CONSTRAINT doslocationspk PRIMARY KEY (locationcode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/DutyStation.sql
CREATE TABLE lookup.dutystation (
    dutystationcode varchar(9) NOT NULL,
    lpa varchar(200) NULL,
    cbsa varchar(5) NULL,
    csa varchar(3) NULL,
    city varchar(200) NULL,
    county varchar(200) NULL,
    state varchar(200) NULL,
    country varchar(200) NOT NULL,
    amcosversionidstart integer NOT NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_armybudget PRIMARY KEY (dutystationcode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/FIPS_ZIP.sql
CREATE TABLE lookup.fips_zip (
    fipscode varchar(5) NOT NULL,
    zipcode char(5) NOT NULL,
    city varchar(50) NULL,
    county varchar(50) NULL,
    state char(2) NULL,
    statename varchar(50) NULL,
    statenamecapitalized varchar(50) NULL,
    latitude numeric(7, 4) NULL,
    longitude numeric(7, 4) NULL,
    location geography NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_fips_zip PRIMARY KEY (fipscode , zipcode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GFEBS_ActivityType.sql
CREATE TABLE lookup.gfebs_activitytype (
    activitytypecode varchar(50) NOT NULL,
    activitytypetext varchar(250) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gfebs_activitytype PRIMARY KEY (activitytypecode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GFEBS_CostCenter.sql
CREATE TABLE lookup.gfebs_costcenter (
    costcentercode varchar(50) NOT NULL,
    costcentertext varchar(250) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gfebs_costcenter PRIMARY KEY (costcentercode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GFEBS_FunctionalArea.sql
CREATE TABLE lookup.gfebs_functionalarea (
    functionalareacode varchar(50) NOT NULL,
    functionalareatext varchar(250) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gfebs_functionalarea PRIMARY KEY (functionalareacode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GFEBS_FundsCenter.sql
CREATE TABLE lookup.gfebs_fundscenter (
    fundscentercode varchar(50) NOT NULL,
    fundscentertext varchar(250) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gfebs_fundscenter PRIMARY KEY (fundscentercode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GFEBS_NonUS.sql
CREATE TABLE lookup.gfebs_nonus (
    statecountry varchar(50) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gfebs_nonus PRIMARY KEY (statecountry , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GSA_GLC.sql
CREATE TABLE lookup.gsa_glc (
    id integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    territory varchar(1) NOT NULL,
    location_name varchar(150) NOT NULL,
    location_code varchar(2) NULL,
    city_code varchar(4) NOT NULL,
    city_name varchar(150) NOT NULL,
    county_code varchar(3) NOT NULL,
    county_name varchar(150) NOT NULL,
    CONSTRAINT pk_gsa_glc PRIMARY KEY (id )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GS_OccupationalGroup.sql
CREATE TABLE lookup.gs_occupationalgroup (
    occupationalgroupnumber varchar(4) NOT NULL,
    grouptitle varchar(250) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gs_occupationalgroups PRIMARY KEY (occupationalgroupnumber , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/GS_OccupationalSeries.sql
CREATE TABLE lookup.gs_occupationalseries (
    occupationalseriesnumber varchar(5) NOT NULL,
    seriestitle varchar(250) NOT NULL,
    workrolecoderequired boolean NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_gs_occupationalseries PRIMARY KEY (occupationalseriesnumber , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/Grade.sql
CREATE TABLE lookup.grade (
    payplan varchar(3) NOT NULL,
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    careertrainingwindowyears smallint NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_grade PRIMARY KEY (payplan , gradetype , gradelevel , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/JicInflationRates.sql
CREATE TABLE lookup.jicinflationrates (
    conversiontype varchar(25) NOT NULL,
    year smallint NOT NULL,
    appropriation varchar(25) NOT NULL,
    amount numeric(18, 15) NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_jicinflationrates PRIMARY KEY (conversiontype , year , appropriation , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/LocalityPayArea.sql
CREATE TABLE lookup.localitypayarea (
    localitycode varchar(6) NOT NULL,
    localitypayarea varchar(100) NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_localitypayarea_1 PRIMARY KEY (localitycode , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MACOM.sql
CREATE TABLE lookup.macom (
    macom char(2) NOT NULL,
    macom_name char(20) NOT NULL,
    description char(50) NOT NULL,
    CONSTRAINT pk_macom PRIMARY KEY (macom )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MOS.sql
CREATE TABLE lookup.mos (
    mos varchar(3) NOT NULL,
    description varchar(250) NULL,
    parent_mos varchar(3) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_mos PRIMARY KEY (mos , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MOSConversion.sql
CREATE TABLE lookup.mosconversion (
    mosold varchar(3) NOT NULL,
    mosnew varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_mosconversion PRIMARY KEY (mosold , gradelevel , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MOS_SkillLevel.sql
CREATE TABLE lookup.mos_skilllevel (
    gradetype varchar(3) NOT NULL,
    gradelevel smallint NOT NULL,
    skilllevel char(1) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_mos_skilllevel PRIMARY KEY (gradetype , gradelevel , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MetropolitanStatisticalArea.sql
CREATE TABLE lookup.metropolitanstatisticalarea (
    msacode varchar(7) NOT NULL,
    msaname varchar(100) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_metropolitanstatisticalarea PRIMARY KEY (msacode, amcosversionid)
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MilitaryAcqTransaction.sql
CREATE TABLE lookup.militaryacqtransaction (
    code varchar(255) NOT NULL,
    description varchar(255) NULL,
    type varchar(255) NULL,
    include_exclude varchar(255) NULL,
    amcosversionidstart integer NOT NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_militaryacqtransaction PRIMARY KEY (code , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MilitaryHousingArea.sql
CREATE TABLE lookup.militaryhousingarea (
    mha varchar(5) NOT NULL,
    location varchar(10) NOT NULL,
    description varchar(250) NULL,
    displayname varchar(250) DEFAULT '' NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_militaryhousingarea_1 PRIMARY KEY (mha , location , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MilitaryInstallation.sql
CREATE TABLE lookup.militaryinstallation (
    mi_id integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    macomname varchar(50) NULL,
    installationname varchar(150) NULL,
    basecode varchar(50) NULL,
    basename varchar(50) NULL,
    staco varchar(50) NULL,
    stationname varchar(150) NULL,
    status varchar(50) NULL,
    sitecode varchar(50) NULL,
    component varchar(50) NULL,
    service varchar(50) NULL,
    address varchar(150) NULL,
    city varchar(50) NULL,
    state varchar(50) NULL,
    zipcode varchar(50) NULL,
    phone varchar(50) NULL,
    facid varchar(50) NULL,
    geloc varchar(50) NULL,
    geona varchar(50) NULL,
    congdis varchar(50) NULL,
    boundarygeom geometry NULL,
    pointgeo geography NULL,
    source varchar(50) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_militaryinstallation PRIMARY KEY (mi_id , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/MilitarySOC.sql
CREATE TABLE lookup.militarysoc (
    code varchar(1) NOT NULL,
    description varchar(255) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_militarysoc PRIMARY KEY (code , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/NonforeignArea.sql
CREATE TABLE lookup.nonforeignarea (
    nonforeignareacode varchar(10) NOT NULL,
    nonforeignareaname varchar(100) NOT NULL,
    localitycode varchar(6) NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_nonforeignarea PRIMARY KEY (nonforeignareacode , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/Organization.sql
CREATE TABLE lookup.organization (
    organizationname varchar(50) NOT NULL,
    organizationdescription varchar(250) NULL,
    organizationtype varchar(20) NULL,
    CONSTRAINT pk_organization PRIMARY KEY (organizationname )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/PayPlan.sql
CREATE TABLE lookup.payplan (
    payplan varchar(3) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    displaytitle varchar(75) NULL,
    grouptitle varchar(50) NULL,
    description varchar(50) NULL,
    categorygrouplabel varchar(50) NULL,
    categorysubgrouplabel varchar(50) NULL,
    includearmycareerprograms boolean NULL,
    explanation varchar(500) NULL,
    displaysequence numeric(3, 2) NULL,
    versionintroduced integer NULL,
    opmstartdate date NULL,
    CONSTRAINT pk_payplan PRIMARY KEY (payplan , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/PayPlanTags.sql
CREATE TABLE lookup.payplantags (
    payplan varchar(3) NOT NULL,
    tag varchar(100) NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_payplantags PRIMARY KEY ( payplan , tag , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/SOCStructure.sql
CREATE TABLE lookup.socstructure (
    occupationcode varchar(7) NOT NULL,
    grouplevel varchar(10) NULL,
    occupationtitle varchar(255) NULL,
    definition varchar(3000) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_socstructure PRIMARY KEY (occupationcode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/StateCountry.sql
CREATE TABLE lookup.statecountry (
    zipcode char(5) NOT NULL,
    state char(2) NOT NULL,
    statename varchar(50) NULL,
    statenamecapitalized varchar(50) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_statecountry PRIMARY KEY (zipcode , state , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/SubgroupMapping.sql
CREATE TABLE lookup.subgroupmapping (
    payplan varchar(3) NOT NULL,
    categorysubgroupcode varchar(7) NOT NULL,
    topayplan varchar(3) NOT NULL,
    tocategorysubgroupcode varchar(7) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_subgroup_mapping PRIMARY KEY (payplan , categorysubgroupcode , topayplan , tocategorysubgroupcode , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/SubgroupMappingForCivOver2299.sql
CREATE TABLE lookup.subgroupmappingforcivover2299 (
    payplan varchar(3) NOT NULL,
    categorysubgroupcode varchar(7) NOT NULL,
    civcategorysubgroupcodeover2299 varchar(7) NOT NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_subgroup_mapping_forcivover2299 PRIMARY KEY (payplan , categorysubgroupcode , civcategorysubgroupcodeover2299 , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/UIC.sql
CREATE TABLE lookup.uic (
    uic varchar(6) NOT NULL,
    edateuic varchar(50) NULL,
    name varchar(75) NULL,
    locationname varchar(25) NULL,
    macom varchar(2) NULL,
    sbcom varchar(2) NULL,
    tpaco varchar(2) NULL,
    ppaco varchar(2) NULL,
    uicur varchar(50) NULL,
    geloc varchar(4) NULL,
    udate varchar(50) NULL,
    tcode char(1) NULL,
    arloc varchar(5) NULL,
    zip varchar(7) NULL,
    tpsn varchar(7) NULL,
    status char(1) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_uic PRIMARY KEY (uic , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/UICLocation.sql
CREATE TABLE lookup.uiclocation (
    id integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    locnm varchar(100) NULL,
    geloc varchar(4) NULL,
    arloc varchar(5) NULL,
    srcasgmt varchar(50) NULL,
    uic varchar(6) NOT NULL,
    source varchar(50) NULL,
    city varchar(50) NULL,
    state varchar(2) NULL,
    zip varchar(10) NULL,
    country varchar(50) NULL,
    drrsname varchar(50) NULL,
    drrszipcdcity varchar(50) NULL,
    drrszipcdstate varchar(2) NULL,
    drrszipcd varchar(5) NULL,
    drrszipcdcountry varchar(50) NULL,
    staco varchar(5) NULL,
    staconame varchar(100) NULL,
    stacocity varchar(50) NULL,
    stacostate varchar(2) NULL,
    stacozip varchar(10) NULL,
    stacocountry varchar(50) NULL,
    efy varchar(4) NULL,
    tfy varchar(4) NULL,
    samasstacocity varchar(50) NULL,
    effectivedate integer NOT NULL,
    CONSTRAINT pk_uiclocation PRIMARY KEY (id )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/ValidEmailSuffix.sql
CREATE TABLE lookup.validemailsuffix (

);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/Valid_OPM_Series_GradeLevels.sql
CREATE TABLE lookup.valid_opm_series_gradelevels (
    series varchar(4) NOT NULL,
    gradelevel integer NOT NULL,
    valid boolean NOT NULL,
    amcosversionidstart integer NOT NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_valid_opm_series_gradelevels PRIMARY KEY (series , gradelevel , amcosversionidstart , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/WOMOS.sql
CREATE TABLE lookup.womos (
    womos varchar(4) NOT NULL,
    description varchar(250) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_womos PRIMARY KEY (womos , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/WOMOSConversion.sql
CREATE TABLE lookup.womosconversion (
    womosold varchar(4) NOT NULL,
    womosnew varchar(4) NOT NULL,
    gradelevel smallint NOT NULL,
    amcosversionid integer NOT NULL,
    CONSTRAINT pk_womosconversion PRIMARY KEY (womosold , gradelevel , amcosversionid )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/WageArea.sql
CREATE TABLE lookup.wagearea (
    wagearea varchar(3) NOT NULL,
    schedulearea varchar(4) NOT NULL,
    areaname varchar(250) NULL,
    amcosversionidstart integer NOT NULL,
    amcosversionidend integer NOT NULL,
    fundtype varchar(3) NOT NULL,
    CONSTRAINT pk_wagearea1 PRIMARY KEY (wagearea , schedulearea , fundtype , amcosversionidstart , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/Wage_OccupationalGroup.sql
CREATE TABLE lookup.wage_occupationalgroup (
    occupationalgroupnumber varchar(4) NOT NULL,
    grouptitle varchar(100) NOT NULL,
    amcosversionidstart integer NOT NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_wage_occupationalgroup PRIMARY KEY (occupationalgroupnumber , amcosversionidstart , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/Wage_OccupationalSeries.sql
CREATE TABLE lookup.wage_occupationalseries (
    occupationalseriesnumber varchar(4) NOT NULL,
    seriestitle varchar(100) NOT NULL,
    amcosversionidstart integer NOT NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_wage_occupationalseries_1 PRIMARY KEY (occupationalseriesnumber , amcosversionidstart , amcosversionidend )
);

-- Source: AMCOS.AMCOS2020_MAR/lookup/Tables/WeaponSystem.sql
CREATE TABLE lookup.weaponsystem (
    weaponsystemid integer GENERATED ALWAYS AS IDENTITY (START WITH -1 INCREMENT BY 1 MINVALUE -2147483648) NOT NULL,
    weaponsystemname varchar(50) NULL,
    amcosversionidstart integer NULL,
    amcosversionidend integer NOT NULL,
    CONSTRAINT pk_weaponsystem PRIMARY KEY (weaponsystemid , amcosversionidend )
);

