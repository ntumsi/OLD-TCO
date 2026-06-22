-- Converted warehouse schema tables from AMCOS SQL Server project

-- Source: AMCOS.AMCOS2020_MAR/warehouse/Tables/Category.sql
CREATE TABLE warehouse.category (
    payplan varchar(3) NOT NULL,
    categorygroupcode varchar(7) NOT NULL,
    categorygroupdescription varchar(150) NULL,
    categorygroupdisplay varchar(175) NULL,
    categorysubgroupcode varchar(7) NOT NULL,
    categorysubgroupdescription varchar(150) NULL,
    categorysubgroupdisplay varchar(175) NULL,
    careerprogramnumber char(2) NOT NULL,
    careerprogramdescription varchar(75) NULL,
    careerprogramdisplay varchar(100) NULL
);

-- Source: AMCOS.AMCOS2020_MAR/warehouse/Tables/JointInflationCalculator.sql
CREATE TABLE warehouse.jointinflationcalculator (
    conversiontype varchar(25) NOT NULL,
    baseyear varchar(4) NOT NULL,
    targetyear varchar(4) NOT NULL,
    appropriation varchar(25) NOT NULL,
    amount numeric(18, 15) NOT NULL,
    CONSTRAINT pk_jointinflationcalculator PRIMARY KEY (conversiontype , baseyear , targetyear , appropriation )
);

-- Source: AMCOS.AMCOS2020_MAR/warehouse/Tables/Location.sql
CREATE TABLE warehouse.location (
    locationid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    sourcesystemcode varchar(100) NULL,
    locationtype varchar(100) NULL,
    displayname varchar(250) NULL,
    geometry geometry NULL,
    coordinates geography NULL,
    amcosversionid integer NULL,
    CONSTRAINT pk_location PRIMARY KEY (locationid )
);

-- Source: AMCOS.AMCOS2020_MAR/warehouse/Tables/LocationByCategory.sql
CREATE TABLE warehouse.locationbycategory (
    id integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    payplan varchar(3) NOT NULL,
    categorygroupcode varchar(7) NOT NULL,
    categorysubgroupcode varchar(7) NOT NULL,
    careerprogramnumber char(2) NOT NULL,
    locationid integer NOT NULL,
    oconusmha varchar(500) NULL,
    conusmha varchar(500) NULL,
    installation varchar(500) NULL,
    localitypayarea varchar(500) NULL,
    specialpayarea varchar(500) NULL,
    country varchar(500) NULL,
    wageschedule varchar(500) NULL,
    citycounty varchar(500) NULL,
    msa varchar(150) NULL,
    strl varchar(200) NULL,
    civoverseas varchar(500) NULL,
    CONSTRAINT pk_locationbycategory PRIMARY KEY (id )
);

-- Source: AMCOS.AMCOS2020_MAR/warehouse/Tables/PPXwalk.sql
CREATE TABLE warehouse.ppxwalk (
    gs_ses_basepayplan varchar(3) NOT NULL,
    gs_ses_basegradelevel varchar(10) NOT NULL,
    gs_ses_basesubgroupcode varchar(5) NOT NULL,
    gs_ses_baselocationid integer NOT NULL,
    targetpayplan varchar(3) NOT NULL,
    targetgradelevel varchar(10) NOT NULL,
    targetsubgroupcode varchar(10) NOT NULL,
    targetlocationid integer NOT NULL,
    targetstrl varchar(20) NOT NULL,
    CONSTRAINT pk_xwalkgradelevel PRIMARY KEY (gs_ses_basepayplan , gs_ses_basegradelevel , gs_ses_basesubgroupcode , gs_ses_baselocationid , targetpayplan , targetgradelevel , targetsubgroupcode , targetlocationid , targetstrl )
);

-- Source: AMCOS.AMCOS2020_MAR/warehouse/Tables/UnitPersonnel.sql
CREATE TABLE warehouse.unitpersonnel (
    uic varchar(6) NOT NULL,
    uictitle varchar(150) NOT NULL,
    payplan varchar(3) NOT NULL,
    categorygroupcode varchar(10) NOT NULL,
    categorysubgroupcode varchar(10) NOT NULL,
    locationid integer NOT NULL,
    locationtext varchar(150) NOT NULL,
    strl varchar(20) NOT NULL,
    gradelevel smallint NOT NULL,
    dependentstatus varchar(25) NOT NULL,
    numberofdependents integer NOT NULL,
    activedutydays smallint NOT NULL,
    inventory integer NOT NULL,
    unityear varchar(4) NOT NULL,
    asof varchar(8) NOT NULL,
    authorizationdocument varchar(50) NULL,
    CONSTRAINT pk_warehouseunitpersonnel PRIMARY KEY (uic , payplan , categorygroupcode , categorysubgroupcode , locationid , strl , gradelevel , dependentstatus , numberofdependents , unityear , asof )
);

