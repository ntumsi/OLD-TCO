-- Converted web schema tables from AMCOS SQL Server project

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/ApplicationErrorLog.sql
CREATE TABLE web.applicationerrorlog (
    errorid integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    errortime timestamp NULL,
    userid varchar(50) NULL,
    errorpage varchar(200) NULL,
    errordetail varchar(3000) NULL
);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/PayPlanTag.sql
CREATE TABLE web.payplantag (
    payplan varchar(3) NOT NULL,
    tag varchar(25) NOT NULL,
    CONSTRAINT pk_payplantag PRIMARY KEY (payplan , tag )
);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/QlikApplication.sql
CREATE TABLE web.qlikapplication (
    id integer GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    applicationtitle varchar(50) NOT NULL,
    devapplicationid varchar(50) NULL,
    devobjectid varchar(50) NULL,
    prodapplicationid varchar(50) NULL,
    prodobjectid varchar(50) NULL,
    cssclass varchar(100) NULL,
    "order" integer DEFAULT 0 NOT NULL,
    isfieldselect boolean DEFAULT FALSE NOT NULL,
    testapplicationid varchar(50) NULL,
    testobjectid varchar(50) NULL,
    description varchar(100) NULL,
    hasexport boolean DEFAULT FALSE NOT NULL,
    CONSTRAINT pk_qlikapplication PRIMARY KEY (id)
);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/QlikGroup.sql
CREATE TABLE web.qlikgroup (
    groupname varchar(25) NOT NULL,
    qlikapplicationid integer NOT NULL,
    "order" integer NULL,
    CONSTRAINT pk_qlikgroup PRIMARY KEY ( groupname , qlikapplicationid )
);
ALTER TABLE web.qlikgroup ADD FOREIGN KEY (qlikapplicationid) REFERENCES web.qlikapplication (id);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/PendingUsers.sql
CREATE TABLE web.pendingusers (
    userinfo varchar(50) NOT NULL,
    username varchar(100) NULL,
    useremail varchar(100) NULL,
    userphone varchar(50) NULL,
    userofficename varchar(100) NULL,
    usermacom varchar(50) NULL,
    useraccounttype varchar(50) NULL,
    userarmyrank varchar(50) NULL,
    usercompanyname varchar(100) NULL,
    userlastlogin timestamp NULL,
    sponsorname varchar(100) NULL,
    sponsoremail varchar(100) NULL,
    sponsorphone varchar(50) NULL,
    sponsorofficename varchar(100) NULL,
    sponsormacom varchar(50) NULL,
    sponsoraccounttype varchar(50) NULL,
    sponsorarmyrank varchar(50) NULL,
    userstatus varchar(14) NULL,
    CONSTRAINT pk_pendingusers PRIMARY KEY (userinfo)
);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/CivLocationPerDiem.sql
CREATE TABLE web.civlocationperdiem (
    locationid integer NOT NULL,
    sourcesystemcode varchar(10) NULL,
    locationtype varchar(25) NULL,
    displayname varchar(150) NULL,
    maxlodgingrate integer NULL,
    mierate integer NULL,
    amcosversionid integer NULL,
    CONSTRAINT pk_civlocationperdiem PRIMARY KEY (locationid)
);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/QuickSightDashboard.sql
CREATE TABLE web.quicksightdashboard (
    initialdashboardid varchar(100) NOT NULL,
    dashboardtitle varchar(200) NULL,
    quicksightnamespace varchar(100) NULL,
    authorizedresourcearns varchar(500) NULL,
    alloweddomains varchar(500) NULL,
    CONSTRAINT pk_quicksightdashboard PRIMARY KEY (initialdashboardid)
);

-- Source: AMCOS.AMCOS2020_MAR/web/Tables/QuickSightEnvironment.sql
CREATE TABLE web.quicksightenvironment (
    awsaccountid varchar(20) NOT NULL,
    awsregioncode varchar(20) NULL,
    sessionlifetimeinminutes varchar(10) NULL,
    alloweddomains varchar(500) NULL,
    CONSTRAINT pk_quicksightenvironment PRIMARY KEY (awsaccountid)
);

