-- ==========================================================================
-- AMCOS seed: versions + core lookups
-- Representative development / demo dataset.
--
-- Run AFTER the schema/table migrations (000-008).
-- Idempotent: re-running will not create duplicate rows.
--
-- Version model (mirrors legacy AMCOS):
--   * lookup.amcosversion holds discrete data versions.
--   * Range-versioned reference rows use amcosversionidstart / amcosversionidend
--     where 1 .. 999999 means "currently effective".
--   * Single-version rows stamp amcosversionid = 202501 (current demo version).
-- ==========================================================================

-- --------------------------------------------------------------------------
-- AMCOS versions
-- --------------------------------------------------------------------------
INSERT INTO lookup.amcosversion (amcosversionid, description) VALUES
    (202401, '2024 March data version'),
    (202501, '2025 March data version (current)')
ON CONFLICT (amcosversionid) DO NOTHING;

-- --------------------------------------------------------------------------
-- Pay plans
-- --------------------------------------------------------------------------
INSERT INTO lookup.payplan
    (payplan, amcosversionidstart, amcosversionidend, displaytitle, grouptitle,
     description, categorygrouplabel, categorysubgrouplabel,
     includearmycareerprograms, displaysequence, versionintroduced)
-- Pay-plan codes follow the legacy taxonomy used by the cost engine
-- (analysis.getpayplans), AMCOS.Logic.Lite.payPlanType, and the Lite UI
-- (object-payplan.js): active military AE/AO/AWO, civilian GS/GG/GP/SES/CCE,
-- wage WG/WL/WS, lab-demo DB, acq-demo NH, NAF CY.
VALUES
    ('AE',  1, 999999, 'Active Enlisted (AE)',         'Military', 'Active Duty Enlisted',        'Career Management Field (CMF)', 'Military Occupational Specialty (MOS)', FALSE, 1.00, 202401),
    ('AO',  1, 999999, 'Active Officer (AO)',          'Military', 'Active Duty Officer',         'Branch', 'Area of Concentration', FALSE, 1.10, 202401),
    ('AWO', 1, 999999, 'Active Warrant Officer (AWO)', 'Military', 'Active Duty Warrant Officer', 'Branch', 'WO Military Occupational Specialty', FALSE, 1.20, 202401),
    ('GS',  1, 999999, 'General Schedule',  'Civilian', 'GS Civilian',          'Occupational Group', 'Occupational Series', TRUE,  2.00, 202401),
    ('GG',  1, 999999, 'Intelligence Personnel (GG)', 'Civilian', 'GG Intelligence', 'Occupational Group', 'Occupational Series', TRUE, 2.05, 202401),
    ('GP',  1, 999999, 'Physicians and Dentists (GP)','Civilian', 'GP Physicians and Dentists', 'Occupational Group', 'Occupational Series', TRUE, 2.07, 202401),
    ('SES', 1, 999999, 'Senior Executive',  'Civilian', 'Senior Executive Service', 'Occupational Group', 'Occupational Series', TRUE, 2.10, 202401),
    ('CCE', 1, 999999, 'Contractor Cost Estimate (CCE)', 'Civilian', 'Contractor Cost Estimate', 'SOC Major Group', 'Detailed Occupation', FALSE, 2.15, 202401),
    ('WG',  1, 999999, 'Wage Grade',        'Civilian', 'Federal Wage System - Worker', 'Wage Occupational Group', 'Wage Occupational Series', FALSE, 2.20, 202401),
    ('WL',  1, 999999, 'Wage Leader',       'Civilian', 'Federal Wage System - Leader', 'Wage Occupational Group', 'Wage Occupational Series', FALSE, 2.30, 202401),
    ('WS',  1, 999999, 'Wage Supervisor',   'Civilian', 'Federal Wage System - Supervisor', 'Wage Occupational Group', 'Wage Occupational Series', FALSE, 2.40, 202401),
    ('DB',  1, 999999, 'Lab Demo Engineer/Scientist (DB)', 'Civilian', 'Laboratory Demonstration', 'Occupational Group', 'Occupational Series', TRUE, 4.00, 202401),
    ('NH',  1, 999999, 'Acq Demo Bus Mgmt (NH)', 'Civilian', 'Acquisition Demonstration', 'Occupational Group', 'Occupational Series', TRUE, 4.10, 202401),
    ('CY',  1, 999999, 'NAF Child & Youth (CY)', 'Civilian', 'Non-Appropriated Fund', 'Wage Occupational Group', 'Wage Occupational Series', FALSE, 4.20, 202401)
ON CONFLICT (payplan, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- Grades (payplan, gradetype, gradelevel)
--   gradetype: O = Officer, W = Warrant, E = Enlisted, C = Civilian
-- --------------------------------------------------------------------------
-- Active Officer (AO) O1..O10
INSERT INTO lookup.grade (payplan, gradetype, gradelevel, careertrainingwindowyears, amcosversionidstart, amcosversionidend)
SELECT 'AO', 'O', g, NULL, 1, 999999 FROM generate_series(1, 10) AS g
ON CONFLICT (payplan, gradetype, gradelevel, amcosversionidend) DO NOTHING;
-- Active Warrant Officer (AWO) W1..W5
INSERT INTO lookup.grade (payplan, gradetype, gradelevel, careertrainingwindowyears, amcosversionidstart, amcosversionidend)
SELECT 'AWO', 'W', g, NULL, 1, 999999 FROM generate_series(1, 5) AS g
ON CONFLICT (payplan, gradetype, gradelevel, amcosversionidend) DO NOTHING;
-- Active Enlisted (AE) E1..E9
INSERT INTO lookup.grade (payplan, gradetype, gradelevel, careertrainingwindowyears, amcosversionidstart, amcosversionidend)
SELECT 'AE', 'E', g, NULL, 1, 999999 FROM generate_series(1, 9) AS g
ON CONFLICT (payplan, gradetype, gradelevel, amcosversionidend) DO NOTHING;
-- General Schedule GS1..GS15
INSERT INTO lookup.grade (payplan, gradetype, gradelevel, careertrainingwindowyears, amcosversionidstart, amcosversionidend)
SELECT 'GS', 'C', g, NULL, 1, 999999 FROM generate_series(1, 15) AS g
ON CONFLICT (payplan, gradetype, gradelevel, amcosversionidend) DO NOTHING;
-- Wage Grade WG1..WG15
INSERT INTO lookup.grade (payplan, gradetype, gradelevel, careertrainingwindowyears, amcosversionidstart, amcosversionidend)
SELECT 'WG', 'C', g, NULL, 1, 999999 FROM generate_series(1, 15) AS g
ON CONFLICT (payplan, gradetype, gradelevel, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- MACOMs (Major Commands)
-- --------------------------------------------------------------------------
INSERT INTO lookup.macom (macom, macom_name, description) VALUES
    ('FC', 'FORSCOM',            'U.S. Army Forces Command'),
    ('TR', 'TRADOC',             'U.S. Army Training and Doctrine Command'),
    ('AM', 'AMC',                'U.S. Army Materiel Command'),
    ('MD', 'MEDCOM',             'U.S. Army Medical Command'),
    ('NG', 'ARNG',               'Army National Guard'),
    ('AR', 'USARC',              'U.S. Army Reserve Command'),
    ('PA', 'USARPAC',            'U.S. Army Pacific'),
    ('EU', 'USAREUR-AF',         'U.S. Army Europe and Africa')
ON CONFLICT (macom) DO NOTHING;

-- --------------------------------------------------------------------------
-- Organizations
-- --------------------------------------------------------------------------
INSERT INTO lookup.organization (organizationname, organizationdescription, organizationtype) VALUES
    ('DASA-CE',  'Deputy Assistant Secretary of the Army - Cost and Economics', 'HQDA'),
    ('FORSCOM',  'U.S. Army Forces Command',                                    'MACOM'),
    ('TRADOC',   'U.S. Army Training and Doctrine Command',                     'MACOM'),
    ('AMC',      'U.S. Army Materiel Command',                                  'MACOM')
ON CONFLICT (organizationname) DO NOTHING;

-- --------------------------------------------------------------------------
-- CMF / Branch / Functional Area
--   gradetype: O = Officer, E = Enlisted
-- --------------------------------------------------------------------------
INSERT INTO lookup.cmf_branch_fa (code, gradetype, description, codetype, amcosversionidstart, amcosversionidend) VALUES
    ('11', 'O', 'Infantry',              'Branch', 1, 999999),
    ('13', 'O', 'Field Artillery',       'Branch', 1, 999999),
    ('19', 'O', 'Armor',                 'Branch', 1, 999999),
    ('25', 'O', 'Signal Corps',          'Branch', 1, 999999),
    ('11', 'E', 'Infantry',              'CMF',    1, 999999),
    ('13', 'E', 'Field Artillery',       'CMF',    1, 999999),
    ('25', 'E', 'Signal',                'CMF',    1, 999999),
    ('68', 'E', 'Medical',               'CMF',    1, 999999)
ON CONFLICT (code, gradetype, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- MOS (Military Occupational Specialty) — enlisted sample
-- --------------------------------------------------------------------------
INSERT INTO lookup.mos (mos, description, parent_mos, amcosversionidstart, amcosversionidend) VALUES
    ('11B', 'Infantryman',                NULL, 1, 999999),
    ('13B', 'Cannon Crewmember',          NULL, 1, 999999),
    ('19K', 'M1 Armor Crewman',           NULL, 1, 999999),
    ('25B', 'Information Technology Specialist', NULL, 1, 999999),
    ('68W', 'Combat Medic Specialist',    NULL, 1, 999999)
ON CONFLICT (mos, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- AOC (Area of Concentration) — officer sample
-- --------------------------------------------------------------------------
INSERT INTO lookup.aoc (aoc, description, amcosversionidstart, amcosversionidend) VALUES
    ('11A', 'Infantry, General',          1, 999999),
    ('13A', 'Field Artillery, General',   1, 999999),
    ('19A', 'Armor, General',             1, 999999),
    ('25A', 'Signal, General',            1, 999999)
ON CONFLICT (aoc, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- Army Career Programs (civilian)
-- --------------------------------------------------------------------------
INSERT INTO lookup.armycareerprogram (careerprogramnumber, title, amcosversionidstart, amcosversionidend) VALUES
    ('00', 'Not Applicable',                       1, 999999),
    ('11', 'Comptroller',                          1, 999999),
    ('17', 'Materiel Maintenance Management',      1, 999999),
    ('34', 'Information Technology Management',    1, 999999)
ON CONFLICT (careerprogramnumber, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- Component / category types
-- --------------------------------------------------------------------------
INSERT INTO lookup.ctype (code, description, amcosversionidstart, amcosversionidend) VALUES
    (1, 'Active Component',          1, 999999),
    (2, 'Army National Guard',      1, 999999),
    (3, 'U.S. Army Reserve',        1, 999999),
    (4, 'Civilian',                 1, 999999)
ON CONFLICT (code, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- Locality pay areas
-- --------------------------------------------------------------------------
INSERT INTO lookup.localitypayarea (localitycode, localitypayarea, amcosversionid) VALUES
    ('RUS',    'Rest of U.S.',                                  202501),
    ('WASDC',  'Washington-Baltimore-Arlington, DC-MD-VA-WV-PA',202501),
    ('SANJOS', 'San Jose-San Francisco-Oakland, CA',            202501),
    ('ATLAN',  'Atlanta-Athens-Clarke County-Sandy Springs, GA-AL', 202501),
    ('SAANTO', 'San Antonio-New Braunfels-Pearsall, TX',        202501)
ON CONFLICT (localitycode, amcosversionid) DO NOTHING;

-- --------------------------------------------------------------------------
-- GS occupational groups / series
-- --------------------------------------------------------------------------
INSERT INTO lookup.gs_occupationalgroup (occupationalgroupnumber, grouptitle, amcosversionidstart, amcosversionidend) VALUES
    ('0300', 'General Administrative, Clerical, and Office Services', 1, 999999),
    ('0800', 'Engineering and Architecture',                         1, 999999),
    ('2200', 'Information Technology',                                1, 999999)
ON CONFLICT (occupationalgroupnumber, amcosversionidend) DO NOTHING;

INSERT INTO lookup.gs_occupationalseries (occupationalseriesnumber, seriestitle, workrolecoderequired, amcosversionidstart, amcosversionidend) VALUES
    ('0343', 'Management and Program Analysis', FALSE, 1, 999999),
    ('0801', 'General Engineering',             FALSE, 1, 999999),
    ('2210', 'Information Technology Management', TRUE, 1, 999999)
ON CONFLICT (occupationalseriesnumber, amcosversionidend) DO NOTHING;

-- --------------------------------------------------------------------------
-- JIC inflation rates (sample — National Defense appropriations)
-- --------------------------------------------------------------------------
INSERT INTO lookup.jicinflationrates (conversiontype, year, appropriation, amount, amcosversionid) VALUES
    ('Raw',      2024, 'MILPERS', 1.000000000000000, 202501),
    ('Raw',      2025, 'MILPERS', 1.041000000000000, 202501),
    ('Raw',      2026, 'MILPERS', 1.062000000000000, 202501),
    ('Constant', 2025, 'MILPERS', 1.000000000000000, 202501),
    ('Raw',      2024, 'O&M',     1.000000000000000, 202501),
    ('Raw',      2025, 'O&M',     1.028000000000000, 202501),
    ('Raw',      2026, 'O&M',     1.048000000000000, 202501)
ON CONFLICT (conversiontype, year, appropriation, amcosversionid) DO NOTHING;
