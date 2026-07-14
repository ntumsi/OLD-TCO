-- Cost-crunch PHASE 1 procedures — simple military cost elements (crunch.*).
--
-- Ports the 10 self-contained military CostOf* procedures from
-- AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/ to PostgreSQL. Each reads
-- inventory (data.KnownInventory / data.Inventory) + processed pay
-- (crunch.PayProcessed, populated by DMDCPay in Phase 2) and writes the final
-- crunch.Costs_* tables. Runs after 006c (helper functions).
--
-- These are CREATE PROCEDURE (invoked via CALL by the CrunchAll orchestrator in
-- Phase 4) and LANGUAGE plpgsql (deferred name resolution — several read
-- payschedule.* / data.* inputs that the Python ETL and Phase 2 populate).
--
-- Faithful-translation conventions (established from CostOfBasePay):
--   * p_debug boolean DEFAULT false. p_debug = true is a DRY RUN: the source
--     only performs the DELETE + INSERT writes under "IF @Debug = 0", and its
--     "IF @Debug = 1" branches are result-set dumps for interactive inspection.
--     We keep the dry-run semantics (writes guarded by "IF NOT p_debug") and
--     drop the debug SELECT dumps (no runtime effect).
--   * #temp -> CREATE TEMP TABLE (dropped explicitly at proc end / DROP IF EXISTS first).
--   * "UPDATE #t SET .. FROM #t a JOIN other b" -> "UPDATE t SET .. FROM other b
--     WHERE <join>" (PG forbids re-aliasing the UPDATE target in FROM).
--   * ISNULL->COALESCE, GETDATE()->now(), CONVERT(SMALLDATETIME,..)->::timestamp,
--     BIT->boolean, NVARCHAR->varchar, TINYINT->smallint.
--   * CostElementId per pay plan is preserved verbatim from the source.
--   * Divisions that spread a budget/pay total across an inventory count are
--     wrapped in NULLIF(denominator, 0) — a documented, behavior-preserving
--     safeguard (identical result when the denominator is non-zero; yields NULL
--     instead of a divide-by-zero error on empty subgroups). The T-SQL source
--     relied on the data never having a zero denominator.

------------------------------------------------------------------------------
-- crunch.CostOfBasePay  (CE ids: AE 1, AO 128, AWO 204, NE 289, NO 359,
--                        NWO 413, RE 453, RO 523, RWO 577)
-- Annualized military base pay, inventory-weighted at grade/subgroup.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofbasepay(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime    timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_activedays    integer;
    v_monthsinayear integer := 12;
    v_daysinamonth  integer := 30;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    v_activedays := crunch.getsinglevalue('AA', 'activedays', p_amcosversionid);

    DROP TABLE IF EXISTS basepaywyos;
    CREATE TEMP TABLE basepaywyos (
        payplan              varchar(3),
        gradelevel           integer,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        yos                  integer,
        inventory            integer,
        pay                  numeric(18, 2),
        amcosversionid       integer
    );

    INSERT INTO basepaywyos
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yos, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yos,
           SUM(inventory) AS inventory, amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yos, amcosversionid;

    -- bring in pay by YOS (active + NG/R drill rate, matched on pay plan)
    UPDATE basepaywyos t
    SET pay = b.rate
    FROM "PaySchedule".payschedule_military b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel
      AND t.yos = b.yos
      AND b.amcosversionid = t.amcosversionid;

    -- active pay is monthly -> annualize to 12 months
    UPDATE basepaywyos
    SET pay = pay * v_monthsinayear
    WHERE payplan IN ('AO', 'AE', 'AWO');

    -- NG/R: annualize drill pay for 12 months, then add ~2 weeks of active pay
    -- (active rate matched on grade type/level/yos to the AE/AO/AWO schedule)
    UPDATE basepaywyos t
    SET pay = (t.pay * v_monthsinayear) + (b.rate * v_activedays / v_daysinamonth)
    FROM "PaySchedule".payschedule_military b
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND t.yos = b.yos
      AND b.amcosversionid = t.amcosversionid
      AND t.payplan IN ('NO', 'NE', 'NWO', 'RE', 'RO', 'RWO')
      AND b.payplan IN ('AE', 'AO', 'AWO');

    -- weight pay by inventory, rolled up to grade/subgroup
    DROP TABLE IF EXISTS weightedbasepay;
    CREATE TEMP TABLE weightedbasepay (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        pay                  numeric(18, 2)
    );

    INSERT INTO weightedbasepay
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, pay)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
           SUM(inventory * pay) / NULLIF(SUM(inventory), 0)
    FROM basepaywyos
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode;

    -- invalid subgroup rows can't be inserted
    DELETE FROM weightedbasepay WHERE categorysubgroupcode = 'ZZZZ';

    IF NOT p_debug THEN
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (1)   AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (128) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (204) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne  WHERE costelementid IN (289) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no  WHERE costelementid IN (359) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo WHERE costelementid IN (413) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re  WHERE costelementid IN (453) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro  WHERE costelementid IN (523) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo WHERE costelementid IN (577) AND amcosversionid = p_amcosversionid;

        -- A-series tables carry locationid/mha/dependentstatus (mha/dependentstatus default '-1')
        INSERT INTO crunch.costs_ae (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 1, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid, -1
        FROM weightedbasepay WHERE payplan = 'AE';

        INSERT INTO crunch.costs_ao (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 128, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid, -1
        FROM weightedbasepay WHERE payplan = 'AO';

        INSERT INTO crunch.costs_awo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 204, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid, -1
        FROM weightedbasepay WHERE payplan = 'AWO';

        -- N/R-series tables have no locationid/mha/dependentstatus columns
        INSERT INTO crunch.costs_ne (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 289, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NE';

        INSERT INTO crunch.costs_no (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 359, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NO';

        INSERT INTO crunch.costs_nwo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 413, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NWO';

        INSERT INTO crunch.costs_re (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 453, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RE';

        INSERT INTO crunch.costs_ro (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 523, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RO';

        INSERT INTO crunch.costs_rwo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 577, gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RWO';
    END IF;

    DROP TABLE IF EXISTS basepaywyos;
    DROP TABLE IF EXISTS weightedbasepay;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfMisc  (must run AFTER Clothing + FICA — the "Total" element sums
--   them). AE: misc 9, total 10 (clothing 7 + fica 8 + misc);
--   AO: misc 144, total 145 (clothing 4215 + fica 143 + misc);
--   AWO: misc 218, total 219 (clothing 4216 + fica 217 + misc, on AO's budget).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofmisc(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime      timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_ao_misc_budget  numeric(20, 2);
    v_ae_misc_budget  numeric(20, 2);
    v_amt_ao_awo_misc numeric(20, 2);
    v_amt_ae_misc     numeric(20, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS inv_misc;
    CREATE TEMP TABLE inv_misc (
        payplan varchar(3), gradelevel smallint, categorygroupcode varchar(2),
        categorysubgroupcode varchar(4), gradetype varchar(3), inventory integer, amcosversionid integer
    );
    INSERT INTO inv_misc (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, SUM(inventory), amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO') AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid;

    v_ao_misc_budget := crunch.getarmybudgetsinglevalue('AO_Misc', 'MPA', 'Avg', p_amcosversionid);
    v_ae_misc_budget := crunch.getarmybudgetsinglevalue('AE_Misc', 'MPA', 'Avg', p_amcosversionid);

    -- AWO has no budget of its own; it shares AO's per-capita amount
    SELECT v_ao_misc_budget / NULLIF(SUM(inventory), 0) INTO v_amt_ao_awo_misc FROM inv_misc WHERE payplan IN ('AO', 'AWO');
    SELECT v_ae_misc_budget / NULLIF(SUM(inventory), 0) INTO v_amt_ae_misc     FROM inv_misc WHERE payplan = 'AE';

    IF NOT p_debug THEN
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (9, 10)    AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (144, 145) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (218, 219) AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_ae (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 9, gradetype, gradelevel, -1, v_amt_ae_misc, v_crunchtime, p_amcosversionid, -1
        FROM inv_misc WHERE payplan = 'AE'
        UNION
        SELECT payplan, cmf, mos, 10, gradetype, gradelevel, -1, SUM(amount) + v_amt_ae_misc, v_crunchtime, p_amcosversionid, -1
        FROM crunch.costs_ae
        WHERE payplan = 'AE' AND amcosversionid = p_amcosversionid AND costelementid IN (7, 8)
        GROUP BY payplan, cmf, mos, gradetype, gradelevel;

        INSERT INTO crunch.costs_ao (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 144, gradetype, gradelevel, -1, v_amt_ao_awo_misc, v_crunchtime, p_amcosversionid, -1
        FROM inv_misc WHERE payplan = 'AO'
        UNION
        SELECT payplan, cmf, aoc, 145, gradetype, gradelevel, -1, SUM(amount) + v_amt_ao_awo_misc, v_crunchtime, p_amcosversionid, -1
        FROM crunch.costs_ao
        WHERE payplan = 'AO' AND amcosversionid = p_amcosversionid AND costelementid IN (4215, 143)
        GROUP BY payplan, cmf, aoc, gradetype, gradelevel;

        INSERT INTO crunch.costs_awo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 218, gradetype, gradelevel, -1, v_amt_ao_awo_misc, v_crunchtime, p_amcosversionid, -1
        FROM inv_misc WHERE payplan = 'AWO'
        UNION
        SELECT payplan, branch, womos, 219, gradetype, gradelevel, -1, SUM(amount) + v_amt_ao_awo_misc, v_crunchtime, p_amcosversionid, -1
        FROM crunch.costs_awo
        WHERE payplan = 'AWO' AND amcosversionid = p_amcosversionid AND costelementid IN (4216, 217)
        GROUP BY payplan, branch, womos, gradetype, gradelevel;
    END IF;

    DROP TABLE IF EXISTS inv_misc;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfSeparationPay  (active only: AE/AO/AWO)
--   Voluntary sep+leave, involuntary sep, and their total, spread across
--   inventory. CE ids  AE: vol 44, invol 46, total 45;
--   AO: vol 153, invol 155, total 154; AWO: vol 227, invol 229, total 228.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofseparationpay(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime          timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_e_vol_sep_budget    numeric;
    v_o_wo_vol_sep_budget numeric;
    v_e_invol_sep_budget  numeric;
    v_o_wo_invol_sep_budget numeric;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS sepcalc;
    CREATE TEMP TABLE sepcalc (
        payplan varchar(3), gradelevel smallint, gradetype varchar(3),
        pp_gl_inv integer, o_e_inv integer, amcosversionid integer,
        budget_vol_sep numeric(15, 2), budget_invol_sep numeric(15, 2),
        gl_budget_leave numeric(15, 2), final_vol_sep_leave numeric(15, 2), final_invol_sep numeric(15, 2)
    );

    INSERT INTO sepcalc (payplan, gradelevel, gradetype, pp_gl_inv, amcosversionid)
    SELECT payplan, gradelevel, gradetype, SUM(inventory), amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO') AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, amcosversionid;

    -- officer/warrant share a combined inventory base; enlisted their own
    UPDATE sepcalc SET o_e_inv = (
        SELECT SUM(inventory) FROM data.knowninventory
        WHERE payplan IN ('AO', 'AWO') AND amcosversionid = p_amcosversionid)
    WHERE gradetype IN ('W', 'O');

    UPDATE sepcalc SET o_e_inv = (
        SELECT SUM(inventory) FROM data.knowninventory
        WHERE payplan = 'AE' AND amcosversionid = p_amcosversionid)
    WHERE gradetype = 'E';

    -- grade-level terminal-leave budgets
    UPDATE sepcalc t
    SET gl_budget_leave = b.amount
    FROM dataload.armybudgetmanualvalues b
    WHERE t.gradelevel = b.gradelevel
      AND t.gradetype = b.gradetype
      AND b.amcosversionid = p_amcosversionid
      AND b.paytype IN ('Enlisted_Terminal_Leave', 'Officer_Warrant_Terminal_Leave');

    v_e_vol_sep_budget      := crunch.getarmybudgetsinglevalue('Enlisted_Voluntary_Separation', 'MPA', 'avg', p_amcosversionid);
    v_o_wo_vol_sep_budget   := crunch.getarmybudgetsinglevalue('Officer_Warrant_Voluntary_Separation', 'MPA', 'avg', p_amcosversionid);
    v_e_invol_sep_budget    := crunch.getarmybudgetsinglevalue('Enlisted_Involuntary_Separation', 'MPA', 'avg', p_amcosversionid);
    v_o_wo_invol_sep_budget := crunch.getarmybudgetsinglevalue('Officer_Warrant_Involuntary_Separation', 'MPA', 'avg', p_amcosversionid);

    UPDATE sepcalc SET budget_vol_sep   = v_e_vol_sep_budget      WHERE payplan = 'AE';
    UPDATE sepcalc SET budget_vol_sep   = v_o_wo_vol_sep_budget   WHERE payplan IN ('AO', 'AWO');
    UPDATE sepcalc SET budget_invol_sep = v_e_invol_sep_budget    WHERE payplan = 'AE';
    UPDATE sepcalc SET budget_invol_sep = v_o_wo_invol_sep_budget WHERE payplan IN ('AO', 'AWO');

    UPDATE sepcalc SET final_vol_sep_leave = (budget_vol_sep / NULLIF(o_e_inv, 0)) + (gl_budget_leave / NULLIF(pp_gl_inv, 0));
    UPDATE sepcalc SET final_invol_sep     = (budget_invol_sep / NULLIF(o_e_inv, 0));

    DROP TABLE IF EXISTS finalcosts;
    CREATE TEMP TABLE finalcosts (
        payplan varchar(3), gradelevel smallint, categorygroupcode varchar(3),
        categorysubgroupcode varchar(4), gradetype varchar(3), inventory integer, amcosversionid integer,
        final_vol_sep_leave numeric(15, 2), final_invol_sep numeric(15, 2)
    );

    INSERT INTO finalcosts (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, SUM(inventory), amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO') AND amcosversionid = p_amcosversionid
    GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradelevel, gradetype, amcosversionid;

    UPDATE finalcosts t
    SET final_vol_sep_leave = b.final_vol_sep_leave,
        final_invol_sep     = b.final_invol_sep
    FROM sepcalc b
    WHERE t.payplan = b.payplan AND t.gradelevel = b.gradelevel;

    IF NOT p_debug THEN
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (44, 46, 45)    AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (154, 155, 153) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (227, 229, 228) AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_ae (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 44, gradetype, gradelevel, -1, final_vol_sep_leave, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 46, gradetype, gradelevel, -1, final_invol_sep, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 45, gradetype, gradelevel, -1, final_invol_sep + final_vol_sep_leave, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AE';

        INSERT INTO crunch.costs_ao (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 153, gradetype, gradelevel, -1, final_vol_sep_leave, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 155, gradetype, gradelevel, -1, final_invol_sep, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 154, gradetype, gradelevel, -1, final_invol_sep + final_vol_sep_leave, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AO';

        INSERT INTO crunch.costs_awo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 227, gradetype, gradelevel, -1, final_vol_sep_leave, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 229, gradetype, gradelevel, -1, final_invol_sep, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 228, gradetype, gradelevel, -1, final_invol_sep + final_vol_sep_leave, v_crunchtime, p_amcosversionid, -1 FROM finalcosts WHERE payplan = 'AWO';
    END IF;

    DROP TABLE IF EXISTS sepcalc;
    DROP TABLE IF EXISTS finalcosts;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfPCS  (PCS move costs, active only: AE / AO / AWO)
--   Per-capita move cost = Army-budget move dollars / summed KnownInventory.
--   CE ids  AE: train 16, rot 14, sep 15, org 4217, oper 13, total 17;
--           AO: train 149, rot 147, sep 148, org 4218, oper 146, total 150;
--           AWO: train 223, rot 221, sep 222, org 4219, oper 220, total 224.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofpcs(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime  timestamp := COALESCE(p_crunchtime, now()::timestamp);

    v_ae_pb_inv     integer;
    v_ao_awo_pb_inv integer;

    v_ae_training_move       double precision;
    v_ae_rotational_move     double precision;
    v_ae_separation_move     double precision;
    v_ae_organizational_move double precision;
    v_ae_operational_move    double precision;
    v_ae_pcs_total           double precision;

    v_ao_awo_training_move       double precision;
    v_ao_awo_rotational_move     double precision;
    v_ao_awo_separation_move     double precision;
    v_ao_awo_organizational_move double precision;
    v_ao_awo_operational_move    double precision;
    v_ao_awo_pcs_total           double precision;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS inventory;
    CREATE TEMP TABLE inventory (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        inventory            integer,
        amcosversionid       integer
    );

    INSERT INTO inventory
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
           SUM(inventory) AS inventory, amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid;

    -- source seeds these from budget avg-end-strength then overrides with the
    -- summed KnownInventory count actually used in the divisions below
    v_ae_pb_inv := crunch.getarmybudgetsinglevalue('Avg_AE_End_Strength', 'MPA', 'avg', p_amcosversionid);
    v_ao_awo_pb_inv := crunch.getarmybudgetsinglevalue('Avg_AO_End_Strength', 'MPA', 'avg', p_amcosversionid)
                     + crunch.getarmybudgetsinglevalue('Avg_AWO_End_Strength', 'MPA', 'avg', p_amcosversionid);

    SELECT SUM(inventory) INTO v_ae_pb_inv     FROM inventory WHERE payplan = 'AE';
    SELECT SUM(inventory) INTO v_ao_awo_pb_inv FROM inventory WHERE payplan IN ('AO', 'AWO');

    v_ae_training_move       := crunch.getarmybudgetsinglevalue('Enlisted_PCS_Training_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ae_pb_inv, 0);
    v_ae_rotational_move     := crunch.getarmybudgetsinglevalue('Enlisted_PCS_Rotational_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ae_pb_inv, 0);
    v_ae_separation_move     := crunch.getarmybudgetsinglevalue('Enlisted_PCS_Separation_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ae_pb_inv, 0);
    v_ae_organizational_move := crunch.getarmybudgetsinglevalue('Enlisted_PCS_Unit_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ae_pb_inv, 0);
    v_ae_operational_move    := crunch.getarmybudgetsinglevalue('Enlisted_PCS_Operational_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ae_pb_inv, 0);
    v_ae_pcs_total           := v_ae_training_move + v_ae_rotational_move + v_ae_separation_move
                              + v_ae_organizational_move + v_ae_operational_move;

    v_ao_awo_training_move       := crunch.getarmybudgetsinglevalue('Officer_PCS_Training_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ao_awo_pb_inv, 0);
    v_ao_awo_rotational_move     := crunch.getarmybudgetsinglevalue('Officer_PCS_Rotational_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ao_awo_pb_inv, 0);
    v_ao_awo_separation_move     := crunch.getarmybudgetsinglevalue('Officer_PCS_Separation_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ao_awo_pb_inv, 0);
    v_ao_awo_organizational_move := crunch.getarmybudgetsinglevalue('Officer_PCS_Unit_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ao_awo_pb_inv, 0);
    v_ao_awo_operational_move    := crunch.getarmybudgetsinglevalue('Officer_PCS_Operational_Move_Budget', 'MPA', 'avg', p_amcosversionid) / NULLIF(v_ao_awo_pb_inv, 0);
    v_ao_awo_pcs_total           := v_ao_awo_training_move + v_ao_awo_rotational_move + v_ao_awo_separation_move
                                  + v_ao_awo_organizational_move + v_ao_awo_operational_move;

    IF NOT p_debug THEN
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (14, 15, 16, 12, 13, 17, 4217) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (146, 147, 148, 149, 150, 4218) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (221, 222, 223, 220, 224, 4219) AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 16, gradetype, gradelevel, -1, v_ae_training_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 14, gradetype, gradelevel, -1, v_ae_rotational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 15, gradetype, gradelevel, -1, v_ae_separation_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4217, gradetype, gradelevel, -1, v_ae_organizational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 13, gradetype, gradelevel, -1, v_ae_operational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 17, gradetype, gradelevel, -1, v_ae_pcs_total, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AE';

        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 149, gradetype, gradelevel, -1, v_ao_awo_training_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 147, gradetype, gradelevel, -1, v_ao_awo_rotational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 148, gradetype, gradelevel, -1, v_ao_awo_separation_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4218, gradetype, gradelevel, -1, v_ao_awo_organizational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 146, gradetype, gradelevel, -1, v_ao_awo_operational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 150, gradetype, gradelevel, -1, v_ao_awo_pcs_total, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AO';

        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 223, gradetype, gradelevel, -1, v_ao_awo_training_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 221, gradetype, gradelevel, -1, v_ao_awo_rotational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 222, gradetype, gradelevel, -1, v_ao_awo_separation_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4219, gradetype, gradelevel, -1, v_ao_awo_organizational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 220, gradetype, gradelevel, -1, v_ao_awo_operational_move, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 224, gradetype, gradelevel, -1, v_ao_awo_pcs_total, v_crunchtime, p_amcosversionid, -1 FROM inventory WHERE payplan = 'AWO';
    END IF;

    DROP TABLE IF EXISTS inventory;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfFICAandRetiredPay
--   Cost of Military FICA (employer share: Social Security + Medicare) and
--   Retired Pay accrual, derived from the base-pay cost elements this crunch
--   already computed. FICA/retired-pay CE ids per pay plan:
--     AE  fica 8,   retired 32    NE  fica 290, retired 291   RE fica 454, retired 455
--     AO  fica 143, retired 151   NO  fica 360, retired 361   RO fica 524, retired 525
--     AWO fica 217, retired 225   NWO fica 414, retired 415   RWO fica 578, retired 579
--   Base-pay source CE ids read from data.Costs: 1,128,204,289,359,413,453,523,577.
--   (Medicare employee-side portion intentionally omitted, matching the source.)
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofficaandretiredpay(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime                 timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_percentsocialsecurity      numeric(26, 6);
    v_percentmedicare            numeric(26, 6);
    v_max_wage_ssw               numeric(26, 6);
    v_active_retired_pay_accrual numeric(26, 6);
    v_ngr_retired_pay_accrual    numeric(26, 6);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    v_percentsocialsecurity := crunch.getsinglevalue('AA', 'PercentSocialSecurity', p_amcosversionid);
    v_percentmedicare       := crunch.getsinglevalue('AA', 'percentMedicare', p_amcosversionid);
    v_max_wage_ssw          := crunch.getsinglevalue('AA', 'Max_Wage_SSW', p_amcosversionid);

    -- base pay is weighted at the grade level and subgroup; we weight and roll it up to that level
    DROP TABLE IF EXISTS weightedbasepay;
    CREATE TEMP TABLE weightedbasepay (
        costelementid        integer,
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        pay                  numeric(17, 2),
        socialsecurity_amt   numeric(17, 2),
        medicare_amt         numeric(17, 2),
        total_fica           numeric(17, 2),
        retiredpay           numeric(17, 2)
    );

    -- get all the military base pay elements so we can quickly calculate
    INSERT INTO weightedbasepay
        (costelementid, payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, pay)
    SELECT costelementid, payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amount
    FROM data.costs
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (1, 128, 204, 289, 359, 413, 453, 523, 577);

    -- social security is capped, so account for that with a case statement
    UPDATE weightedbasepay
    SET socialsecurity_amt = CASE
                                 WHEN pay < v_max_wage_ssw THEN pay * v_percentsocialsecurity
                                 ELSE v_max_wage_ssw * v_percentsocialsecurity
                             END;

    -- medicare amount has no cap, so that calculation is simple
    UPDATE weightedbasepay
    SET medicare_amt = pay * v_percentmedicare;

    -- total is the sum of the two
    UPDATE weightedbasepay
    SET total_fica = COALESCE(medicare_amt, 0) + COALESCE(socialsecurity_amt, 0);

    -- calculate retired pay based on base pay
    v_active_retired_pay_accrual := crunch.getsinglevalue('AA', 'Retired_Pay_Accrual', p_amcosversionid);
    v_ngr_retired_pay_accrual    := crunch.getsinglevalue('AA2', 'Retired_Pay_Accrual', p_amcosversionid);

    UPDATE weightedbasepay
    SET retiredpay = pay * v_active_retired_pay_accrual
    WHERE payplan IN ('AO', 'AE', 'AWO');

    UPDATE weightedbasepay
    SET retiredpay = pay * v_ngr_retired_pay_accrual
    WHERE payplan IN ('RO', 'RE', 'RWO', 'NE', 'NO', 'NWO');

    IF NOT p_debug THEN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (151, 143) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (32, 8)    AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (225, 217) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne  WHERE costelementid IN (291, 290) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no  WHERE costelementid IN (361, 360) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo WHERE costelementid IN (415, 414) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re  WHERE costelementid IN (455, 454) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro  WHERE costelementid IN (525, 524) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo WHERE costelementid IN (579, 578) AND amcosversionid = p_amcosversionid;

        -- AE (A-series carries mha/locationid; source sets mha '-1', locationid -1)
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 8, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid, '-1', -1
        FROM weightedbasepay WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 32, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid, '-1', -1
        FROM weightedbasepay WHERE payplan = 'AE';

        -- NE (N/R-series has no mha/locationid columns)
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 290, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 291, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NE';

        -- RE
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 454, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 455, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RE';

        -- AO (A-series carries mha/locationid)
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 143, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid, '-1', -1
        FROM weightedbasepay WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 151, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid, '-1', -1
        FROM weightedbasepay WHERE payplan = 'AO';

        -- RO
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 524, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 525, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RO';

        -- NO
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 360, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 361, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NO';

        -- AWO (WO-series uses branch/womos; A-series carries mha/locationid)
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 217, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid, '-1', -1
        FROM weightedbasepay WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 225, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid, '-1', -1
        FROM weightedbasepay WHERE payplan = 'AWO';

        -- RWO
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 578, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 579, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'RWO';

        -- NWO
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 414, gradetype, gradelevel, -1,
               COALESCE(total_fica, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, 415, gradetype, gradelevel, -1,
               COALESCE(retiredpay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay WHERE payplan = 'NWO';
    END IF;

    DROP TABLE IF EXISTS weightedbasepay;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfClothing  (CE ids: AE 7, AO 4215, AWO 4216, NE 327, NO 398,
--                         NWO 438, RE 491, RO 562, RWO 602)
-- In-kind (recruit/YOS0 issue) + in-cash (DMDC uniform allowance) clothing cost,
-- averaged per grade and spread to subgroup via inventory.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofclothing(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime    timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_ae_pb         numeric(17, 2);
    v_ao_awo_pb     numeric(17, 2);
    v_ne_pb         numeric(17, 2);
    v_no_nwo_pb     numeric(17, 2);
    v_re_pb         numeric(17, 2);
    v_ro_rwo_pb     numeric(17, 2);
    v_ae_yos0_cost  numeric(17, 2);
    v_re_yos0_cost  numeric(17, 2);
    v_ne_yos0_cost  numeric(17, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS tempdmdcpay;
    CREATE TEMP TABLE tempdmdcpay (
        paytype        varchar(50),
        payplan        varchar(3),
        gradelevel     smallint,
        pay            numeric(17, 2),
        amcosversionid integer
    );

    INSERT INTO tempdmdcpay (paytype, payplan, amcosversionid, gradelevel, pay)
    SELECT paytype, payplan, p_amcosversionid, gradelevel, SUM(totalpayamount) AS pay
    FROM "DMDC".pay
    WHERE paytype = 'Uniform/Equipment Allowance'
      AND amcosversionid = p_amcosversionid
    GROUP BY paytype, payplan, gradelevel
    ORDER BY payplan, gradelevel;

    DROP TABLE IF EXISTS tempclothingcalc;
    CREATE TEMP TABLE tempclothingcalc (
        payplan        varchar(3),
        gradelevel     smallint,
        inventory      integer,
        amcosversionid integer,
        yos0           integer,
        inkind         numeric(17, 2),
        incash         numeric(17, 2),
        total          numeric(17, 2)
    );

    INSERT INTO tempclothingcalc (payplan, gradelevel, amcosversionid, inventory)
    SELECT payplan, gradelevel, amcosversionid, SUM(inventory) AS inventory
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, amcosversionid;

    -- now we add in the yos 0 folks who are our new recruits getting in-kind clothing.
    -- Source is a LEFT JOIN update (unmatched -> ISNULL(..,0)); PG UPDATE..FROM would
    -- drop unmatched rows, so this is rewritten as a correlated subquery that preserves
    -- the "0 when no YOS-0 inventory" semantics for every row. Join is payplan+gradelevel
    -- only, exactly as the source ON clause.
    UPDATE tempclothingcalc t
    SET yos0 = COALESCE((
        SELECT SUM(ki.inventory)
        FROM data.knowninventory ki
        WHERE ki.payplan IN ('AO', 'AE', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
          AND ki.amcosversionid = p_amcosversionid
          AND ki.yos = 0
          AND ki.payplan = t.payplan
          AND ki.gradelevel = t.gradelevel
    ), 0);

    -- the following gets the budget amounts for every associated pay plan
    v_ae_pb     := crunch.getarmybudgetsinglevalue('AE_Clothing', 'MPA', 'Avg', p_amcosversionid);
    v_ao_awo_pb := crunch.getarmybudgetsinglevalue('AO_AWO_Clothing', '', 'Avg', p_amcosversionid);
    v_ne_pb     := crunch.getarmybudgetsinglevalue('NE_Clothing', 'NGPA', 'Avg', p_amcosversionid);
    v_no_nwo_pb := crunch.getarmybudgetsinglevalue('NO_NWO_Clothing', 'NGPA', 'Avg', p_amcosversionid);
    v_re_pb     := crunch.getarmybudgetsinglevalue('RE_Clothing', 'RPA', 'Avg', p_amcosversionid);
    v_ro_rwo_pb := crunch.getarmybudgetsinglevalue('RO_RWO_Clothing', 'RPA', 'Avg', p_amcosversionid);

    -- average cost per recruit (enlisted only); YOS 0 represents a recruit.
    -- cost of in-kind is the PB minus the cash paid from DMDC, per YOS-0 head.
    v_ae_yos0_cost := (v_ae_pb - (SELECT SUM(pay) FROM tempdmdcpay WHERE payplan = 'AE'))
                      / NULLIF((SELECT SUM(yos0) FROM tempclothingcalc WHERE payplan = 'AE'), 0);
    v_re_yos0_cost := (v_re_pb - (SELECT SUM(pay) FROM tempdmdcpay WHERE payplan = 'RE'))
                      / NULLIF((SELECT SUM(yos0) FROM tempclothingcalc WHERE payplan = 'RE'), 0);
    v_ne_yos0_cost := (v_ne_pb - (SELECT SUM(pay) FROM tempdmdcpay WHERE payplan = 'NE'))
                      / NULLIF((SELECT SUM(yos0) FROM tempclothingcalc WHERE payplan = 'NE'), 0);

    -- in-kind = average YOS-0 cost * number of them in the grade / total inventory in that grade
    UPDATE tempclothingcalc SET inkind = (v_ae_yos0_cost * yos0) / NULLIF(inventory, 0) WHERE payplan = 'AE';
    UPDATE tempclothingcalc SET inkind = (v_re_yos0_cost * yos0) / NULLIF(inventory, 0) WHERE payplan = 'RE';
    UPDATE tempclothingcalc SET inkind = (v_ne_yos0_cost * yos0) / NULLIF(inventory, 0) WHERE payplan = 'NE';

    -- in-cash comes straight from (averaged) DMDC pay, spread over inventory.
    -- UPDATE..FROM: target re-aliased as t; joined table only in FROM (PG-legal).
    UPDATE tempclothingcalc t
    SET incash = b.pay / NULLIF(t.inventory, 0)
    FROM tempdmdcpay b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- total is the sum of the in-cash and in-kind values
    UPDATE tempclothingcalc SET total = COALESCE(inkind, 0) + COALESCE(incash, 0);

    IF NOT p_debug THEN
        -- clear out the existing cost rows for the CE IDs we are about to insert
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (7)    AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (4215) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (4216) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne  WHERE costelementid IN (327)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no  WHERE costelementid IN (398)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo WHERE costelementid IN (438)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re  WHERE costelementid IN (491)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro  WHERE costelementid IN (562)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo WHERE costelementid IN (602)  AND amcosversionid = p_amcosversionid;

        -- Insert average cost elements. Calculated at grade level but stored at the
        -- subgroup level, so join grade totals back to the distinct inventory subgroups.
        -- A-series tables carry locationid (mha/dependentstatus default '-1').

        --AE
        INSERT INTO crunch.costs_ae (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 7, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid, -1
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'AE' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --NE
        INSERT INTO crunch.costs_ne (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 327, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'NE' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --RE
        INSERT INTO crunch.costs_re (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 491, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'RE' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --AO
        INSERT INTO crunch.costs_ao (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 4215, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid, -1
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'AO' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --RO
        INSERT INTO crunch.costs_ro (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 562, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'RO' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --NO
        INSERT INTO crunch.costs_no (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 398, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'NO' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --AWO
        INSERT INTO crunch.costs_awo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 4216, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid, -1
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'AWO' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --RWO
        INSERT INTO crunch.costs_rwo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 602, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'RWO' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;

        --NWO
        INSERT INTO crunch.costs_nwo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode, 438, inv.gradetype, inv.gradelevel, -1,
               COALESCE(tcc.total, 0), v_crunchtime, p_amcosversionid
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
            FROM data.knowninventory
            WHERE payplan = 'NWO' AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) inv
        LEFT OUTER JOIN tempclothingcalc tcc
            ON inv.payplan = tcc.payplan AND inv.gradelevel = tcc.gradelevel;
    END IF;

    DROP TABLE IF EXISTS tempdmdcpay;
    DROP TABLE IF EXISTS tempclothingcalc;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfFamilySeparation  (active only: AE/AO/AWO)
--   Family Separation Allowance. DMDC pay (3-year sliding average) is used only
--   to derive each grade level's share of the MPA Family-Separation budget
--   (split Enlisted vs Officer/Warrant), which is then spread across inventory.
--   CE ids  AE: 48   AO: 157   AWO: 231
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costoffamilyseparation(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime           timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_e_fam_sep_budget     numeric;
    v_o_wo_fam_sep_budget  numeric;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- get all the military inventory at the subgroup level (active only)
    DROP TABLE IF EXISTS faminventory;
    CREATE TEMP TABLE faminventory (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        inventory            integer,
        amcosversionid       integer,
        amount               numeric(17, 2)
    );

    INSERT INTO faminventory
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
           SUM(inventory) AS inventory, amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid;

    -- DMDC family-separation pay, most recent 3 years of DMDC data (sliding average base)
    DROP TABLE IF EXISTS famseppaybyversion;
    CREATE TEMP TABLE famseppaybyversion (
        paytype        varchar,
        payplan        varchar(3),
        gradelevel     smallint,
        amount         numeric,
        amcosversionid integer
    );

    INSERT INTO famseppaybyversion
        (paytype, payplan, gradelevel, amount, amcosversionid)
    SELECT paytype, payplan, gradelevel, SUM(totalpayamount), amcosversionid
    FROM "DMDC".pay
    WHERE paytype = 'family separation allowance'
      AND payplan IN ('AO', 'AE', 'AWO')
      AND amcosversionid IN
          -- we only want the most recent 3 years of DMDC data to compute our sliding average
          (
              SELECT amcosversionid
              FROM "DMDC".pay
              WHERE amcosversionid <= p_amcosversionid
              GROUP BY amcosversionid
              ORDER BY amcosversionid DESC
              LIMIT 3
          )
    GROUP BY paytype, payplan, gradelevel, amcosversionid;

    -- average the DMDC pay across the (up to 3) versions
    DROP TABLE IF EXISTS avgfamseppay;
    CREATE TEMP TABLE avgfamseppay (
        paytype       varchar,
        payplan       varchar(3),
        gradelevel    smallint,
        gradeconformed varchar(1),
        dmdcpay       numeric,
        budgetamt     numeric(17, 2),
        percofbudget  numeric(17, 2),
        inventory     integer,
        famsepamt     numeric(17, 2)
    );

    INSERT INTO avgfamseppay
        (paytype, payplan, gradelevel, dmdcpay)
    SELECT paytype, payplan, gradelevel, AVG(amount) AS amt
    FROM famseppaybyversion
    GROUP BY paytype, payplan, gradelevel;

    -- set the gradetype: the budget is only by Enlisted (E) and Officer (W & O)
    UPDATE avgfamseppay SET gradeconformed = 'E' WHERE payplan = 'AE';
    UPDATE avgfamseppay SET gradeconformed = 'O' WHERE payplan IN ('AO', 'AWO');

    -- bring in the budget amounts which we divy across the grade levels
    v_e_fam_sep_budget    := crunch.getarmybudgetsinglevalue('Enlisted_Family_Separation', 'MPA', 'avg', p_amcosversionid);
    v_o_wo_fam_sep_budget := crunch.getarmybudgetsinglevalue('Officer_Warrant_Family_Separation', 'MPA', 'avg', p_amcosversionid);

    UPDATE avgfamseppay SET budgetamt = v_e_fam_sep_budget    WHERE payplan IN ('AE');
    UPDATE avgfamseppay SET budgetamt = v_o_wo_fam_sep_budget WHERE payplan IN ('AO', 'AWO');

    -- percentage each grade level's pay is of its conformed group's total DMDC pay,
    -- later applied to the budget (which is not broken out by grade level)
    UPDATE avgfamseppay t
    SET percofbudget = b.myperc
    FROM (
        SELECT paytype, payplan, gradeconformed, gradelevel,
               dmdcpay / SUM(dmdcpay) OVER (PARTITION BY gradeconformed) AS myperc
        FROM avgfamseppay
    ) b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- bring in inventory so we can use it to compute the average pay
    UPDATE avgfamseppay t
    SET inventory = b.myinv
    FROM (
        SELECT payplan, gradelevel, SUM(inventory) AS myinv
        FROM faminventory
        GROUP BY payplan, gradelevel
    ) b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- fam sep amount = DMDC-determined portion of the budget divided by inventory
    UPDATE avgfamseppay
    SET famsepamt = COALESCE(budgetamt * percofbudget / NULLIF(inventory, 0), 0);

    -- push the amount back onto the subgroup inventory table for an easy insert
    UPDATE faminventory t
    SET amount = COALESCE(b.famsepamt, 0)
    FROM avgfamseppay b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    IF NOT p_debug THEN
        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (48)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (157) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (231) AND amcosversionid = p_amcosversionid;

        -- AE
        INSERT INTO crunch.costs_ae (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 48, gradetype, gradelevel, -1, amount, v_crunchtime, p_amcosversionid, '-1', -1
        FROM faminventory WHERE payplan = 'AE';

        -- AO
        INSERT INTO crunch.costs_ao (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 157, gradetype, gradelevel, -1, amount, v_crunchtime, p_amcosversionid, '-1', -1
        FROM faminventory WHERE payplan = 'AO';

        -- AWO
        INSERT INTO crunch.costs_awo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 231, gradetype, gradelevel, -1, amount, v_crunchtime, p_amcosversionid, '-1', -1
        FROM faminventory WHERE payplan = 'AWO';
    END IF;

    DROP TABLE IF EXISTS faminventory;
    DROP TABLE IF EXISTS famseppaybyversion;
    DROP TABLE IF EXISTS avgfamseppay;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfBasicAllowanceForSubsistence
--   Basic Allowance for Subsistence (BAS). Writes all nine pay plans.
--   CE ids  AE 4, AO 131, AWO 207, NE 293, NO 363, NWO 417,
--           RE 457, RO 527, RWO 581.
--   Active BAS is a fixed statutory amount (DMDC/PB data irrelevant for AO/AWO);
--   AE uses a president's-budget ratio against DMDC average pay; NG/R apply the
--   legacy daily-rate * activedays methodology off the active-component cost.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofbasicallowanceforsubsistence(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime     timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_bas_ao_awo_amt numeric(18, 2);
    v_bas_ae_amt     numeric(18, 2);
    v_ao_awo_ratio   numeric(18, 2);
    v_ae_ratio       numeric(18, 2);
    v_daysinyear     integer;
    v_activedays     integer;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- ------------------------------------------------------------------
    -- raw BAS pay types straight from processed DMDC pay
    -- ------------------------------------------------------------------
    DROP TABLE IF EXISTS dmdcbas;
    CREATE TEMP TABLE dmdcbas (
        paytype              varchar(300),
        payplan              varchar(3),
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        amcosversionid       integer,
        avgannualpay         numeric(18, 2),
        avgannualpayments    numeric(18, 2)
    );

    INSERT INTO dmdcbas
        (paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
         gradelevel, amcosversionid, avgannualpay, avgannualpayments)
    SELECT paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
           gradelevel, amcosversionid, avg_annual_pay, avg_annual_payments
    FROM crunch.payprocessed
    WHERE amcosversionid = p_amcosversionid
      -- if there is no pay then don't worry about the row
      AND paytype IN ('Basic Allowance for Subsistence', 'Family Supplement Subistence Allowance');

    -- ------------------------------------------------------------------
    -- aggregate away the subgroup detail: BAS is consistent across all
    -- subgroups within a pay plan / grade level
    -- ------------------------------------------------------------------
    DROP TABLE IF EXISTS dmdcbasgradelevel;
    CREATE TEMP TABLE dmdcbasgradelevel (
        payplan        varchar(3),
        gradetype      varchar(3),
        gradelevel     smallint,
        amcosversionid integer,
        avg_annual_pay numeric(18, 2),
        costelementid  integer,
        inventory      integer,
        adj_ratio      numeric(18, 2),
        cost           numeric(18, 2)
    );

    INSERT INTO dmdcbasgradelevel
        (payplan, gradetype, gradelevel, amcosversionid, avg_annual_pay, inventory, adj_ratio, cost)
    SELECT payplan, gradetype, gradelevel, amcosversionid,
           SUM(avgannualpay) AS pay,
           0   AS inventory,
           1   AS adj_ratio,
           0.0 AS cost
    FROM dmdcbas
    GROUP BY payplan, gradetype, gradelevel, amcosversionid;

    -- inventory by pay plan / grade level
    -- (T-SQL: UPDATE ... FROM #t a JOIN (agg) b -> target un-aliased in PG)
    UPDATE dmdcbasgradelevel t
    SET inventory = b.inventory
    FROM (
        SELECT payplan, gradelevel, SUM(inventory) AS inventory
        FROM data.knowninventory
        WHERE payplan IN ('AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
          AND amcosversionid = p_amcosversionid
        GROUP BY payplan, gradelevel
    ) b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- ------------------------------------------------------------------
    -- president's-budget amounts -> adjustment ratios
    -- ------------------------------------------------------------------
    v_bas_ao_awo_amt := crunch.getarmybudgetsinglevalue('BAS_Domestic_AO_AWO', 'MPA', 'Avg', p_amcosversionid);
    v_bas_ae_amt     := crunch.getarmybudgetsinglevalue('BAS_Domestic_AE', 'MPA', 'Avg', p_amcosversionid);

    SELECT v_bas_ao_awo_amt / NULLIF(SUM(avgannualpay), 0)
      INTO v_ao_awo_ratio
    FROM dmdcbas
    WHERE payplan IN ('AO', 'AWO');

    SELECT v_bas_ae_amt / NULLIF(SUM(avgannualpay), 0)
      INTO v_ae_ratio
    FROM dmdcbas
    WHERE payplan IN ('AE');

    -- add the ratio to the table
    UPDATE dmdcbasgradelevel SET adj_ratio = v_ao_awo_ratio WHERE payplan IN ('AO', 'AWO');
    UPDATE dmdcbasgradelevel SET adj_ratio = v_ae_ratio     WHERE payplan IN ('AE');

    -- compute the adjusted-pay amount
    UPDATE dmdcbasgradelevel
    SET cost = (avg_annual_pay * adj_ratio) / NULLIF(inventory, 0);

    -- active BAS is one fixed statutory amount; DMDC/PB data is irrelevant
    UPDATE dmdcbasgradelevel
    SET cost = crunch.getsinglevalue('AA', 'BAS_O_WO', p_amcosversionid)
    WHERE payplan IN ('AO', 'AWO');

    -- ------------------------------------------------------------------
    -- NG/R legacy methodology: annual active cost / daysinyear * activedays
    -- (matched to the active component of the same grade type/level)
    -- ------------------------------------------------------------------
    v_daysinyear := crunch.getsinglevalue('AA', 'daysinyear', p_amcosversionid);
    v_activedays := crunch.getsinglevalue('AA', 'activedays', p_amcosversionid);

    -- T-SQL self-join (target a vs a snapshot of A-plan rows b). Reads only the
    -- AE/AO/AWO rows (never the rows being updated), so an un-aliased UPDATE ...
    -- FROM (subquery) b is result-equivalent.
    UPDATE dmdcbasgradelevel t
    SET cost = b.cost / v_daysinyear * v_activedays
    FROM (
        SELECT gradetype, gradelevel, cost
        FROM dmdcbasgradelevel
        WHERE payplan IN ('AWO', 'AO', 'AE')
    ) b
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND t.payplan NOT IN ('AO', 'AWO', 'AE');

    -- cost element ids per pay plan
    UPDATE dmdcbasgradelevel
    SET costelementid = CASE
                            WHEN payplan = 'AE'  THEN 4
                            WHEN payplan = 'AO'  THEN 131
                            WHEN payplan = 'AWO' THEN 207
                            WHEN payplan = 'RO'  THEN 527
                            WHEN payplan = 'RE'  THEN 457
                            WHEN payplan = 'RWO' THEN 581
                            WHEN payplan = 'NO'  THEN 363
                            WHEN payplan = 'NE'  THEN 293
                            WHEN payplan = 'NWO' THEN 417
                        END;

    -- ------------------------------------------------------------------
    -- spread the per-(payplan,gradelevel) cost across all subgroup inventory
    -- ------------------------------------------------------------------
    DROP TABLE IF EXISTS basfinal;
    CREATE TEMP TABLE basfinal (
        payplan              varchar(3),
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        cost                 numeric(18, 2),
        amcosversionid       integer,
        inventory            integer,
        costelementid        integer
    );

    INSERT INTO basfinal
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, inventory, amcosversionid)
    SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
           SUM(inventory) AS inventory, p_amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

    -- bring in the cost (same for every subgroup within a pay plan / grade level).
    -- T-SQL LEFT OUTER JOIN: unmatched rows would be set to NULL, i.e. left at
    -- their initialized NULL -> an inner-join UPDATE ... FROM is equivalent.
    UPDATE basfinal t
    SET cost = b.cost,
        costelementid = b.costelementid
    FROM dmdcbasgradelevel b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel
      AND t.gradetype = b.gradetype;

    -- high-grade officers may have no DMDC cost; fill from another row in the
    -- same pay plan (officer BAS is the same across all grade levels).
    -- T-SQL self-join over (SELECT * FROM #BASFinal); the subquery snapshot
    -- reflects pre-update state, matching the source's read of a copy.
    UPDATE basfinal t
    SET cost = b.cost,
        costelementid = b.costelementid
    FROM (SELECT * FROM basfinal) b
    WHERE t.payplan = b.payplan
      AND t.costelementid IS NULL;

    -- ------------------------------------------------------------------
    -- write out (dry run when p_debug)
    -- ------------------------------------------------------------------
    IF NOT p_debug THEN
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne  WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no  WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re  WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro  WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo WHERE costelementid IN (SELECT costelementid FROM basfinal) AND amcosversionid = p_amcosversionid;

        -- A-series tables carry mha/locationid/dependentstatus (mha & dependentstatus default '-1')
        INSERT INTO crunch.costs_ae (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid, '-1', -1
        FROM basfinal WHERE payplan = 'AE';

        INSERT INTO crunch.costs_ao (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid, '-1', -1
        FROM basfinal WHERE payplan = 'AO';

        INSERT INTO crunch.costs_awo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, mha, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid, '-1', -1
        FROM basfinal WHERE payplan = 'AWO';

        -- N/R-series tables have no mha/locationid/dependentstatus columns
        INSERT INTO crunch.costs_ne (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM basfinal WHERE payplan = 'NE';

        INSERT INTO crunch.costs_no (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM basfinal WHERE payplan = 'NO';

        INSERT INTO crunch.costs_nwo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM basfinal WHERE payplan = 'NWO';

        INSERT INTO crunch.costs_re (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM basfinal WHERE payplan = 'RE';

        INSERT INTO crunch.costs_ro (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM basfinal WHERE payplan = 'RO';

        INSERT INTO crunch.costs_rwo (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM basfinal WHERE payplan = 'RWO';
    END IF;

    DROP TABLE IF EXISTS dmdcbas;
    DROP TABLE IF EXISTS dmdcbasgradelevel;
    DROP TABLE IF EXISTS basfinal;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfSimpleCEs  (largest Phase-1 proc; consolidates many single-value
--   / simple-calc cost elements across all nine pay plans)
--
-- Active (A-series) CEs: MERHC, MWR, Medical, Discount Groceries, DoDEA,
--   Child Education, Treasury Concurrent Receipts, Treasury MERHC, Veteran Benefits.
-- NG/R (N/R-series) CEs: prorated Health Care, DHDG, Educational Benefits (GI Bill),
--   Student Loan Repayment (SLRP).
--
-- Each single-value amount is computed once, then spread to the subgroup level by
-- joining to inventory (via the inv_simple temp table). A-series tables carry
-- locationid (= -1 here) plus mha/dependentstatus defaults; N/R tables do not.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofsimpleces(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime timestamp := COALESCE(p_crunchtime, now()::timestamp);

    -- days in a year (constant) + active-duty days from the single-value store
    v_days       numeric := 365.0;
    v_activedays numeric;

    -- ### Active computed amounts ###
    v_amt_active_merhc        numeric(20, 2);
    v_amt_active_mwr          numeric(20, 2);
    v_amt_active_medical      numeric(20, 2);
    v_amt_active_groceries    numeric(20, 2);
    v_amt_active_dodea        numeric(20, 2);
    v_amt_active_childedu     numeric(20, 2);
    v_amt_active_concurrec    numeric(20, 2);
    v_amt_active_treas_merhcf numeric(20, 2);
    v_amt_active_veteran      numeric(20, 2);

    -- ### NG/R computed amounts (and their budget/endstrength inputs) ###
    v_amt_ng_r_health   numeric(20, 2);

    v_re_dhdg           numeric(20, 2);
    v_re_endstrength    numeric(20, 2);
    v_amt_re_dhdg       numeric(20, 2);

    v_ro_rwo_dhdg        numeric(20, 2);
    v_ro_rwo_endstrength numeric(20, 2);
    v_amt_ro_rwo_dhdg    numeric(20, 2);

    v_ne_dhdg           numeric(20, 2);
    v_ne_endstrength    numeric(20, 2);
    v_amt_ne_dhdg       numeric(20, 2);

    v_no_nwo_endstrength numeric(20, 2);
    v_no_nwo_dhdg        numeric(20, 2);
    v_amt_no_nwo_dhdg    numeric(20, 2);

    v_re_basic_benefit  numeric(20, 2);
    v_re_kicker         numeric(20, 2);
    v_amt_re_eduben     numeric(20, 2);

    v_ne_basic_benefit  numeric(20, 2);
    v_ne_kicker         numeric(20, 2);
    v_amt_ne_eduben     numeric(20, 2);

    v_nestudentloanrepayment numeric(20, 2);
    v_amt_ne_slrp            numeric(20, 2);

    v_restudentloanrepayment numeric(20, 2);
    v_amt_re_slrp            numeric(20, 2);

    -- ### Cost element ids (preserved verbatim from the source) ###
    -- Active
    c_ce_ae_merhc         integer := 83;
    c_ce_ao_merhc         integer := 180;
    c_ce_awo_merhc        integer := 245;
    c_ce_ae_mwr           integer := 75;
    c_ce_ao_mwr           integer := 174;
    c_ce_awo_mwr          integer := 248;
    c_ce_ae_medical       integer := 74;
    c_ce_ao_medical       integer := 173;
    c_ce_awo_medical      integer := 247;
    c_ce_ae_groceries     integer := 774;
    c_ce_ao_groceries     integer := 790;
    c_ce_awo_groceries    integer := 806;
    c_ce_ae_dodea         integer := 775;
    c_ce_ao_dodea         integer := 791;
    c_ce_awo_dodea        integer := 807;
    c_ce_ae_childedu      integer := 773;
    c_ce_ao_childedu      integer := 789;
    c_ce_awo_childedu     integer := 805;
    c_ce_ae_concurrec     integer := 777;
    c_ce_ao_concurrec     integer := 793;
    c_ce_awo_concurrec    integer := 809;
    c_ce_ae_treas_merhcf  integer := 778;
    c_ce_ao_treas_merhcf  integer := 794;
    c_ce_awo_treas_merhcf integer := 810;
    c_ce_ae_veteran       integer := 780;
    c_ce_ao_veteran       integer := 796;
    c_ce_awo_veteran      integer := 812;
    -- NG/R Health
    c_ce_ne_health   integer := 288;
    c_ce_no_health   integer := 358;
    c_ce_nwo_health  integer := 412;
    c_ce_re_health   integer := 452;
    c_ce_ro_health   integer := 522;
    c_ce_rwo_health  integer := 576;
    -- DHDG
    c_ce_re_dhdg   integer := 494;
    c_ce_ro_dhdg   integer := 563;
    c_ce_rwo_dhdg  integer := 603;
    c_ce_ne_dhdg   integer := 330;
    c_ce_no_dhdg   integer := 399;
    c_ce_nwo_dhdg  integer := 439;
    -- Educational benefits + SLRP
    c_ce_re_educ_benefits integer := 492;
    c_ce_ne_educ_benefits integer := 328;
    c_ce_ne_slrp integer := 329;
    c_ce_re_slrp integer := 493;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    ---------------------------------------------------------------------------
    -- Inventory rolled up to the subgroup level (all nine military pay plans)
    ---------------------------------------------------------------------------
    DROP TABLE IF EXISTS inv_simple;
    CREATE TEMP TABLE inv_simple (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        inventory            integer,
        amcosversionid       integer
    );

    INSERT INTO inv_simple
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
           SUM(inventory) AS inventory, amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid;

    v_activedays := crunch.getsinglevalue('AA', 'activedays', p_amcosversionid);

    ---------------------------------------------------------------------------
    -- Active single-value amounts
    ---------------------------------------------------------------------------
    v_amt_active_merhc     := crunch.getsinglevalue('AA', 'MERHC', p_amcosversionid);

    -- MWR = OMA morale/welfare/recreation budget spread over avg MPA end strength
    v_amt_active_mwr := crunch.getarmybudgetsinglevalue('MoraleWelfareRecreation', 'OMA', 'Avg', p_amcosversionid)
                        / NULLIF(crunch.getarmybudgetsinglevalue('Avg_OE_End_Strength', 'MPA', 'Avg', p_amcosversionid), 0);

    v_amt_active_medical      := crunch.getsinglevalue('AA', 'Health_Care_Cost_Per_Family_Member', p_amcosversionid);
    v_amt_active_groceries    := crunch.getsinglevalue('AA', 'DiscountGroceries', p_amcosversionid);
    v_amt_active_dodea        := crunch.getsinglevalue('AA', 'DoDEAandFamilyAssistance', p_amcosversionid);
    v_amt_active_childedu     := crunch.getsinglevalue('AA', 'ChildEducation', p_amcosversionid);
    v_amt_active_concurrec    := crunch.getsinglevalue('AA', 'TreasuryContributionForConcurrentReceipts', p_amcosversionid);
    v_amt_active_treas_merhcf := crunch.getsinglevalue('AA', 'TreasuryContributionToMERHC', p_amcosversionid);
    v_amt_active_veteran      := crunch.getsinglevalue('AA', 'VeteransBenefits', p_amcosversionid);

    ---------------------------------------------------------------------------
    -- NG/R amounts
    ---------------------------------------------------------------------------
    -- Health care: prorate the active medical support cost by active days / year
    v_amt_ng_r_health := v_amt_active_medical / v_days * v_activedays;

    -- RE DHDG
    v_re_dhdg        := crunch.getarmybudgetsinglevalue('RE_DHDG', 'RPA', 'Avg', p_amcosversionid);
    v_re_endstrength := crunch.getarmybudgetsinglevalue('RE_Endstrength', 'RPA', 'Avg', p_amcosversionid);
    v_amt_re_dhdg    := v_re_dhdg / NULLIF(v_re_endstrength, 0);

    -- RO/RWO DHDG
    v_ro_rwo_dhdg        := crunch.getarmybudgetsinglevalue('RO_RWO_DHDG', 'RPA', 'Avg', p_amcosversionid);
    v_ro_rwo_endstrength := crunch.getarmybudgetsinglevalue('RO_RWO_Endstrength', 'RPA', 'Avg', p_amcosversionid);
    v_amt_ro_rwo_dhdg    := v_ro_rwo_dhdg / NULLIF(v_ro_rwo_endstrength, 0);

    -- NE DHDG
    v_ne_dhdg        := crunch.getarmybudgetsinglevalue('NE_DHDG', 'NGPA', 'Avg', p_amcosversionid);
    v_ne_endstrength := crunch.getarmybudgetsinglevalue('NE_Endstrength', 'NGPA', 'Avg', p_amcosversionid);
    v_amt_ne_dhdg    := v_ne_dhdg / NULLIF(v_ne_endstrength, 0);

    -- NO/NWO DHDG
    v_no_nwo_endstrength := crunch.getarmybudgetsinglevalue('NO_NWO_Endstrength', 'NGPA', 'Avg', p_amcosversionid);
    v_no_nwo_dhdg        := crunch.getarmybudgetsinglevalue('NO_NWO_DHDG', 'NGPA', 'Avg', p_amcosversionid);
    v_amt_no_nwo_dhdg    := v_no_nwo_dhdg / NULLIF(v_no_nwo_endstrength, 0);

    -- RE Educational Benefits (GI Bill): (basic + kicker) spread over RE inventory
    v_re_basic_benefit := crunch.getarmybudgetsinglevalue('RE_Basic_Benefit', 'RPA', 'Avg', p_amcosversionid);
    v_re_kicker        := crunch.getarmybudgetsinglevalue('RE_Edu_Kicker', 'RPA', 'Avg', p_amcosversionid);
    v_amt_re_eduben    := (v_re_basic_benefit + v_re_kicker)
                          / NULLIF((SELECT SUM(inventory) FROM inv_simple WHERE payplan = 'RE'), 0);

    -- NE Educational Benefits (GI Bill): (basic + kicker) spread over NE inventory
    v_ne_basic_benefit := crunch.getarmybudgetsinglevalue('NE_Basic_Benefit', 'NGPA', 'Avg', p_amcosversionid);
    v_ne_kicker        := crunch.getarmybudgetsinglevalue('NE_Edu_Kicker', 'NGPA', 'Avg', p_amcosversionid);
    v_amt_ne_eduben    := (v_ne_basic_benefit + v_ne_kicker)
                          / NULLIF((SELECT SUM(inventory) FROM inv_simple WHERE payplan = 'NE'), 0);

    -- NE Student Loan Repayment Program (SLRP): budget spread over NE inventory
    v_nestudentloanrepayment := crunch.getarmybudgetsinglevalue('NE_Student_Loan_Repayment', 'NGPA', 'Avg', p_amcosversionid);
    v_amt_ne_slrp := v_nestudentloanrepayment
                     / NULLIF((SELECT SUM(inventory) FROM inv_simple WHERE payplan = 'NE'), 0);

    -- RE Student Loan Repayment Program (SLRP)
    -- NOTE: source divides the *NE* repayment budget (@NEStudentLoanRepayment) over
    -- RE inventory — a source bug preserved verbatim. v_restudentloanrepayment is
    -- fetched (as the source declares it) but intentionally unused in the amount.
    v_restudentloanrepayment := crunch.getarmybudgetsinglevalue('RE_Student_Loan_Repayment', 'RPA', 'Avg', p_amcosversionid);
    v_amt_re_slrp := v_nestudentloanrepayment
                     / NULLIF((SELECT SUM(inventory) FROM inv_simple WHERE payplan = 'RE'), 0);

    ---------------------------------------------------------------------------
    -- Clear + write the cost tables (dry run when p_debug = true)
    ---------------------------------------------------------------------------
    IF NOT p_debug THEN
        -- clear the CE ids we are about to (re)insert, for this version
        DELETE FROM crunch.costs_ae
        WHERE costelementid IN (c_ce_ae_childedu, c_ce_ae_concurrec, c_ce_ae_dodea, c_ce_ae_groceries, c_ce_ae_medical,
                                c_ce_ae_merhc, c_ce_ae_mwr, c_ce_ae_treas_merhcf, c_ce_ae_veteran)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ao
        WHERE costelementid IN (c_ce_ao_childedu, c_ce_ao_concurrec, c_ce_ao_dodea, c_ce_ao_groceries, c_ce_ao_medical,
                                c_ce_ao_merhc, c_ce_ao_mwr, c_ce_ao_treas_merhcf, c_ce_ao_veteran)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_awo
        WHERE costelementid IN (c_ce_awo_childedu, c_ce_awo_concurrec, c_ce_awo_dodea, c_ce_awo_groceries,
                                c_ce_awo_medical, c_ce_awo_merhc, c_ce_awo_mwr, c_ce_awo_treas_merhcf, c_ce_awo_veteran)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ne
        WHERE costelementid IN (c_ce_ne_health, c_ce_ne_dhdg, c_ce_ne_educ_benefits, c_ce_ne_slrp)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_re
        WHERE costelementid IN (c_ce_re_health, c_ce_re_dhdg, c_ce_re_educ_benefits, c_ce_re_slrp)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_no
        WHERE costelementid IN (c_ce_no_health, c_ce_no_dhdg)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ro
        WHERE costelementid IN (c_ce_ro_health, c_ce_ro_dhdg)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_nwo
        WHERE costelementid IN (c_ce_nwo_health, c_ce_nwo_dhdg)
          AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_rwo
        WHERE costelementid IN (c_ce_rwo_health, c_ce_rwo_dhdg)
          AND amcosversionid = p_amcosversionid;

        -- ================= AE (A-series: carries locationid; mha/dependentstatus default) =================
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_merhc, gradetype, gradelevel, -1, v_amt_active_merhc, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_mwr, gradetype, gradelevel, -1, v_amt_active_mwr, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_medical, gradetype, gradelevel, -1, v_amt_active_medical, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_groceries, gradetype, gradelevel, -1, v_amt_active_groceries, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_dodea, gradetype, gradelevel, -1, v_amt_active_dodea, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_childedu, gradetype, gradelevel, -1, v_amt_active_childedu, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_concurrec, gradetype, gradelevel, -1, v_amt_active_concurrec, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_treas_merhcf, gradetype, gradelevel, -1, v_amt_active_treas_merhcf, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ae_veteran, gradetype, gradelevel, -1, v_amt_active_veteran, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AE';

        -- ================= AO =================
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_merhc, gradetype, gradelevel, -1, v_amt_active_merhc, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_mwr, gradetype, gradelevel, -1, v_amt_active_mwr, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_medical, gradetype, gradelevel, -1, v_amt_active_medical, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_groceries, gradetype, gradelevel, -1, v_amt_active_groceries, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_dodea, gradetype, gradelevel, -1, v_amt_active_dodea, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_childedu, gradetype, gradelevel, -1, v_amt_active_childedu, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_concurrec, gradetype, gradelevel, -1, v_amt_active_concurrec, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_treas_merhcf, gradetype, gradelevel, -1, v_amt_active_treas_merhcf, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ao_veteran, gradetype, gradelevel, -1, v_amt_active_veteran, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AO';

        -- ================= AWO =================
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_merhc, gradetype, gradelevel, -1, v_amt_active_merhc, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_mwr, gradetype, gradelevel, -1, v_amt_active_mwr, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_medical, gradetype, gradelevel, -1, v_amt_active_medical, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_groceries, gradetype, gradelevel, -1, v_amt_active_groceries, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_dodea, gradetype, gradelevel, -1, v_amt_active_dodea, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_childedu, gradetype, gradelevel, -1, v_amt_active_childedu, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_concurrec, gradetype, gradelevel, -1, v_amt_active_concurrec, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_treas_merhcf, gradetype, gradelevel, -1, v_amt_active_treas_merhcf, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_awo_veteran, gradetype, gradelevel, -1, v_amt_active_veteran, v_crunchtime, p_amcosversionid, -1
        FROM inv_simple WHERE payplan = 'AWO';

        -- ================= NE (N/R-series: no locationid/mha/dependentstatus) =================
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ne_health, gradetype, gradelevel, -1, v_amt_ng_r_health, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ne_dhdg, gradetype, gradelevel, -1, v_amt_ne_dhdg, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ne_educ_benefits, gradetype, gradelevel, -1, v_amt_ne_eduben, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ne_slrp, gradetype, gradelevel, -1, v_amt_ne_slrp, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NE';

        -- ================= RE =================
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_re_health, gradetype, gradelevel, -1, v_amt_ng_r_health, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_re_dhdg, gradetype, gradelevel, -1, v_amt_re_dhdg, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_re_educ_benefits, gradetype, gradelevel, -1, v_amt_re_eduben, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RE'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_re_slrp, gradetype, gradelevel, -1, v_amt_re_slrp, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RE';

        -- ================= NO =================
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_no_health, gradetype, gradelevel, -1, v_amt_ng_r_health, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_no_dhdg, gradetype, gradelevel, -1, v_amt_no_nwo_dhdg, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NO';

        -- ================= RO =================
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ro_health, gradetype, gradelevel, -1, v_amt_ng_r_health, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_ro_dhdg, gradetype, gradelevel, -1, v_amt_ro_rwo_dhdg, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RO';

        -- ================= NWO =================
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_nwo_health, gradetype, gradelevel, -1, v_amt_ng_r_health, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_nwo_dhdg, gradetype, gradelevel, -1, v_amt_no_nwo_dhdg, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'NWO';

        -- ================= RWO =================
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_rwo_health, gradetype, gradelevel, -1, v_amt_ng_r_health, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RWO'
        UNION
        SELECT payplan, categorygroupcode, categorysubgroupcode, c_ce_rwo_dhdg, gradetype, gradelevel, -1, v_amt_ro_rwo_dhdg, v_crunchtime, p_amcosversionid
        FROM inv_simple WHERE payplan = 'RWO';
    END IF;

    DROP TABLE IF EXISTS inv_simple;
END;
$$;

-- ============================================================================
-- crunch.crunch1activeday  —  Cost of 1 Active Duty Day (variable CEs only)
--
-- Faithful structural port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
-- Crunch1ActiveDay.sql. Computes the six variable cost elements for the
-- Reserve/Guard pay plans (NE/NO/NWO/RE/RO/RWO): Medical Support, Base Pay,
-- Housing (BAH non-locality), Subsistence, FICA, Retired Pay — then rolls up
-- group-level and pay-plan-level inventory-weighted averages.
--
-- Conventions (per 006d style template):
--   * p_debug = true is a DRY RUN: the source only writes under "IF @Debug = 0"
--     (kept as "IF NOT p_debug"); "IF @Debug = 1" result-set dumps are dropped.
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS first + at proc end).
--   * "UPDATE #t SET .. FROM #t a JOIN b" -> "UPDATE t SET .. FROM b WHERE .."
--     (PG forbids re-aliasing the UPDATE target in FROM).
--   * ISNULL->COALESCE, GETDATE()/CONVERT(SMALLDATETIME,..)->now()::timestamp,
--     BIT->boolean, NVARCHAR->varchar, TINYINT->smallint, FLOAT->double precision.
--   * CostElementId + pay-plan literals preserved verbatim.
--   * Inventory / count divisions wrapped in NULLIF(denominator, 0).
--
-- Signature is two params (p_amcosversionid, p_debug) per the source, which has
-- no @CrunchTime parameter; crunchtime is materialized locally as now().
-- ============================================================================
CREATE OR REPLACE PROCEDURE crunch.crunch1activeday(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime          timestamp     := now()::timestamp;
    v_daysinamonth        integer       := 30;
    v_daysinyr            numeric(12, 2) := 365.0;
    v_activedays          integer;
    v_amt_active_medical  numeric(20, 2);
    v_ss                  double precision;
    v_retired_pay_accrual double precision;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- ----------------------------------------------------------------------
    -- Inventory pay by YOS (Reserve/Guard pay plans only)
    -- ----------------------------------------------------------------------
    DROP TABLE IF EXISTS basepaywyos;
    CREATE TEMP TABLE basepaywyos (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        yos                  integer,
        inventory            integer,
        pay                  numeric(18, 2),
        amcosversionid       integer
    );

    INSERT INTO basepaywyos
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yos, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yos,
           SUM(inventory) AS inventory, amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yos, amcosversionid;

    -- bring in pay by YOS (matched on pay plan)
    UPDATE basepaywyos t
    SET pay = b.rate
    FROM "PaySchedule".payschedule_military b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel
      AND t.yos = b.yos
      AND b.amcosversionid = t.amcosversionid;

    -- reserve/guard: overwrite with the matched active-schedule daily rate
    UPDATE basepaywyos t
    SET pay = (b.rate / v_daysinamonth)
    FROM "PaySchedule".payschedule_military b
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND t.yos = b.yos
      AND b.amcosversionid = t.amcosversionid
      AND t.payplan IN ('NO', 'NE', 'NWO', 'RE', 'RO', 'RWO')
      AND b.payplan IN ('AE', 'AO', 'AWO');

    -- ----------------------------------------------------------------------
    -- Base pay weighted by inventory, rolled up to grade/subgroup
    -- ----------------------------------------------------------------------
    DROP TABLE IF EXISTS weightedbasepay;
    CREATE TEMP TABLE weightedbasepay (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        pay                  numeric(18, 2)
    );

    INSERT INTO weightedbasepay
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, pay)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
           SUM(inventory * pay) / NULLIF(SUM(inventory), 0)
    FROM basepaywyos
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode;

    -- (IF @Debug = 1 interactive result-set dumps dropped: no runtime effect.)

    IF NOT p_debug THEN

        -- ################  Base Pay  ################
        DELETE FROM crunch.costs_1activeday
        WHERE costelementid IN (289, 359, 413, 453, 523, 577)
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode,
               CASE payplan
                   WHEN 'NE' THEN 289
                   WHEN 'NO' THEN 359
                   WHEN 'NWO' THEN 413
                   WHEN 'RE' THEN 453
                   WHEN 'RO' THEN 523
                   WHEN 'RWO' THEN 577
                   ELSE -1
               END,
               gradetype, gradelevel, -1, COALESCE(pay, 0), v_crunchtime, p_amcosversionid
        FROM weightedbasepay;

        -- ################  Cost of Health Care (Medical Support)  ################
        v_amt_active_medical := crunch.getsinglevalue('AA', 'Health_Care_Cost_Per_Family_Member', p_amcosversionid);

        DELETE FROM crunch.costs_1activeday
        WHERE costelementid IN (288, 358, 412, 452, 522, 576)
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode,
               CASE payplan
                   WHEN 'NE' THEN 288
                   WHEN 'NO' THEN 358
                   WHEN 'NWO' THEN 412
                   WHEN 'RE' THEN 452
                   WHEN 'RO' THEN 522
                   WHEN 'RWO' THEN 576
                   ELSE -1
               END,
               gradetype, gradelevel, -1,
               v_amt_active_medical / v_daysinyr, v_crunchtime, p_amcosversionid
        FROM weightedbasepay;

        -- ################  Basic Allowance for Housing (non-locality)  ################
        v_activedays := crunch.getsinglevalue('AA', 'activedays', p_amcosversionid);

        DELETE FROM crunch.costs_1activeday
        WHERE costelementid IN (292, 362, 416, 456, 526, 580)
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, cmf, mos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_ne  WHERE costelementid = 292 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, cmf, mos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_re  WHERE costelementid = 456 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, cmf, aoc, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_no  WHERE costelementid = 362 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, cmf, aoc, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_ro  WHERE costelementid = 526 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, branch, womos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_nwo WHERE costelementid = 416 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, branch, womos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_rwo WHERE costelementid = 580 AND amcosversionid = p_amcosversionid;

        -- ################  Basic Allowance for Subsistence  ################
        DELETE FROM crunch.costs_1activeday
        WHERE costelementid IN (293, 363, 417, 457, 527, 581)
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, cmf, mos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_ne  WHERE costelementid = 293 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, cmf, mos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_re  WHERE costelementid = 457 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, cmf, aoc, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_no  WHERE costelementid = 363 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, cmf, aoc, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_ro  WHERE costelementid = 527 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, branch, womos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_nwo WHERE costelementid = 417 AND amcosversionid = p_amcosversionid
        UNION
        SELECT payplan, branch, womos, costelementid, gradetype, gradelevel, -1,
               amount / NULLIF(v_activedays, 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_rwo WHERE costelementid = 581 AND amcosversionid = p_amcosversionid;

        -- ################  FICA (Social Security)  ################
        v_ss := crunch.getsinglevalue('AA', 'PercentSocialSecurity', p_amcosversionid);

        DELETE FROM crunch.costs_1activeday
        WHERE costelementid IN (290, 360, 414, 454, 524, 578)
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode,
               CASE payplan
                   WHEN 'NE' THEN 290
                   WHEN 'NO' THEN 360
                   WHEN 'NWO' THEN 414
                   WHEN 'RE' THEN 454
                   WHEN 'RO' THEN 524
                   WHEN 'RWO' THEN 578
                   ELSE -1
               END,
               gradetype, gradelevel, -1, pay * v_ss, v_crunchtime, p_amcosversionid
        FROM weightedbasepay;

        -- ################  Retired Pay  ################
        v_retired_pay_accrual := crunch.getsinglevalue('AA2', 'Retired_Pay_Accrual', p_amcosversionid);

        DELETE FROM crunch.costs_1activeday
        WHERE costelementid IN (291, 361, 415, 455, 525, 579)
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode,
               CASE payplan
                   WHEN 'NE' THEN 291
                   WHEN 'NO' THEN 361
                   WHEN 'NWO' THEN 415
                   WHEN 'RE' THEN 455
                   WHEN 'RO' THEN 525
                   WHEN 'RWO' THEN 579
                   ELSE -1
               END,
               gradetype, gradelevel, -1, pay * v_retired_pay_accrual, v_crunchtime, p_amcosversionid
        FROM weightedbasepay;

        -- ################  Group Avgs  ################
        -- Inventory-weighted average across subgroups, per category group.
        DELETE FROM crunch.costs_1activeday
        WHERE categorygroupcode <> '-1'
          AND categorysubgroupcode = '-1'
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT a.payplan, a.categorygroupcode, '-1', a.costelementid, a.gradetype, a.gradelevel, -1,
               SUM(a.amount * b.inventory) / NULLIF(SUM(b.inventory), 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_1activeday a
            LEFT OUTER JOIN data.knowninventory b
                ON a.payplan = b.payplan
               AND b.categorygroupcode = a.categorygroupcode
               AND b.categorysubgroupcode = a.categorysubgroupcode
               AND b.gradelevel = a.gradelevel
               AND b.amcosversionid = a.amcosversionid
        WHERE a.amcosversionid = p_amcosversionid
          AND a.categorysubgroupcode <> '-1'
        GROUP BY a.payplan, a.categorygroupcode, a.costelementid, a.gradetype, a.gradelevel;

        -- ################  PP Avgs  ################
        -- Inventory-weighted average across all subgroups, per pay plan.
        DELETE FROM crunch.costs_1activeday
        WHERE categorygroupcode = '-1'
          AND categorysubgroupcode = '-1'
          AND amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_1activeday
            (payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT a.payplan, '-1', '-1', a.costelementid, a.gradetype, a.gradelevel, -1,
               SUM(a.amount * b.inventory) / NULLIF(SUM(b.inventory), 0), v_crunchtime, p_amcosversionid
        FROM crunch.costs_1activeday a
            LEFT OUTER JOIN data.knowninventory b
                ON a.payplan = b.payplan
               AND b.categorygroupcode = a.categorygroupcode
               AND b.categorysubgroupcode = a.categorysubgroupcode
               AND b.gradelevel = a.gradelevel
               AND b.amcosversionid = a.amcosversionid
        WHERE a.amcosversionid = p_amcosversionid
          AND a.categorysubgroupcode <> '-1'
        GROUP BY a.payplan, a.costelementid, a.gradetype, a.gradelevel;

    END IF;

    DROP TABLE IF EXISTS basepaywyos;
    DROP TABLE IF EXISTS weightedbasepay;
END;
$$;
