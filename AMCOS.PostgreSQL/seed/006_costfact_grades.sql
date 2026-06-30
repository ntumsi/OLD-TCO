-- ==========================================================================
-- AMCOS seed: cost-fact grade coverage (AMCOS Lite + Project Manager cascades)
--
-- The grade-level dropdown (AMCOS.Logic.Lite.GetOptionListGradeLevel) reads
-- DISTINCT gradelevel from the data.costs VIEW, which unions the per-pay-plan
-- crunch.costs_* tables and INNER JOINs lookup.costelement on costelementid.
-- So a grade only appears when a crunch row exists for the exact
-- (payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
-- locationid, amcosversionid) the cascade selects, with a VALID costelementid.
--
-- This file generates those rows directly from the categories/locations seeded
-- in 005 (warehouse.locationbycategory), so the keys line up automatically:
-- one grade row per (combo, location) for each location the cascade offers,
-- plus a locationid = -1 variant (grades show right after a category is picked).
-- A representative amount is set so the cost tables/report are not empty,
-- though this is grade coverage, not a full cost load.
--
-- CCE is intentionally excluded: it is not part of the data.costs union
-- (it has a separate data.costscce path), so grades cannot flow through here.
--
-- Idempotent (ON CONFLICT DO NOTHING). Run after 001-005 (see seed/README.md).
-- ==========================================================================

-- A always-valid cost element id (the view drops rows whose costelementid is
-- absent from lookup.costelement); prefer the pay plan's own element if present.
-- Helper expressions are inlined per INSERT below.

-- --------------------------------------------------------------------------
-- Active Enlisted (AE) -> crunch.costs_ae  (E1..E9)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_ae
    (payplan, cmf, mos, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amount, crunchtime, amcosversionid)
SELECT 'AE', lbc.categorygroupcode, lbc.categorysubgroupcode, '-1', v.locationid, '-1', -1, 'E', g.gradelevel,
       COALESCE(ppce.costelementid, gce.anyce), (40000 + g.gradelevel * 4000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 9) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
CROSS JOIN (SELECT MIN(costelementid) AS anyce FROM lookup.costelement) gce
LEFT JOIN LATERAL (SELECT costelementid FROM lookup.costelement c WHERE c.payplan = 'AE' AND c.amcosversionidend = 999999 ORDER BY c.showorder LIMIT 1) ppce ON true
WHERE lbc.payplan = 'AE'
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- Active Officer (AO) -> crunch.costs_ao  (O1..O10)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_ao
    (payplan, cmf, aoc, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amount, crunchtime, amcosversionid)
SELECT 'AO', lbc.categorygroupcode, lbc.categorysubgroupcode, '-1', v.locationid, '-1', -1, 'O', g.gradelevel,
       COALESCE(ppce.costelementid, gce.anyce), (60000 + g.gradelevel * 6000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 10) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
CROSS JOIN (SELECT MIN(costelementid) AS anyce FROM lookup.costelement) gce
LEFT JOIN LATERAL (SELECT costelementid FROM lookup.costelement c WHERE c.payplan = 'AO' AND c.amcosversionidend = 999999 ORDER BY c.showorder LIMIT 1) ppce ON true
WHERE lbc.payplan = 'AO'
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- Active Warrant Officer (AWO) -> crunch.costs_awo  (W1..W5)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_awo
    (payplan, branch, womos, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel, costelementid, amount, crunchtime, amcosversionid)
SELECT 'AWO', lbc.categorygroupcode, lbc.categorysubgroupcode, '-1', v.locationid, '-1', -1, 'W', g.gradelevel,
       COALESCE(ppce.costelementid, gce.anyce), (55000 + g.gradelevel * 5000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 5) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
CROSS JOIN (SELECT MIN(costelementid) AS anyce FROM lookup.costelement) gce
LEFT JOIN LATERAL (SELECT costelementid FROM lookup.costelement c WHERE c.payplan = 'AWO' AND c.amcosversionidend = 999999 ORDER BY c.showorder LIMIT 1) ppce ON true
WHERE lbc.payplan = 'AWO'
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- General Schedule family (GS, GG, GP) -> crunch.costs_g  (GS-1..GS-15)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_g
    (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, locationid, numberofdependents, costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid)
SELECT lbc.payplan, lbc.categorygroupcode, lbc.categorysubgroupcode, lbc.careerprogramnumber, v.locationid, -1,
       COALESCE(ppce.costelementid, gce.anyce), 'C', g.gradelevel, (45000 + g.gradelevel * 6000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 15) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
CROSS JOIN (SELECT MIN(costelementid) AS anyce FROM lookup.costelement) gce
LEFT JOIN LATERAL (SELECT costelementid FROM lookup.costelement c WHERE c.payplan = lbc.payplan AND c.amcosversionidend = 999999 ORDER BY c.showorder LIMIT 1) ppce ON true
WHERE lbc.payplan IN ('GS', 'GG', 'GP')
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- Senior Executive Service (SES) -> crunch.costs_ses  (Min/Avg/Max = 1..3)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_ses
    (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid, numberofdependents, costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid)
SELECT 'SES', lbc.categorygroupcode, lbc.categorysubgroupcode, v.locationid, -1,
       COALESCE(ppce.costelementid, gce.anyce), 'C', g.gradelevel, (170000 + g.gradelevel * 10000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 3) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
CROSS JOIN (SELECT MIN(costelementid) AS anyce FROM lookup.costelement) gce
LEFT JOIN LATERAL (SELECT costelementid FROM lookup.costelement c WHERE c.payplan = 'SES' AND c.amcosversionidend = 999999 ORDER BY c.showorder LIMIT 1) ppce ON true
WHERE lbc.payplan = 'SES'
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- Wage family (WG, WL, WS) -> crunch.costs_wage  (WG-1..WG-15)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_wage
    (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule, locationid, numberofdependents, costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid)
SELECT lbc.payplan, lbc.categorygroupcode, lbc.categorysubgroupcode, '-1', '-1', v.locationid, -1,
       COALESCE(ppce.costelementid, gce.anyce), 'C', g.gradelevel, (35000 + g.gradelevel * 2500)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 15) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
CROSS JOIN (SELECT MIN(costelementid) AS anyce FROM lookup.costelement) gce
LEFT JOIN LATERAL (SELECT costelementid FROM lookup.costelement c WHERE c.payplan = lbc.payplan AND c.amcosversionidend = 999999 ORDER BY c.showorder LIMIT 1) ppce ON true
WHERE lbc.payplan IN ('WG', 'WL', 'WS')
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- NAF (CY) -> crunch.costs_cy  (paybands 1..5)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_cy
    (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid, costelementid, gradetype, payband, amount, crunchtime, amcosversionid)
SELECT 'CY', lbc.categorygroupcode, lbc.categorysubgroupcode, v.locationid,
       (SELECT MIN(costelementid) FROM lookup.costelement), 'C', g.payband, (30000 + g.payband * 4000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 5) AS g(payband)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
WHERE lbc.payplan = 'CY'
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------------------------
-- Lab Demo (DB) & Acq Demo (NH) -> crunch.costs_gfebs  (paybands 1..5)
-- (gfebs has no gradetype column; the view maps gradetype = payplan)
-- --------------------------------------------------------------------------
INSERT INTO crunch.costs_gfebs
    (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, localitycode, country, locationid, strl, costelementid, gradelevel, amount, crunchtime, amcosversionid)
-- strl is varchar(20) and the grade lookup does not filter on it, so use '-1'.
SELECT lbc.payplan, lbc.categorygroupcode, lbc.categorysubgroupcode, lbc.careerprogramnumber, 'RUS', 'United States',
       v.locationid, '-1', (SELECT MIN(costelementid) FROM lookup.costelement),
       g.gradelevel, (50000 + g.gradelevel * 7000)::numeric, NULL, 202501
FROM warehouse.locationbycategory lbc
CROSS JOIN generate_series(1, 5) AS g(gradelevel)
CROSS JOIN LATERAL (VALUES (lbc.locationid), (-1)) AS v(locationid)
WHERE lbc.payplan IN ('DB', 'NH')
ON CONFLICT DO NOTHING;
