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

-- NOTE: web.PendingUsers is a VIEW in the source database, not a table. It is
-- defined in 008_views.sql (over webuser.amcosuser). The placeholder table that
-- was here has been removed so the view name does not collide.

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

