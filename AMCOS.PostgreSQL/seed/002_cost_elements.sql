-- ==========================================================================
-- AMCOS seed: cost elements, summaries, and summary->element mapping
-- Representative Army composite-rate cost elements per pay-plan family.
-- Idempotent: guarded on natural keys (identity ids are assigned by the DB).
-- ==========================================================================

-- --------------------------------------------------------------------------
-- Cost elements
--   model:    1 = composite/standard, 2 = location-specific
--   showorder controls display sequence within a pay plan.
-- --------------------------------------------------------------------------
INSERT INTO lookup.costelement
    (payplan, appropriationgroup, appn, costelementcategory, costelementname,
     model, locality, showorder, active, applyinflation,
     islocationspecific, amcosversionidstart, amcosversionidend)
SELECT v.payplan, v.appropriationgroup, v.appn, v.costelementcategory, v.costelementname,
       v.model, v.locality, v.showorder, TRUE, v.applyinflation,
       v.islocationspecific, 1, 999999
FROM (VALUES
    -- Military (AE/AO/AWO share the same composite military pay elements)
    ('AE', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Pay',                     1, FALSE, 10, TRUE,  FALSE),
    ('AE', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Allowance for Housing',   1, TRUE,  20, TRUE,  TRUE),
    ('AE', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Allowance for Subsistence',1, FALSE, 30, TRUE,  FALSE),
    ('AE', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Incentive and Special Pays',    1, FALSE, 40, TRUE,  FALSE),
    ('AE', 'Military Benefits','MILPERS', 'Benefits',           'Retired Pay Accrual',           1, FALSE, 50, TRUE,  FALSE),
    ('AE', 'Military Benefits','MILPERS', 'Benefits',           'Medicare-Eligible Retiree Health',1, FALSE, 60, TRUE,  FALSE),
    ('AE', 'Training',         'O&M',     'Training',           'Permanent Change of Station',   1, FALSE, 70, TRUE,  FALSE),
    ('AO', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Pay',                     1, FALSE, 10, TRUE,  FALSE),
    ('AO', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Allowance for Housing',   1, TRUE,  20, TRUE,  TRUE),
    ('AO', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Allowance for Subsistence',1, FALSE, 30, TRUE,  FALSE),
    ('AO', 'Military Benefits','MILPERS', 'Benefits',           'Retired Pay Accrual',           1, FALSE, 50, TRUE,  FALSE),
    ('AWO', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Pay',                     1, FALSE, 10, TRUE,  FALSE),
    ('AWO', 'Military Pay',     'MILPERS', 'Pay and Allowances', 'Basic Allowance for Housing',   1, TRUE,  20, TRUE,  TRUE),
    -- Civilian (GS)
    ('GS', 'Civilian Pay',     'O&M',     'Pay',                'Base Salary',                   1, FALSE, 10, FALSE, FALSE),
    ('GS', 'Civilian Pay',     'O&M',     'Pay',                'Locality Pay',                  1, TRUE,  20, TRUE,  TRUE),
    ('GS', 'Civilian Benefits','O&M',     'Benefits',           'Civilian Benefits (Acc Cost)',  1, FALSE, 30, FALSE, FALSE),
    ('GS', 'Civilian Benefits','O&M',     'Benefits',           'Retirement (FERS/CSRS)',        1, FALSE, 40, FALSE, FALSE),
    ('GS', 'Civilian Benefits','O&M',     'Benefits',           'TSP Agency Contribution',       1, FALSE, 50, FALSE, FALSE),
    ('GS', 'Civilian Benefits','O&M',     'Benefits',           'FEHB (Health Insurance)',       1, FALSE, 60, FALSE, FALSE),
    -- Wage Grade
    ('WG', 'Civilian Pay',     'O&M',     'Pay',                'Wage Grade Base Pay',           1, TRUE,  10, TRUE,  TRUE),
    ('WG', 'Civilian Benefits','O&M',     'Benefits',           'Civilian Benefits (Acc Cost)',  1, FALSE, 20, FALSE, FALSE)
) AS v(payplan, appropriationgroup, appn, costelementcategory, costelementname,
       model, locality, showorder, applyinflation, islocationspecific)
WHERE NOT EXISTS (
    SELECT 1 FROM lookup.costelement ce
    WHERE ce.payplan = v.payplan
      AND ce.costelementname = v.costelementname
      AND ce.amcosversionidend = 999999
);

-- --------------------------------------------------------------------------
-- Cost summaries (top-level rollups per pay plan)
-- --------------------------------------------------------------------------
INSERT INTO lookup.costsummary (payplan, name, amcosversionidstart, amcosversionidend)
SELECT v.payplan, v.name, 1, 999999
FROM (VALUES
    ('AE', 'Military Composite Rate'),
    ('AO', 'Military Composite Rate'),
    ('AWO', 'Military Composite Rate'),
    ('GS', 'Civilian Composite Rate'),
    ('WG', 'Wage Grade Composite Rate')
) AS v(payplan, name)
WHERE NOT EXISTS (
    SELECT 1 FROM lookup.costsummary cs
    WHERE cs.payplan = v.payplan
      AND cs.name = v.name
      AND cs.amcosversionidend = 999999
);

-- --------------------------------------------------------------------------
-- Summary -> element membership
--   Maps every active cost element into its pay-plan's composite summary.
-- --------------------------------------------------------------------------
INSERT INTO lookup.costsummaryelement (summaryid, costelementid, amcosversionidstart, amcosversionidend)
SELECT cs.summaryid, ce.costelementid, 1, 999999
FROM lookup.costelement ce
JOIN lookup.costsummary cs
  ON cs.payplan = ce.payplan
 AND cs.amcosversionidend = 999999
WHERE ce.amcosversionidend = 999999
  AND NOT EXISTS (
      SELECT 1 FROM lookup.costsummaryelement cse
      WHERE cse.summaryid = cs.summaryid
        AND cse.costelementid = ce.costelementid
        AND cse.amcosversionidend = 999999
  );
