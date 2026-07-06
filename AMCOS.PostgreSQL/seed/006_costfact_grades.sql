-- ==========================================================================
-- AMCOS seed: AMCOS Lite cost data (populates the cost table + grade dropdowns)
--
-- The AMCOS Lite cost table is produced by web.getamcoslitecosts -> web.getcosts,
-- which joins data.costs (the crunch.costs_* union view) to lookup.costelement ->
-- costsummaryelement -> costsummary, filtered by cs.name = the requested summary
-- (AMCOS Lite always requests 'Default'), and by two location branches:
--   * non-location-specific elements: locationid = -1, islocationspecific = false
--   * location-specific elements:     locationid = <picked>, islocationspecific = true
-- Inflation is then applied by matching cost-element APPN to lookup.jicinflationrates.
--
-- So for a cost to appear, ALL of the following must line up:
--   1. a 'Default' cost summary exists for the pay plan,
--   2. the pay plan's cost elements are members of that 'Default' summary,
--   3. data.costs (crunch.costs_*) has a row per element x grade on the correct
--      location branch, with a valid costelementid,
--   4. jicinflationrates covers the element's APPN for the conversion type/year.
-- This file seeds all four, keyed to the categories/locations from seed 005.
--
-- Grade dropdowns are a natural subset (every grade gets rows). CCE is excluded
-- (separate data.costscce / BLS_OES path). Idempotent. Run after 001-005.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Cost elements for the dropdown pay plans that have none yet.
--    (AE/AO/AWO/GS/WG already have elements from seed 002.) Standard civilian
--    composite set: Base Salary, Locality Pay (location-specific), Benefits,
--    Retirement. costelementid is identity-assigned.
-- --------------------------------------------------------------------------
INSERT INTO lookup.costelement
    (payplan, appropriationgroup, appn, costelementcategory, costelementname,
     model, locality, showorder, active, applyinflation, islocationspecific,
     amcosversionidstart, amcosversionidend)
SELECT pp.payplan, e.appropriationgroup, 'O&M', e.costelementcategory, e.costelementname,
       1, e.islocationspecific, e.showorder, TRUE, TRUE, e.islocationspecific, 1, 999999
FROM (VALUES ('GG'), ('GP'), ('SES'), ('WL'), ('WS'), ('DB'), ('NH'), ('CY')) AS pp(payplan)
CROSS JOIN (VALUES
    ('Civilian Pay',      'Pay',      'Base Salary',                  10, FALSE),
    ('Civilian Pay',      'Pay',      'Locality Pay',                 20, TRUE),
    ('Civilian Benefits', 'Benefits', 'Civilian Benefits (Acc Cost)', 30, FALSE),
    ('Civilian Benefits', 'Benefits', 'Retirement (FERS/CSRS)',       40, FALSE)
) AS e(appropriationgroup, costelementcategory, costelementname, showorder, islocationspecific)
WHERE NOT EXISTS (
    SELECT 1 FROM lookup.costelement ce
    WHERE ce.payplan = pp.payplan AND ce.costelementname = e.costelementname AND ce.amcosversionidend = 999999
);

-- --------------------------------------------------------------------------
-- 2. A 'Default' cost summary for every non-CCE dropdown pay plan.
-- --------------------------------------------------------------------------
INSERT INTO lookup.costsummary (payplan, name, amcosversionidstart, amcosversionidend)
SELECT DISTINCT ce.payplan, 'Default', 1, 999999
FROM lookup.costelement ce
WHERE ce.amcosversionidend = 999999
  AND ce.payplan IN ('AE','AO','AWO','GS','GG','GP','SES','WG','WL','WS','DB','NH','CY')
  AND NOT EXISTS (
      SELECT 1 FROM lookup.costsummary cs
      WHERE cs.payplan = ce.payplan AND cs.name = 'Default' AND cs.amcosversionidend = 999999
  );

-- --------------------------------------------------------------------------
-- 3. Make every cost element a member of its pay plan's 'Default' summary.
-- --------------------------------------------------------------------------
INSERT INTO lookup.costsummaryelement (summaryid, costelementid, amcosversionidstart, amcosversionidend)
SELECT cs.summaryid, ce.costelementid, 1, 999999
FROM lookup.costelement ce
JOIN lookup.costsummary cs
  ON cs.payplan = ce.payplan AND cs.name = 'Default' AND cs.amcosversionidend = 999999
WHERE ce.amcosversionidend = 999999
  AND NOT EXISTS (
      SELECT 1 FROM lookup.costsummaryelement cse
      WHERE cse.summaryid = cs.summaryid AND cse.costelementid = ce.costelementid AND cse.amcosversionidend = 999999
  );

-- --------------------------------------------------------------------------
-- 4. Inflation factors for the APPNs the cost elements actually use
--    (MILPERS, O&M) plus the existing Army CivPay/OMA, across the demo year
--    range and both conversion types. ~2%/yr from the 2025 base year.
-- --------------------------------------------------------------------------
INSERT INTO lookup.jicinflationrates (conversiontype, year, appropriation, amount, amcosversionid)
SELECT ct.conversiontype, y.year::smallint, ap.appropriation,
       ROUND((1.02 ^ (y.year - 2025))::numeric, 6), 202501
FROM (VALUES ('ThenToThen'), ('ThenToConstant')) AS ct(conversiontype)
CROSS JOIN (VALUES ('MILPERS'), ('O&M'), ('Army CivPay'), ('OMA')) AS ap(appropriation)
CROSS JOIN generate_series(2025, 2060) AS y(year)
ON CONFLICT (conversiontype, year, appropriation, amcosversionid) DO NOTHING;

-- --------------------------------------------------------------------------
-- 5. Cost facts. One row per (category/location combo, grade, cost element).
--    locationid is chosen by the element's islocationspecific flag so it lands
--    on the branch web.getcosts expects. Amount = per-grade base scaled down by
--    show order (Base Salary largest), so the crosstab shows a realistic spread.
-- --------------------------------------------------------------------------
-- Active Enlisted (AE) — E1..E9
INSERT INTO crunch.costs_ae
    (payplan, cmf, mos, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amount, crunchtime, amcosversionid)
SELECT 'AE', lbc.categorygroupcode, lbc.categorysubgroupcode, '-1',
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, '-1', -1, 'E', g.gradelevel, ce.costelementid,
       ROUND((20000 + g.gradelevel * 3000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 9) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = 'AE' AND ce.amcosversionidend = 999999
WHERE lbc.payplan = 'AE'
ON CONFLICT DO NOTHING;

-- Active Officer (AO) — O1..O10
INSERT INTO crunch.costs_ao
    (payplan, cmf, aoc, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amount, crunchtime, amcosversionid)
SELECT 'AO', lbc.categorygroupcode, lbc.categorysubgroupcode, '-1',
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, '-1', -1, 'O', g.gradelevel, ce.costelementid,
       ROUND((45000 + g.gradelevel * 5000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 10) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = 'AO' AND ce.amcosversionidend = 999999
WHERE lbc.payplan = 'AO'
ON CONFLICT DO NOTHING;

-- Active Warrant Officer (AWO) — W1..W5
INSERT INTO crunch.costs_awo
    (payplan, branch, womos, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amount, crunchtime, amcosversionid)
SELECT 'AWO', lbc.categorygroupcode, lbc.categorysubgroupcode, '-1',
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, '-1', -1, 'W', g.gradelevel, ce.costelementid,
       ROUND((40000 + g.gradelevel * 4000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 5) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = 'AWO' AND ce.amcosversionidend = 999999
WHERE lbc.payplan = 'AWO'
ON CONFLICT DO NOTHING;

-- General Schedule family (GS, GG, GP) — GS-1..GS-15
INSERT INTO crunch.costs_g
    (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, locationid, numberofdependents, costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid)
SELECT lbc.payplan, lbc.categorygroupcode, lbc.categorysubgroupcode, lbc.careerprogramnumber,
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, -1, ce.costelementid, lbc.payplan, g.gradelevel,
       ROUND((40000 + g.gradelevel * 4000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 15) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = lbc.payplan AND ce.amcosversionidend = 999999
WHERE lbc.payplan IN ('GS', 'GG', 'GP')
ON CONFLICT DO NOTHING;

-- Senior Executive Service (SES) — MIN/AVG/MAX (1..3)
INSERT INTO crunch.costs_ses
    (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid, numberofdependents, costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid)
SELECT 'SES', lbc.categorygroupcode, lbc.categorysubgroupcode,
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, -1, ce.costelementid, lbc.payplan, g.gradelevel,
       ROUND((160000 + g.gradelevel * 12000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 3) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = 'SES' AND ce.amcosversionidend = 999999
WHERE lbc.payplan = 'SES'
ON CONFLICT DO NOTHING;

-- Wage family (WG, WL, WS) — WG-1..WG-15
INSERT INTO crunch.costs_wage
    (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule, locationid, numberofdependents, costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid)
SELECT lbc.payplan, lbc.categorygroupcode, lbc.categorysubgroupcode, '-1', '-1',
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, -1, ce.costelementid, lbc.payplan, g.gradelevel,
       ROUND((30000 + g.gradelevel * 2000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 15) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = lbc.payplan AND ce.amcosversionidend = 999999
WHERE lbc.payplan IN ('WG', 'WL', 'WS')
ON CONFLICT DO NOTHING;

-- NAF (CY) — paybands 1..5
INSERT INTO crunch.costs_cy
    (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid, costelementid, gradetype, payband, amount, crunchtime, amcosversionid)
SELECT 'CY', lbc.categorygroupcode, lbc.categorysubgroupcode,
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, ce.costelementid, 'CY', g.payband,
       ROUND((28000 + g.payband * 3500) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 5) AS g(payband)
JOIN lookup.costelement ce ON ce.payplan = 'CY' AND ce.amcosversionidend = 999999
WHERE lbc.payplan = 'CY'
ON CONFLICT DO NOTHING;

-- Lab Demo (DB) & Acq Demo (NH) — paybands 1..5 (costs_gfebs has no gradetype col;
-- the data.costs view maps gradetype = payplan for this table).
INSERT INTO crunch.costs_gfebs
    (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, localitycode, country, locationid, strl, costelementid, gradelevel, amount, crunchtime, amcosversionid)
SELECT lbc.payplan, lbc.categorygroupcode, lbc.categorysubgroupcode, lbc.careerprogramnumber, 'RUS', 'United States',
       CASE WHEN ce.islocationspecific THEN lbc.locationid ELSE -1 END, '-1', ce.costelementid, g.gradelevel,
       ROUND((55000 + g.gradelevel * 8000) * (1.0 - (COALESCE(ce.showorder,10) - 10) * 0.012)::numeric, 2), NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 5) AS g(gradelevel)
JOIN lookup.costelement ce ON ce.payplan = lbc.payplan AND ce.amcosversionidend = 999999
WHERE lbc.payplan IN ('DB', 'NH')
ON CONFLICT DO NOTHING;
