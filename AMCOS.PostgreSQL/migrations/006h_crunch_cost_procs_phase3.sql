-- Cost-crunch PHASE 3 procedures — complex military cost elements (crunch.*).
--
-- The heaviest tier: recursion (MOS-tree bonus/training roll-ups via the 006g
-- helpers), CGLA weighting, locality/overseas, and DMDC-driven special pays.
-- Writes the military crunch.Costs_* tables and the crunch_temp.* staging tables
-- (005e). CREATE PROCEDURE, LANGUAGE plpgsql (CALL-invoked by CrunchAll in Phase 4;
-- p_debug=true is a dry run). Runs after 006g. Conventions: 006d header +
-- scratchpad PORT_CONVENTIONS.md / PHASE3_TARGETS.md.
--
-- CostOfTraining (14,730 lines + its own crunch_temp staging pipeline) is ported
-- separately (sub-wave C).


------------------------------------------------------------------------------
-- crunch.CostOfSelectiveRetentionBonus
--   CE ids: AE 3966 (avg/CGLA) + 3963 (actual)
--           NE  342 (avg/CGLA) + 3964 (actual)
--           RE  506 (avg/CGLA) + 3965 (actual)
-- Selective Retention Bonus (SRB/RRB active + Sel Res reserve) cost element.
-- Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
-- CostOfSelectiveRetentionBonus.sql.
--
-- Uses persistent staging tables crunch_temp.dmdcpayprocessed,
-- crunch_temp.militarysrbcaps, crunch_temp.srbpay (created empty by 005e;
-- TRUNCATE + repopulate each run). Calls crunch.getsinglevalue,
-- crunch.getparentinventory, crunch.getchildbonusrecursive.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofselectiveretentionbonus(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime            timestamp := COALESCE(p_crunchtime, now()::timestamp);
    -- active only; reserve component receiving it is an anomaly
    v_rrb                   varchar(50) := 'Regular Reenlistment Bonus';
    v_srb                   varchar(50) := 'Selective Reenlistment Bonus';
    -- reserve component only
    v_sel_res_pseb          varchar(50) := 'Sel Res Prior Service Enlistment Bonus';
    v_sel_res_rb            varchar(50) := 'Sel Res Reenlistment Bonus';
    -- NOTE: source declares @SRB_Max but never assigns it -> stays NULL (see RISKS)
    v_srb_max               numeric(16, 2);
    v_srb_kicker            numeric(16, 2);
    v_sel_reenliste_max     numeric(16, 2);
    v_sel_priosservice_max  numeric(16, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- in addition to the SRB caps there is a kicker allowed for reenlistments
    -- within 10-15 months of contractual ETS
    v_srb_kicker := crunch.getsinglevalue('AE', 'SRB_Kicker', p_amcosversionid);
    -- the reserve component have a single cap per FMR Volume 7a Chapter 56
    v_sel_reenliste_max := crunch.getsinglevalue('RC', 'Sel_Reenliste_Max', p_amcosversionid);
    v_sel_priosservice_max := crunch.getsinglevalue('RC', 'Sel_PriosService_Max', p_amcosversionid);

    TRUNCATE TABLE crunch_temp.dmdcpayprocessed;
    INSERT INTO crunch_temp.dmdcpayprocessed
        (paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
         gradelevel, avg_cost, amcosversionid, avg_annual_pay, avg_annual_payments,
         pay_cap, capped_avg_mpa_pay)
    SELECT paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
           gradelevel, avg_cost, amcosversionid, avg_annual_pay, avg_annual_payments,
           0.0 AS pay_cap, 0.0 AS capped_avg_mpa_pay
    FROM crunch.payprocessed
    WHERE amcosversionid = p_amcosversionid
          -- if there is no pay then don't worry about the row
          AND avg_cost > 0
          AND (
                (paytype IN (v_rrb, v_srb) AND payplan = 'AE')
                OR (paytype IN (v_sel_res_pseb, v_sel_res_rb) AND payplan IN ('RE', 'NE'))
              );

    TRUNCATE TABLE crunch_temp.militarysrbcaps;
    INSERT INTO crunch_temp.militarysrbcaps
        (mos, gradelevel, tier, amcosversionid, bonuscap)
    SELECT mos, gradelevel, tier, amcosversionid, bonuscap
    FROM dataload.militarysrbcaps
    WHERE amcosversionid = p_amcosversionid;

    -- bring in the pay cap from the MILPERS message (HRC, at least annually).
    -- Rewritten from T-SQL "UPDATE ..FROM dmdcpayprocessed a JOIN militarysrbcaps b":
    -- target self-alias dropped; join predicate moved to WHERE (pay_cap starts 0.0,
    -- unmatched rows keep 0.0 so inner-join UPDATE is equivalent).
    UPDATE crunch_temp.dmdcpayprocessed t
    SET pay_cap = b.bonuscap
    FROM crunch_temp.militarysrbcaps b
    WHERE t.categorysubgroupcode = b.mos
          AND t.gradelevel = b.gradelevel
          -- pay caps right now only apply to SRB
          AND t.paytype = v_srb
          AND t.payplan = 'AE';

    -- update the pay caps above zero to account for the kicker
    -- (degenerate T-SQL self-FROM dropped; predicate applies to target rows)
    UPDATE crunch_temp.dmdcpayprocessed
    SET pay_cap = pay_cap + v_srb_kicker
    WHERE paytype = v_srb
          AND pay_cap > 0
          AND payplan = 'AE';

    -- bring in the reserve pay caps (degenerate self-FROM dropped)
    UPDATE crunch_temp.dmdcpayprocessed
    SET pay_cap = v_sel_reenliste_max
    WHERE paytype = v_sel_res_rb;

    UPDATE crunch_temp.dmdcpayprocessed
    SET pay_cap = v_sel_priosservice_max
    WHERE paytype = v_sel_res_pseb;

    -- populate the capped pay column
    UPDATE crunch_temp.dmdcpayprocessed
    SET capped_avg_mpa_pay = avg_annual_pay;

    -- implement pay caps
    UPDATE crunch_temp.dmdcpayprocessed
    SET capped_avg_mpa_pay = pay_cap * avg_annual_payments
    WHERE avg_annual_pay > (pay_cap * avg_annual_payments);

    -- one final calculation for those over the total cap
    -- (v_srb_max is NULL in source -> predicate never true; preserved verbatim)
    UPDATE crunch_temp.dmdcpayprocessed
    SET capped_avg_mpa_pay = v_srb_max * avg_annual_payments
    WHERE avg_annual_pay > (v_srb_max * avg_annual_payments)
          AND paytype = v_srb;

    -- bring in inventory
    TRUNCATE TABLE crunch_temp.srbpay;
    INSERT INTO crunch_temp.srbpay
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
         inventory, cglainventory, avg_annual_pay, pay_cap, cgla_mpa_pay)
    SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
           SUM(inventory) AS inventory,
           0 AS cglainventory,   -- inventory at/above the pp, GL, AOC for bonus amounts
           0.0 AS avg_annual_pay,
           0.0 AS pay_cap,
           0.0 AS cgla_mpa_pay
    FROM data.knowninventory
    WHERE gradetype IN ('E')
          AND amcosversionid = p_amcosversionid
    GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

    -- generate CGLA inventory: cumulative inventory at or above any one
    -- PayPlan & subgroup combination (used later to average bonus across grades).
    -- Rewritten from "UPDATE srbpay a JOIN (subq) b": target self-alias dropped;
    -- subquery reads data.knowninventory (not the target), so a plain FROM works.
    UPDATE crunch_temp.srbpay t
    SET cglainventory = b.rev_cumulative
    FROM (
        -- reverse cumulative sum for Cross Grade Level Allocation (CGLA)
        SELECT payplan, categorysubgroupcode, gradetype, gradelevel, inventory,
               SUM(inventory) OVER (PARTITION BY payplan, categorysubgroupcode
                                    ORDER BY payplan, categorysubgroupcode, gradelevel DESC)
               + crunch.getparentinventory(payplan, categorysubgroupcode, p_amcosversionid)
                 AS rev_cumulative
        FROM (
            SELECT payplan, categorysubgroupcode, gradetype, gradelevel,
                   SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
            GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel
        ) AS a
        WHERE gradetype IN ('E')
        GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel, inventory
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel;

    -- bring in SRB payment amounts with caps.
    -- Rewritten from "UPDATE srbpay a JOIN (subq over dmdcpayprocessed) b": target
    -- self-alias dropped; subquery pre-aggregates so updates aren't sort-dependent.
    -- b.gradelevel cast ::integer to mirror source CONVERT(INT, b.GradeLevel).
    UPDATE crunch_temp.srbpay t
    SET avg_annual_pay = b.capped_avg_mpa_pay,
        pay_cap = b.pay_cap
    FROM (
        SELECT payplan, categorysubgroupcode, gradelevel,
               SUM(capped_avg_mpa_pay) AS capped_avg_mpa_pay,
               MAX(pay_cap) AS pay_cap
        FROM crunch_temp.dmdcpayprocessed
        GROUP BY payplan, categorysubgroupcode, gradelevel
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel::integer;

    -- because there can be more payments than inventory we re-implement pay caps:
    -- individual cap check
    UPDATE crunch_temp.srbpay
    SET avg_annual_pay = pay_cap * inventory
    WHERE avg_annual_pay > (pay_cap * inventory);
    -- total cap check (v_srb_max NULL in source -> predicate never true; preserved)
    UPDATE crunch_temp.srbpay
    SET avg_annual_pay = v_srb_max * inventory
    WHERE avg_annual_pay > (v_srb_max * inventory);

    -- execute the CGLA math: spread a bonus cost in one grade across all later
    -- grades within that subgroup based on inventory.
    -- Rewritten from "UPDATE srbpay a JOIN (subq over srbpay) b": target self-alias
    -- dropped; the same-table subquery is a separate scan (legal in PG FROM).
    -- avg_annual_pay / cglainventory denominator wrapped in NULLIF(.,0) to avoid
    -- divide-by-zero (behavior-preserving when denominator is non-zero).
    -- getchildbonusrecursive gradelevel arg cast ::smallint (function param is TINYINT).
    UPDATE crunch_temp.srbpay t
    SET cgla_mpa_pay = b.cgla_bonus
    FROM (
        SELECT payplan, categorysubgroupcode, gradetype, gradelevel,
               SUM(avg_annual_pay / NULLIF(cglainventory, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode
                   ORDER BY payplan, categorysubgroupcode, gradelevel ASC)
               + crunch.getchildbonusrecursive(payplan, categorysubgroupcode,
                                                gradetype, gradelevel::smallint,
                                                'RetentionBonus', p_amcosversionid)
                 AS cgla_bonus
        FROM crunch_temp.srbpay
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel;

    IF NOT p_debug THEN
        -- clear out the existing cost rows for the CE IDs we are about to insert
        DELETE FROM crunch.costs_ae
        WHERE costelementid IN (3963, 3966)
              AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ne
        WHERE costelementid IN (342, 3964)
              AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_re
        WHERE costelementid IN (506, 3965)
              AND amcosversionid = p_amcosversionid;

        -- Average cost elements (CGLA-spread), one APPN per PayPlan
        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3966, gradetype,
               gradelevel, -1, cgla_mpa_pay, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.srbpay
        WHERE payplan = 'AE';

        -- NE
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 342, gradetype,
               gradelevel, -1, cgla_mpa_pay, v_crunchtime, p_amcosversionid
        FROM crunch_temp.srbpay
        WHERE payplan = 'NE';

        -- RE
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 506, gradetype,
               gradelevel, -1, cgla_mpa_pay, v_crunchtime, p_amcosversionid
        FROM crunch_temp.srbpay
        WHERE payplan = 'RE';

        -- Actual cost elements (uncapped avg_annual_pay), one APPN per PayPlan
        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3963, gradetype,
               gradelevel, -1, avg_annual_pay, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.srbpay
        WHERE payplan = 'AE';

        -- NE
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3964, gradetype,
               gradelevel, -1, avg_annual_pay, v_crunchtime, p_amcosversionid
        FROM crunch_temp.srbpay
        WHERE payplan = 'NE';

        -- RE
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3965, gradetype,
               gradelevel, -1, avg_annual_pay, v_crunchtime, p_amcosversionid
        FROM crunch_temp.srbpay
        WHERE payplan = 'RE';
    END IF;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfRecruiting  (Phase 3 — Recruiting & Enlistment Bonus)
--   Port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CostOfRecruiting.sql.
--   Builds the crunch_temp.costofrecruiting staging table (persistent, TRUNCATEd)
--   from enlisted inventory, layers in per-capita recruiting/advertising budget
--   costs (MPA/OMA/RPA/OMAR/NGPA/OMNG) and DMDC enlistment-bonus pay (capped,
--   CGLA-allocated across grades), then writes the enlisted cost tables.
--   Writes: crunch.costs_ae (CE 22 MPA_total, 80 OMA_recruiting, 4189 bonus),
--           crunch.costs_ne (CE 331 MPA_total, 298 OMA_recruiting, 4191 bonus),
--           crunch.costs_re (CE 495 MPA_total, 462 OMA_recruiting, 4190 bonus).
--   Depends on: crunch.getarmybudgetsinglevalue, crunch.getsinglevalue,
--               crunch.getparentinventory, crunch.getchildbonusrecursive.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofrecruiting(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime timestamp := COALESCE(p_crunchtime, now()::timestamp);

    v_reb_max numeric(18, 2);
    v_aeb_max numeric(18, 2);

    v_inv_aes                     numeric(18, 2);
    v_accession_cost_per_enlisted numeric(18, 2);
    v_accession_cost_3yr_avg      numeric(18, 2);

    v_adv_oma_3yr_avg       numeric(18, 2);
    v_inv_es                numeric(18, 2);
    v_inv_total             numeric(18, 2);
    v_adv_oma_e_estimate    numeric(18, 2);
    v_adv_oma_e_per_soldier numeric(18, 2);

    v_recruiting_oma_3yr_avg        numeric(18, 2);
    v_recruiting_oma_ae_per_soldier numeric(18, 2);

    v_recruiting_endstrength_officer_3yr_avg  numeric(18, 2);
    v_recruiting_endstrength_enlisted_3yr_avg numeric(18, 2);
    v_e7_composite_standard                   numeric(18, 2);
    v_o3_composite_standard                   numeric(18, 2);
    v_recruiting_mpa_est                       numeric(18, 2);
    v_recruiting_mpa_est_per_ae                numeric(18, 2);

    v_recruiting_rpa_non_ft_3yr_avg       numeric(18, 2);
    v_recruiting_rpa_non_ft_e_per_soldier numeric(18, 2);
    v_inv_r_es                            numeric(18, 2);
    v_inv_r                               numeric(18, 2);
    v_recruiting_rpa_est                  numeric(18, 2);
    v_recruiting_rpa_est_per_re           numeric(18, 2);
    v_recruiting_omar_est                 numeric(18, 2);
    v_recruiting_omar_est_per_re          numeric(18, 2);

    v_recruiting_ngpa_non_ft_3yr_avg       numeric(18, 2);
    v_recruiting_ngpa_non_ft_e_per_soldier numeric(18, 2);
    v_inv_ng_es                            numeric(18, 2);
    v_inv_ng                               numeric(18, 2);
    v_recruiting_ngpa_est                  numeric(18, 2);
    v_recruiting_ngpa_est_per_ne           numeric(18, 2);
    v_recruiting_omng_est                  numeric(18, 2);
    v_recruiting_omng_est_per_ne           numeric(18, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- =============================================
    -- Set up the recruiting cost table by bringing in enlisted inventory
    -- =============================================
    TRUNCATE TABLE crunch_temp.costofrecruiting;

    INSERT INTO crunch_temp.costofrecruiting
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
         inventory, bonusaverageannualpay, bonus_avg_annual_payments, bonuspaycap,
         bonus_capped_amt, cglainventory, cgla_bonus, mpa_recruiting, oma_recruiting, mpa_total)
    SELECT a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.gradetype,
           a.gradelevel,
           a.inventory,
           0.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0
    FROM (
        SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
               SUM(inventory) AS inventory
        FROM data.knowninventory
        WHERE gradetype IN ('E')
          AND amcosversionid = p_amcosversionid
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
    ) AS a;

    -- generate CGLA inventory (reverse-cumulative inventory at or above a grade
    -- within a payplan+subgroup, used to average bonus costs across grades).
    -- SELF-JOIN REWRITE: source did UPDATE .. FROM CostOfRecruiting a INNER JOIN (b
    -- over data.KnownInventory); b does not read the target, so rewritten as an
    -- inner-join UPDATE..FROM (b) with the join in WHERE. Unmatched target rows keep
    -- their inserted 0 exactly as the T-SQL INNER JOIN left them.
    UPDATE crunch_temp.costofrecruiting t
    SET cglainventory = b.rev_cumulative
    FROM (
        SELECT payplan, categorysubgroupcode, gradetype, gradelevel, inventory,
               SUM(inventory) OVER (PARTITION BY payplan, categorysubgroupcode
                                    ORDER BY payplan, categorysubgroupcode, gradelevel DESC)
               + crunch.getparentinventory(payplan, categorysubgroupcode, p_amcosversionid) AS rev_cumulative
        FROM (
            SELECT payplan, categorysubgroupcode, gradetype, gradelevel,
                   SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
            GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel
        ) AS a
        WHERE gradetype IN ('E')
        GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel, inventory
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.categorysubgroupcode = b.categorysubgroupcode
      AND t.gradelevel = b.gradelevel;

    -- =============================================
    -- Contribution of Active Accession move costs
    -- =============================================
    v_accession_cost_3yr_avg := crunch.getarmybudgetsinglevalue('Accession_Travel_Enlisted', 'MPA', 'avg', p_amcosversionid);

    SELECT SUM(inventory) INTO v_inv_aes
    FROM data.inventory
    WHERE payplan IN ('AE')
      AND amcosversionid = p_amcosversionid;

    v_accession_cost_per_enlisted := v_accession_cost_3yr_avg / NULLIF(v_inv_aes, 0);

    -- bring in recruiting costs to our master table
    UPDATE crunch_temp.costofrecruiting
    SET mpa_recruiting = v_accession_cost_per_enlisted + mpa_recruiting
    WHERE payplan = 'AE';

    -- =============================================
    -- Contribution of Advertising costs (spread across the whole force)
    -- =============================================
    v_adv_oma_3yr_avg := crunch.getarmybudgetsinglevalue('Advertising', 'OMA', 'avg', p_amcosversionid);

    SELECT SUM(inventory) INTO v_inv_es
    FROM data.inventory
    WHERE payplan IN ('AE', 'NE', 'RE')
      AND amcosversionid = p_amcosversionid;

    SELECT SUM(inventory) INTO v_inv_total
    FROM data.inventory
    WHERE amcosversionid = p_amcosversionid;

    v_adv_oma_e_estimate    := (v_inv_es / NULLIF(v_inv_total, 0)) * v_adv_oma_3yr_avg;
    v_adv_oma_e_per_soldier := v_adv_oma_e_estimate / NULLIF(v_inv_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET oma_recruiting = v_adv_oma_e_per_soldier + oma_recruiting;

    -- =============================================
    -- Contribution of Active Recruiting costs
    -- =============================================
    v_recruiting_oma_3yr_avg        := crunch.getarmybudgetsinglevalue('Recruiting', 'OMA', 'avg', p_amcosversionid);
    v_recruiting_oma_ae_per_soldier := v_recruiting_oma_3yr_avg / NULLIF(v_inv_aes, 0);

    v_recruiting_endstrength_officer_3yr_avg  := crunch.getarmybudgetsinglevalue('Officer_Recruiters', 'MPA', 'avg', p_amcosversionid);
    v_recruiting_endstrength_enlisted_3yr_avg := crunch.getarmybudgetsinglevalue('Enlisted_Recruiters', 'MPA', 'avg', p_amcosversionid);

    -- assume O3 & E7 recruiters
    v_e7_composite_standard := crunch.getsinglevalue('AA', 'E7_Composite_Standard_Rate', p_amcosversionid);
    v_o3_composite_standard := crunch.getsinglevalue('AA', 'O3_Composite_Standard_Rate', p_amcosversionid);

    v_recruiting_mpa_est := (v_o3_composite_standard * v_recruiting_endstrength_officer_3yr_avg
                             + v_recruiting_endstrength_enlisted_3yr_avg * v_e7_composite_standard);
    v_recruiting_mpa_est_per_ae := v_recruiting_mpa_est / NULLIF(v_inv_aes, 0);

    UPDATE crunch_temp.costofrecruiting
    SET oma_recruiting = v_recruiting_oma_ae_per_soldier + oma_recruiting,
        mpa_recruiting = mpa_recruiting + v_recruiting_mpa_est_per_ae
    WHERE payplan = 'AE';

    -- =============================================
    -- Contribution of Army Reserve Recruiting
    -- =============================================
    -- RPA Non-Full-Time reservists
    v_recruiting_rpa_non_ft_3yr_avg := crunch.getarmybudgetsinglevalue('Recruiting', 'RPA', 'avg', p_amcosversionid);

    SELECT SUM(inventory) INTO v_inv_r_es
    FROM data.inventory
    WHERE payplan IN ('RE')
      AND amcosversionid = p_amcosversionid;

    SELECT SUM(inventory) INTO v_inv_r
    FROM data.inventory
    WHERE payplan IN ('RO', 'RWO', 'RE')
      AND amcosversionid = p_amcosversionid;

    v_recruiting_rpa_non_ft_e_per_soldier := v_recruiting_rpa_non_ft_3yr_avg * (v_inv_r_es / NULLIF(v_inv_r, 0)) / NULLIF(v_inv_r_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET mpa_recruiting = v_recruiting_rpa_non_ft_e_per_soldier + mpa_recruiting
    WHERE payplan = 'RE';

    -- RPA drill reservists (assume reserve recruiters are 79R inventory; drill pay
    -- annualized by *15)
    SELECT SUM(weighted_pay) INTO v_recruiting_rpa_est
    FROM (
        SELECT a.*,
               b.pay,
               a.inventory * b.pay AS weighted_pay
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, yos, gradetype, gradelevel,
                   SUM(inventory) AS inventory
            FROM data.inventory
            WHERE payplan = 'RE'
              AND categorysubgroupcode = '79R'
              AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, yos, gradetype, gradelevel
        ) AS a
        INNER JOIN (
            SELECT payplan, gradetype, gradelevel, yos, rate * 15 AS pay
            FROM data.payschedules
            WHERE payplan = 'RE'
              AND amcosversionid = p_amcosversionid
        ) AS b
            ON a.payplan = b.payplan
               AND a.gradetype = b.gradetype
               AND a.gradelevel = b.gradelevel
               AND a.yos = b.yos
    ) AS a;

    v_recruiting_rpa_est_per_re := v_recruiting_rpa_est / NULLIF(v_inv_r_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET mpa_recruiting = v_recruiting_rpa_est_per_re + mpa_recruiting
    WHERE payplan = 'RE';

    -- OMAR Recruiting Costs
    v_recruiting_omar_est        := crunch.getarmybudgetsinglevalue('Recruiting', 'OMAR', 'avg', p_amcosversionid);
    v_recruiting_omar_est_per_re := v_recruiting_omar_est / NULLIF(v_inv_r_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET oma_recruiting = v_recruiting_omar_est_per_re + oma_recruiting
    WHERE payplan = 'RE';

    -- =============================================
    -- Contribution of Army Guard Recruiting
    -- =============================================
    -- NGPA Non-Full-Time reservists
    v_recruiting_ngpa_non_ft_3yr_avg := crunch.getarmybudgetsinglevalue('Recruiting_Retention', 'NGPA', 'avg', p_amcosversionid);

    SELECT SUM(inventory) INTO v_inv_ng_es
    FROM data.inventory
    WHERE payplan IN ('NE')
      AND amcosversionid = p_amcosversionid;

    SELECT SUM(inventory) INTO v_inv_ng
    FROM data.inventory
    WHERE payplan IN ('NO', 'NWO', 'NE')
      AND amcosversionid = p_amcosversionid;

    v_recruiting_ngpa_non_ft_e_per_soldier := v_recruiting_ngpa_non_ft_3yr_avg * (v_inv_ng_es / NULLIF(v_inv_ng, 0)) / NULLIF(v_inv_ng_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET mpa_recruiting = v_recruiting_ngpa_non_ft_e_per_soldier + mpa_recruiting
    WHERE payplan = 'NE';

    -- NGPA Full-Time reservists (79R inventory; drill pay annualized by *15)
    SELECT SUM(weighted_pay) INTO v_recruiting_ngpa_est
    FROM (
        SELECT a.*,
               b.pay,
               a.inventory * b.pay AS weighted_pay
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, yos, gradetype, gradelevel,
                   SUM(inventory) AS inventory
            FROM data.inventory
            WHERE payplan = 'NE'
              AND categorysubgroupcode = '79R'
              AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, yos, gradetype, gradelevel
        ) AS a
        INNER JOIN (
            SELECT payplan, gradetype, gradelevel, yos, rate * 15 AS pay
            FROM data.payschedules
            WHERE payplan = 'NE'
              AND amcosversionid = p_amcosversionid
        ) AS b
            ON a.gradetype = b.gradetype
               AND a.gradelevel = b.gradelevel
               AND a.yos = b.yos
    ) AS a;

    v_recruiting_ngpa_est_per_ne := v_recruiting_ngpa_est / NULLIF(v_inv_ng_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET mpa_recruiting = v_recruiting_ngpa_est_per_ne + mpa_recruiting
    WHERE payplan = 'NE';

    -- OMNG Recruiting Costs
    v_recruiting_omng_est        := crunch.getarmybudgetsinglevalue('Recruiting', 'OMNG', 'avg', p_amcosversionid);
    v_recruiting_omng_est_per_ne := v_recruiting_omng_est / NULLIF(v_inv_ng_es, 0);

    UPDATE crunch_temp.costofrecruiting
    SET oma_recruiting = v_recruiting_omng_est_per_ne + oma_recruiting
    WHERE payplan = 'NE';

    -- =============================================
    -- Contribution of Enlistment Bonus
    -- =============================================
    -- @DMDCEnlistmentBonus table variable -> TEMP TABLE.
    -- gradelevel declared smallint (source NVARCHAR(2)): it is sourced from
    -- crunch.payprocessed.gradelevel (smallint) and joined to
    -- crunch_temp.costofrecruiting.gradelevel (smallint); keeping it smallint
    -- avoids a varchar/smallint comparison and preserves the grouping/join result.
    DROP TABLE IF EXISTS dmdcenlistmentbonus;
    CREATE TEMP TABLE dmdcenlistmentbonus (
        paytype             varchar(50),
        payplan             varchar(3),
        cmf                 varchar(4),
        subgrp              varchar(4),
        gradetype           varchar(3),
        gradelevel          smallint,
        avg_cost            numeric(18, 2),
        amcosversionid      integer,
        avg_annual_pay      numeric(18, 2),
        avg_annual_payments numeric(18, 2),
        pay_cap             numeric(18, 2),
        capped_avg_mpa_pay  numeric(18, 2)
    );

    INSERT INTO dmdcenlistmentbonus
        (paytype, payplan, cmf, subgrp, gradetype, gradelevel, avg_cost, amcosversionid,
         avg_annual_pay, avg_annual_payments, pay_cap, capped_avg_mpa_pay)
    SELECT paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
           avg_cost, amcosversionid, avg_annual_pay, avg_annual_payments, 0.0, 0.0
    FROM crunch.payprocessed
    WHERE amcosversionid = p_amcosversionid
      AND avg_annual_pay > 0
      AND (
              (paytype IN ('Enlistment Bonus') AND payplan LIKE 'A%')
              OR (paytype IN ('Sel Res Enlisted Accession Bonus', 'Sel Res Enlisted Affiliation Bonus')
                  AND payplan IN ('NE', 'RE'))
          );

    TRUNCATE TABLE crunch_temp.bonuscaps;

    INSERT INTO crunch_temp.bonuscaps (mos, cap, amcosversionid)
    SELECT mos, cap, amcosversionid
    FROM dataload.militaryenlistmentbonuscap
    WHERE amcosversionid = p_amcosversionid;

    -- maximum allowed by law 37 U.S.C. 309 (active) and FMR Vol 7A Ch 56 (reserve)
    v_aeb_max := crunch.getsinglevalue('AE', 'EnlistmentBonus_Max', p_amcosversionid);
    v_reb_max := crunch.getsinglevalue('RC', 'EnlistmentBonus_Max', p_amcosversionid);

    -- bring in the MILPERS pay cap (active only, by MOS).
    -- SELF-JOIN REWRITE: source UPDATE @tbl a INNER JOIN crunch_temp.BonusCaps b;
    -- b is a different table, rewritten to inner-join UPDATE..FROM. Target pay_cap
    -- starts 0.0; unmatched rows keep 0.0 as the T-SQL INNER JOIN left them.
    UPDATE dmdcenlistmentbonus t
    SET pay_cap = b.cap
    FROM crunch_temp.bonuscaps b
    WHERE t.subgrp = b.mos
      AND t.payplan IN ('AE');

    -- reserve pay caps
    UPDATE dmdcenlistmentbonus
    SET pay_cap = v_reb_max
    WHERE payplan IN ('RE', 'NE');

    -- copy avg cost into capped pay before adjusting by the cap
    UPDATE dmdcenlistmentbonus
    SET capped_avg_mpa_pay = avg_annual_pay;

    -- move bonus data collected so far into the recruiting table.
    -- SELF-JOIN REWRITE: source UPDATE CostOfRecruiting a INNER JOIN (b aggregated
    -- over @tbl); b reads the temp table, not the target, so rewritten as inner-join
    -- UPDATE..FROM (b) with the join in WHERE (target starts NULL/0, inner-join
    -- match set identical).
    UPDATE crunch_temp.costofrecruiting t
    SET bonusaverageannualpay      = b.avg_annual_pay,
        bonus_avg_annual_payments  = b.avg_annual_payments,
        bonuspaycap                = b.pay_cap
    FROM (
        SELECT payplan, subgrp, gradelevel,
               SUM(avg_annual_pay) AS avg_annual_pay,
               SUM(avg_annual_payments) AS avg_annual_payments,
               MAX(pay_cap) AS pay_cap
        FROM dmdcenlistmentbonus
        GROUP BY payplan, subgrp, gradelevel
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.categorysubgroupcode = b.subgrp
      AND t.gradelevel = b.gradelevel;

    -- implement pay caps
    UPDATE crunch_temp.costofrecruiting
    SET bonus_capped_amt = bonuspaycap * bonus_avg_annual_payments
    WHERE bonusaverageannualpay > (bonuspaycap * bonus_avg_annual_payments);

    -- cap against inventory
    UPDATE crunch_temp.costofrecruiting
    SET bonus_capped_amt = bonuspaycap * inventory
    WHERE bonusaverageannualpay > (bonuspaycap * inventory);

    -- maximum cap for AE (reserve max already applied)
    UPDATE crunch_temp.costofrecruiting
    SET bonus_capped_amt = bonus_avg_annual_payments * v_aeb_max
    WHERE bonusaverageannualpay > (v_aeb_max * bonus_avg_annual_payments)
      AND payplan IN ('AE');

    -- maximum cap for AE, against inventory
    UPDATE crunch_temp.costofrecruiting
    SET bonus_capped_amt = inventory * v_aeb_max
    WHERE bonusaverageannualpay > (v_aeb_max * inventory)
      AND payplan IN ('AE');

    -- cap any E7 and above at 0 (bonus fully paid out within ~4 YOS)
    UPDATE crunch_temp.costofrecruiting
    SET bonus_capped_amt = 0
    WHERE gradelevel >= 7;

    -- bring in CGLA calculation.
    -- SELF-JOIN REWRITE: source UPDATE CostOfRecruiting a INNER JOIN (b over
    -- CostOfRecruiting itself, the target). Per convention the self-scan lives in a
    -- FROM subquery (b), a materialized snapshot, so the target can be updated safely.
    -- The bonus_capped_amt / cglainventory division is wrapped in NULLIF(...,0) to
    -- avoid divide-by-zero (behavior-preserving where cglainventory <> 0).
    UPDATE crunch_temp.costofrecruiting t
    SET cgla_bonus = b.mybonus
    FROM (
        SELECT payplan, categorysubgroupcode, gradelevel,
               SUM(bonus_capped_amt / NULLIF(cglainventory, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode
                   ORDER BY payplan, categorysubgroupcode, gradelevel ASC)
               + crunch.getchildbonusrecursive(payplan, categorysubgroupcode, gradetype,
                                                gradelevel, 'Recruiting', p_amcosversionid) AS mybonus
        FROM crunch_temp.costofrecruiting
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.categorysubgroupcode = b.categorysubgroupcode
      AND t.gradelevel = b.gradelevel;

    -- total MPA = recruiting + bonus costs
    UPDATE crunch_temp.costofrecruiting
    SET mpa_total = COALESCE(mpa_recruiting, 0) + COALESCE(cgla_bonus, 0);

    IF NOT p_debug THEN
        -- clear existing cost rows for the CE IDs we are about to insert
        DELETE FROM crunch.costs_ae WHERE costelementid IN (4189, 22, 80)   AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne WHERE costelementid IN (4191, 331, 298) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re WHERE costelementid IN (4190, 462, 495) AND amcosversionid = p_amcosversionid;

        -- ---- Average cost elements ----
        -- AE MPA (CE 22)
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 22, gradetype, gradelevel, -1,
               mpa_total, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'AE';
        -- AE OMA (CE 80)
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 80, gradetype, gradelevel, -1,
               oma_recruiting, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'AE';

        -- NE NGPA (CE 331)
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 331, gradetype, gradelevel, -1,
               mpa_total, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'NE';
        -- NE OMNG (CE 298)
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 298, gradetype, gradelevel, -1,
               oma_recruiting, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'NE';

        -- RE RPA (CE 495)
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 495, gradetype, gradelevel, -1,
               mpa_total, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'RE';
        -- RE OMAR (CE 462)
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 462, gradetype, gradelevel, -1,
               oma_recruiting, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'RE';

        -- ---- Actual (bonus) cost elements ----
        -- AE (CE 4189)
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4189, gradetype, gradelevel, -1,
               bonusaverageannualpay, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'AE';
        -- NE (CE 4191)
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4191, gradetype, gradelevel, -1,
               bonusaverageannualpay, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'NE';
        -- RE (CE 4190)
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4190, gradetype, gradelevel, -1,
               bonusaverageannualpay, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofrecruiting
        WHERE payplan = 'RE';
    END IF;

    DROP TABLE IF EXISTS dmdcenlistmentbonus;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfOfficerAcquisition  (Phase 3 — officer/warrant acquisition cost)
--
-- Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
-- CostOfOfficerAcquisition.sql. Spreads Source-of-Commission acquisition costs
-- (USMA, OCS, NG-OCS, ROTC scholarship/non-scholarship, Direct Commission) plus
-- accession-travel, advertising and reserve/guard recruiting per-capita costs
-- across officer/warrant grades, then adds capped Sel-Res accession/affiliation
-- bonus (with Cross-Grade-Level Allocation) for the reserve components.
--
-- Writes the crunch_temp staging tables (soctransactiongl, soctransaction,
-- costofofficeracquisitiontotal, costofofficeracquisitionbyaoc, dmdcbonus) —
-- UNCONDITIONALLY, exactly as the source (these writes are NOT under @Debug=0) —
-- and, only when NOT p_debug (dry run), the final crunch.Costs_AO/AWO/NO/NWO/
-- RO/RWO tables.
--   CE ids  AO: mpa 136, oma 177
--           AWO: mpa 210, oma 678
--           NO: mpa 389, oma 4200, actual-bonus(NGPA) 4197
--           NWO: mpa 4194, oma 4195, actual-bonus(NGPA) 4199
--           RO: mpa 553, oma 4201, actual-bonus(RPA) 4196
--           RWO: mpa 4192, oma 4193, actual-bonus(RPA) 4198
--
-- Port conventions: @Debug=1 result dumps dropped (no runtime effect);
-- UPDATE..FROM self-joins de-aliased (PG forbids re-aliasing the target);
-- ISNULL->COALESCE; every budget/total-over-count division wrapped in NULLIF;
-- string + -> ||; helper calls -> crunch.get*.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofofficeracquisition(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_int integer := 0;

    -- Accession travel
    v_accession_cost_3yr_avg    numeric(18, 2);
    v_inv_aos                   numeric(18, 2);
    v_accession_cost_per_officer numeric(18, 2);

    -- Advertising / R&A
    v_adv_oma_3yr_avg           numeric(18, 2);
    v_inv_ows                   numeric(18, 2);
    v_inv_total                 numeric(18, 2);
    v_adv_oma_ow_estimate       numeric(18, 2);
    v_adv_oma_ow_per_soldier    numeric(18, 2);

    -- Reserve (RPA) recruiting
    v_recruiting_rpa_non_ft_3yr_avg        numeric(18, 2);
    v_recruiting_rpa_non_ft_e_per_soldier  numeric(18, 2);
    v_inv_r_os                  numeric(18, 2);
    v_inv_r                     numeric(18, 2);

    -- National Guard (NGPA) recruiting
    v_recruiting_ngpa_non_ft_3yr_avg       numeric(18, 2);
    v_recruiting_ngpa_non_ft_e_per_soldier numeric(18, 2);
    v_inv_ng_os                 numeric(18, 2);
    v_inv_ng                    numeric(18, 2);

    -- USMA
    v_usma_mpa_est              numeric(18, 2);
    v_usma_oma_est              numeric(18, 2);
    v_usma_mpa_officers         integer;
    v_usma_mpa_enlisted         integer;
    v_usma_mpa_warrant          integer;
    v_e7_composite_standard     numeric(18, 2);
    v_o5_composite_standard     numeric(18, 2);
    v_w2_composite_standard     numeric(18, 2);

    -- OCS
    v_ocs_mpa_acpg              numeric(18, 2);
    v_ocs_oma_acpg              numeric(18, 2);

    -- NG state OCS
    v_ngocs_mpa_3yr_avg         numeric(18, 2);
    v_ngocs_omng_3yr_avg        numeric(18, 2);

    -- ROTC
    v_rotc_oma_scholarship_3yr_avg numeric(18, 2);
    v_rotc_oma_3yr_avg          numeric(18, 2);
    v_rotc_oma_scholarship      numeric(18, 2);
    v_rotc_oma_non_scholarship  numeric(18, 2);
    v_rotc_mpa_non_scholarship  numeric(18, 2);
    v_rotc_mpa_scholarship      numeric(18, 2);
    v_rotc_scholarship_tnos     numeric(18, 2);
    v_rotc_non_scholarship_tnos numeric(18, 2);
    v_rotc_enlisted             integer;
    v_rotc_warrant              integer;
    v_rotc_officer              integer;
    v_rotc_enlisted_cost        numeric(18, 2);
    v_rotc_officer_cost         numeric(18, 2);
    v_rotc_warrant_cost         numeric(18, 2);
    v_rotc_scholarship_tnos_ratio     numeric(18, 2);
    v_rotc_non_scholarship_tnos_ratio numeric(18, 2);

    -- Direct commission
    v_dcocs_mpa_acpg            numeric(18, 2);
    v_dcocs_oma_acpg            numeric(18, 2);

    -- Reserve bonus caps
    v_racb_annual_max           numeric(18, 2);
    v_rafb_annual_max           numeric(18, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- drop leftover temp table + clear the staging tables (unconditional, as in source)
    DROP TABLE IF EXISTS crunch.tempacq_calc;
    TRUNCATE TABLE crunch_temp.soctransactiongl;
    TRUNCATE TABLE crunch_temp.soctransaction;

    -- ------------------------------------------------------------------
    -- Pull the DMDC gains-by-Source-of-Commission transaction file into a
    -- grade-level staging table (only "Include" transaction types, officers only)
    -- ------------------------------------------------------------------
    INSERT INTO crunch_temp.soctransactiongl
        (payplan, grade, gradelevel, soc, soc_name, total)
    SELECT a.payplan,
           a.grade,
           (a.gradelevel)::integer::text AS gradelevel,   -- source CAST(GradeLevel AS INT), stored as text
           a.sourceofcommission AS soc,
           b.description AS soc_name,
           a.total
    FROM (
        SELECT a.component,
               replace(left(a.component, 1) || left(a.paygrade, 1), 'W', 'WO') AS payplan,
               a.paygrade,
               left(a.paygrade, 1) AS grade,
               right(a.paygrade, 2) AS gradelevel,
               a.sourceofcommission,
               SUM(a.total) AS total
        FROM "DMDC".militaryacqsourceofcommission AS a
            LEFT JOIN lookup.militaryacqtransaction AS b
                ON a.transactiontypecode = b.code
        WHERE b.include_exclude = 'Include'
          AND a.amcosversionid = p_amcosversionid
          AND (p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
        GROUP BY a.component, a.paygrade, a.sourceofcommission
    ) AS a
        INNER JOIN lookup.militarysoc AS b
            ON a.sourceofcommission = b.code
               AND (p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
    WHERE a.payplan IN ('AO', 'NO', 'RO');   -- warrants excluded (their acq comes via WOCS training)

    -- aggregate away grade level
    INSERT INTO crunch_temp.soctransaction
        (payplan, grade, soc, soc_name, number, mypercent, mpa_cost, oma_cost, pp_inventory, avg_mpa, avg_oma)
    SELECT payplan,
           grade,
           soc,
           soc_name,
           SUM(total) AS number,
           0.0, 0.0, 0.0,
           v_int AS pp_inventory,
           0.0, 0.0
    FROM crunch_temp.soctransactiongl
    GROUP BY payplan, grade, soc, soc_name;

    -- pay plan's percent of the SOC total (self-scan moved to FROM subquery)
    UPDATE crunch_temp.soctransaction t
    SET mypercent = b.calc_perc
    FROM (
        SELECT payplan, grade, soc,
               number / NULLIF(SUM(number) OVER (PARTITION BY soc_name), 0) AS calc_perc
        FROM crunch_temp.soctransaction
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.grade = b.grade
      AND t.soc = b.soc;

    -- ------------------------------------------------------------------
    -- Active accession move cost (MPA) — benefits reserve officers too
    -- ------------------------------------------------------------------
    v_accession_cost_3yr_avg := crunch.getarmybudgetsinglevalue('Accession_Travel_Officer', 'MPA', 'Avg', p_amcosversionid);
    SELECT SUM(inventory) INTO v_inv_aos
    FROM data.inventory
    WHERE payplan IN ('AO', 'AWO') AND amcosversionid = p_amcosversionid;
    v_accession_cost_per_officer := v_accession_cost_3yr_avg / NULLIF(v_inv_aos, 0);

    -- ------------------------------------------------------------------
    -- Advertising / Recruiting & Advertising (OMA), spread across the whole force
    -- ------------------------------------------------------------------
    v_adv_oma_3yr_avg := crunch.getarmybudgetsinglevalue('Advertising', 'OMA', 'Avg', p_amcosversionid);
    SELECT SUM(inventory) INTO v_inv_ows
    FROM data.inventory
    WHERE payplan IN ('AO', 'RO', 'NO', 'RWO', 'AWO', 'NWO') AND amcosversionid = p_amcosversionid;
    SELECT SUM(inventory) INTO v_inv_total
    FROM data.inventory
    WHERE amcosversionid = p_amcosversionid;
    v_adv_oma_ow_estimate    := (v_inv_ows / NULLIF(v_inv_total, 0)) * v_adv_oma_3yr_avg;
    v_adv_oma_ow_per_soldier := v_adv_oma_ow_estimate / NULLIF(v_inv_ows, 0);

    -- ------------------------------------------------------------------
    -- Army Reserve (RPA) non-full-time recruiting, officer share
    -- ------------------------------------------------------------------
    v_recruiting_rpa_non_ft_3yr_avg := crunch.getarmybudgetsinglevalue('Recruiting', 'RPA', 'avg', p_amcosversionid);
    SELECT SUM(inventory) INTO v_inv_r_os
    FROM data.inventory WHERE payplan IN ('RO') AND amcosversionid = p_amcosversionid;
    SELECT SUM(inventory) INTO v_inv_r
    FROM data.inventory WHERE payplan IN ('RO', 'RWO', 'RE') AND amcosversionid = p_amcosversionid;
    v_recruiting_rpa_non_ft_e_per_soldier :=
        v_recruiting_rpa_non_ft_3yr_avg * (v_inv_r_os / NULLIF(v_inv_r, 0)) / NULLIF(v_inv_r_os, 0);

    -- ------------------------------------------------------------------
    -- National Guard (NGPA) non-full-time recruiting, officer share
    -- ------------------------------------------------------------------
    v_recruiting_ngpa_non_ft_3yr_avg := crunch.getarmybudgetsinglevalue('Recruiting_Retention', 'NGPA', 'avg', p_amcosversionid);
    SELECT SUM(inventory) INTO v_inv_ng_os
    FROM data.inventory WHERE payplan IN ('NO') AND amcosversionid = p_amcosversionid;
    SELECT SUM(inventory) INTO v_inv_ng
    FROM data.inventory WHERE payplan IN ('NO', 'NWO', 'NE') AND amcosversionid = p_amcosversionid;
    v_recruiting_ngpa_non_ft_e_per_soldier :=
        v_recruiting_ngpa_non_ft_3yr_avg * (v_inv_ng_os / NULLIF(v_inv_ng, 0)) / NULLIF(v_inv_ng_os, 0);

    -- ------------------------------------------------------------------
    -- US Military Academy average cost (SOC = 'A')
    -- ------------------------------------------------------------------
    v_usma_mpa_est      := crunch.getarmybudgetsinglevalue('USMA', 'MPA', 'avg', p_amcosversionid);
    v_usma_oma_est      := crunch.getarmybudgetsinglevalue('USMA', 'OMA', 'avg', p_amcosversionid);
    v_usma_mpa_officers := crunch.getarmybudgetsinglevalue('Officer_USMA', 'MPA', 'avg', p_amcosversionid);
    v_usma_mpa_enlisted := crunch.getarmybudgetsinglevalue('Enlisted_USMA', 'MPA', 'avg', p_amcosversionid);
    v_usma_mpa_warrant  := crunch.getarmybudgetsinglevalue('Warrant_USMA', 'MPA', 'avg', p_amcosversionid);

    v_e7_composite_standard := crunch.getsinglevalue('AA', 'E7_Composite_Standard_Rate', p_amcosversionid);
    v_o5_composite_standard := crunch.getsinglevalue('AA', 'O5_Composite_Standard_Rate', p_amcosversionid);
    v_w2_composite_standard := crunch.getsinglevalue('AA', 'W2_Composite_Standard_Rate', p_amcosversionid);

    v_usma_mpa_est := v_usma_mpa_est
        + (v_usma_mpa_officers * v_o5_composite_standard)
        + (v_usma_mpa_enlisted * v_e7_composite_standard)
        + (v_usma_mpa_warrant  * v_w2_composite_standard);

    UPDATE crunch_temp.soctransaction SET mpa_cost = v_usma_mpa_est * mypercent WHERE soc = 'A';
    UPDATE crunch_temp.soctransaction SET oma_cost = v_usma_oma_est * mypercent WHERE soc = 'A';

    -- ------------------------------------------------------------------
    -- Officer Candidate School (SOC J/X/Z) — per-graduate ATRM-159 costs
    -- ------------------------------------------------------------------
    v_ocs_mpa_acpg := crunch.getsinglevalue('AO', 'OCS_MPA_Cost_Per_Grad', p_amcosversionid);
    v_ocs_oma_acpg := crunch.getsinglevalue('AO', 'OCS_OMA_Cost_Per_Grad', p_amcosversionid);

    UPDATE crunch_temp.soctransaction SET mpa_cost = v_ocs_mpa_acpg * number WHERE soc IN ('J', 'X', 'Z');
    UPDATE crunch_temp.soctransaction SET oma_cost = v_ocs_oma_acpg * number WHERE soc IN ('J', 'X', 'Z');

    -- ------------------------------------------------------------------
    -- National Guard state OCS (SOC = 'L')
    -- ------------------------------------------------------------------
    v_ngocs_mpa_3yr_avg  := crunch.getarmybudgetsinglevalue('NGOCS', 'NGPA', 'avg', p_amcosversionid);
    v_ngocs_omng_3yr_avg := crunch.getarmybudgetsinglevalue('NGOCS', 'OMNG', 'avg', p_amcosversionid);

    UPDATE crunch_temp.soctransaction SET mpa_cost = v_ngocs_mpa_3yr_avg  * mypercent WHERE soc IN ('L');
    UPDATE crunch_temp.soctransaction SET oma_cost = v_ngocs_omng_3yr_avg * mypercent WHERE soc IN ('L');

    -- ------------------------------------------------------------------
    -- ROTC scholarship (SOC G) & non-scholarship (SOC H)
    -- ------------------------------------------------------------------
    v_rotc_oma_scholarship_3yr_avg := crunch.getarmybudgetsinglevalue('ROTC_Scholarship', 'OMA', 'avg', p_amcosversionid);
    v_rotc_oma_3yr_avg             := crunch.getarmybudgetsinglevalue('ROTC', 'OMA', 'avg', p_amcosversionid);

    v_rotc_oma_non_scholarship := v_rotc_oma_3yr_avg / 2;
    v_rotc_oma_scholarship     := (v_rotc_oma_3yr_avg / 2) + v_rotc_oma_scholarship_3yr_avg;

    v_rotc_mpa_non_scholarship := crunch.getarmybudgetsinglevalue('ROTC_NonScholarship', 'MPA', 'avg', p_amcosversionid);
    v_rotc_mpa_scholarship     := crunch.getarmybudgetsinglevalue('ROTC_Scholarship', 'MPA', 'avg', p_amcosversionid);

    v_rotc_scholarship_tnos     := crunch.getsinglevalue('MO', 'ROTC_Scholarship_TNoS', p_amcosversionid);
    v_rotc_non_scholarship_tnos := crunch.getsinglevalue('MO', 'ROTC_Non_Scholarship_TNoS', p_amcosversionid);

    v_rotc_enlisted := crunch.getarmybudgetsinglevalue('Enlisted_ROTC', 'MPA', 'avg', p_amcosversionid);
    v_rotc_warrant  := crunch.getarmybudgetsinglevalue('Warrant_ROTC', 'MPA', 'avg', p_amcosversionid);
    v_rotc_officer  := crunch.getarmybudgetsinglevalue('Officer_ROTC', 'MPA', 'avg', p_amcosversionid);

    v_rotc_enlisted_cost := v_e7_composite_standard * v_rotc_enlisted;
    v_rotc_officer_cost  := v_o5_composite_standard * v_rotc_officer;
    v_rotc_warrant_cost  := v_w2_composite_standard * v_rotc_warrant;

    v_rotc_scholarship_tnos_ratio :=
        v_rotc_scholarship_tnos / NULLIF(v_rotc_scholarship_tnos + v_rotc_non_scholarship_tnos, 0);
    v_rotc_non_scholarship_tnos_ratio :=
        v_rotc_non_scholarship_tnos / NULLIF(v_rotc_scholarship_tnos + v_rotc_non_scholarship_tnos, 0);

    v_rotc_mpa_scholarship := v_rotc_mpa_scholarship
        + (v_rotc_scholarship_tnos_ratio * (v_rotc_enlisted_cost + v_rotc_officer_cost + v_rotc_warrant_cost));
    v_rotc_mpa_non_scholarship := v_rotc_mpa_non_scholarship
        + (v_rotc_non_scholarship_tnos_ratio * (v_rotc_enlisted_cost + v_rotc_officer_cost + v_rotc_warrant_cost));

    UPDATE crunch_temp.soctransaction
    SET mpa_cost = v_rotc_mpa_scholarship * mypercent,
        oma_cost = v_rotc_oma_scholarship * mypercent
    WHERE soc IN ('G');

    UPDATE crunch_temp.soctransaction
    SET mpa_cost = v_rotc_mpa_non_scholarship * mypercent,
        oma_cost = v_rotc_oma_non_scholarship * mypercent
    WHERE soc IN ('H');

    -- ------------------------------------------------------------------
    -- Direct Commission (SOC M/N) — per-graduate ATRM-159 costs
    -- ------------------------------------------------------------------
    v_dcocs_mpa_acpg := crunch.getsinglevalue('AO', 'DOCS_MPA_Cost_Per_Grad', p_amcosversionid);
    v_dcocs_oma_acpg := crunch.getsinglevalue('AO', 'DOCS_OMA_Cost_Per_Grad', p_amcosversionid);

    UPDATE crunch_temp.soctransaction
    SET mpa_cost = v_dcocs_mpa_acpg * number,
        oma_cost = v_dcocs_oma_acpg * number
    WHERE soc IN ('M', 'N');

    -- pay plan inventory (self-scan moved to FROM subquery)
    UPDATE crunch_temp.soctransaction t
    SET pp_inventory = b.inv
    FROM (
        SELECT payplan, SUM(inventory) AS inv
        FROM data.inventory
        WHERE amcosversionid = p_amcosversionid
        GROUP BY payplan
    ) AS b
    WHERE t.payplan = b.payplan;

    -- per-officer averages
    UPDATE crunch_temp.soctransaction
    SET avg_mpa = mpa_cost / NULLIF(pp_inventory, 0),
        avg_oma = oma_cost / NULLIF(pp_inventory, 0);

    -- ------------------------------------------------------------------
    -- Roll averages up to the pay plan
    -- ------------------------------------------------------------------
    TRUNCATE TABLE crunch_temp.costofofficeracquisitiontotal;
    INSERT INTO crunch_temp.costofofficeracquisitiontotal (payplan, mpa, oma)
    SELECT payplan, SUM(avg_mpa) AS mpa, SUM(avg_oma) AS oma
    FROM crunch_temp.soctransaction
    GROUP BY payplan;

    -- ------------------------------------------------------------------
    -- Build the by-AOC master table (officers + warrants)
    -- ------------------------------------------------------------------
    TRUNCATE TABLE crunch_temp.costofofficeracquisitionbyaoc;
    INSERT INTO crunch_temp.costofofficeracquisitionbyaoc
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
         inv, cglainventory, ofc_acq_mpa, ofc_acq_oma, bonus_mpa, cgla_bonus_mpa)
    SELECT payplan,
           categorygroupcode,
           categorysubgroupcode,
           gradetype,
           gradelevel,
           SUM(inventory) AS inv,
           v_int AS cglainventory,
           0.0, 0.0, 0.0, 0.0
    FROM data.knowninventory
    WHERE gradetype IN ('O', 'W')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

    -- reverse-cumulative (CGLA) inventory at/above each pay plan+subgroup+grade
    -- (subquery scans data.knowninventory, not the target — de-aliased UPDATE..FROM)
    UPDATE crunch_temp.costofofficeracquisitionbyaoc t
    SET cglainventory = b.rev_cumulative
    FROM (
        SELECT payplan,
               categorysubgroupcode,
               gradetype,
               gradelevel,
               inventory,
               SUM(inventory) OVER (PARTITION BY payplan, categorysubgroupcode
                                    ORDER BY payplan, categorysubgroupcode, gradelevel DESC)
               + crunch.getparentinventory(payplan, categorysubgroupcode, p_amcosversionid) AS rev_cumulative
        FROM (
            SELECT payplan, categorysubgroupcode, gradetype, gradelevel, SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
            GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel
        ) AS a
        WHERE gradetype IN ('O', 'W')
        GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel, inventory
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.categorysubgroupcode = b.categorysubgroupcode
      AND t.gradelevel = b.gradelevel;

    -- R&A cost applies to everyone
    UPDATE crunch_temp.costofofficeracquisitionbyaoc
    SET ofc_acq_oma = v_adv_oma_ow_per_soldier;

    -- accession move cost (active)
    UPDATE crunch_temp.costofofficeracquisitionbyaoc
    SET ofc_acq_mpa = ofc_acq_mpa + v_accession_cost_per_officer
    WHERE payplan IN ('AO', 'AWO');

    -- reserve recruiting per soldier
    UPDATE crunch_temp.costofofficeracquisitionbyaoc
    SET ofc_acq_mpa = ofc_acq_mpa + v_recruiting_rpa_non_ft_e_per_soldier
    WHERE payplan IN ('RO', 'RWO');

    -- national guard recruiting per soldier
    UPDATE crunch_temp.costofofficeracquisitionbyaoc
    SET ofc_acq_mpa = ofc_acq_mpa + v_recruiting_ngpa_non_ft_e_per_soldier
    WHERE payplan IN ('NO', 'NWO');

    -- add the pay-plan averages (Total is a distinct table — de-aliased UPDATE..FROM)
    UPDATE crunch_temp.costofofficeracquisitionbyaoc t
    SET ofc_acq_oma = t.ofc_acq_oma + b.oma,
        ofc_acq_mpa = t.ofc_acq_mpa + b.mpa
    FROM crunch_temp.costofofficeracquisitiontotal b
    WHERE t.payplan = b.payplan;

    -- ------------------------------------------------------------------
    -- Reserve-component officer accession/affiliation bonus
    -- ------------------------------------------------------------------
    TRUNCATE TABLE crunch_temp.dmdcbonus;
    INSERT INTO crunch_temp.dmdcbonus
        (paytype, payplan, cmf, subgrp, gradetype, gradelevel, avg_cost, amcosversionid,
         avg_annual_pay, avg_annual_payments, pay_cap, capped_avg_mpa_pay)
    SELECT paytype,
           payplan,
           categorygroupcode,
           categorysubgroupcode,
           gradetype,
           gradelevel::text,
           avg_cost,
           amcosversionid,
           avg_annual_pay,
           avg_annual_payments,
           0.0, 0.0
    FROM crunch.payprocessed
    WHERE amcosversionid = p_amcosversionid
      AND avg_cost > 0
      AND (paytype IN ('Sel Res Officer Accession Bonus', 'Sel Res Officer Affiliation Bonus')
           AND payplan IN ('NO', 'RO', 'RWO', 'NWO'));

    v_racb_annual_max := crunch.getsinglevalue('RC', 'AccessionBonus_Annual_Max', p_amcosversionid);
    v_rafb_annual_max := crunch.getsinglevalue('RC', 'AffiliationBonus_Annual_Max', p_amcosversionid);

    UPDATE crunch_temp.dmdcbonus SET pay_cap = v_racb_annual_max WHERE paytype = 'Sel Res Officer Accession Bonus';
    UPDATE crunch_temp.dmdcbonus SET pay_cap = v_rafb_annual_max WHERE paytype = 'Sel Res Officer Affiliation Bonus';

    -- seed capped pay with the raw pay, then apply the annual cap
    UPDATE crunch_temp.dmdcbonus SET capped_avg_mpa_pay = avg_annual_pay;
    UPDATE crunch_temp.dmdcbonus
    SET capped_avg_mpa_pay = pay_cap * avg_annual_payments
    WHERE capped_avg_mpa_pay > pay_cap * avg_annual_payments;

    -- bring the capped bonus into the master table.
    -- Source is a LEFT JOIN update onto a NOT-NULL (0.0) column, so unmatched rows
    -- become NULL; a PG inner-join UPDATE..FROM would keep 0.0 instead. Rewritten as
    -- a correlated aggregate subquery, which yields NULL when there is no match —
    -- preserving the source's NULL-on-unmatched semantics.
    UPDATE crunch_temp.costofofficeracquisitionbyaoc t
    SET bonus_mpa = (
        SELECT SUM(d.capped_avg_mpa_pay)
        FROM crunch_temp.dmdcbonus d
        WHERE d.payplan = t.payplan
          AND d.subgrp = t.categorysubgroupcode
          AND d.gradelevel::integer = t.gradelevel
    );

    -- CGLA: spread a bonus in one grade across later grades in the subgroup
    -- (self-scan lives in a FROM subquery; div-by-inventory wrapped in NULLIF)
    UPDATE crunch_temp.costofofficeracquisitionbyaoc t
    SET cgla_bonus_mpa = b.cgla_bonus
    FROM (
        SELECT payplan,
               categorysubgroupcode,
               gradetype,
               gradelevel,
               SUM(bonus_mpa / NULLIF(cglainventory, 0)) OVER (PARTITION BY payplan, categorysubgroupcode
                                                               ORDER BY payplan, categorysubgroupcode, gradelevel ASC)
               + crunch.getchildbonusrecursive(payplan, categorysubgroupcode, gradetype, gradelevel,
                                                'OfficerAcquisition', p_amcosversionid) AS cgla_bonus
        FROM crunch_temp.costofofficeracquisitionbyaoc
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.categorysubgroupcode = b.categorysubgroupcode
      AND t.gradelevel = b.gradelevel;

    -- drop rows whose PayPlan/GradeLevel/subgroup has no matching known inventory
    DELETE FROM crunch_temp.costofofficeracquisitionbyaoc
    WHERE payplan || gradelevel::text || categorysubgroupcode NOT IN (
        SELECT DISTINCT payplan || gradelevel::text || categorysubgroupcode
        FROM data.knowninventory
        WHERE amcosversionid = p_amcosversionid
    );

    DELETE FROM crunch_temp.dmdcbonus
    WHERE payplan || gradelevel || subgrp NOT IN (
        SELECT DISTINCT payplan || gradelevel::text || categorysubgroupcode
        FROM data.knowninventory
        WHERE amcosversionid = p_amcosversionid
    );

    -- ------------------------------------------------------------------
    -- Final cost-element writes (skipped on dry run)
    -- ------------------------------------------------------------------
    IF NOT p_debug THEN
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (136, 177)        AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (210, 678)        AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no  WHERE costelementid IN (389, 4197, 4200) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo WHERE costelementid IN (4199, 4194, 4195) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro  WHERE costelementid IN (553, 4196, 4201) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo WHERE costelementid IN (4198, 4192, 4193) AND amcosversionid = p_amcosversionid;

        -- AO (A-series carries locationid; source sets locationid = -1)
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 136, gradetype, gradelevel, -1,
               ofc_acq_mpa + COALESCE(cgla_bonus_mpa, 0), v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'AO';

        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 177, gradetype, gradelevel, -1,
               ofc_acq_oma, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'AO';

        -- AWO (A-series carries locationid)
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 210, gradetype, gradelevel, -1,
               ofc_acq_mpa + COALESCE(cgla_bonus_mpa, 0), v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'AWO';

        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 678, gradetype, gradelevel, -1,
               ofc_acq_oma, v_crunchtime, p_amcosversionid, -1
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'AWO';

        -- RO (N/R-series: no locationid)
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 553, gradetype, gradelevel, -1,
               ofc_acq_mpa + COALESCE(cgla_bonus_mpa, 0), v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'RO';

        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4201, gradetype, gradelevel, -1,
               ofc_acq_oma, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'RO';

        -- RWO
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4192, gradetype, gradelevel, -1,
               ofc_acq_mpa + COALESCE(cgla_bonus_mpa, 0), v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'RWO';

        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4193, gradetype, gradelevel, -1,
               ofc_acq_oma, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'RWO';

        -- NO
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 389, gradetype, gradelevel, -1,
               ofc_acq_mpa + COALESCE(cgla_bonus_mpa, 0), v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'NO';

        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4200, gradetype, gradelevel, -1,
               ofc_acq_oma, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'NO';

        -- NWO
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4194, gradetype, gradelevel, -1,
               ofc_acq_mpa + COALESCE(cgla_bonus_mpa, 0), v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'NWO';

        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 4195, gradetype, gradelevel, -1,
               ofc_acq_oma, v_crunchtime, p_amcosversionid
        FROM crunch_temp.costofofficeracquisitionbyaoc WHERE payplan = 'NWO';

        -- actual bonus cost elements (one APPN each), aggregated from DMDCBonus.
        -- dmdcbonus.gradelevel is varchar -> cast to smallint for the costs tables.
        -- RO RPA
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, cmf, subgrp, 4196, gradetype, gradelevel::smallint, -1,
               SUM(avg_annual_pay), v_crunchtime, p_amcosversionid
        FROM crunch_temp.dmdcbonus WHERE payplan = 'RO'
        GROUP BY payplan, cmf, subgrp, gradetype, gradelevel;

        -- NO NGPA
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, cmf, subgrp, 4197, gradetype, gradelevel::smallint, -1,
               SUM(avg_annual_pay), v_crunchtime, p_amcosversionid
        FROM crunch_temp.dmdcbonus WHERE payplan = 'NO'
        GROUP BY payplan, cmf, subgrp, gradetype, gradelevel;

        -- RWO RPA
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, cmf, subgrp, 4198, gradetype, gradelevel::smallint, -1,
               SUM(avg_annual_pay), v_crunchtime, p_amcosversionid
        FROM crunch_temp.dmdcbonus WHERE payplan = 'RWO'
        GROUP BY payplan, cmf, subgrp, gradetype, gradelevel;

        -- NWO NGPA
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, cmf, subgrp, 4199, gradetype, gradelevel::smallint, -1,
               SUM(avg_annual_pay), v_crunchtime, p_amcosversionid
        FROM crunch_temp.dmdcbonus WHERE payplan = 'NWO'
        GROUP BY payplan, cmf, subgrp, gradetype, gradelevel;
    END IF;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfBasicAllowanceForHousingAndCola  (Phase 3 port)
--
-- Basic Allowance for Housing (BAH) + CONUS COLA for all nine military pay
-- plans. Writes crunch.Costs_{AE,AO,AWO,NE,NO,NWO,RE,RO,RWO}.
--
-- BAH CE ids:  AE 2, AO 129, AWO 205, NE 292, NO 362, NWO 416,
--              RE 456, RO 526, RWO 580
-- COLA CE ids: AE 4212, AO 4213, AWO 4214  (A-series only; MHA / dependent-
--              status / location-based rows plus one pay-plan-average row)
--
-- Reads dataload BAH/COLA inputs (BAHRates, NonLocalityBAHRates, ConusCola,
-- ConusColaLocations), "DMDC".membersanddependents, "DMDC".pay, data.inventory
-- (gradelevel is text in the view -> ::smallint), data.knowninventory, and the
-- xwalk.ziptomha / warehouse.location crosswalks. Calls
-- crunch.getarmybudgetsinglevalue / getreservecomponentbah / getsinglevalue.
--
-- Faithful structural port. Notable rewrites (see DECISIONS/RISKS):
--   * Two T-SQL PIVOTs -> MAX(...) FILTER (WHERE withdependents = n) GROUP BY.
--   * Every "UPDATE #t .. FROM #t a JOIN .." de-aliased (PG forbids re-aliasing
--     the UPDATE target in FROM); LEFT-join updates whose target column starts
--     NULL are rendered as inner-join UPDATE..FROM (behaviour-preserving).
--   * Count/inventory denominators wrapped in NULLIF(.., 0).
--   * data.inventory.gradelevel cast ::smallint. DutyStationIndex char(2) cast
--     ::numeric to feed the numeric COLAIndex.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofbasicallowanceforhousingandcola(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime           timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_bah_ao_awo_amt       numeric(16, 2);
    v_bah_ae_amt           numeric(16, 2);
    v_ao_awo_ratio         numeric(16, 2);
    v_ae_ratio             numeric(16, 2);
    v_daysinyear           integer;
    v_activedutydays       integer;
    v_ae_conuscola_avg     numeric(18, 2);
    v_ao_awo_conuscola_avg numeric(18, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    ----------------------------------------------------------------------------
    -- known inventory by category subgroup (A-series only)
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS knowninventorybycategorysubgroup;
    CREATE TEMP TABLE knowninventorybycategorysubgroup (
        payplan              varchar(3),
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        amcosversionid       integer
    );
    INSERT INTO knowninventorybycategorysubgroup
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, amcosversionid)
    SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, amcosversionid
    FROM data.knowninventory
    WHERE amcosversionid = p_amcosversionid
      -- if there is no pay then don't worry about the row
      AND payplan IN ('AE', 'AO', 'AWO');

    ----------------------------------------------------------------------------
    -- DMDC BAH: inventory joined to DMDC average annual BAH pay (by pay plan/grade)
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS dmdcbah;
    CREATE TEMP TABLE dmdcbah (
        paytype               varchar(50),
        payplan               varchar(3),
        categorygroupcode     varchar(2),
        categorysubgroupcode  varchar(4),
        gradetype             varchar(3),
        gradelevel            smallint,
        amcosversionid        integer,
        averageannualpay      numeric(16, 2),
        averageannualpayments numeric(16, 2),
        inventory             integer
    );
    INSERT INTO dmdcbah
        (paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
         gradelevel, amcosversionid, averageannualpay, averageannualpayments, inventory)
    SELECT b.paytype,
           a.payplan,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.payplan,               -- source loads pay plan into the gradetype column (never read later)
           a.gradelevel,
           a.amcosversionid,
           b.averageannualpay,
           NULL,
           a.inventory
    FROM (
        SELECT payplan, categorygroupcode, categorysubgroupcode, gradelevel, amcosversionid,
               SUM(inventory) AS inventory
        FROM data.knowninventory
        WHERE amcosversionid = p_amcosversionid
          AND payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'military')
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradelevel, amcosversionid
    ) AS a
    LEFT OUTER JOIN (
        SELECT paytype, payplan, gradelevel, AVG(averageannualpay) AS averageannualpay
        FROM (
            SELECT paytype, payplan, gradelevel, amcosversionid,
                   AVG(totalpayamount / NULLIF("count", 0)) * 12 AS averageannualpay
            FROM "DMDC".pay
            WHERE paytype IN ('Basic Allowance for Housing', 'Non-Locality Basic Allowance for Housing')
              AND amcosversionid IN (
                  SELECT amcosversionid
                  FROM lookup.amcosversion
                  WHERE amcosversionid >= p_amcosversionid - 200
                  ORDER BY amcosversionid DESC
                  LIMIT 3
              )
            GROUP BY paytype, payplan, gradelevel, amcosversionid
        ) AS a
        GROUP BY paytype, payplan, gradelevel
    ) AS b
        ON b.payplan = a.payplan
       AND b.gradelevel = a.gradelevel;

    ----------------------------------------------------------------------------
    -- DMDC members-and-dependents counts
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS dmdcdependents;
    CREATE TEMP TABLE dmdcdependents (
        payplan                  varchar(50),
        gradetype                varchar(50),
        gradelevel               smallint,
        totalmembers             integer,
        memberswithdependents    integer,
        memberswithoutdependents integer,
        numberofdependents       integer
    );
    INSERT INTO dmdcdependents
        (payplan, gradetype, gradelevel, totalmembers, memberswithdependents,
         memberswithoutdependents, numberofdependents)
    SELECT payplan, gradetype, gradelevel, totalmembers, memberswithdependents,
           memberswithoutdependents, numberofdependents
    FROM "DMDC".membersanddependents
    WHERE amcosversionid = p_amcosversionid;

    CREATE INDEX ON dmdcdependents (payplan, gradetype, gradelevel);

    ----------------------------------------------------------------------------
    -- non-locality BAH rates (NG/R)
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS nonlocalitybahrates;
    CREATE TEMP TABLE nonlocalitybahrates (
        gradetype             varchar(50),
        gradelevel            smallint,
        ratepartial           numeric(7, 2),
        ratewithoutdependents numeric(7, 2),
        ratewithdependents    numeric(7, 2),
        ratedifferential      numeric(7, 2)
    );
    INSERT INTO nonlocalitybahrates
        (gradetype, gradelevel, ratepartial, ratewithoutdependents, ratewithdependents, ratedifferential)
    SELECT gradetype, gradelevel, ratepartial, ratewithoutdependents, ratewithdependents, ratedifferential
    FROM dataload.nonlocalitybahrates
    WHERE amcosversionid = p_amcosversionid;

    CREATE INDEX ON nonlocalitybahrates (gradetype, gradelevel);

    ----------------------------------------------------------------------------
    -- BAH aggregated to grade level (subgroup detail dropped: BAH is uniform
    -- across subgroups within a pay plan/grade level)
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS bahgradelevel;
    CREATE TEMP TABLE bahgradelevel (
        payplan               varchar(3),
        gradetype             varchar(3),
        gradelevel            smallint,
        averageannualpay      numeric(16, 2),
        costelementid         integer,
        inventory             integer,
        amcosadjustmentamount numeric(16, 2),
        cost                  numeric(16, 2)
    );
    INSERT INTO bahgradelevel (payplan, gradetype, gradelevel, inventory)
    SELECT payplan, gradetype, gradelevel::smallint, SUM(inventory) AS inventory
    FROM data.inventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradetype, gradelevel::smallint;

    CREATE INDEX ON bahgradelevel (payplan, gradetype, gradelevel);

    -- bring in DMDC average annual pay (de-aliased; averageannualpay is uniform
    -- per pay plan/grade level so the arbitrary multi-match pick is immaterial)
    UPDATE bahgradelevel t
    SET averageannualpay = b.averageannualpay
    FROM dmdcbah b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- president's-budget amounts -> ratio
    v_bah_ao_awo_amt := crunch.getarmybudgetsinglevalue('BAH_Domestic_AO_AWO', 'MPA', 'Avg', p_amcosversionid);
    v_bah_ae_amt     := crunch.getarmybudgetsinglevalue('BAH_Domestic_AE', 'MPA', 'Avg', p_amcosversionid);

    SELECT v_bah_ao_awo_amt / NULLIF(SUM(averageannualpay * inventory), 0)
    INTO v_ao_awo_ratio
    FROM dmdcbah
    WHERE payplan IN ('AO', 'AWO');

    SELECT v_bah_ae_amt / NULLIF(SUM(averageannualpay * inventory), 0)
    INTO v_ae_ratio
    FROM dmdcbah
    WHERE payplan IN ('AE');

    UPDATE bahgradelevel SET amcosadjustmentamount = v_ao_awo_ratio WHERE payplan IN ('AO', 'AWO');
    UPDATE bahgradelevel SET amcosadjustmentamount = v_ae_ratio     WHERE payplan IN ('AE');

    UPDATE bahgradelevel SET cost = averageannualpay * amcosadjustmentamount;

    -- ARNG/USAR get non-locality BAH; recompute NG/R cost (de-aliased LEFT->inner
    -- on nonlocality rates, LEFT on dependents; cost starts NULL for these rows so
    -- an unmatched rate row stays NULL and the NULL guard below fires, matching the
    -- source. The tautology "c.gradelevel = c.gradelevel" is preserved verbatim, so
    -- dependents match on gradetype+payplan only -- a source quirk kept as-is.)
    UPDATE bahgradelevel t
    SET cost = crunch.getreservecomponentbah(
                   b.ratewithdependents,
                   b.ratewithoutdependents,
                   c.totalmembers,
                   c.memberswithdependents,
                   c.memberswithoutdependents)
    FROM nonlocalitybahrates b
    LEFT OUTER JOIN dmdcdependents c
        ON b.gradetype = c.gradetype
       AND c.gradelevel = c.gradelevel
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND t.payplan = c.payplan
      AND t.payplan IN ('NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- prorate monthly rates to active-duty days for NG/R
    v_daysinyear     := crunch.getsinglevalue('AA', 'daysinyear', p_amcosversionid);
    v_activedutydays := crunch.getsinglevalue('AA', 'activedays', p_amcosversionid);

    UPDATE bahgradelevel
    SET cost = cost * 12 / v_daysinyear * v_activedutydays
    WHERE payplan NOT IN ('AE', 'AO', 'AWO');

    -- cost element ids by pay plan
    UPDATE bahgradelevel
    SET costelementid = CASE payplan
                            WHEN 'AE'  THEN 2
                            WHEN 'AO'  THEN 129
                            WHEN 'AWO' THEN 205
                            WHEN 'RO'  THEN 526
                            WHEN 'RE'  THEN 456
                            WHEN 'RWO' THEN 580
                            WHEN 'NO'  THEN 362
                            WHEN 'NE'  THEN 292
                            WHEN 'NWO' THEN 416
                            ELSE -1
                        END;

    ----------------------------------------------------------------------------
    -- spread grade-level cost across the category-subgroup inventory
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS bahfinal;
    CREATE TEMP TABLE bahfinal (
        payplan              varchar(3),
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        cost                 numeric(16, 2),
        inventory            integer,
        costelementid        integer
    );
    INSERT INTO bahfinal
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, inventory)
    SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
           SUM(inventory) AS inventory
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

    -- bring in the (subgroup-uniform) cost + CE id (de-aliased LEFT->inner; cost
    -- and costelementid start NULL so unmatched rows stay NULL -> caught below)
    UPDATE bahfinal t
    SET cost = b.cost,
        costelementid = b.costelementid
    FROM bahgradelevel b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel
      AND t.gradetype = b.gradetype;

    ----------------------------------------------------------------------------
    -- BAH by location & dependent status (+ COLA)
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS bahbylocationanddependentstatus;
    CREATE TEMP TABLE bahbylocationanddependentstatus (
        mha                  varchar(5),
        gradetype            varchar(3),
        gradelevel           smallint,
        withdependents       integer,
        dependentstatus      varchar(15),
        numwithdependents    integer,
        numwithoutdependents integer,
        bahamount            numeric(16, 2),
        colabase             numeric(16, 2),
        colaindex            numeric(16, 2),
        colaamount           numeric(16, 2),
        amcosversionid       integer
    );
    -- source seeds num* / dependentstatus with '' (0 / empty for the int / text cols)
    INSERT INTO bahbylocationanddependentstatus
        (mha, gradetype, gradelevel, withdependents, dependentstatus,
         numwithdependents, numwithoutdependents, bahamount, colaamount, amcosversionid)
    SELECT mha, gradetype, gradelevel, withdependents::int, '',
           0, 0, amount * 12, 0.0, amcosversionid
    FROM dataload.bahrates
    WHERE amcosversionid = p_amcosversionid
    UNION
    -- duplicate rows (withdependents = 99) used for the average-cost-of-dependents calc
    SELECT mha, gradetype, gradelevel, 99, '',
           0, 0, 0, 0.0, amcosversionid
    FROM dataload.bahrates
    WHERE amcosversionid = p_amcosversionid
      AND withdependents = 1;

    -- bring in the dependent counts (de-aliased) for the average rows only
    UPDATE bahbylocationanddependentstatus t
    SET numwithdependents = b.memberswithdependents,
        numwithoutdependents = b.memberswithoutdependents
    FROM dmdcdependents b
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND b.payplan IN ('AE', 'AO', 'AWO')   -- no BAH-location calc for ARNG/USAR
      AND t.withdependents = 99;             -- dependent info only needed for the average

    -- BAH weighted average (T-SQL PIVOT -> FILTER); self-join via subquery in FROM
    UPDATE bahbylocationanddependentstatus t
    SET bahamount = (t.numwithdependents * b.d1 + t.numwithoutdependents * b.d0)
                    / NULLIF(t.numwithdependents + t.numwithoutdependents, 0)
    FROM (
        SELECT gradetype, gradelevel, mha,
               MAX(bahamount) FILTER (WHERE withdependents = 0) AS d0,
               MAX(bahamount) FILTER (WHERE withdependents = 1) AS d1
        FROM bahbylocationanddependentstatus
        GROUP BY gradetype, gradelevel, mha
    ) AS b
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND t.mha = b.mha
      AND t.withdependents = 99;

    -- pay-plan average COLA from the budget (all inventory, not just known)
    SELECT crunch.getarmybudgetsinglevalue('AE_Bdgt_CONUS_COLA', 'MPA', 'Avg', p_amcosversionid)
           / NULLIF(SUM(inventory), 0)
    INTO v_ae_conuscola_avg
    FROM data.inventory
    WHERE amcosversionid = p_amcosversionid
      AND payplan = 'AE';

    SELECT crunch.getarmybudgetsinglevalue('AO_AWO_Bdgt_CONUS_COLA', 'MPA', 'Avg', p_amcosversionid)
           / NULLIF(SUM(inventory), 0)
    INTO v_ao_awo_conuscola_avg
    FROM data.inventory
    WHERE amcosversionid = p_amcosversionid
      AND payplan IN ('AO', 'AWO');

    ----------------------------------------------------------------------------
    -- COLA base is by YoS; weight to grade level for display
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS weightedcola;
    CREATE TEMP TABLE weightedcola (
        gradetype      varchar(3),
        gradelevel     smallint,
        withdependents integer,
        weightedamount numeric(16, 2),
        amcosversionid integer
    );
    INSERT INTO weightedcola (gradetype, gradelevel, withdependents, weightedamount, amcosversionid)
    SELECT gradetype, gradelevel, withdependents,
           SUM(amount * inventory) / NULLIF(SUM(inventory), 0) AS weightedamount,
           amcosversionid
    FROM (
        SELECT a.*, b.inventory
        FROM dataload.conuscola AS a
        INNER JOIN (
            SELECT gradetype, gradelevel, modifiedyearsofservice, SUM(inventory) AS inventory
            FROM (
                -- COLA data is only by even YoS, so round odd years down (3 kept as-is)
                SELECT gradetype,
                       gradelevel,
                       CASE
                           WHEN yos < 2 THEN 0
                           WHEN yos = 3 THEN 3
                           WHEN yos % 2 = 1 THEN yos - 1
                           ELSE yos
                       END AS modifiedyearsofservice,
                       yos,
                       inventory
                FROM data.knowninventory
                WHERE payplan IN ('AE', 'AO', 'AWO')
                  AND amcosversionid = p_amcosversionid   -- filter out unknown YoS
            ) AS a
            GROUP BY gradetype, gradelevel, modifiedyearsofservice
        ) AS b
            ON a.gradetype = b.gradetype
           AND a.gradelevel = b.gradelevel
           AND a.yos::int = b.modifiedyearsofservice   -- ConusCola.yos is text -> cast
    ) AS a
    GROUP BY gradetype, gradelevel, withdependents, amcosversionid;

    -- COLA base for the average rows (T-SQL PIVOT -> FILTER)
    UPDATE bahbylocationanddependentstatus t
    SET colabase = (t.numwithdependents * b.d1 + t.numwithoutdependents * b.d0)
                   / NULLIF(t.numwithdependents + t.numwithoutdependents, 0)
    FROM (
        SELECT gradetype, gradelevel,
               MAX(weightedamount) FILTER (WHERE withdependents = 0) AS d0,
               MAX(weightedamount) FILTER (WHERE withdependents = 1) AS d1
        FROM weightedcola
        GROUP BY gradetype, gradelevel
    ) AS b
    WHERE t.gradetype = b.gradetype
      AND t.gradelevel = b.gradelevel
      AND t.withdependents = 99;

    -- COLA base for the with/without rows (de-aliased; withdependents = 99 rows
    -- don't match weightedcola's 0/1 so they keep the pivot value above)
    UPDATE bahbylocationanddependentstatus t
    SET colabase = b.weightedamount
    FROM weightedcola b
    WHERE t.gradelevel = b.gradelevel
      AND t.gradetype = b.gradetype
      AND t.withdependents = b.withdependents;

    -- COLA index by MHA (de-aliased LEFT->inner; colaindex starts NULL so
    -- unmatched MHAs stay NULL and get 0 COLA below, matching the source)
    UPDATE bahbylocationanddependentstatus t
    SET colaindex = b.dutystationindex
    FROM (
        SELECT mha, dutystationindex, amcosversionid
        FROM (
            SELECT a.dutystationindex, x.mha, a.amcosversionid
            FROM dataload.conuscolalocations AS a
            INNER JOIN xwalk.ziptomha AS x
                ON a.zipcode = x.zipcode
               AND a.amcosversionid = x.amcosversionid
            WHERE a.amcosversionid = p_amcosversionid
        ) AS a
        GROUP BY mha, dutystationindex, amcosversionid
    ) AS b
    WHERE b.mha = t.mha;

    -- COLA amount (monthly -> annual); NULL index means the MHA gets no COLA
    UPDATE bahbylocationanddependentstatus
    SET colaamount = COALESCE(colabase * colaindex * 12, 0);

    -- normalize dependent-status nomenclature for the eventual insert
    UPDATE bahbylocationanddependentstatus SET dependentstatus = 'with'    WHERE withdependents = 1;
    UPDATE bahbylocationanddependentstatus SET dependentstatus = 'without' WHERE withdependents = 0;
    UPDATE bahbylocationanddependentstatus SET dependentstatus = 'average' WHERE withdependents = 99;

    ----------------------------------------------------------------------------
    -- explode to category subgroup + location for insertion
    ----------------------------------------------------------------------------
    DROP TABLE IF EXISTS bahlocdepbysubgroup;
    CREATE TEMP TABLE bahlocdepbysubgroup (
        mha                  varchar(5),
        locationid           integer,
        payplan              varchar(3),
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        withdependents       integer,
        dependentstatus      varchar(15),
        numwithdependents    integer,
        numwithoutdependents integer,
        bahamount            numeric(16, 2),
        colabase             numeric(16, 2),
        colaindex            numeric(16, 2),
        colaamount           numeric(16, 2),
        amcosversionid       integer
    );
    INSERT INTO bahlocdepbysubgroup
        (mha, locationid, payplan, categorygroupcode, categorysubgroupcode, gradetype,
         gradelevel, withdependents, dependentstatus, numwithdependents, numwithoutdependents,
         bahamount, colabase, colaindex, colaamount, amcosversionid)
    SELECT b.mha,
           l.locationid,
           i.payplan,
           i.categorygroupcode,
           i.categorysubgroupcode,
           i.gradetype,
           i.gradelevel,
           b.withdependents,
           b.dependentstatus,
           b.numwithdependents,
           b.numwithoutdependents,
           b.bahamount,
           b.colabase,
           b.colaindex,
           b.colaamount,
           b.amcosversionid
    FROM knowninventorybycategorysubgroup AS i
    INNER JOIN bahbylocationanddependentstatus AS b
        ON i.gradetype = b.gradetype
       AND i.gradelevel = b.gradelevel
    LEFT OUTER JOIN warehouse.location l
        ON b.mha = l.sourcesystemcode;

    ----------------------------------------------------------------------------
    -- guard: no NULL costs allowed
    ----------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM bahfinal WHERE cost IS NULL) THEN
        RAISE EXCEPTION 'null values not allowed, check output';
    END IF;

    ----------------------------------------------------------------------------
    -- writes (dry run when p_debug = true)
    ----------------------------------------------------------------------------
    IF NOT p_debug THEN
        -- clear the CE ids we are about to (re)insert
        DELETE FROM crunch.costs_ae  a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne  a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no  a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re  a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro  a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo a WHERE EXISTS (SELECT 1 FROM bahfinal f WHERE a.costelementid = f.costelementid) AND a.amcosversionid = p_amcosversionid;

        -- clear the COLA CE ids (A-series; BAH/MHA rows already cleared above)
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (4212) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (4213) AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (4214) AND amcosversionid = p_amcosversionid;

        -- grade-level BAH (CE ids already stamped on bahfinal), one insert per pay plan
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid, -1
        FROM bahfinal WHERE payplan = 'AE';

        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid, -1
        FROM bahfinal WHERE payplan = 'AO';

        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid, -1
        FROM bahfinal WHERE payplan = 'AWO';

        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM bahfinal WHERE payplan = 'NE';

        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM bahfinal WHERE payplan = 'NO';

        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM bahfinal WHERE payplan = 'NWO';

        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM bahfinal WHERE payplan = 'RE';

        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM bahfinal WHERE payplan = 'RO';

        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel, -1, cost, v_crunchtime, p_amcosversionid
        FROM bahfinal WHERE payplan = 'RWO';

        -- location-based BAH + COLA inserts (A-series)
        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, costelementid, cmf, mos, gradetype, gradelevel, weaponsystemid, amount, mha, locationid, dependentstatus, crunchtime, amcosversionid)
        SELECT payplan, 2, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, bahamount, mha, locationid, dependentstatus, v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AE'
        UNION
        SELECT payplan, 4212, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, colaamount, mha, locationid, dependentstatus, v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AE' AND COALESCE(colaamount, 0) > 0
        UNION
        -- pay-plan-average COLA (location unspecific)
        SELECT payplan, 4212, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, v_ae_conuscola_avg, '-1', -1, '-1', v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AE';

        -- AO
        INSERT INTO crunch.costs_ao
            (payplan, costelementid, cmf, aoc, gradetype, gradelevel, weaponsystemid, amount, mha, locationid, dependentstatus, crunchtime, amcosversionid)
        SELECT payplan, 129, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, bahamount, mha, locationid, dependentstatus, v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AO'
        UNION
        SELECT payplan, 4213, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, colaamount, mha, locationid, dependentstatus, v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AO' AND COALESCE(colaamount, 0) > 0
        UNION
        SELECT payplan, 4213, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, v_ao_awo_conuscola_avg, '-1', -1, '-1', v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AO';

        -- AWO
        INSERT INTO crunch.costs_awo
            (payplan, costelementid, branch, womos, gradetype, gradelevel, weaponsystemid, amount, mha, locationid, dependentstatus, crunchtime, amcosversionid)
        SELECT payplan, 205, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, bahamount, mha, locationid, dependentstatus, v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AWO'
        UNION
        SELECT payplan, 4214, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, colaamount, mha, locationid, dependentstatus, v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AWO' AND COALESCE(colaamount, 0) > 0
        UNION
        SELECT payplan, 4214, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, -1, v_ao_awo_conuscola_avg, '-1', -1, '-1', v_crunchtime, p_amcosversionid
        FROM bahlocdepbysubgroup WHERE payplan = 'AWO';
    END IF;

    DROP TABLE IF EXISTS knowninventorybycategorysubgroup;
    DROP TABLE IF EXISTS dmdcbah;
    DROP TABLE IF EXISTS dmdcdependents;
    DROP TABLE IF EXISTS nonlocalitybahrates;
    DROP TABLE IF EXISTS bahgradelevel;
    DROP TABLE IF EXISTS bahfinal;
    DROP TABLE IF EXISTS bahbylocationanddependentstatus;
    DROP TABLE IF EXISTS weightedcola;
    DROP TABLE IF EXISTS bahlocdepbysubgroup;
END;
$$;

------------------------------------------------------------------------------
-- crunch.costofspecialpays  (Special Pays calculation)
--
-- Faithful PostgreSQL/plpgsql port of
-- AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CostOfSpecialPays.sql
-- (Author: Dan Hogan, 9/26/2018).
--
-- Reads processed pay (crunch.payprocessed, populated in Phase 2 by DMDCPay),
-- applies per-pay-type caps and AMCOS CostElementId assignments, drops zero/no-
-- inventory rows, then writes the nine military crunch.costs_* tables plus the
-- per-plan "Total" CE rows (AE 55, NE 3942, RE 3945, AO 162, NO 3943, RO 3946,
-- AWO 236, NWO 3944, RWO 3947).
--
-- Conventions (per PORT_CONVENTIONS.md):
--   * p_debug = true is a DRY RUN: source performed DELETE/INSERT writes only
--     under "IF @Debug = 0"; those are guarded here by "IF NOT p_debug".
--     The "IF @Debug = 1" result-set dump blocks have no runtime effect and are
--     dropped.
--   * #temp -> CREATE TEMP TABLE, with DROP TABLE IF EXISTS before each create
--     and again at proc end.
--   * NVARCHAR->varchar, TINYINT->smallint, FLOAT->double precision,
--     BIT->boolean, LEFT->left, string "+" -> "||", @var->p_/v_.
--   * Every CostElementId, pay-plan literal and numeric cap constant preserved
--     verbatim.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofspecialpays(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime timestamp := COALESCE(p_crunchtime, now()::timestamp);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS dmdcspecialpayprocessed;
    CREATE TEMP TABLE dmdcspecialpayprocessed (
        paytype              varchar(255),
        payplan              varchar(3),
        categorygroupcode    varchar(4),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        avg_cost             double precision,
        amcosversionid       integer,
        avg_annual_pay       double precision,
        avg_annual_payments  double precision,
        costelementid        integer,
        pay_cap              double precision,
        capped_avg_mpa_pay   double precision,
        aggregation_group    varchar(50)
    );

    INSERT INTO dmdcspecialpayprocessed
        (paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
         gradelevel, avg_cost, amcosversionid, avg_annual_pay, avg_annual_payments,
         costelementid, pay_cap, capped_avg_mpa_pay, aggregation_group)
    SELECT paytype,
           payplan,
           categorygroupcode,
           categorysubgroupcode,
           gradetype,
           gradelevel,
           avg_cost,
           amcosversionid,
           avg_annual_pay,
           avg_annual_payments,
           0 AS costelementid,
           0.0 AS pay_cap,
           0.0 AS capped_avg_mpa_pay,
           '' AS aggregation_group
    FROM crunch.payprocessed
    WHERE amcosversionid = p_amcosversionid
          -- if there is no pay then don't worry about the row
          AND avg_cost > 0
          AND (
              paytype IN (
                  -- broadly applicable pay types: taken for any pay plan
                  'All Hazardous Duty Pays', 'Aviation Career Incentive Pay',
                  'Board Certification Pay-Veterinarians', 'Career Sea Pay',
                  'Dental Officers Incentive Special Pay', 'Dental Officers Variable Special Pay',
                  'Diving Duty Pay', 'FLPB Total', 'Hardship Pay for Certain Places',
                  'Hardship Pay for Designated Area', 'Hardship Pay-Mission Assignment',
                  'Hostile Fire and Imminent Danger Pay', 'Medical Officer Additional Special Pay',
                  'Medical Officer Board Certified Pay', 'Medical Officer Incentive Special Pay',
                  'Medical Officer Multi-Year Special Pay Bonus', 'Medical Officer Variable Special Pay',
                  'Military Occ Spclty Conversion Bonus', 'Optometrist Regular Special Pay',
                  'Registered Nurse Accession Bonus', 'Veterinarians Special Pay',
                  'Dental Officers Board Certification Pay', 'Non-Phys Hlthcare Provider Board Cert Pay',
                  'Dental Officers Additional Special Pay', 'Health Profession Officers Retention Bonus',
                  'Incentive Pay for Reg Nurse Anesthetists', 'Special Duty Assignment Pay-Enlisted',
                  'Aviator Retention Bonus', 'Selected Reserve Critically Short Wartime Health S',
                  'Special Pay for Extending Duty at Designated Locations Overseas (Also called Overseas Tour Extension'
              )
              OR
              -- pay types applied only to the reserve components (residual/inaccurate for active)
              (
                  payplan NOT IN ('AE', 'AO', 'AWO')
                  AND paytype IN ('Designated Unit Pay', 'Bonus for IRR and ING', 'Incapacitation Pay')
              )
          );

    -- Incapacitation Pay: income-replacement, no cap (pay_cap = -1)
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = -1,
        costelementid = CASE
                            WHEN payplan = 'NE' THEN 3936
                            WHEN payplan = 'RE' THEN 3939
                            WHEN payplan = 'NO' THEN 3937
                            WHEN payplan = 'RO' THEN 3940
                            WHEN payplan = 'NWO' THEN 3938
                            WHEN payplan = 'RWO' THEN 3941
                        END
    WHERE paytype = 'Incapacitation Pay';

    -- Hostile Fire and Imminent Danger Pay
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 225 * 12,
        costelementid = CASE
                            WHEN payplan = 'AE' THEN 3927
                            WHEN payplan = 'NE' THEN 3930
                            WHEN payplan = 'RE' THEN 3933
                            WHEN payplan = 'AO' THEN 3928
                            WHEN payplan = 'NO' THEN 3931
                            WHEN payplan = 'RO' THEN 3934
                            WHEN payplan = 'AWO' THEN 3929
                            WHEN payplan = 'NWO' THEN 3932
                            WHEN payplan = 'RWO' THEN 3935
                        END
    WHERE paytype = 'Hostile Fire and Imminent Danger Pay';

    -- All Hazardous Duty Pays (HALO + other HDIP)
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = (225 * 12) + (150 * 12),
        costelementid = CASE
                            WHEN payplan = 'AE' THEN 50
                            WHEN payplan = 'NE' THEN 3921
                            WHEN payplan = 'RE' THEN 3924
                            WHEN payplan = 'AO' THEN 158
                            WHEN payplan = 'NO' THEN 3922
                            WHEN payplan = 'RO' THEN 3925
                            WHEN payplan = 'AWO' THEN 232
                            WHEN payplan = 'NWO' THEN 3923
                            WHEN payplan = 'RWO' THEN 3926
                        END
    WHERE paytype = 'All Hazardous Duty Pays';

    -- Hardship Duty Pay
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 150 * 12,
        costelementid = CASE
                            WHEN payplan = 'AE' THEN 3948
                            WHEN payplan = 'NE' THEN 3951
                            WHEN payplan = 'RE' THEN 3954
                            WHEN payplan = 'AO' THEN 3949
                            WHEN payplan = 'NO' THEN 3952
                            WHEN payplan = 'RO' THEN 3955
                            WHEN payplan = 'AWO' THEN 3950
                            WHEN payplan = 'NWO' THEN 3953
                            WHEN payplan = 'RWO' THEN 3956
                        END
    WHERE paytype IN ('Hardship Pay for Certain Places', 'Hardship Pay for Designated Area',
                      'Hardship Pay-Mission Assignment');

    -- SDAP / Overseas Tour Extension (enlisted): higher cap, reuse Hardship CE ids
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 450 * 12,
        costelementid = CASE
                            WHEN payplan = 'AE' THEN 3948
                            WHEN payplan = 'NE' THEN 3951
                            WHEN payplan = 'RE' THEN 3954
                        END
    WHERE paytype IN ('Special Duty Assignment Pay-Enlisted',
                      'Special Pay for Extending Duty at Designated Locations Overseas (Also called Overseas Tour Extension')
          AND gradetype = 'E';

    -- Foreign Language Pay (FLPB)
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 12000,
        costelementid = CASE
                            WHEN payplan = 'AE' THEN 51
                            WHEN payplan = 'NE' THEN 3915
                            WHEN payplan = 'RE' THEN 3918
                            WHEN payplan = 'AO' THEN 159
                            WHEN payplan = 'NO' THEN 3916
                            WHEN payplan = 'RO' THEN 3919
                            WHEN payplan = 'AWO' THEN 233
                            WHEN payplan = 'NWO' THEN 3917
                            WHEN payplan = 'RWO' THEN 3920
                        END
    WHERE paytype = 'FLPB Total';

    -- Diving Duty Pay: cap by category/grade, then assign CE ids
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 240 * 12
    WHERE paytype = 'Diving Duty Pay'
          AND (
              (categorygroupcode IN ('11', '18', '60', '61', '62', '65') AND gradetype IN ('O'))
              OR (categorysubgroupcode IN ('180A') AND gradetype IN ('W'))
          );

    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 340 * 12
    WHERE paytype = 'Diving Duty Pay'
          AND (
              (categorygroupcode IN ('12', '18') AND gradetype = 'O')
              OR ((categorysubgroupcode IN ('68W', '12D') OR categorygroupcode IN ('18')) AND gradetype = 'E')
              OR (categorygroupcode IN ('18') AND gradetype = 'W')
          );

    UPDATE dmdcspecialpayprocessed
    SET costelementid = CASE
                            WHEN payplan = 'AE' THEN 47
                            WHEN payplan = 'NE' THEN 3909
                            WHEN payplan = 'RE' THEN 3912
                            WHEN payplan = 'AO' THEN 156
                            WHEN payplan = 'NO' THEN 3910
                            WHEN payplan = 'RO' THEN 3913
                            WHEN payplan = 'AWO' THEN 230
                            WHEN payplan = 'NWO' THEN 3911
                            WHEN payplan = 'RWO' THEN 3914
                        END
    WHERE paytype = 'Diving Duty Pay';

    -- Consolidated Special Pays (medical incentive): cap 100000
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 100000,
        aggregation_group = 'medical incentive'
    WHERE paytype IN ('Dental Officers Additional Special Pay', 'Dental Officers Incentive Special Pay',
                      'Dental Officers Variable Special Pay', 'Medical Officer Additional Special Pay',
                      'Medical Officer Incentive Special Pay', 'Medical Officer Variable Special Pay',
                      'Optometrist Regular Special Pay', 'Veterinarians Special Pay',
                      'Selected Reserve Critically Short Wartime Health S')
          AND categorygroupcode IN (
              SELECT code
              FROM lookup.cmf_branch_fa
              WHERE description IN ('DENTAL CORPS', 'MEDICAL CORPS')
                    AND gradetype = 'O'
                    AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
          );

    -- Consolidated Special Pays (medical incentive): cap 15000 (overwrites some 100000 above)
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 15000,
        aggregation_group = 'medical incentive'
    WHERE paytype IN ('Dental Officers Additional Special Pay', 'Dental Officers Incentive Special Pay',
                      'Dental Officers Variable Special Pay', 'Medical Officer Additional Special Pay',
                      'Medical Officer Incentive Special Pay', 'Medical Officer Variable Special Pay',
                      'Optometrist Regular Special Pay', 'Veterinarians Special Pay',
                      'Incentive Pay for Reg Nurse Anesthetists')
          AND categorygroupcode IN (
              SELECT code
              FROM lookup.cmf_branch_fa
              WHERE description IN ('VETERINARY CORPS', 'ARMY MEDICAL SPECIALIST CORPS', 'ARMY NURSE CORPS',
                                    'MEDICAL SERVICE CORPS', 'MEDICAL', 'HEALTH SERVICES', 'LABORATORY SCIENCES',
                                    'PREVENTIVE MEDICINE SCIENCES', 'BEHAVIORAL SCIENCES', 'DENTAL CORPS')
                    AND gradetype = 'O'
                    AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
          );

    -- Registered Nurse Accession Bonus: cap 30000
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 30000
    WHERE paytype IN ('Registered Nurse Accession Bonus')
          AND categorygroupcode IN (
              SELECT code
              FROM lookup.cmf_branch_fa
              WHERE description IN ('VETERINARY CORPS', 'ARMY MEDICAL SPECIALIST CORPS', 'ARMY NURSE CORPS',
                                    'MEDICAL SERVICE CORPS', 'MEDICAL', 'HEALTH SERVICES', 'LABORATORY SCIENCES',
                                    'PREVENTIVE MEDICINE SCIENCES', 'BEHAVIORAL SCIENCES')
                    AND gradetype = 'O'
                    AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
          );

    -- Medical multiyear: cap 75000
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 75000,
        aggregation_group = 'medical multiyear'
    WHERE paytype IN ('Medical Officer Multi-Year Special Pay Bonus', 'Health Profession Officers Retention Bonus')
          AND categorygroupcode IN (
              SELECT code
              FROM lookup.cmf_branch_fa
              WHERE description IN ('VETERINARY CORPS', 'ARMY MEDICAL SPECIALIST CORPS', 'ARMY NURSE CORPS',
                                    'MEDICAL SERVICE CORPS', 'MEDICAL', 'HEALTH SERVICES', 'LABORATORY SCIENCES',
                                    'PREVENTIVE MEDICINE SCIENCES', 'BEHAVIORAL SCIENCES', 'DENTAL CORPS')
                    AND gradetype = 'O'
                    AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
          );

    -- Consolidated Special Pays CE ids
    UPDATE dmdcspecialpayprocessed
    SET costelementid = CASE
                            WHEN payplan = 'AO' THEN 3906
                            WHEN payplan = 'NO' THEN 3908
                            WHEN payplan = 'RO' THEN 3907
                        END
    WHERE paytype IN ('Dental Officers Additional Special Pay', 'Dental Officers Incentive Special Pay',
                      'Dental Officers Variable Special Pay', 'Medical Officer Additional Special Pay',
                      'Medical Officer Incentive Special Pay', 'Medical Officer Multi-Year Special Pay Bonus',
                      'Medical Officer Variable Special Pay', 'Optometrist Regular Special Pay',
                      'Registered Nurse Accession Bonus', 'Veterinarians Special Pay',
                      'Incentive Pay for Reg Nurse Anesthetists', 'Health Profession Officers Retention Bonus');

    -- Career Sea Pay (Transportation Corps officers)
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 534 * 12,
        costelementid = CASE
                            WHEN payplan = 'AE' THEN 3897
                            WHEN payplan = 'NE' THEN 3900
                            WHEN payplan = 'RE' THEN 3903
                            WHEN payplan = 'AO' THEN 3898
                            WHEN payplan = 'NO' THEN 3901
                            WHEN payplan = 'RO' THEN 3904
                            WHEN payplan = 'AWO' THEN 3899
                            WHEN payplan = 'NWO' THEN 3902
                            WHEN payplan = 'RWO' THEN 3905
                        END
    WHERE paytype = 'Career Sea Pay'
          AND categorygroupcode IN (
              SELECT code
              FROM lookup.cmf_branch_fa
              WHERE description IN ('TRANSPORTATION CORPS')
                    AND gradetype = 'O'
                    AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
          );

    -- Board Certification Pay (any medical professional, officer): cap 6000
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 6000
    WHERE paytype IN ('Medical Officer Board Certified Pay', 'Dental Officers Board Certification Pay',
                      'Board Certification Pay-Veterinarians', 'Non-Phys Hlthcare Provider Board Cert Pay')
          AND (
              left(categorygroupcode, 1) = '6'
              OR categorygroupcode IN ('72', '73')
          )
          AND gradetype = 'O';

    UPDATE dmdcspecialpayprocessed
    SET costelementid = CASE
                            WHEN payplan = 'AO' THEN 3894
                            WHEN payplan = 'NO' THEN 3896
                            WHEN payplan = 'RO' THEN 3895
                        END
    WHERE paytype IN ('Medical Officer Board Certified Pay', 'Dental Officers Board Certification Pay',
                      'Board Certification Pay-Veterinarians', 'Non-Phys Hlthcare Provider Board Cert Pay');

    -- Aviation Career Incentive Pay (officers): cap 250/mo
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 250 * 12
    WHERE paytype = 'Aviation Career Incentive Pay'
          AND (
              categorygroupcode IN (
                  SELECT code
                  FROM lookup.cmf_branch_fa
                  WHERE description IN ('AVIATION', 'SPECIAL FORCES')
                        AND gradetype = 'O'
                        AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
              )
              OR categorysubgroupcode IN ('67J')
          )
          AND dmdcspecialpayprocessed.gradetype = 'O';

    -- Aviation Career Incentive Pay (warrants): cap 350/mo
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 350 * 12
    WHERE paytype = 'Aviation Career Incentive Pay'
          AND categorygroupcode IN (
              SELECT code
              FROM lookup.cmf_branch_fa
              WHERE description IN ('AVIATION')
                    AND gradetype = 'W'
                    AND (p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend)
          )
          AND dmdcspecialpayprocessed.gradetype = 'W';

    -- Aviator Retention Bonus (warrants): cap 25000
    UPDATE dmdcspecialpayprocessed
    SET pay_cap = 25000
    WHERE paytype = 'Aviator Retention Bonus'
          AND dmdcspecialpayprocessed.gradetype = 'W';

    UPDATE dmdcspecialpayprocessed
    SET costelementid = CASE
                            WHEN payplan = 'AO' THEN 3888
                            WHEN payplan = 'NO' THEN 3892
                            WHEN payplan = 'RO' THEN 3890
                            WHEN payplan = 'AWO' THEN 3889
                            WHEN payplan = 'NWO' THEN 3893
                            WHEN payplan = 'RWO' THEN 3891
                        END
    WHERE paytype IN ('Aviation Career Incentive Pay', 'Aviator Retention Bonus');

    -- implement pay caps
    UPDATE dmdcspecialpayprocessed
    SET capped_avg_mpa_pay = CASE
                                 WHEN pay_cap = -1 THEN avg_cost              -- no cap
                                 WHEN pay_cap > -1 AND pay_cap >= avg_cost THEN avg_cost -- below cap
                                 ELSE pay_cap                                 -- above cap
                             END;

    -- drop zero-pay rows and aggregate up to the AMCOS CE level from the DMDC pay type level
    DROP TABLE IF EXISTS dmdcspecialpayprocessedfinal;
    CREATE TEMP TABLE dmdcspecialpayprocessedfinal (
        payplan              varchar(3),
        categorygroupcode    varchar(4),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        avg_cost             double precision,
        amcosversionid       integer,
        avg_annual_pay       double precision,
        avg_annual_payments  double precision,
        costelementid        integer,
        pay_cap              double precision,
        capped_avg_mpa_pay   double precision
    );

    INSERT INTO dmdcspecialpayprocessedfinal
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
         costelementid, capped_avg_mpa_pay, amcosversionid)
    SELECT payplan,
           categorygroupcode,
           categorysubgroupcode,
           gradetype,
           gradelevel,
           costelementid,
           SUM(capped_avg_mpa_pay),
           p_amcosversionid
    FROM (
        -- avg within aggregation groups of pay types before summing, so a pay
        -- type that transitions to a new type year-over-year is not double counted
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               gradetype,
               gradelevel,
               costelementid,
               AVG(capped_avg_mpa_pay) AS capped_avg_mpa_pay,
               aggregation_group
        FROM dmdcspecialpayprocessed
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype,
                 gradelevel, costelementid, aggregation_group
    ) AS a
    WHERE capped_avg_mpa_pay > 0
    GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype,
             gradelevel, costelementid;

    -- prevent costs with no inventory from coming in
    DELETE FROM dmdcspecialpayprocessedfinal
    WHERE payplan || gradelevel::varchar || categorysubgroupcode NOT IN (
        SELECT DISTINCT payplan || gradelevel::varchar || categorysubgroupcode
        FROM data.knowninventory
        WHERE amcosversionid = p_amcosversionid
    );

    IF NOT p_debug THEN

        -- clear out existing Special Pays CE rows for each plan before re-inserting
        DELETE FROM crunch.costs_ae
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_re
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ne
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ro
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_no
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_rwo
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_nwo
        WHERE costelementid IN (SELECT costelementid FROM lookup.costelement WHERE costelementcategory = 'Special Pays')
              AND amcosversionid = p_amcosversionid;

        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime,
               p_amcosversionid, -1
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'AE'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- RE
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'RE'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- NE
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'NE'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- AO
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime,
               p_amcosversionid, -1
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'AO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- RO
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'RO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- NO
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'NO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- AWO
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime,
               p_amcosversionid, -1
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'AWO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- RWO
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'RWO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- NWO
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, costelementid,
               gradetype, gradelevel, -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'NWO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradetype, gradelevel;

        -- Insert Totals (per-plan aggregate CE ids)
        -- AE total (CE 55)
        DELETE FROM crunch.costs_ae WHERE costelementid = 55 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 55, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid, -1
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'AE'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- NE total (CE 3942)
        DELETE FROM crunch.costs_ne WHERE costelementid = 3942 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3942, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'NE'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- RE total (CE 3945)
        DELETE FROM crunch.costs_re WHERE costelementid = 3945 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3945, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'RE'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- AO total (CE 162)
        DELETE FROM crunch.costs_ao WHERE costelementid = 162 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 162, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid, -1
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'AO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- NO total (CE 3943)
        DELETE FROM crunch.costs_no WHERE costelementid = 3943 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3943, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'NO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- RO total (CE 3946)
        DELETE FROM crunch.costs_ro WHERE costelementid = 3946 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3946, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'RO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- AWO total (CE 236)
        DELETE FROM crunch.costs_awo WHERE costelementid = 236 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 236, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid, -1
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'AWO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- NWO total (CE 3944)
        DELETE FROM crunch.costs_nwo WHERE costelementid = 3944 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3944, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'NWO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

        -- RWO total (CE 3947)
        DELETE FROM crunch.costs_rwo WHERE costelementid = 3947 AND amcosversionid = p_amcosversionid;
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, categorysubgroupcode, 3947, gradetype, gradelevel,
               -1, SUM(capped_avg_mpa_pay), v_crunchtime, p_amcosversionid
        FROM dmdcspecialpayprocessedfinal
        WHERE payplan = 'RWO'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel;

    END IF;

    DROP TABLE IF EXISTS dmdcspecialpayprocessed;
    DROP TABLE IF EXISTS dmdcspecialpayprocessedfinal;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfOverseas  (CE ids: AE 53, AO 161, AWO 235)
-- Cost of Overseas Allowances (OCONUS COLA + OHA rental/utility/MIHA).
--
-- Faithful structural port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
-- CostOfOverseas.sql. Two output passes, both guarded by "IF NOT p_debug":
--   1. A non-location-specific average cost (budget spread by DMDC-pay share,
--      per grade level, over inventory) -> crunch.costs_ae/ao/awo.
--   2. A location-specific (loccode/MHA) OCONUS COLA + OHA cost, weighted by
--      inventory and dependent status -> crunch.costs_ae/ao/awo (same CE ids;
--      the pass-1 DELETE already cleared the prior rows, per the source).
--
-- Reads: data.knowninventory, "DMDC".pay, "DMDC".membersanddependents,
--        dataload.militaryannualcomp, dataload.militaryspendableincome,
--        dataload.militaryoverseashousingallowance, warehouse.location.
-- Calls: crunch.getarmybudgetsinglevalue.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofoverseas(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime     timestamp := COALESCE(p_crunchtime, now()::timestamp);
    v_ao_awo_budget  numeric(20, 2);
    v_ae_budget      numeric(20, 2);
    v_ce_ae          integer := 53;
    v_ce_ao          integer := 161;
    v_ce_awo         integer := 235;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- ================= Non-location-specific average overseas cost =================

    DROP TABLE IF EXISTS ovinventory;
    CREATE TEMP TABLE ovinventory (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        inventory            integer,
        amcosversionid       integer,
        amount               numeric(15, 2)
    );

    -- all the military inventory at the subgroup level (active only)
    INSERT INTO ovinventory
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory, amcosversionid)
    SELECT payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
           SUM(inventory) AS inventory, amcosversionid
    FROM data.knowninventory
    WHERE payplan IN ('AE', 'AO', 'AWO')
      AND amcosversionid = p_amcosversionid
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid;

    DROP TABLE IF EXISTS overseaspaybyversion;
    CREATE TEMP TABLE overseaspaybyversion (
        paytype        text,
        payplan        varchar(3),
        gradelevel     smallint,
        amount         numeric,
        amcosversionid integer
    );

    INSERT INTO overseaspaybyversion
        (paytype, payplan, gradelevel, amount, amcosversionid)
    SELECT paytype, payplan, gradelevel, SUM(totalpayamount), amcosversionid
    FROM "DMDC".pay
    WHERE paytype IN ('OCONUS 1 COLA Barracks', 'OCONUS 1 Cost of Living', 'OCONUS 2 COLA Barracks',
                      'OCONUS 2 Cost of Living', 'OHA MIHA Miscellaneous', 'OHA MIHA Rent', 'OHA MIHA Security')
      AND payplan IN ('AO', 'AE', 'AWO')
      AND amcosversionid IN
          -- only the most recent 3 years of DMDC data for the sliding average
          (
              SELECT amcosversionid
              FROM "DMDC".pay
              WHERE amcosversionid <= p_amcosversionid
              GROUP BY amcosversionid
              ORDER BY amcosversionid DESC
              LIMIT 3
          )
    GROUP BY paytype, payplan, gradelevel, amcosversionid;

    DROP TABLE IF EXISTS avgoverseaspay;
    CREATE TEMP TABLE avgoverseaspay (
        payplan         varchar(3),
        gradelevel      smallint,
        gradeconformed  varchar(1),
        dmdcpay         numeric,
        budgetamt       numeric(15, 2),
        percentofbudget double precision,
        inventory       integer,
        overseasamount  numeric(15, 2)
    );

    -- one single CE (not split by pay type): sum per version, then average across versions
    INSERT INTO avgoverseaspay (payplan, gradelevel, dmdcpay)
    SELECT payplan, gradelevel, AVG(amount) AS amount
    FROM (
        SELECT payplan, gradelevel, amcosversionid, SUM(amount) AS amount
        FROM overseaspaybyversion
        GROUP BY payplan, gradelevel, amcosversionid
    ) AS a
    GROUP BY payplan, gradelevel;

    -- gradetype (budget is only Enlisted (E) and Officer (W & O))
    UPDATE avgoverseaspay SET gradeconformed = 'E' WHERE payplan = 'AE';
    UPDATE avgoverseaspay SET gradeconformed = 'O' WHERE payplan IN ('AO', 'AWO');

    -- budget amounts to divvy across the grade levels
    v_ao_awo_budget := crunch.getarmybudgetsinglevalue('AO_AWO_Bdgt_OCONUS_COLA_OHA', 'MPA', 'Avg', p_amcosversionid);
    v_ae_budget     := crunch.getarmybudgetsinglevalue('Enl_Bdgt_OCONUS_COLA_OHA', 'MPA', 'Avg', p_amcosversionid);

    UPDATE avgoverseaspay SET budgetamt = v_ae_budget     WHERE payplan IN ('AE');
    UPDATE avgoverseaspay SET budgetamt = v_ao_awo_budget WHERE payplan IN ('AO', 'AWO');

    -- percent of the budget each pay plan/grade level should get (share of conformed DMDC pay).
    -- Self-join on avgoverseaspay -> derived subquery in FROM (PG forbids re-aliasing the UPDATE target).
    UPDATE avgoverseaspay t
    SET percentofbudget = b.mypercent
    FROM (
        SELECT payplan,
               gradeconformed,
               gradelevel,
               dmdcpay / SUM(dmdcpay) OVER (PARTITION BY gradeconformed) AS mypercent
        FROM avgoverseaspay
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- bring in inventory. Source LEFT JOIN would leave unmatched rows NULL; column starts
    -- NULL so an inner-join UPDATE..FROM is equivalent (b is a separate table, not a self-scan).
    UPDATE avgoverseaspay t
    SET inventory = b.myinventory
    FROM (
        SELECT payplan, gradelevel, SUM(inventory) AS myinventory
        FROM ovinventory
        GROUP BY payplan, gradelevel
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    -- DMDC-determined portion of the budget divided by inventory (NULLIF guards div-by-zero)
    UPDATE avgoverseaspay
    SET overseasamount = COALESCE(budgetamt * percentofbudget / NULLIF(inventory, 0), 0);

    -- push the average amount back onto the inventory table for the subgroup-level insert
    UPDATE ovinventory t
    SET amount = COALESCE(b.overseasamount, 0)
    FROM avgoverseaspay b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel;

    IF NOT p_debug THEN
        -- clear existing cost rows for the CE ids we are about to insert (covers pass 2 too)
        DELETE FROM crunch.costs_ae  WHERE costelementid IN (v_ce_ae)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_ao  WHERE costelementid IN (v_ce_ao)  AND amcosversionid = p_amcosversionid;
        DELETE FROM crunch.costs_awo WHERE costelementid IN (v_ce_awo) AND amcosversionid = p_amcosversionid;

        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid, dependentstatus)
        SELECT payplan, categorygroupcode, categorysubgroupcode, v_ce_ae, gradetype, gradelevel, -1, amount, v_crunchtime, p_amcosversionid, -1, '-1'
        FROM ovinventory
        WHERE payplan = 'AE';

        -- AO
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid, dependentstatus)
        SELECT payplan, categorygroupcode, categorysubgroupcode, v_ce_ao, gradetype, gradelevel, -1, amount, v_crunchtime, p_amcosversionid, -1, '-1'
        FROM ovinventory
        WHERE payplan = 'AO';

        -- AWO
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid, locationid, dependentstatus)
        SELECT payplan, categorygroupcode, categorysubgroupcode, v_ce_awo, gradetype, gradelevel, -1, amount, v_crunchtime, p_amcosversionid, -1, '-1'
        FROM ovinventory
        WHERE payplan = 'AWO';
    END IF;

    -- ================= Location-specific OCONUS costing =================

    DROP TABLE IF EXISTS dmdcdependents;
    CREATE TEMP TABLE dmdcdependents (
        amcosversionid            integer,
        payplan                   varchar(50),
        gradetype                 varchar(50),
        gradelevel                smallint,   -- source NVARCHAR(50); held numeric-only, kept smallint to
                                              -- match the integer grade levels it is compared against
        averagenumberofdependents integer,
        percentwithdependents     numeric(5, 4)
    );

    INSERT INTO dmdcdependents
        (amcosversionid, gradetype, gradelevel, averagenumberofdependents, percentwithdependents)
    SELECT amcosversionid,
           gradetype,
           gradelevel,
           -- OHA/OCOLA data maxes at 5 dependents; integer division preserved, then rounded
           CASE
               WHEN ROUND((numberofdependents / NULLIF(memberswithdependents, 0))::numeric, 0) > 5 THEN 5
               ELSE ROUND((numberofdependents / NULLIF(memberswithdependents, 0))::numeric, 0)
           END AS avgnumdependents,
           memberswithdependents::double precision / NULLIF(totalmembers, 0) AS percwithdependents
    FROM "DMDC".membersanddependents
    WHERE payplan IN ('AE', 'AO', 'AWO')
      AND amcosversionid = p_amcosversionid;

    DROP TABLE IF EXISTS spendableincome;
    CREATE TEMP TABLE spendableincome (
        hasdependents           smallint,   -- source BIT; read as ::integer so it works whether the
                                            -- dataload column is boolean or numeric
        grade                   varchar(1),
        gradelevel              integer,
        yearsofservice          integer,
        annualcompensation      numeric(16, 2),
        amcosversionid          integer,
        lowerlimit              numeric(16, 2),
        upperlimit              numeric(16, 2),
        numberofdependents      integer,
        spendableincome         numeric(16, 2),
        computedspendableincome numeric(16, 2)
    );

    -- OCONUS COLA is based on spendable income; join annual comp to the spendable-income bands
    INSERT INTO spendableincome
        (hasdependents, grade, gradelevel, yearsofservice, annualcompensation, amcosversionid,
         lowerlimit, upperlimit, numberofdependents, spendableincome, computedspendableincome)
    SELECT s.hasdependents,
           s.grade,
           s.gradelevel,
           s.yos,
           s.annualcompensation,
           s.amcosversionid,
           s.lowerlimit,
           s.upperlimit,
           s.numberofdependents,
           s.spendableincome,
           s.computedspendableincome
    FROM (
        SELECT mac.hasdependents::integer AS hasdependents,
               mac.grade,
               mac.gradelevel,
               mac.yos,
               mac.annualcompensation,
               mac.amcosversionid,
               msi.lowerlimit,
               msi.upperlimit,
               msi.numberofdependents,
               msi.spendableincome,
               -- cross join yields rows outside the limits; those get 0 and are filtered below
               CASE
                   WHEN mac.annualcompensation BETWEEN msi.lowerlimit AND msi.upperlimit THEN msi.spendableincome
                   ELSE 0
               END AS computedspendableincome
        FROM dataload.militaryannualcomp AS mac
            CROSS JOIN dataload.militaryspendableincome AS msi
        WHERE (
                  (msi.numberofdependents = 0 AND mac.hasdependents::integer = 0)
                  OR
                  (msi.numberofdependents >= 1 AND mac.hasdependents::integer = 1)
              )
              AND mac.amcosversionid = msi.amcosversionid
              AND mac.amcosversionid = p_amcosversionid
              AND msi.amcosversionid = p_amcosversionid
    ) AS s
    WHERE s.computedspendableincome > 0;

    DROP TABLE IF EXISTS oconus_cola_oha;
    CREATE TEMP TABLE oconus_cola_oha (
        oconus_cola                  numeric(12, 2),
        rental_amt                   numeric(12, 2),
        utility_amt                  numeric(12, 2),
        miha_amt                     numeric(12, 2),
        loccode                      varchar(5),
        locname                      varchar(75),
        grade                        varchar(1),
        gradelevel                   integer,
        yearsofservice               integer,
        dependents                   integer,
        averagenumberofdependents    integer,
        computedspendableincome      numeric(16, 2),
        kyloc                        varchar(10),
        xrat                         numeric(25, 2),
        ocola_index                  integer,
        ocola_groupcode              integer,
        perc_o_utility_wdep          numeric(10, 2),
        perc_e_utiliy_wdep           numeric(10, 2),
        o_utility_wdep               numeric(10, 2),
        e_utility_wdep               numeric(10, 2),
        perc_o_rentalallowance_wodep numeric(10, 2),
        perc_e_rentalallowance_wodep numeric(10, 2),
        o_miha                       numeric(10, 2),
        e_miha                       numeric(10, 2),
        off_curr_name                varchar(150),
        rentalamt_wdep               numeric(10, 2),
        amcosversionid               integer
    );

    -- index arrives as an integer and is converted to a decimal percent of spendable income
    INSERT INTO oconus_cola_oha
        (oconus_cola, rental_amt, utility_amt, miha_amt, loccode, locname, kyloc, xrat, ocola_index,
         ocola_groupcode, perc_o_utility_wdep, perc_e_utiliy_wdep, o_utility_wdep, e_utility_wdep,
         perc_o_rentalallowance_wodep, perc_e_rentalallowance_wodep, o_miha, e_miha, off_curr_name,
         grade, gradelevel, rentalamt_wdep, amcosversionid, yearsofservice, dependents, computedspendableincome)
    SELECT b.computedspendableincome * (a.ocola_index / 100.00 - 1) AS oconus_annual_cola,
           a.rentalamt_wdep
           * CASE
                 WHEN b.hasdependents = 0 AND a.grade = 'E'  THEN a.perc_e_rentalallowance_wodep / 100.00
                 WHEN b.hasdependents = 0 AND a.grade <> 'E' THEN a.perc_o_rentalallowance_wodep / 100.00
                 ELSE 1
             END * a.xrat / POWER(10.00, 12)   -- currency conversion to dollars
           * 12                                -- rental allowance is monthly; AMCOS wants annual
           AS rental_amt,
           CASE
               WHEN b.hasdependents = 0 AND a.grade = 'E'  THEN a.e_utility_wdep * a.perc_e_utility_wdep / 100.00
               WHEN b.hasdependents = 0 AND a.grade <> 'E' THEN a.o_utility_wdep * a.perc_o_utility_wdep / 100.00
               WHEN b.hasdependents = 1 AND a.grade = 'E'  THEN a.e_utility_wdep
               WHEN b.hasdependents = 1 AND a.grade <> 'E' THEN a.o_utility_wdep
               ELSE 0
           END * a.xrat / POWER(10.00, 12)     -- currency conversion to dollars
           * 12                                -- utility is monthly; AMCOS wants annual
           AS utiliy_amt,
           CASE
               WHEN a.grade = 'E'  THEN a.e_miha
               WHEN a.grade <> 'E' THEN a.o_miha
               ELSE 0
           END * a.xrat / POWER(10.00, 12)     -- currency conversion to dollars
           * 1                                 -- MIHA is a one-time amount; not annualized
           AS miha_amt,
           a.loccode,
           a.locname,
           a.keyloc,
           a.xrat,
           a.ocola_index,
           a.ocola_groupcode,
           a.perc_o_utility_wdep,
           a.perc_e_utility_wdep,
           a.o_utility_wdep,
           a.e_utility_wdep,
           a.perc_o_rentalallowance_wodep,
           a.perc_e_rentalallowance_wodep,
           a.o_miha,
           a.e_miha,
           a.off_curr_name,
           a.grade,
           a.gradelevel,
           a.rentalamt_wdep,
           a.amcosversionid,
           b.yearsofservice,
           b.numberofdependents,
           b.computedspendableincome
    FROM dataload.militaryoverseashousingallowance AS a
        INNER JOIN spendableincome AS b
            ON a.grade = b.grade
               AND a.gradelevel = b.gradelevel
               AND a.amcosversionid = b.amcosversionid
    WHERE a.ocola_index > 0;   -- index 0 means no cola is currently calculated for that area

    -- bring in the avg num dependents (this join orphans most rows, which is intended:
    -- we want the average cost by grade level/grade/avg-number-of-dependents)
    UPDATE oconus_cola_oha t
    SET averagenumberofdependents = b.averagenumberofdependents
    FROM dmdcdependents b
    WHERE b.gradetype = t.grade
      AND b.gradelevel = t.gradelevel
      AND b.averagenumberofdependents = t.dependents;

    -- link the complete OCONUS COLA/OHA (by YoS and dependents) up with inventory
    DROP TABLE IF EXISTS oconus_oha_yos;
    CREATE TEMP TABLE oconus_oha_yos (
        payplan                   varchar(3),
        gradelevel                smallint,
        categorygroupcode         varchar(2),
        categorysubgroupcode      varchar(4),
        gradetype                 varchar(3),
        yearsofservice            integer,
        inventory                 integer,
        amcosversionid            integer,
        oconus_cola               numeric(15, 2),
        rental                    numeric(15, 2),
        utility                   numeric(15, 2),
        miha                      numeric(15, 2),
        averagenumberofdependents integer,
        loccode                   varchar(5),
        dependentweight           numeric(5, 4)
    );

    -- military inventory at the subgroup + YearsOfService level, crossed with every loccode
    INSERT INTO oconus_oha_yos
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, yearsofservice,
         inventory, amcosversionid, averagenumberofdependents, loccode)
    SELECT a.payplan,
           a.gradelevel,
           a.gradetype,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.yos,
           a.inventory,
           a.amcosversionid,
           a.averagenumberofdependents,
           b.loccode
    FROM (
        SELECT payplan,
               gradelevel,
               gradetype,
               categorygroupcode,
               categorysubgroupcode,
               -- input data does not exceed 40 YoS; clamp higher YoS back to 40
               CASE WHEN yos > 40 THEN 40 ELSE yos END AS yos,
               SUM(inventory) AS inventory,
               amcosversionid,
               NULL::integer AS averagenumberofdependents  -- first arm = with dependents (count unknown yet)
        FROM data.knowninventory
        WHERE payplan IN ('AE', 'AO', 'AWO')
          AND amcosversionid = p_amcosversionid
        GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid, yos
        UNION
        SELECT payplan,
               gradelevel,
               gradetype,
               categorygroupcode,
               categorysubgroupcode,
               yos,
               SUM(inventory) AS inventory,
               amcosversionid,
               0 AS averagenumberofdependents             -- second arm = no dependents
        FROM data.knowninventory
        WHERE payplan IN ('AE', 'AO', 'AWO')
          AND amcosversionid = p_amcosversionid
        GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid, yos
    ) AS a
        CROSS JOIN (SELECT loccode FROM oconus_cola_oha GROUP BY loccode) AS b;

    -- costs for no dependents
    UPDATE oconus_oha_yos t
    SET oconus_cola = b.oconus_cola,
        rental      = b.rental_amt,
        utility     = b.utility_amt,
        miha        = b.miha_amt
    FROM oconus_cola_oha b
    WHERE t.gradetype = b.grade
      AND t.gradelevel = b.gradelevel
      AND t.yearsofservice = b.yearsofservice
      AND t.loccode = b.loccode
      AND b.dependents = 0
      AND t.averagenumberofdependents = 0;

    -- costs for those with dependents
    UPDATE oconus_oha_yos t
    SET oconus_cola = b.oconus_cola,
        rental      = b.rental_amt,
        utility     = b.utility_amt,
        miha        = b.miha_amt,
        averagenumberofdependents = b.averagenumberofdependents
    FROM oconus_cola_oha b
    WHERE t.gradetype = b.grade
      AND t.gradelevel = b.gradelevel
      AND t.yearsofservice = b.yearsofservice
      AND t.loccode = b.loccode
      AND b.averagenumberofdependents > 0
      AND t.averagenumberofdependents IS NULL;

    -- no-dependents rows whose YoS has no exact match: drop YoS by one to find a linkage
    UPDATE oconus_oha_yos t
    SET oconus_cola = b.oconus_cola,
        rental      = b.rental_amt,
        utility     = b.utility_amt,
        miha        = b.miha_amt
    FROM oconus_cola_oha b
    WHERE t.gradetype = b.grade
      AND t.gradelevel = b.gradelevel
      AND (t.yearsofservice - 1) = b.yearsofservice
      AND t.loccode = b.loccode
      AND b.dependents = 0
      AND t.averagenumberofdependents = 0
      AND t.oconus_cola IS NULL;

    -- with-dependents rows whose YoS has no exact match: drop YoS by one to find a linkage
    UPDATE oconus_oha_yos t
    SET oconus_cola = b.oconus_cola,
        rental      = b.rental_amt,
        utility     = b.utility_amt,
        miha        = b.miha_amt,
        averagenumberofdependents = b.averagenumberofdependents
    FROM oconus_cola_oha b
    WHERE t.gradetype = b.grade
      AND t.gradelevel = b.gradelevel
      AND (t.yearsofservice - 1) = b.yearsofservice
      AND t.loccode = b.loccode
      AND b.averagenumberofdependents > 0
      AND t.averagenumberofdependents IS NULL
      AND t.oconus_cola IS NULL;

    -- percent of dependents
    UPDATE oconus_oha_yos t
    SET dependentweight = b.percentwithdependents
    FROM dmdcdependents b
    WHERE b.gradetype = t.gradetype
      AND b.gradelevel = t.gradelevel;

    -- invert the percentage for the no-dependents rows (it was originally percent WITH dependents)
    UPDATE oconus_oha_yos
    SET dependentweight = 1 - dependentweight
    WHERE averagenumberofdependents = 0;

    DROP TABLE IF EXISTS oconus_oha_weighted;
    CREATE TEMP TABLE oconus_oha_weighted (
        payplan              varchar(3),
        gradelevel           smallint,
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        inventory            integer,
        amcosversionid       integer,
        oconus_cola          numeric(15, 2),
        rental               numeric(15, 2),
        utility              numeric(15, 2),
        miha                 numeric(15, 2),
        loccode              varchar(5)
    );

    -- inventory-weighted, dependent-status-weighted average per subgroup/loccode.
    -- Inventory is halved because the YoS build unioned a with- and a without-dependents copy.
    -- NULLIF guards the (SUM(inventory)/2) denominator against div-by-zero (integer division preserved).
    INSERT INTO oconus_oha_weighted
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, inventory,
         amcosversionid, loccode, oconus_cola, rental, utility, miha)
    SELECT payplan,
           gradelevel,
           gradetype,
           categorygroupcode,
           categorysubgroupcode,
           SUM(inventory) / 2,
           amcosversionid,
           loccode,
           SUM(oconus_cola * dependentweight * inventory) / NULLIF(SUM(inventory) / 2, 0) AS oconus_cola,
           SUM(rental * dependentweight * inventory)      / NULLIF(SUM(inventory) / 2, 0) AS rental,
           SUM(utility * dependentweight * inventory)     / NULLIF(SUM(inventory) / 2, 0) AS utility,
           SUM(miha * dependentweight * inventory)        / NULLIF(SUM(inventory) / 2, 0) AS miha
    FROM oconus_oha_yos
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode, amcosversionid, loccode;

    IF NOT p_debug THEN
        -- the pass-1 DELETE already removed the location-specific overseas rows for these CE ids

        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid, amount, mha, crunchtime, amcosversionid, locationid, dependentstatus)
        SELECT a.payplan,
               a.categorygroupcode,
               a.categorysubgroupcode,
               v_ce_ae,
               a.gradetype,
               a.gradelevel,
               -1,
               a.oconus_cola + a.rental + a.utility + a.miha,
               a.loccode,
               v_crunchtime,
               p_amcosversionid,
               b.locationid,
               '-1'
        FROM oconus_oha_weighted AS a
            LEFT OUTER JOIN warehouse.location AS b
                ON a.loccode = b.sourcesystemcode
        WHERE a.payplan = 'AE';

        -- AO
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid, amount, mha, crunchtime, amcosversionid, locationid, dependentstatus)
        SELECT a.payplan,
               a.categorygroupcode,
               a.categorysubgroupcode,
               v_ce_ao,
               a.gradetype,
               a.gradelevel,
               -1,
               a.oconus_cola + a.rental + a.utility + a.miha,
               a.loccode,
               v_crunchtime,
               p_amcosversionid,
               b.locationid,
               '-1'
        FROM oconus_oha_weighted AS a
            LEFT OUTER JOIN warehouse.location AS b
                ON a.loccode = b.sourcesystemcode
        WHERE a.payplan = 'AO';

        -- AWO
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid, amount, mha, crunchtime, amcosversionid, locationid, dependentstatus)
        SELECT a.payplan,
               a.categorygroupcode,
               a.categorysubgroupcode,
               v_ce_awo,
               a.gradetype,
               a.gradelevel,
               -1,
               a.oconus_cola + a.rental + a.utility + a.miha,
               a.loccode,
               v_crunchtime,
               p_amcosversionid,
               b.locationid,
               '-1'
        FROM oconus_oha_weighted AS a
            LEFT OUTER JOIN warehouse.location AS b
                ON a.loccode = b.sourcesystemcode
        WHERE a.payplan = 'AWO';
    END IF;

    DROP TABLE IF EXISTS ovinventory;
    DROP TABLE IF EXISTS overseaspaybyversion;
    DROP TABLE IF EXISTS avgoverseaspay;
    DROP TABLE IF EXISTS dmdcdependents;
    DROP TABLE IF EXISTS spendableincome;
    DROP TABLE IF EXISTS oconus_cola_oha;
    DROP TABLE IF EXISTS oconus_oha_yos;
    DROP TABLE IF EXISTS oconus_oha_weighted;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CostOfMilAverages  (Cost of Averages — Dan Hogan, 9/17/2019)
--   Runs AFTER every other military CostOf* proc. Aggregates the per-subgroup
--   military rows already sitting in data.Costs into (a) group-level weighted
--   averages and (b) pay-plan-level weighted averages, then re-inserts those
--   averaged rows back into the nine military crunch.Costs_* tables with the
--   subgroup (and, for group level, subgroup) codes set to '-1'.
--
--   Weighted average = SUM(amount * inventory) / SUM(inventory), EXCEPT cost
--   elements whose name begins 'Actual%' which are summed, not averaged. Weapon
--   Specific Training elements get a cross join against lookup.WeaponSystem.
--
--   Writes: costs_ae, costs_ao, costs_awo, costs_ne, costs_no, costs_nwo,
--           costs_re, costs_ro, costs_rwo  (average rows only; MHA/location data
--           is never averaged and is left untouched).
--
-- Faithful port. Notes:
--   * Source has NO @CrunchTime param; it computes @CrunchTime = GETDATE()
--     internally -> v_crunchtime := now()::timestamp. Param list therefore keeps
--     only p_amcosversionid + p_debug (no p_crunchtime added, per conventions).
--   * The "bring in the cost data" UPDATE ... FROM #SubgroupData a INNER JOIN
--     (data.Costs subquery) b is retargeted: the T-SQL "a" alias IS the update
--     target, so it becomes UPDATE subgroupdata t SET amount = b.amount FROM
--     (subquery) b WHERE <join keys>. amount starts NULL and only matched rows
--     are set, so PG inner-join semantics match the T-SQL inner join exactly.
--   * Weighted-average denominators SUM(inventory) wrapped in NULLIF(...,0)
--     (behavior-preserving div-by-zero guard).
--   * gradelevel kept smallint (source TINYINT). All grade comparisons are
--     smallint=smallint (data.Costs military branches expose smallint gradelevel),
--     so no ::smallint cast is required here.
--   * @Debug=1 result-set dump blocks dropped (no runtime effect); writes guarded
--     by IF NOT p_debug.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.costofmilaverages(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime timestamp := now()::timestamp;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    ------------------------------------------------------------------
    -- #SubgroupData : every cost/subgroup combination + its amount
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS subgroupdata;
    CREATE TEMP TABLE subgroupdata (
        payplan              varchar(3),
        gradelevel           smallint,
        gradetype            varchar(3),
        categorygroupcode    varchar(2),
        categorysubgroupcode varchar(4),
        costelementid        integer,
        costelementname      varchar(250),
        costelementcategory  varchar(50),
        weaponsystemid       integer,
        weaponsystemname     varchar(50),
        appn                 varchar(25),
        inventory            integer,
        amount               numeric(26, 2),
        amcosversionid       integer,
        amcosversionidstart  integer,
        amcosversionidend    integer
    );

    -- get every combination of costs available (non weapon-specific)
    INSERT INTO subgroupdata
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
         costelementid, costelementname, costelementcategory, weaponsystemid, appn,
         inventory, amcosversionidstart, amcosversionidend, amcosversionid)
    SELECT a.payplan,
           b.gradelevel,
           b.gradetype,
           b.categorygroupcode,
           b.categorysubgroupcode,
           a.costelementid,
           a.costelementname,
           a.costelementcategory,
           -1,
           a.appn,
           b.inventory,
           a.amcosversionidstart,
           a.amcosversionidend,
           b.amcosversionid
    FROM lookup.costelement AS a
        INNER JOIN (
            SELECT payplan,
                   categorygroupcode,
                   categorysubgroupcode,
                   gradelevel,
                   gradetype,
                   SUM(inventory) AS inventory,
                   amcosversionid
            FROM data.knowninventory
            WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
                  AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradelevel, gradetype, amcosversionid
        ) AS b
            ON a.payplan = b.payplan
    WHERE a.payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
          AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
          AND a.costelementname NOT LIKE '%Weapon Specific Training';

    -- another insert, this time with weapon system data (cross join)
    INSERT INTO subgroupdata
        (payplan, gradelevel, gradetype, categorygroupcode, categorysubgroupcode,
         costelementid, costelementname, costelementcategory, weaponsystemid, weaponsystemname,
         appn, inventory, amcosversionidstart, amcosversionidend, amcosversionid)
    SELECT a.payplan,
           a.gradelevel,
           a.gradetype,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.costelementid,
           a.costelementname,
           a.costelementcategory,
           b.weaponsystemid,
           b.weaponsystemname,
           a.appn,
           a.inventory,
           a.amcosversionidstart,
           a.amcosversionidend,
           a.amcosversionid
    FROM (
        SELECT a.payplan,
               b.gradelevel,
               b.gradetype,
               b.categorygroupcode,
               b.categorysubgroupcode,
               a.costelementid,
               a.costelementname,
               a.costelementcategory,
               a.appn,
               b.inventory,
               a.amcosversionidstart,
               a.amcosversionidend,
               b.amcosversionid
        FROM lookup.costelement AS a
            INNER JOIN (
                SELECT payplan,
                       categorygroupcode,
                       categorysubgroupcode,
                       gradelevel,
                       gradetype,
                       SUM(inventory) AS inventory,
                       amcosversionid
                FROM data.knowninventory
                WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
                      AND amcosversionid = p_amcosversionid
                GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradelevel, gradetype, amcosversionid
            ) AS b
                ON a.payplan = b.payplan
        WHERE a.payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
              AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
              AND a.costelementname LIKE '%Weapon Specific Training'
    ) AS a
        CROSS JOIN lookup.weaponsystem AS b
    WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- bring in the cost data for active (no MHA). Source: UPDATE #SubgroupData
    -- SET Amount = b.Amount FROM #SubgroupData a INNER JOIN (data.Costs) b ON ...
    -- The "a" alias is the update target itself -> retarget to subgroupdata t.
    UPDATE subgroupdata t
    SET amount = b.amount
    FROM (
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               costelementid,
               gradetype,
               gradelevel,
               weaponsystemid,
               amount,
               crunchtime,
               amcosversionid
        FROM data.costs
        WHERE amcosversionid = p_amcosversionid
              AND locationid = -1              -- location specific data is not averaged
              AND categorygroupcode <> '-1'    -- don't pull in any existing payplan avg costs
              AND categorysubgroupcode <> '-1' -- don't pull in any existing group avg costs
              AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
    ) AS b
    WHERE t.payplan = b.payplan
      AND t.gradelevel = b.gradelevel
      AND t.costelementid = b.costelementid
      AND t.categorysubgroupcode = b.categorysubgroupcode
      AND t.weaponsystemid = b.weaponsystemid;

    -- no matching cost record -> amount NULL; for a proper weighted average
    -- those costs must be 0
    UPDATE subgroupdata
    SET amount = 0
    WHERE amount IS NULL;

    ------------------------------------------------------------------
    -- #GroupData : weighted average rolled up to the group level
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS groupdata;
    CREATE TEMP TABLE groupdata (
        payplan             varchar(3),
        gradelevel          smallint,
        gradetype           varchar(3),
        categorygroupcode   varchar(2),
        costelementid       integer,
        costelementname     varchar(250),
        costelementcategory varchar(50),
        weaponsystemid      integer,
        weaponsystemname    varchar(50),
        appn                varchar(25),
        inventory           integer,
        amount              numeric(26, 2),
        amcosversionid      integer,
        amcosversionidstart integer,
        amcosversionidend   integer
    );

    -- averaged elements (everything except Actual%)
    INSERT INTO groupdata
        (payplan, gradelevel, gradetype, categorygroupcode, costelementid, costelementname,
         costelementcategory, weaponsystemid, weaponsystemname, appn, inventory, amount,
         amcosversionidstart, amcosversionidend, amcosversionid)
    SELECT payplan,
           gradelevel,
           gradetype,
           categorygroupcode,
           costelementid,
           costelementname,
           costelementcategory,
           weaponsystemid,
           weaponsystemname,
           appn,
           SUM(inventory),
           SUM(amount * inventory) / NULLIF(SUM(inventory), 0),
           MAX(amcosversionidstart),
           MAX(amcosversionidend),
           MAX(amcosversionid)
    FROM subgroupdata
    WHERE costelementname NOT LIKE 'Actual%'
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, costelementid,
             costelementname, costelementcategory, appn, weaponsystemid, weaponsystemname;

    -- actual costs are summed, not averaged
    INSERT INTO groupdata
        (payplan, gradelevel, gradetype, categorygroupcode, costelementid, costelementname,
         costelementcategory, weaponsystemid, weaponsystemname, appn, inventory, amount,
         amcosversionidstart, amcosversionidend, amcosversionid)
    SELECT payplan,
           gradelevel,
           gradetype,
           categorygroupcode,
           costelementid,
           costelementname,
           costelementcategory,
           weaponsystemid,
           weaponsystemname,
           appn,
           SUM(inventory),
           SUM(amount),
           MAX(amcosversionidstart),
           MAX(amcosversionidend),
           MAX(amcosversionid)
    FROM subgroupdata
    WHERE costelementname LIKE 'Actual%'
    GROUP BY payplan, gradelevel, gradetype, categorygroupcode, costelementid,
             costelementname, costelementcategory, appn, weaponsystemid, weaponsystemname;

    ------------------------------------------------------------------
    -- #PayPlanData : weighted average rolled up to the pay-plan level
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS payplandata;
    CREATE TEMP TABLE payplandata (
        payplan             varchar(3),
        gradelevel          smallint,
        gradetype           varchar(3),
        costelementid       integer,
        costelementname     varchar(250),
        costelementcategory varchar(50),
        weaponsystemid      integer,
        weaponsystemname    varchar(50),
        appn                varchar(25),
        inventory           integer,
        amount              numeric(26, 2),
        amcosversionid      integer,
        amcosversionidstart integer,
        amcosversionidend   integer
    );

    -- averaged elements (everything except Actual%)
    INSERT INTO payplandata
        (payplan, gradelevel, gradetype, costelementid, costelementname, costelementcategory,
         weaponsystemid, weaponsystemname, appn, inventory, amount,
         amcosversionidstart, amcosversionidend, amcosversionid)
    SELECT payplan,
           gradelevel,
           gradetype,
           costelementid,
           costelementname,
           costelementcategory,
           weaponsystemid,
           weaponsystemname,
           appn,
           SUM(inventory),
           SUM(amount * inventory) / NULLIF(SUM(inventory), 0),
           MAX(amcosversionidstart),
           MAX(amcosversionidend),
           MAX(amcosversionid)
    FROM subgroupdata
    WHERE costelementname NOT LIKE 'Actual%'
    GROUP BY payplan, gradelevel, gradetype, costelementid, costelementname,
             costelementcategory, appn, weaponsystemid, weaponsystemname;

    -- actual costs are summed, not averaged
    INSERT INTO payplandata
        (payplan, gradelevel, gradetype, costelementid, costelementname, costelementcategory,
         weaponsystemid, weaponsystemname, appn, inventory, amount,
         amcosversionidstart, amcosversionidend, amcosversionid)
    SELECT payplan,
           gradelevel,
           gradetype,
           costelementid,
           costelementname,
           costelementcategory,
           weaponsystemid,
           weaponsystemname,
           appn,
           SUM(inventory),
           SUM(amount),
           MAX(amcosversionidstart),
           MAX(amcosversionidend),
           MAX(amcosversionid)
    FROM subgroupdata
    WHERE costelementname LIKE 'Actual%'
    GROUP BY payplan, gradelevel, gradetype, costelementid, costelementname,
             costelementcategory, appn, weaponsystemid, weaponsystemname;

    IF NOT p_debug THEN
        ----------------------------------------------------------------
        -- clear out existing group + pay-plan average rows for the CE ids
        -- we are about to insert (subgroup/group codes '-1'; MHA '-1' so
        -- location-specific data is preserved)
        ----------------------------------------------------------------
        DELETE FROM crunch.costs_ae
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'AE' GROUP BY costelementid)
              AND mos = '-1' AND mha = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ao
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'AO' GROUP BY costelementid)
              AND aoc = '-1' AND mha = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_awo
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'AWO' GROUP BY costelementid)
              AND womos = '-1' AND mha = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_no
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'NO' GROUP BY costelementid)
              AND aoc = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ro
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'RO' GROUP BY costelementid)
              AND aoc = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_nwo
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'NWO' GROUP BY costelementid)
              AND womos = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_rwo
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'RWO' GROUP BY costelementid)
              AND womos = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_ne
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'NE' GROUP BY costelementid)
              AND mos = '-1' AND amcosversionid = p_amcosversionid;

        DELETE FROM crunch.costs_re
        WHERE costelementid IN (SELECT costelementid FROM groupdata WHERE payplan = 'RE' GROUP BY costelementid)
              AND mos = '-1' AND amcosversionid = p_amcosversionid;

        ----------------------------------------------------------------
        -- insert the computed averages (group level -> subgroup '-1';
        -- pay-plan level -> group and subgroup '-1'; only amount > 0)
        ----------------------------------------------------------------
        -- AE
        INSERT INTO crunch.costs_ae
            (payplan, cmf, mos, mha, dependentstatus, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, '-1', '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid, -1
        FROM groupdata WHERE payplan = 'AE' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid, -1
        FROM payplandata WHERE payplan = 'AE' AND amount > 0;

        -- AO
        INSERT INTO crunch.costs_ao
            (payplan, cmf, aoc, mha, dependentstatus, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, '-1', '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid, -1
        FROM groupdata WHERE payplan = 'AO' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid, -1
        FROM payplandata WHERE payplan = 'AO' AND amount > 0;

        -- AWO
        INSERT INTO crunch.costs_awo
            (payplan, branch, womos, mha, dependentstatus, costelementid, gradetype, gradelevel,
             weaponsystemid, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan, categorygroupcode, '-1', '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid, -1
        FROM groupdata WHERE payplan = 'AWO' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid, -1
        FROM payplandata WHERE payplan = 'AWO' AND amount > 0;

        -- NO
        INSERT INTO crunch.costs_no
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM groupdata WHERE payplan = 'NO' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM payplandata WHERE payplan = 'NO' AND amount > 0;

        -- RO
        INSERT INTO crunch.costs_ro
            (payplan, cmf, aoc, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM groupdata WHERE payplan = 'RO' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM payplandata WHERE payplan = 'RO' AND amount > 0;

        -- NE
        INSERT INTO crunch.costs_ne
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM groupdata WHERE payplan = 'NE' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM payplandata WHERE payplan = 'NE' AND amount > 0;

        -- RE
        INSERT INTO crunch.costs_re
            (payplan, cmf, mos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM groupdata WHERE payplan = 'RE' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM payplandata WHERE payplan = 'RE' AND amount > 0;

        -- NWO
        INSERT INTO crunch.costs_nwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM groupdata WHERE payplan = 'NWO' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM payplandata WHERE payplan = 'NWO' AND amount > 0;

        -- RWO
        INSERT INTO crunch.costs_rwo
            (payplan, branch, womos, costelementid, gradetype, gradelevel, weaponsystemid,
             amount, crunchtime, amcosversionid)
        SELECT payplan, categorygroupcode, '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM groupdata WHERE payplan = 'RWO' AND amount > 0
        UNION
        SELECT payplan, '-1', '-1', costelementid, gradetype, gradelevel,
               weaponsystemid, amount, v_crunchtime, amcosversionid
        FROM payplandata WHERE payplan = 'RWO' AND amount > 0;
    END IF;

    DROP TABLE IF EXISTS subgroupdata;
    DROP TABLE IF EXISTS groupdata;
    DROP TABLE IF EXISTS payplandata;
END;
$$;
