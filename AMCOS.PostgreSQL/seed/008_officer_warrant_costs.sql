-- ============================================================================
-- 006_officer_warrant_costs.sql
-- Bring the Active Officer (AO) and Active Warrant Officer (AWO) cost seed up to
-- parity with Active Enlisted (AE). The demo seed defined the full 7-element
-- military cost breakdown only for AE; AO had 4 elements (missing Incentive and
-- Special Pays, Medicare-Eligible Retiree Health, Permanent Change of Station)
-- and AWO had 2 (missing Basic Allowance for Subsistence, Incentive and Special
-- Pays, Retired Pay Accrual, Medicare-Eligible Retiree Health, Permanent Change
-- of Station), so AMCOS Lite produced a thin/incomplete cost table for officers.
--
-- This clones AE's cost-element DEFINITIONS (lookup.costelement) for AO/AWO and
-- adds matching cost rows (crunch.costs_ao / crunch.costs_awo) at the same
-- category/location/grade coverage as each pay plan's existing Basic Pay rows.
-- Amounts follow the existing linear demo ratios (BAS = Basic Pay x 0.76,
-- Retired Pay Accrual = Basic Pay x 0.52, Incentive/Special Pays = Basic Pay x
-- 0.05) with flat figures for Medicare ($1,800) and PCS ($6,000). Idempotent.
-- ============================================================================

-- 1. Cost-element definitions: clone AE's missing elements for AO and AWO.
INSERT INTO lookup.costelement
    (payplan, appropriationgroup, appn, costelementcategory, costelementname, amort, model,
     locality, description, businesslogic, basisofcomputation, source, showorder, armycestitle,
     osdcapecestitle, active, amcosversionidstart, amcosversionidend, applyinflation, islocationspecific)
SELECT tgt.payplan, ae.appropriationgroup, ae.appn, ae.costelementcategory, ae.costelementname,
       ae.amort, ae.model, ae.locality, ae.description, ae.businesslogic, ae.basisofcomputation,
       ae.source, ae.showorder, ae.armycestitle, ae.osdcapecestitle, ae.active,
       ae.amcosversionidstart, ae.amcosversionidend, ae.applyinflation, ae.islocationspecific
FROM lookup.costelement ae
CROSS JOIN (VALUES ('AO'), ('AWO')) AS tgt(payplan)
WHERE ae.payplan = 'AE'
  AND (
        (tgt.payplan = 'AO'  AND ae.costelementname IN
            ('Incentive and Special Pays', 'Medicare-Eligible Retiree Health', 'Permanent Change of Station'))
     OR (tgt.payplan = 'AWO' AND ae.costelementname IN
            ('Basic Allowance for Subsistence', 'Incentive and Special Pays', 'Retired Pay Accrual',
             'Medicare-Eligible Retiree Health', 'Permanent Change of Station'))
      )
  AND NOT EXISTS (
        SELECT 1 FROM lookup.costelement x
        WHERE x.payplan = tgt.payplan AND x.costelementname = ae.costelementname);

-- 2. Cost rows for the newly-added AO elements — clone the key tuples (categories,
--    location, grades) of AO Basic Pay and compute an amount per element.
INSERT INTO crunch.costs_ao
    (payplan, cmf, aoc, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel,
     costelementid, amount, amcosversionid)
SELECT bp.payplan, bp.cmf, bp.aoc, bp.mha, bp.locationid, bp.dependentstatus, bp.weaponsystemid,
       bp.gradetype, bp.gradelevel, ce.costelementid,
       CASE ce.costelementname
           WHEN 'Incentive and Special Pays'        THEN ROUND(bp.amount * 0.05, 2)
           WHEN 'Medicare-Eligible Retiree Health'  THEN 1800.00
           WHEN 'Permanent Change of Station'       THEN 6000.00
       END,
       bp.amcosversionid
FROM crunch.costs_ao bp
JOIN lookup.costelement ce
     ON ce.payplan = 'AO'
    AND ce.costelementname IN ('Incentive and Special Pays', 'Medicare-Eligible Retiree Health', 'Permanent Change of Station')
WHERE bp.costelementid = (SELECT costelementid FROM lookup.costelement WHERE payplan = 'AO' AND costelementname = 'Basic Pay')
  AND NOT EXISTS (
        SELECT 1 FROM crunch.costs_ao x
        WHERE x.costelementid = ce.costelementid AND x.cmf = bp.cmf AND x.aoc = bp.aoc AND x.mha = bp.mha
          AND x.locationid = bp.locationid AND x.dependentstatus = bp.dependentstatus
          AND x.weaponsystemid = bp.weaponsystemid AND x.gradetype = bp.gradetype
          AND x.gradelevel = bp.gradelevel AND x.amcosversionid = bp.amcosversionid);

-- 3. Cost rows for the newly-added AWO elements — clone AWO Basic Pay key tuples.
INSERT INTO crunch.costs_awo
    (payplan, branch, womos, mha, locationid, dependentstatus, weaponsystemid, gradetype, gradelevel,
     costelementid, amount, amcosversionid)
SELECT bp.payplan, bp.branch, bp.womos, bp.mha, bp.locationid, bp.dependentstatus, bp.weaponsystemid,
       bp.gradetype, bp.gradelevel, ce.costelementid,
       CASE ce.costelementname
           WHEN 'Basic Allowance for Subsistence'   THEN ROUND(bp.amount * 0.76, 2)
           WHEN 'Retired Pay Accrual'               THEN ROUND(bp.amount * 0.52, 2)
           WHEN 'Incentive and Special Pays'        THEN ROUND(bp.amount * 0.05, 2)
           WHEN 'Medicare-Eligible Retiree Health'  THEN 1800.00
           WHEN 'Permanent Change of Station'       THEN 6000.00
       END,
       bp.amcosversionid
FROM crunch.costs_awo bp
JOIN lookup.costelement ce
     ON ce.payplan = 'AWO'
    AND ce.costelementname IN ('Basic Allowance for Subsistence', 'Incentive and Special Pays',
                               'Retired Pay Accrual', 'Medicare-Eligible Retiree Health', 'Permanent Change of Station')
WHERE bp.costelementid = (SELECT costelementid FROM lookup.costelement WHERE payplan = 'AWO' AND costelementname = 'Basic Pay')
  AND NOT EXISTS (
        SELECT 1 FROM crunch.costs_awo x
        WHERE x.costelementid = ce.costelementid AND x.branch = bp.branch AND x.womos = bp.womos AND x.mha = bp.mha
          AND x.locationid = bp.locationid AND x.dependentstatus = bp.dependentstatus
          AND x.weaponsystemid = bp.weaponsystemid AND x.gradetype = bp.gradetype
          AND x.gradelevel = bp.gradelevel AND x.amcosversionid = bp.amcosversionid);

-- 4. Summary membership: link each AO/AWO cost element to the same cost summaries
--    (Default, Detailed, Military Composite Rate, Training/Ancillary, Weapon System
--    Manpower) as the same-named AE element. web.getcosts only returns an element that
--    is a member of the requested summary, so without this the new elements never show.
INSERT INTO lookup.costsummaryelement (summaryid, costelementid, amcosversionidstart, amcosversionidend)
SELECT ae_cse.summaryid, tgt_ce.costelementid, ae_cse.amcosversionidstart, ae_cse.amcosversionidend
FROM lookup.costelement tgt_ce
JOIN lookup.costelement ae_ce
     ON ae_ce.payplan = 'AE' AND ae_ce.costelementname = tgt_ce.costelementname
JOIN lookup.costsummaryelement ae_cse
     ON ae_cse.costelementid = ae_ce.costelementid
WHERE tgt_ce.payplan IN ('AO', 'AWO')
  AND NOT EXISTS (
        SELECT 1 FROM lookup.costsummaryelement x
        WHERE x.summaryid = ae_cse.summaryid AND x.costelementid = tgt_ce.costelementid
          AND x.amcosversionidend = ae_cse.amcosversionidend);
