-- ==========================================================================
-- AMCOS seed: AMCOS Lite filter coverage
--
-- Builds the AMCOS Lite filter cascade on top of the pay plans defined in
-- 001 (legacy taxonomy: AE/AO/AWO, GS/GG/GP/SES/CCE, WG/WL/WS, DB, NH, CY --
-- the codes the cost engine, AMCOS.Logic.Lite.payPlanType, and the Lite UI
-- all use). This file seeds warehouse.category + correctly-keyed
-- warehouse.locationbycategory (incl. STRL) so every cascade branch
-- (Pay Plan -> Category -> Location -> STRL / Dependent Status /
-- Number of Dependents) populates.
--
-- Scope: filter cascade only. It does NOT seed the deep cost-engine inputs
-- (web.getcosts), so "Refresh Cost Table" may still return no rows until a
-- fuller cost load is run via the ETL pipeline.
--
-- Idempotent: ON CONFLICT DO NOTHING / WHERE NOT EXISTS guards throughout.
-- Run after 001-004 (see seed/README.md).
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Extra location master rows referenced below (guarded on displayname).
-- --------------------------------------------------------------------------
INSERT INTO warehouse.location (sourcesystemcode, locationtype, displayname, amcosversionid)
SELECT v.sourcesystemcode, v.locationtype, v.displayname, 202501
FROM (VALUES
    ('APGRMD', 'Installation', 'Aberdeen Proving Ground, MD'),
    ('REDSAL', 'Installation', 'Redstone Arsenal, AL')
) AS v(sourcesystemcode, locationtype, displayname)
WHERE NOT EXISTS (SELECT 1 FROM warehouse.location l WHERE l.displayname = v.displayname);

-- --------------------------------------------------------------------------
-- 2. Categories. The dropdown emits one item per non-null code projection
--    (group / subgroup / career program), so each row can surface up to three
--    selectable options. careerprogramnumber '00' = N/A (military).
-- --------------------------------------------------------------------------
INSERT INTO warehouse.category
    (payplan, categorygroupcode, categorygroupdescription, categorygroupdisplay,
     categorysubgroupcode, categorysubgroupdescription, categorysubgroupdisplay,
     careerprogramnumber, careerprogramdescription, careerprogramdisplay)
SELECT v.payplan, v.cgc, v.cgd, v.cgdisp, v.csc, v.csd, v.csdisp, v.cpn, v.cpd, v.cpdisp
FROM (VALUES
    -- Military (CMF/Branch -> MOS/AOC; no career programs)
    ('AE',  '11', 'Infantry CMF',        'CMF 11 - Infantry',        '11B', 'Infantryman',          '11B - Infantryman',        '00', 'Not Applicable', 'N/A'),
    ('AE',  '25', 'Signal CMF',          'CMF 25 - Signal',          '25B', 'IT Specialist',        '25B - IT Specialist',      '00', 'Not Applicable', 'N/A'),
    ('AO',  '11', 'Infantry Branch',     'Infantry',                 '11A', 'Infantry, General',    '11A - Infantry, General',  '00', 'Not Applicable', 'N/A'),
    ('AWO', '14', 'Aviation Branch',     'Aviation',                 '140A','Air Defense Tech',     '140A - ADA Technician',    '00', 'Not Applicable', 'N/A'),
    -- General Schedule (with career programs)
    ('GS',  '2200','Information Technology','IT Occupational Group',  '2210','IT Management',        '2210 - IT Management',     '34', 'IT Management',  'CP-34 IT Management'),
    ('GS',  '0300','General Administrative','Admin Occupational Group','0343','Program Analysis',    '0343 - Program Analysis',  '11', 'Comptroller',    'CP-11 Comptroller'),
    -- Other civilian families
    ('GG',  '0100','Social Science Group','Intel Occupational Group', '0132','Intelligence',         '0132 - Intelligence',      '35', 'Intelligence',   'CP-35 Intelligence'),
    ('GP',  '0600','Medical Group',       'Medical Occupational Group','0602','Medical Officer',     '0602 - Medical Officer',   '53', 'Medical',        'CP-53 Medical'),
    ('SES', '0300','General Administrative','Admin Occupational Group','0340','Program Management',   '0340 - Program Management','00', 'Not Applicable', 'N/A'),
    ('DB',  '0800','Engineering Group',   'Engineering Occupational Group','0855','Electronics Engineer','0855 - Electronics Engineer','16','Engineers & Scientists','CP-16 Engineers & Scientists'),
    ('NH',  '1100','Business & Industry', 'Business Occupational Group','1102','Contract Specialist','1102 - Contract Specialist','14','Contracting',     'CP-14 Contracting'),
    -- Contractor Cost Estimate (SOC codes, no career program)
    ('CCE', '11-0000','Management Occupations','Management',          '11-1021','General & Operations Mgr','11-1021 - General & Operations Mgr','00','Not Applicable','N/A'),
    -- Wage (Federal Wage System)
    ('WG',  '4200','Plumbing/Pipefitting','Wage Group 4200',         '4204','Pipefitting',          '4204 - Pipefitting',       '00', 'Not Applicable', 'N/A'),
    ('WL',  '4200','Plumbing/Pipefitting','Wage Group 4200',         '4204','Pipefitting',          '4204 - Pipefitting',       '00', 'Not Applicable', 'N/A'),
    ('WS',  '4200','Plumbing/Pipefitting','Wage Group 4200',         '4204','Pipefitting',          '4204 - Pipefitting',       '00', 'Not Applicable', 'N/A'),
    -- NAF wage
    ('CY',  '1700','Education Group',     'NAF Group 1700',           '1702','Education Aid',         '1702 - Education Aid',     '00', 'Not Applicable', 'N/A')
) AS v(payplan, cgc, cgd, cgdisp, csc, csd, csdisp, cpn, cpd, cpdisp)
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.category c
    WHERE c.payplan = v.payplan AND c.categorygroupcode = v.cgc
      AND c.categorysubgroupcode = v.csc AND c.careerprogramnumber = v.cpn
);

-- --------------------------------------------------------------------------
-- 3. Location-by-category. KEY ALIGNMENT IS CRITICAL: GetOptionListLocation
--    matches on (payplan, categorygroupcode, categorysubgroupcode,
--    careerprogramnumber) using the codes parseCategory() *produces*:
--      group item   selected -> (group, '-1',  '-1')
--      subgroup item selected -> (group, sub,  '-1')
--      career item   selected -> ('-1', '-1',  career)
--      "All"                  -> ('-1', '-1',  '-1')
--    Each non-null type column (installation/localitypayarea/etc.) surfaces a
--    separate location option; locationtype drives the dependent-status /
--    number-of-dependents / STRL sub-cascade. locationid resolves by name.
-- --------------------------------------------------------------------------
INSERT INTO warehouse.locationbycategory
    (payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber, locationid,
     installation, conusmha, oconusmha, localitypayarea, specialpayarea,
     country, wageschedule, citycounty, msa, civoverseas, strl)
SELECT v.payplan, v.cgc, v.csc, v.cpn, l.locationid,
       v.installation, v.conusmha, v.oconusmha, v.localitypayarea, v.specialpayarea,
       v.country, v.wageschedule, v.citycounty, v.msa, v.civoverseas, v.strl
FROM (VALUES
    -- payplan, cgc, csc, cpn, locname, installation, conusmha, oconusmha, localitypayarea, specialpayarea, country, wageschedule, citycounty, msa, civoverseas, strl
    -- AE (military: installation + CONUS MHA -> dependent status; OCONUS MHA -> no dependent status)
    ('AE','11','11B','-1','Fort Liberty, NC','Fort Liberty, NC','Fayetteville, NC MHA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AE','11','11B','-1','Fort Cavazos, TX',NULL,NULL,'Wiesbaden, GE MHA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AE','11','-1','-1','Fort Liberty, NC','Fort Liberty, NC',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AE','25','25B','-1','Fort Cavazos, TX','Fort Cavazos, TX','Killeen, TX MHA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AE','-1','-1','-1','Fort Liberty, NC','Fort Liberty, NC',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- AO / AWO (lighter)
    ('AO','11','11A','-1','Fort Moore, GA','Fort Moore, GA','Columbus, GA MHA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AO','-1','-1','-1','Fort Moore, GA','Fort Moore, GA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AWO','14','140A','-1','Fort Cavazos, TX','Fort Cavazos, TX','Killeen, TX MHA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('AWO','-1','-1','-1','Fort Cavazos, TX','Fort Cavazos, TX',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- GS (installation + locality + special + overseas[civilianOverseasArea -> number of dependents]; career-program-keyed row)
    ('GS','2200','2210','-1','Pentagon, Arlington, VA','Pentagon, Arlington, VA',NULL,NULL,'Washington-Baltimore-Arlington, DC-MD-VA-WV-PA','Washington DC Special Rate',NULL,NULL,NULL,NULL,'Germany (Overseas)',NULL),
    ('GS','2200','-1','-1','Pentagon, Arlington, VA','Pentagon, Arlington, VA',NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('GS','-1','-1','34','Pentagon, Arlington, VA',NULL,NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('GS','0300','0343','-1','Fort Belvoir, VA','Fort Belvoir, VA',NULL,NULL,'Washington-Baltimore-Arlington, DC-MD-VA-WV-PA',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('GS','-1','-1','-1','Pentagon, Arlington, VA',NULL,NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- GG / GP (GP gets gfebs country)
    ('GG','0100','0132','-1','Fort Belvoir, VA','Fort Belvoir, VA',NULL,NULL,'Washington-Baltimore-Arlington, DC-MD-VA-WV-PA',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('GG','-1','-1','-1','Fort Belvoir, VA',NULL,NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('GP','0600','0602','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,'Rest of U.S.',NULL,'United States',NULL,NULL,NULL,NULL,NULL),
    ('GP','-1','-1','-1','Fort Sill, OK',NULL,NULL,NULL,'Rest of U.S.',NULL,'United States',NULL,NULL,NULL,NULL,NULL),
    -- SES ("All" shows as CONUS)
    ('SES','0300','0340','-1','Pentagon, Arlington, VA','Pentagon, Arlington, VA',NULL,NULL,'Washington-Baltimore-Arlington, DC-MD-VA-WV-PA',NULL,NULL,NULL,NULL,NULL,'Germany (Overseas)',NULL),
    ('SES','-1','-1','-1','Pentagon, Arlington, VA',NULL,NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- DB (lab demo: STRL on the installation row)
    ('DB','0800','0855','-1','Aberdeen Proving Ground, MD','Aberdeen Proving Ground, MD',NULL,NULL,'Rest of U.S.',NULL,'United States',NULL,NULL,NULL,NULL,'ARL - Army Research Laboratory'),
    ('DB','0800','-1','-1','Redstone Arsenal, AL','Redstone Arsenal, AL',NULL,NULL,'Huntsville-Decatur, AL',NULL,'United States',NULL,NULL,NULL,NULL,'AVMC - Aviation & Missile Center'),
    ('DB','-1','-1','-1','Aberdeen Proving Ground, MD',NULL,NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- NH (acq demo)
    ('NH','1100','1102','-1','Redstone Arsenal, AL','Redstone Arsenal, AL',NULL,NULL,'Huntsville-Decatur, AL',NULL,'United States',NULL,NULL,NULL,NULL,NULL),
    ('NH','-1','-1','-1','Redstone Arsenal, AL',NULL,NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- CCE (installation + MSA; overhead-percent path)
    ('CCE','11-0000','11-1021','-1','Fort Belvoir, VA','Fort Belvoir, VA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Washington-Arlington-Alexandria, DC-VA-MD-WV',NULL,NULL),
    ('CCE','11-0000','-1','-1','Fort Belvoir, VA','Fort Belvoir, VA',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Washington-Arlington-Alexandria, DC-VA-MD-WV',NULL,NULL),
    -- WG / WL / WS (wage schedule + city/county + overseas)
    ('WG','4200','4204','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,NULL,NULL,NULL,'Oklahoma City, OK Wage Area','Comanche County, OK',NULL,'Germany (Overseas)',NULL),
    ('WG','4200','-1','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,NULL,NULL,NULL,'Oklahoma City, OK Wage Area',NULL,NULL,NULL,NULL),
    ('WL','4200','4204','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,NULL,NULL,NULL,'Oklahoma City, OK Wage Area','Comanche County, OK',NULL,'Germany (Overseas)',NULL),
    ('WL','4200','-1','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,NULL,NULL,NULL,'Oklahoma City, OK Wage Area',NULL,NULL,NULL,NULL),
    ('WS','4200','4204','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,NULL,NULL,NULL,'Oklahoma City, OK Wage Area','Comanche County, OK',NULL,'Germany (Overseas)',NULL),
    ('WS','4200','-1','-1','Fort Sill, OK','Fort Sill, OK',NULL,NULL,NULL,NULL,NULL,'Oklahoma City, OK Wage Area',NULL,NULL,NULL,NULL),
    -- CY (NAF: installation + locality)
    ('CY','1700','1702','-1','Fort Liberty, NC','Fort Liberty, NC',NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    ('CY','1700','-1','-1','Fort Liberty, NC','Fort Liberty, NC',NULL,NULL,'Rest of U.S.',NULL,NULL,NULL,NULL,NULL,NULL,NULL)
) AS v(payplan, cgc, csc, cpn, locname, installation, conusmha, oconusmha, localitypayarea,
       specialpayarea, country, wageschedule, citycounty, msa, civoverseas, strl)
JOIN warehouse.location l ON l.displayname = v.locname
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.locationbycategory lbc
    WHERE lbc.payplan = v.payplan AND lbc.categorygroupcode = v.cgc
      AND lbc.categorysubgroupcode = v.csc AND lbc.careerprogramnumber = v.cpn
      AND lbc.locationid = l.locationid
      AND COALESCE(lbc.installation,'')   = COALESCE(v.installation,'')
      AND COALESCE(lbc.localitypayarea,'')= COALESCE(v.localitypayarea,'')
      AND COALESCE(lbc.wageschedule,'')   = COALESCE(v.wageschedule,'')
      AND COALESCE(lbc.msa,'')            = COALESCE(v.msa,'')
);
