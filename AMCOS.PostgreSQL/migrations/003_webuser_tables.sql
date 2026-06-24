-- Converted webuser schema tables from AMCOS SQL Server project

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/AMCOSUser.sql
CREATE TABLE webuser.amcosuser (
    userid varchar(50) NOT NULL,
    firstname varchar(50) NOT NULL,
    middlename varchar(50) NULL,
    lastname varchar(50) NOT NULL,
    email varchar(50) NOT NULL,
    prefix varchar(5) NULL,
    akoid varchar(50) NULL,
    dodid varchar(50) NULL,
    comphone varchar(50) NULL,
    dsn varchar(50) NULL,
    internationalno varchar(30) NULL,
    armyaccounttype varchar(50) NULL,
    armyrank varchar(50) NULL,
    officename varchar(100) NULL,
    companyname varchar(100) NULL,
    macom varchar(50) NULL,
    accessstatus smallint NULL,
    userstatus varchar(14) NULL,
    userrole varchar(50) NULL,
    selfaccounttype varchar(10) NULL,
    sponsoruserid varchar(50) NULL,
    lastlogin timestamp NULL,
    datecreated timestamp NOT NULL,
    lastupdate timestamp NOT NULL,
    lastapproveddate timestamp NULL,
    lastdenieddate timestamp NULL,
    cacemail varchar(500) NULL,
    cn varchar(50) NULL,
    CONSTRAINT pk_amcosuser PRIMARY KEY (userid )
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/AmcosLiteAudit.sql
CREATE TABLE webuser.amcosliteaudit (
    userid varchar(50) NOT NULL,
    createdate timestamp NOT NULL,
    pageaction varchar(50) NOT NULL,
    pageelement varchar(50) NOT NULL,
    payplan varchar(3) NULL,
    costsummaryname varchar(50) NULL,
    categorygroupcode varchar(7) NULL,
    categorysubgroupcode varchar(7) NULL,
    careerprogramnumber char(2) NULL,
    locationid integer NULL,
    locationtext varchar(150) NULL,
    strl varchar(20) NULL,
    dependentstatus varchar(25) NULL,
    numberofdependents integer NULL,
    overheadpercent integer NULL,
    inflationconversiontype varchar(25) NULL,
    inflationyear varchar(4) NULL,
    CONSTRAINT pk_amcosliteaudit PRIMARY KEY ( userid , createdate , pageaction , pageelement )
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/PCSProject.sql
CREATE TABLE webuser.pcsproject (
    userid varchar(50) NOT NULL,
    projectname varchar(50) NOT NULL,
    projectsavedate timestamp NOT NULL,
    conversiontype varchar(25) NOT NULL,
    year smallint NOT NULL,
    appropriation varchar(25) NOT NULL,
    amcosversionid integer NOT NULL,
    originationid integer NOT NULL,
    destinationid integer NOT NULL,
    calculateddistance integer NULL,
    numberofdayshunting integer NULL,
    househuntinghavespouse boolean NULL,
    selflodgingperdiem numeric(18, 2) NULL,
    spouselodgingperdiem numeric(18, 2) NULL,
    selfmieperdiem numeric(18, 2) NULL,
    spousemieperdiem numeric(18, 2) NULL,
    househuntingtotal numeric(18, 2) NULL,
    spouseperdiemrate numeric(18, 2) NULL,
    povmileage integer NULL,
    pcsmaltrate numeric(18, 2) NULL,
    mileagereimbursement numeric(18, 2) NULL,
    dependantmileagereimbursement numeric(18, 2) NULL,
    transportationsubtotal numeric(18, 2) NULL,
    numberdaystqse integer NULL,
    tqseselfperdiemlodging numeric(18, 2) NULL,
    tqsespouseperdiemlodging numeric(18, 2) NULL,
    tqseselfperdiemmie numeric(18, 2) NULL,
    tqsespouseperdiemmie numeric(18, 2) NULL,
    tqseperdiemrate numeric(18, 2) NULL,
    tqsespouseperdiemrate numeric(18, 2) NULL,
    tqsetotal numeric(18, 2) NULL,
    transportationtype varchar(25) NULL,
    ghtransportationtotal numeric(18, 2) NULL,
    hhgtotalmileage integer NULL,
    hhgtotalweight double precision NULL,
    hhgmaxweight integer NULL,
    hhgestimatedcostpermile numeric(18, 2) NULL,
    hhgestimatedcostperpound numeric(18, 2) NULL,
    hhgcostbytotalmiles numeric(18, 2) NULL,
    hhgcostbytotalweight numeric(18, 2) NULL,
    subtotalhhg numeric(18, 2) NULL,
    mobilehometotalmileage integer NULL,
    mobilehomeestcostpermile numeric(18, 2) NULL,
    mobilehomesubtotal numeric(18, 2) NULL,
    meahasspouse boolean NULL,
    meacivilian numeric(18, 2) NULL,
    meacivilianandspouse numeric(18, 2) NULL,
    measubtotal numeric(18, 2) NULL,
    realestateorlease varchar(25) NULL,
    salepriceamount numeric(18, 2) NULL,
    purchasepriceamount numeric(18, 2) NULL,
    realestatesubtotal numeric(18, 2) NULL,
    uelamount numeric(18, 2) NULL,
    ueltotal numeric(18, 2) NULL,
    realestateleasetotal numeric(18, 2) NULL,
    isisolateddutystation boolean NULL,
    ntssubtotal numeric(18, 2) NULL,
    defaultfederaltaxrate numeric(8, 4) NULL,
    federaltaxrate numeric(8, 4) NULL,
    househuntingrita numeric(18, 2) NULL,
    transportationrita numeric(18, 2) NULL,
    tqserita numeric(18, 2) NULL,
    ghtransportationrita numeric(18, 2) NULL,
    mearita numeric(18, 2) NULL,
    realestateleaserita numeric(18, 2) NULL,
    ntsrita numeric(18, 2) NULL,
    ritasubtotal numeric(18, 2) NULL,
    grandtotal numeric(18, 2) NULL,
    statetaxrate numeric(8, 4) NULL,
    socialsecuritytaxrate numeric(8, 4) NULL,
    medicaretaxrate numeric(8, 4) NULL,
    countytaxrate numeric(8, 4) NULL,
    citytaxrate numeric(8, 4) NULL,
    totaltaxrate numeric(8, 4) NULL,
    deleted boolean DEFAULT FALSE NOT NULL,
    salepricerefund numeric(8, 4) NULL,
    purchasepricerefund numeric(8, 4) NULL,
    tqsedependents integer NULL,
    transportationdependents integer NULL,
    CONSTRAINT pk_pcsproject PRIMARY KEY (userid , projectname ),
    CONSTRAINT fk__pcsproject__userid__amcosuser FOREIGN KEY (userid) REFERENCES webuser.amcosuser (userid)
);
-- FK to warehouse.location added in 005_warehouse_tables.sql after that table is created.

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/PMProject.sql
CREATE TABLE webuser.pmproject (
    projectid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    userid varchar(50) NOT NULL,
    projectname varchar(50) NOT NULL,
    yearstart integer NOT NULL,
    yearduration integer DEFAULT 5 NOT NULL,
    projectcreator varchar(50) NULL,
    projecttype varchar(50) DEFAULT 'Weapons System' NOT NULL,
    reservedaysinactive integer DEFAULT 24 NOT NULL,
    reservedaysactive integer DEFAULT 14 NOT NULL,
    createdate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    lastupdate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description varchar(4000) NULL,
    discountrate double precision NULL,
    CONSTRAINT pk_pmproject PRIMARY KEY (projectid )
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/PMCategory.sql
CREATE TABLE webuser.pmcategory (
    categoryid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    projectid integer NOT NULL,
    categoryname varchar(50) NULL,
    CONSTRAINT pk_pmcategory PRIMARY KEY (categoryid ),
    CONSTRAINT fk_pmcategory_pmproject FOREIGN KEY (projectid) REFERENCES webuser.pmproject (projectid)
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/PMCategorySkill.sql
CREATE TABLE webuser.pmcategoryskill (
    skillid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    categoryid integer NOT NULL,
    uic varchar(6) NULL,
    payplan varchar(3) NOT NULL,
    categorygroupcode varchar(10) NOT NULL,
    categorysubgroupcode varchar(10) NOT NULL,
    careerprogramnumber char(2) NOT NULL,
    locationid integer NOT NULL,
    locationtext varchar(150) NOT NULL,
    strl varchar(20) NOT NULL,
    gradelevel smallint NOT NULL,
    dependentstatus varchar(25) NOT NULL,
    numberofdependents integer NOT NULL,
    activedutydays smallint NOT NULL,
    overheadpercent double precision NOT NULL,
    _type varchar(5) NULL,
    _areacode varchar(50) NULL,
    _localityid integer NULL,
    _specialratetablenumber varchar(4) NULL,
    _statecountry varchar(50) NULL,
    _functionalareacode varchar(50) NULL,
    _costcentercode varchar(50) NULL,
    CONSTRAINT pk_pmcategoryskill PRIMARY KEY (skillid )
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/PMCategorySkillInventory.sql
CREATE TABLE webuser.pmcategoryskillinventory (
    inventoryid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    skillid integer NOT NULL,
    year integer NOT NULL,
    amount integer NOT NULL,
    CONSTRAINT pk_pmcategoryskillinventory PRIMARY KEY (inventoryid ),
    CONSTRAINT fk_pmcategoryskillinventory_pmcategoryskill FOREIGN KEY (skillid) REFERENCES webuser.pmcategoryskill (skillid)
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/PMReport.sql
CREATE TABLE webuser.pmreport (
    reportid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    categoryid integer NOT NULL,
    payplan varchar(3) NOT NULL,
    CONSTRAINT pk_pmreport PRIMARY KEY (reportid ),
    CONSTRAINT fk_pmreport_pmcategory FOREIGN KEY (categoryid) REFERENCES webuser.pmcategory (categoryid)
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/ProjectAddUnitAudit.sql
CREATE TABLE webuser.projectaddunitaudit (
    userid varchar(50) NOT NULL,
    createdate timestamp NOT NULL,
    categoryid integer NULL,
    uic varchar(6) NULL,
    excludedpayplans varchar(50) NULL,
    dataaction varchar(7) NULL,
    newsubprojectname varchar(50) NULL,
    unitlocation char(2) NULL,
    mtoeprojectinventoryyear integer NULL,
    projectextendssacsyears varchar(25) NULL,
    contractoroverheadpercent double precision NULL,
    CONSTRAINT pk_projectaddunitaudit PRIMARY KEY (userid , createdate )
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/UserDeleteMaster.sql
CREATE TABLE webuser.userdeletemaster (
    delete varchar(255) NULL,
    userid varchar(255) NULL,
    firstname varchar(255) NULL,
    middlename varchar(255) NULL,
    lastname varchar(255) NULL,
    email varchar(255) NULL,
    comphone varchar(255) NULL,
    officename varchar(255) NULL,
    macom varchar(255) NULL,
    lastlogin timestamp NULL,
    datecreated timestamp NULL,
    lastupdate timestamp NULL,
    accessstatus double precision NULL,
    akoid varchar(255) NULL,
    armyrank varchar(255) NULL,
    companyname varchar(255) NULL,
    armyaccounttype varchar(255) NULL
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/User_Login_History.sql
CREATE TABLE webuser.user_login_history (
    userid varchar(50) NOT NULL,
    logindatetime timestamp NOT NULL,
    browser varchar(50) NULL,
    browserversion varchar(50) NULL,
    CONSTRAINT pk_user_login_history PRIMARY KEY (userid , logindatetime )
);

-- Source: AMCOS.AMCOS2020_MAR/webuser/Tables/User_Login_History_DeletedUsers.sql
CREATE TABLE webuser.user_login_history_deletedusers (
    userid varchar(50) NOT NULL,
    logindatetime timestamp NOT NULL,
    browser varchar(50) NULL,
    browserversion varchar(50) NULL
);

