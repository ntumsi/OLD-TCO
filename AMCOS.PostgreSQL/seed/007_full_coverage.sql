-- AMCOS seed 007 — full web-feature coverage.
--
-- Fills the tables that earlier seeds left empty so every web page shows data:
--   * lookup.payplantags        — pay-plan family tags (Military/DMDC/WASS); the
--                                 data.inventory view filters on these, so without
--                                 them the inventory branches return nothing.
--   * crunch.inventoryprocessed / crunch.wass_processed — civilian inventory (feeds
--                                 data.inventory → Admin ▸ Inventory "development").
--   * load_inventory.inventory_production — the "production" side of Admin ▸ Inventory
--                                 (created here; no migration owns it).
--   * "BLS_OES".occupationalemploymentstatisticsmetro + warehouse.location MSA rows
--                                 — CCE (Contractor Cost Estimate) costs (data.costscce).
--   * web.civlocationperdiem     — Civilian PCS per-diem lookups.
--   * web.applicationerrorlog    — sample rows for Admin ▸ Log.
--   * webuser.amcosuser (+ login history) — a richer user set with PendingSponsor /
--                                 PendingAdmin / Denied / Active statuses so Admin ▸
--                                 Approvals / Sponsor Action / Users filters have content.
--   * extra Project Manager project + Civilian PCS estimate for variety.
--
-- Version: 202501 (the current/default AMCOS version). Idempotent (ON CONFLICT DO
-- NOTHING / WHERE NOT EXISTS). Demo/dev only — remove before production.

\set ver 202501

-- =====================================================================
-- 1. lookup.payplantags — pay-plan family classification (PK: payplan,tag,amcosversionid)
-- =====================================================================
INSERT INTO lookup.payplantags (payplan, tag, amcosversionid)
SELECT payplan, tag, 202501 FROM (VALUES
    ('AE','Military'),('AO','Military'),('AWO','Military'),
    ('NE','Military'),('NO','Military'),('NWO','Military'),
    ('RE','Military'),('RO','Military'),('RWO','Military'),
    ('GS','DMDC'),('GG','DMDC'),('GP','DMDC'),('SES','DMDC'),
    ('DB','DMDC'),('NH','DMDC'),('CY','DMDC'),
    ('WG','WASS'),('WL','WASS'),('WS','WASS')
) t(payplan, tag)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 2a. crunch.inventoryprocessed — DMDC civilian inventory (feeds data.inventory)
--     PK: civtype,payplan,categorygroup,categorysubgroup,step,locationid,yos,gradetype,gradelevel,amcosversionid
-- =====================================================================
INSERT INTO crunch.inventoryprocessed
    (civtype, payplan, categorygroup, categorysubgroup, gradetype, gradelevel, step, locationid, yos, inventory, amcosversionid)
SELECT 'W', pp.payplan, '99', '9999', left(pp.payplan, 2), gl::text, '1', loc.locationid, 0,
       (40 + gl * 6 + loc.locationid * 2)::int, 202501
FROM (VALUES ('GS',15),('GG',15),('GP',15),('SES',3),('DB',5),('NH',5)) pp(payplan, maxgl)
CROSS JOIN LATERAL generate_series(1, pp.maxgl) AS gl
CROSS JOIN (VALUES (1),(2),(3),(5)) loc(locationid)
ON CONFLICT DO NOTHING;

-- 2b. crunch.wass_processed — wage-grade (WASS) inventory
INSERT INTO crunch.wass_processed
    (payplan, "group", subgroup, gradetype, gradelevel, step, locationid, inventory, amcosversionid, avgpay)
SELECT pp.payplan, '88', '8888', pp.payplan, gl::text, '1', loc.locationid,
       (25 + gl * 4 + loc.locationid)::int, 202501, (35000 + gl * 1200)::numeric
FROM (VALUES ('WG',15),('WL',15),('WS',15)) pp(payplan, maxgl)
CROSS JOIN LATERAL generate_series(1, pp.maxgl) AS gl
CROSS JOIN (VALUES (1),(2),(3)) loc(locationid)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 3. load_inventory.inventory_production — Admin ▸ Inventory "production" side.
--    No migration owns this table; create it here for the demo. Slightly different
--    counts than the development side so the comparison shows a visible delta.
-- =====================================================================
CREATE TABLE IF NOT EXISTS load_inventory.inventory_production (
    payplan        varchar(3),
    gradelevel     varchar(2),
    inventory      integer,
    amcosversionid integer
);

-- Derived from data.inventory (the "development" side) with a small per-grade delta so
-- the Admin comparison shows differences. TRUNCATE-then-insert keeps it idempotent (the
-- table has no unique key, so a plain re-insert would duplicate rows).
TRUNCATE load_inventory.inventory_production;
INSERT INTO load_inventory.inventory_production (payplan, gradelevel, inventory, amcosversionid)
SELECT payplan, gradelevel, SUM(inventory) + 5 + (gradelevel::int % 3), 202501
FROM data.inventory
WHERE amcosversionid = 202501
GROUP BY payplan, gradelevel;

-- =====================================================================
-- 4. CCE (Contractor Cost Estimate): MSA locations + BLS OES wages.
--    data.costscce joins "BLS_OES".occupationalemploymentstatisticsmetro to
--    warehouse.location on sourcesystemcode = msacode WHERE locationtype='MSA'.
-- =====================================================================
INSERT INTO warehouse.location (locationid, sourcesystemcode, locationtype, displayname, amcosversionid)
OVERRIDING SYSTEM VALUE
SELECT locationid, msacode, 'MSA', displayname, 202501 FROM (VALUES
    (101, '10420', 'Akron, OH'),
    (102, '31080', 'Los Angeles-Long Beach-Anaheim, CA'),
    (103, '47900', 'Washington-Arlington-Alexandria, DC-VA-MD-WV'),
    (104, '19100', 'Dallas-Fort Worth-Arlington, TX')
) t(locationid, msacode, displayname)
ON CONFLICT (locationid) DO NOTHING;

INSERT INTO "BLS_OES".occupationalemploymentstatisticsmetro
    (soc, msacode, tot_emp, emp_prse, a_mean, mean_prse, a_pct10, a_pct25, a_median, a_pct75, a_pct90, amcosversionid)
SELECT soc, msacode, tot_emp, 0.5, med, 0.5, p10, p25, med, p75, p90, 202501 FROM (VALUES
    -- Software Developers (15-1252)
    ('15-1252','10420', 3200,  62000,  82000, 104000, 133000, 168000),
    ('15-1252','31080',48000,  78000, 101000, 132000, 168000, 205000),
    ('15-1252','47900',52000,  84000, 108000, 138000, 174000, 210000),
    ('15-1252','19100',31000,  70000,  92000, 118000, 150000, 185000),
    -- Management Analysts (13-1111)
    ('13-1111','10420', 2100,  48000,  62000,  84000, 112000, 146000),
    ('13-1111','31080',26000,  56000,  74000,  99000, 131000, 170000),
    ('13-1111','47900',60000,  66000,  86000, 112000, 145000, 185000),
    ('13-1111','19100',18000,  52000,  68000,  91000, 120000, 156000),
    -- Mechanical Engineers (17-2141)
    ('17-2141','10420', 1400,  61000,  75000,  93000, 116000, 141000),
    ('17-2141','31080', 9800,  70000,  88000, 110000, 137000, 168000),
    ('17-2141','47900', 4300,  72000,  90000, 113000, 140000, 171000),
    ('17-2141','19100', 6600,  66000,  82000, 103000, 129000, 158000)
) t(soc, msacode, tot_emp, p10, p25, med, p75, p90)
ON CONFLICT (soc, msacode, amcosversionid) DO NOTHING;

-- =====================================================================
-- 5. web.civlocationperdiem — Civilian PCS per-diem (PK: locationid)
-- =====================================================================
INSERT INTO web.civlocationperdiem (locationid, sourcesystemcode, locationtype, displayname, maxlodgingrate, mierate, amcosversionid)
SELECT locationid, sourcesystemcode, locationtype, displayname, lodging, mie, 202501 FROM (VALUES
    (1,   'INST01', 'Installation', 'Fort Demo, VA',      149, 68),
    (2,   'INST02', 'Installation', 'Fort Sample, TX',    120, 64),
    (3,   'INST03', 'Installation', 'Camp Example, GA',   110, 59),
    (5,   'INST05', 'Installation', 'Aberdeen PG, MD',    135, 69),
    (102, '31080',  'MSA',          'Los Angeles, CA',    182, 74),
    (103, '47900',  'MSA',          'Washington, DC',     257, 79)
) t(locationid, sourcesystemcode, locationtype, displayname, lodging, mie)
ON CONFLICT (locationid) DO NOTHING;

-- =====================================================================
-- 6. web.applicationerrorlog — sample entries for Admin ▸ Log (errorid is identity)
-- =====================================================================
INSERT INTO web.applicationerrorlog (errortime, userid, errorpage, errordetail)
SELECT errortime, userid, errorpage, errordetail FROM (VALUES
    (now() - interval '2 days',   'analyst.demo', '/App/Lite',            'Timeout expired while loading cost data for pay plan GS.'),
    (now() - interval '1 day',    'admin.demo',   '/App/Project/Report',  'NullReferenceException in CostReportBuilder for project 1.'),
    (now() - interval '6 hours',  'test.user',    '/App/CivilianPcs',     'Per-diem lookup returned no rows for destination locationId 999.'),
    (now() - interval '2 hours',  'analyst.demo', '/Admin/Inventory',     'relation "load_inventory.inventory_production" did not exist (resolved).'),
    (now() - interval '30 minutes','admin.demo',  '/App/Xwalk',           'QuickSight dashboard not configured (AwsAccountId missing).')
) t(errortime, userid, errorpage, errordetail)
WHERE NOT EXISTS (SELECT 1 FROM web.applicationerrorlog);

-- =====================================================================
-- 7. webuser.amcosuser — richer user set for Admin ▸ Users / Approvals / Sponsor Action
--    Statuses: PendingSponsor -> PendingAdmin -> Active/Denied.
-- =====================================================================
INSERT INTO webuser.amcosuser
    (userid, firstname, lastname, email, companyname, macom, selfaccounttype, userstatus, userrole,
     accessstatus, sponsoruserid, armyrank, officename, comphone, datecreated, lastlogin, lastupdate, lastapproveddate, lastdenieddate)
SELECT * FROM (VALUES
    ('pending.sponsor', 'Pat',  'Sponsorpending', 'pat.sp@contractor.example',  'Acme Defense LLC',      'AMC',   'CONTRACTOR', 'PendingSponsor', 'User', 0::smallint, 'admin.demo',  NULL,      'Contracts',   '555-0101', now() - interval '5 days',  NULL,                     now() - interval '5 days',  NULL::timestamp, NULL::timestamp),
    ('pending.admin',   'Dana', 'Adminpending',   'dana.ap@contractor.example', 'Globex Systems Inc',    'IMCOM', 'CONTRACTOR', 'PendingAdmin',   'User', 0::smallint, 'admin.demo',  NULL,      'Engineering', '555-0102', now() - interval '9 days',  NULL,                     now() - interval '3 days',  NULL::timestamp, NULL::timestamp),
    ('pending.mil',     'Sam',  'Militarypending','sam.mp@army.mil',            'Department of the Army','FORSCOM','MILITARY',  'PendingAdmin',   'User', 0::smallint, NULL,          'SFC',     'S3',          '555-0103', now() - interval '4 days',  NULL,                     now() - interval '4 days',  NULL::timestamp, NULL::timestamp),
    ('denied.user',     'Alex', 'Deniedperson',   'alex.dn@contractor.example', 'Initech Corp',          'AMC',   'CONTRACTOR', 'Denied',         'User', 0::smallint, 'admin.demo',  NULL,      'Logistics',   '555-0104', now() - interval '20 days', NULL,                     now() - interval '15 days', NULL::timestamp, now() - interval '15 days'),
    ('active.analyst2', 'Jill', 'Analysttwo',     'jill.a2@army.mil',           'TRADOC Analysis Center','TRADOC','CIVILIAN',   'Active',         'User', 1::smallint, NULL,          NULL,      'Cost Analysis','555-0105', now() - interval '90 days', now() - interval '1 day', now() - interval '2 days',  now() - interval '88 days', NULL::timestamp),
    ('active.manager',  'Rob',  'Managerthree',   'rob.m3@army.mil',            'ASA(FM&C)',             'HQDA',  'CIVILIAN',   'Active',         'Admin', 1::smallint, NULL,        NULL,      'Resource Mgmt','555-0106',now() - interval '200 days',now() - interval '3 hours',now() - interval '10 days', now() - interval '198 days',NULL::timestamp)
) t
WHERE NOT EXISTS (SELECT 1 FROM webuser.amcosuser u2 WHERE u2.userid = t.column1);

-- login history for the two active demo additions
INSERT INTO webuser.user_login_history (userid, logindatetime)
SELECT userid, logindatetime FROM (VALUES
    ('active.analyst2', now() - interval '1 day'),
    ('active.analyst2', now() - interval '8 days'),
    ('active.manager',  now() - interval '3 hours'),
    ('active.manager',  now() - interval '5 days')
) t(userid, logindatetime)
WHERE NOT EXISTS (SELECT 1 FROM webuser.user_login_history h WHERE h.userid = t.userid);
