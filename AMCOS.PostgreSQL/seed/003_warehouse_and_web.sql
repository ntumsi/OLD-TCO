-- ==========================================================================
-- AMCOS seed: warehouse + web tables
-- warehouse.location feeds the Lite / PCS / Project location pickers and is
-- referenced by FK from webuser.pcsproject. Spatial columns are left NULL
-- (no PostGIS dependency required to load this seed).
-- ==========================================================================

-- --------------------------------------------------------------------------
-- Locations (identity ids; guarded on displayname)
-- --------------------------------------------------------------------------
INSERT INTO warehouse.location (sourcesystemcode, locationtype, displayname, amcosversionid)
SELECT v.sourcesystemcode, v.locationtype, v.displayname, 202501
FROM (VALUES
    ('FTLIBJ', 'Installation', 'Fort Liberty, NC'),
    ('FTCAVA', 'Installation', 'Fort Cavazos, TX'),
    ('FTMOOR', 'Installation', 'Fort Moore, GA'),
    ('FTBELV', 'Installation', 'Fort Belvoir, VA'),
    ('FTSILL', 'Installation', 'Fort Sill, OK'),
    ('PENTGN', 'Installation', 'Pentagon, Arlington, VA'),
    ('RUS',    'LocalityArea', 'Rest of U.S.'),
    ('WASDC',  'LocalityArea', 'Washington-Baltimore-Arlington, DC-MD-VA-WV-PA')
) AS v(sourcesystemcode, locationtype, displayname)
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.location l WHERE l.displayname = v.displayname
);

-- --------------------------------------------------------------------------
-- Categories (no PK on table; guarded on natural key)
-- --------------------------------------------------------------------------
INSERT INTO warehouse.category
    (payplan, categorygroupcode, categorygroupdescription, categorygroupdisplay,
     categorysubgroupcode, categorysubgroupdescription, categorysubgroupdisplay,
     careerprogramnumber, careerprogramdescription, careerprogramdisplay)
SELECT v.payplan, v.cgc, v.cgd, v.cgdisp, v.csc, v.csd, v.csdisp, v.cpn, v.cpd, v.cpdisp
FROM (VALUES
    ('AE', '11', 'Infantry CMF',            'CMF 11 - Infantry',          '11B', 'Infantryman',            '11B - Infantryman',            '00', 'Not Applicable', 'N/A'),
    ('AE', '13', 'Field Artillery CMF',     'CMF 13 - Field Artillery',   '13B', 'Cannon Crewmember',      '13B - Cannon Crewmember',      '00', 'Not Applicable', 'N/A'),
    ('AE', '25', 'Signal CMF',              'CMF 25 - Signal',            '25B', 'IT Specialist',          '25B - IT Specialist',          '00', 'Not Applicable', 'N/A'),
    ('AO', '11', 'Infantry Branch',         'Infantry',                   '11A', 'Infantry, General',      '11A - Infantry, General',      '00', 'Not Applicable', 'N/A'),
    ('GS', '2200','Information Technology', 'IT Occupational Group',       '2210','IT Management',          '2210 - IT Management',         '34', 'IT Management',  'CP-34 IT Management'),
    ('GS', '0300','General Administrative', 'Admin Occupational Group',    '0343','Program Analysis',       '0343 - Program Analysis',      '11', 'Comptroller',    'CP-11 Comptroller')
) AS v(payplan, cgc, cgd, cgdisp, csc, csd, csdisp, cpn, cpd, cpdisp)
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.category c
    WHERE c.payplan = v.payplan
      AND c.categorygroupcode = v.cgc
      AND c.categorysubgroupcode = v.csc
      AND c.careerprogramnumber = v.cpn
);

-- --------------------------------------------------------------------------
-- Location-by-category (links categories to a default installation)
-- --------------------------------------------------------------------------
INSERT INTO warehouse.locationbycategory
    (payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber, locationid,
     installation, localitypayarea, country)
SELECT c.payplan, c.categorygroupcode, c.categorysubgroupcode, c.careerprogramnumber,
       l.locationid, l.displayname, 'Rest of U.S.', 'United States'
FROM warehouse.category c
CROSS JOIN LATERAL (
    SELECT locationid, displayname FROM warehouse.location
    WHERE displayname = 'Fort Liberty, NC' LIMIT 1
) l
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.locationbycategory lbc
    WHERE lbc.payplan = c.payplan
      AND lbc.categorygroupcode = c.categorygroupcode
      AND lbc.categorysubgroupcode = c.categorysubgroupcode
      AND lbc.careerprogramnumber = c.careerprogramnumber
      AND lbc.locationid = l.locationid
);

-- --------------------------------------------------------------------------
-- Joint inflation calculator (base->target factors)
-- --------------------------------------------------------------------------
INSERT INTO warehouse.jointinflationcalculator (conversiontype, baseyear, targetyear, appropriation, amount) VALUES
    ('Raw', '2024', '2025', 'MILPERS', 1.041000000000000),
    ('Raw', '2024', '2026', 'MILPERS', 1.062000000000000),
    ('Raw', '2025', '2026', 'MILPERS', 1.020000000000000),
    ('Raw', '2024', '2025', 'O&M',     1.028000000000000),
    ('Raw', '2024', '2026', 'O&M',     1.048000000000000)
ON CONFLICT (conversiontype, baseyear, targetyear, appropriation) DO NOTHING;

-- --------------------------------------------------------------------------
-- Unit personnel (sample authorized strength for one UIC)
-- --------------------------------------------------------------------------
INSERT INTO warehouse.unitpersonnel
    (uic, uictitle, payplan, categorygroupcode, categorysubgroupcode, locationid,
     locationtext, strl, gradelevel, dependentstatus, numberofdependents,
     activedutydays, inventory, unityear, asof, authorizationdocument)
SELECT 'WABCAA', '1st Bn, Sample Regiment', v.payplan, v.cgc, v.csc, l.locationid,
       'Fort Liberty, NC', 'TOE', v.gradelevel, 'With Dependents', 2, 365, v.inv, '2025', '20250301', 'MTOE'
FROM (VALUES
    ('AE', '11', '11B', 4::smallint, 40),
    ('AE', '11', '11B', 5::smallint, 25),
    ('AO', '11', '11A', 3::smallint, 6)
) AS v(payplan, cgc, csc, gradelevel, inv)
CROSS JOIN LATERAL (
    SELECT locationid FROM warehouse.location WHERE displayname = 'Fort Liberty, NC' LIMIT 1
) l
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.unitpersonnel up
    WHERE up.uic = 'WABCAA' AND up.payplan = v.payplan
      AND up.categorygroupcode = v.cgc AND up.categorysubgroupcode = v.csc
      AND up.locationid = l.locationid AND up.strl = 'TOE'
      AND up.gradelevel = v.gradelevel AND up.dependentstatus = 'With Dependents'
      AND up.numberofdependents = 2 AND up.unityear = '2025' AND up.asof = '20250301'
);

-- --------------------------------------------------------------------------
-- web.payplantag (tags used to group pay plans in the UI)
-- --------------------------------------------------------------------------
INSERT INTO web.payplantag (payplan, tag) VALUES
    ('AE', 'Military'),
    ('AO', 'Military'),
    ('AWO','Military'),
    ('GS', 'Civilian'),
    ('GG', 'Civilian'),
    ('GP', 'Civilian'),
    ('SES','Civilian'),
    ('CCE','Civilian'),
    ('WG', 'Civilian'),
    ('WL', 'Civilian'),
    ('WS', 'Civilian'),
    ('DB', 'Civilian'),
    ('NH', 'Civilian'),
    ('CY', 'Civilian')
ON CONFLICT (payplan, tag) DO NOTHING;

-- --------------------------------------------------------------------------
-- web.qlikapplication (dashboards surfaced in the app; identity ids)
-- --------------------------------------------------------------------------
INSERT INTO web.qlikapplication (applicationtitle, "order", isfieldselect, description, hasexport)
SELECT v.title, v.ord, FALSE, v.descr, v.hasexport
FROM (VALUES
    ('Cost Element Browser', 1, 'Browse composite cost elements by pay plan', TRUE),
    ('Inventory Dashboard',  2, 'Authorized vs. on-hand strength by UIC',     TRUE),
    ('Comparison Analysis',  3, 'Compare cost estimates across versions',     FALSE)
) AS v(title, ord, descr, hasexport)
WHERE NOT EXISTS (
    SELECT 1 FROM web.qlikapplication q WHERE q.applicationtitle = v.title
);
