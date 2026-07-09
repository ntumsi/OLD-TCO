-- =============================================================================
-- crunch.CostOfTraining  (PHASE 3 — the largest crunch cost procedure)
--
-- Faithful PostgreSQL plpgsql port of
-- AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CostOfTraining.sql (14,730 lines).
--   Author: Dan Hogan, July 2018 — training calculation to replace amortization.
--
-- Pipeline: stages ATRM (course cost model) + ATRRS (course attendance) into the
-- crunch_temp.* tables, crosswalks course->MOS/AOC/WOMOS, brings in a 3-year
-- moving-average inventory, throttles students to graduates/inventory, averages
-- course costs across the latest 3 AMCOS versions, rebalances to the Army budget
-- by course type, spreads costs down grade levels via Cross-Grade-Level-Allocation
-- (CGLA) using the recursive helper functions, layers on NG/R-specific budget
-- costs, and finally writes the nine military crunch.Costs_* tables (~409 element
-- inserts across CE ids preserved verbatim from the source).
--
-- Port conventions (see 006d Phase-1 header for the established style):
--   * p_debug = true is a DRY RUN: the source performs its final DELETE/INSERT
--     writes only under "IF @Debug = 0"; those are guarded here by "IF NOT p_debug".
--     The staging TRUNCATE/INSERT/UPDATE steps run unconditionally, exactly as the
--     source runs them regardless of @Debug. All "IF @Debug = 1" result-set dumps
--     and their RAISERROR/SELECT diagnostics are dropped (no runtime effect).
--   * crunch_temp column names are the NORMALISED names from migration 005e
--     ([Modal Grade]->modal_grade, [Flying Hours]->flying_hours, [TMW/EGRAD]->
--     tmw_egrad, [OMA CIV]->oma_civ, [OMA Non-Pay]->oma_non_pay).
--   * "UPDATE #t SET .. FROM #t a JOIN other b" self-joins are rewritten so the
--     UPDATE target is not re-aliased in FROM (PG forbids that).
--   * data.knowninventory.gradelevel / data.inventory.gradelevel is varchar; it is
--     cast ::smallint when compared to / stored into a numeric grade, and cast
--     ::smallint in reverse-cumulative CGLA window ORDER BYs so grade 10 sorts
--     after grade 9 (numeric, not lexical) as it did in the T-SQL source.
--   * ISNULL->COALESCE, GETDATE()/SYSDATETIME->now(), CONVERT(INT,x)->trunc(x)::int
--     (truncation, matching T-SQL), LEN->length, LEFT/RIGHT->left/right,
--     ISNUMERIC(x)=1 -> x ~ '^[0-9]+$', SELECT TOP (n)->LIMIT n,
--     RAISERROR(sev 10)->dropped, string + -> handled by CONCAT()/native.
--   * Divisions whose denominator is an inventory / student count (or a budget
--     total that can be empty for a course type) are wrapped in NULLIF(denom,0):
--     behaviour-preserving when non-zero, NULL instead of a divide-by-zero error
--     on empty subgroups. The T-SQL source relied on non-zero denominators.
--   * CostElementId, pay-plan literal and every numeric constant preserved exactly.
-- =============================================================================
CREATE OR REPLACE PROCEDURE crunch.costoftraining(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime timestamp := COALESCE(p_crunchtime, now()::timestamp);

    v_exception  varchar(50);   -- source @Exception: declared, never SET -> always NULL

    -- course-type budget rebalancing factors / totals
    v_osut_perc                      numeric(18, 2);
    v_b_perc                         numeric(18, 2);
    v_pc_perc                        numeric(18, 2);
    v_ait_iet_perc                   numeric(18, 2);
    v_training_budget_total          numeric(18, 2);
    v_unallocated_training_budget    numeric(18, 2);
    v_unallocated_budget_per_soldier numeric(18, 2);
    v_osut_total                     numeric(18, 2);
    v_b_total                        numeric(18, 2);
    v_pc_total                       numeric(18, 2);
    v_ait_iet_total                  numeric(18, 2);
    v_osut_budget                    numeric(18, 2);
    v_b_budget                       numeric(18, 2);
    v_pc_budget                      numeric(18, 2);
    v_ait_iet_budget                 numeric(18, 2);
    v_budgettrainingflight           numeric(18, 2);
    v_budgettrainingsupport          numeric(18, 2);

    -- NG/R inventory bases and per-soldier training budget shares
    v_ar_all numeric(18, 2);
    v_ng_all numeric(18, 2);
    v_ar_e   numeric(18, 2);
    v_ng_e   numeric(18, 2);

    v_iet_rpa  numeric(18, 2); v_iet_ngpa numeric(18, 2); v_iet_omar numeric(18, 2); v_iet_omng numeric(18, 2);
    v_iet_rpa_soldier  numeric(18, 2); v_iet_ngpa_soldier numeric(18, 2);
    v_iet_omar_soldier numeric(18, 2); v_iet_omng_soldier numeric(18, 2);

    v_ait_rpa  numeric(18, 2); v_ait_ngpa numeric(18, 2); v_ait_omar numeric(18, 2); v_ait_omng numeric(18, 2);
    v_ait_rpa_soldier  numeric(18, 2); v_ait_ngpa_soldier numeric(18, 2);
    v_ait_omar_soldier numeric(18, 2); v_ait_omng_soldier numeric(18, 2);

    v_mos_qual_rpa  numeric(18, 2); v_mos_qual_ngpa numeric(18, 2);
    v_mos_qual_omar numeric(18, 2); v_mos_qual_omng numeric(18, 2);
    v_mos_qual_rpa_soldier  numeric(18, 2); v_mos_qual_ngpa_soldier numeric(18, 2);
    v_mos_qual_omar_soldier numeric(18, 2); v_mos_qual_omng_soldier numeric(18, 2);

    v_g_rpa  numeric(18, 2); v_g_ngpa numeric(18, 2); v_g_omar numeric(18, 2); v_g_omng numeric(18, 2);
    v_g_rpa_soldier  numeric(18, 2); v_g_ngpa_soldier numeric(18, 2);
    v_g_omar_soldier numeric(18, 2); v_g_omng_soldier numeric(18, 2);

    v_p_rpa  numeric(18, 2); v_p_ngpa numeric(18, 2); v_p_omar numeric(18, 2); v_p_omng numeric(18, 2);
    v_p_rpa_soldier  numeric(18, 2); v_p_ngpa_soldier numeric(18, 2);
    v_p_omar_soldier numeric(18, 2); v_p_omng_soldier numeric(18, 2);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- =========================================================================
    -- stage the source tables into crunch_temp (unconditional, as in the source)
    -- =========================================================================
    TRUNCATE TABLE crunch_temp.atrm;
    TRUNCATE TABLE crunch_temp.atrrs;
    TRUNCATE TABLE crunch_temp.training_xwalk_atrrs_atrm;
    TRUNCATE TABLE crunch_temp.training_xwalk_atrrs_crstype_mos;
    TRUNCATE TABLE crunch_temp.atrrsofficerbranchcodes;
    TRUNCATE TABLE crunch_temp.militaryconversions;
    TRUNCATE TABLE crunch_temp.atrrs_atrm_raw;
    TRUNCATE TABLE crunch_temp.atrrsatrmcoursemos;
    TRUNCATE TABLE crunch_temp.trainingcostsbyversion;
    TRUNCATE TABLE crunch_temp.trainingcostsaverage;
    TRUNCATE TABLE crunch_temp.trainingcosts;

    -- ATRM: latest 3 AMCOS versions of the course cost model
    INSERT INTO crunch_temp.atrm
        (schoolcode, coursenumber, coursetitle, courselengthweeks, egrads, modal_grade,
         frequency, flying_hours, tmw_egrad, mpa, oma_civ, oma_non_pay, other, amcosversionid)
    SELECT schoolcode, coursenumber, coursetitle, length_weeks, egrads, modalgrade,
           frequency, flyinghours, ich, mpa_cost, omacivpay_cost, omanonpay_cost, other_cost, amcosversionid
    FROM load_training.atrm
    WHERE amcosversionid IN (
        SELECT amcosversionid
        FROM load_training.atrm
        WHERE amcosversionid <= p_amcosversionid
        GROUP BY amcosversionid
        ORDER BY amcosversionid DESC
        LIMIT 3);

    -- ATRRS: matching attendance rows for the same 3 versions
    INSERT INTO crunch_temp.atrrs
        (cpbranch, schoolcode, schoolname, crsph, coursetitle, pgrad, pmosen4, crmgof, crstype,
         numberofstudents, amcosversionid)
    SELECT cpbranch, schoolcode, schoolname, coursenumber, coursetitle, pgrad, pmosen4, crmgof, crstype,
           numberofstudents, amcosversionid
    FROM load_training.atrrs
    WHERE amcosversionid IN (
        SELECT amcosversionid
        FROM load_training.atrm
        WHERE amcosversionid <= p_amcosversionid
        GROUP BY amcosversionid
        ORDER BY amcosversionid DESC
        LIMIT 3);

    -- 3/8/2024 business rule: force 68W for a specific course/school for non-68/18D enlisted
    UPDATE crunch_temp.atrrs
    SET pmosen4 = '68W'
    WHERE schoolcode = '0081'
          AND crsph = '6H-F35/300-F38'
          AND left(pmosen4, 2) <> '68'
          AND left(pmosen4, 3) <> '18D'
          AND left(pgrad, 1) = 'E';

    INSERT INTO crunch_temp.training_xwalk_atrrs_atrm
        (atrm_key, atrrs_key, amcosversionid)
    SELECT atrm_key, atrrs_key, amcosversionid
    FROM xwalk.atrrsatrmcrosswalk
    WHERE amcosversionid IN (
        SELECT amcosversionid
        FROM load_training.atrm
        WHERE amcosversionid <= p_amcosversionid
        GROUP BY amcosversionid
        ORDER BY amcosversionid DESC
        LIMIT 3);

    INSERT INTO crunch_temp.training_xwalk_atrrs_crstype_mos
        (atrrs_schoolcode, atrrs_coursenumber, crs_type_o, crs_type_e, weaponsystemname, aoc, womos, mos,
         o_gradelevel_floor, o_gradelevel_ceiling, w_gradelevel_floor, w_gradelevel_ceiling,
         e_gradelevel_floor, e_gradelevel_ceiling, amcosversionid)
    SELECT atrrs_schoolcode, atrrs_coursenumber, crs_type_o, crs_type_e, weaponsystemname, aoc, womos, mos,
           o_gradelevel_floor, o_gradelevel_ceiling, w_gradelevel_floor, w_gradelevel_ceiling,
           e_gradelevel_floor, e_gradelevel_ceiling, amcosversionid
    FROM lookup.atrrscoursetypemos
    WHERE amcosversionid IN (
        SELECT amcosversionid
        FROM load_training.atrm
        WHERE amcosversionid <= p_amcosversionid
        GROUP BY amcosversionid
        ORDER BY amcosversionid DESC
        LIMIT 3);

    INSERT INTO crunch_temp.atrrsofficerbranchcodes
        (cmf, branch, definition, amcosversionid)
    SELECT cmf, branch, definition, amcosversionid
    FROM lookup.atrrsofficerbranchcodes
    WHERE amcosversionid IN (
        SELECT amcosversionid
        FROM load_training.atrm
        WHERE amcosversionid <= p_amcosversionid
        GROUP BY amcosversionid
        ORDER BY amcosversionid DESC
        LIMIT 3);

    -- MilitaryConversions: union of WOMOS/MOS/AOC conversion tables
    INSERT INTO crunch_temp.militaryconversions
        (oldmos, grade, newmos, gradelevel, amcosversionid)
    SELECT womosold, grade, womosnew, a.gradelevel, amcosversionid
    FROM (
        SELECT 'W' AS grade, womosold, gradelevel, womosnew, amcosversionid
        FROM lookup.womosconversion
        UNION
        SELECT 'E' AS grade, mosold, gradelevel, mosnew, amcosversionid
        FROM lookup.mosconversion
        UNION
        SELECT 'A' AS grade, aocold, gradelevel, aocnew, amcosversionid
        FROM lookup.aocconversion
    ) AS a
    WHERE amcosversionid IN (
        SELECT amcosversionid
        FROM load_training.atrm
        WHERE amcosversionid <= p_amcosversionid
        GROUP BY amcosversionid
        ORDER BY amcosversionid DESC
        LIMIT 3);

    -- Combine ATRM (cost) and ATRRS (attendance) via the crosswalk into the "raw" table.
    -- v_exception is the source @Exception NULL placeholder. CONCAT keys, FULL OUTER JOINs
    -- preserved 1:1. atrm_activity is never populated by the source (not in its column list).
    INSERT INTO crunch_temp.atrrs_atrm_raw
        (exception, atrm_other, atrm_oma, atrm_mpa, atrm_tmw_egrd, atrm_flying_hrs, atrm_frequency,
         atrm_modal_grade, atrm_egrads, atrm_courselengthweeks, atrm_coursetitle, atrm_coursenumber,
         atrm_schoolcode, atrm_versionid, atrm_key, atrrs_key, amcosversionid, atrrs_versionid,
         atrrs_schoolcode, atrrs_coursenumber, atrrs_component, atrrs_school, atrrs_coursetitle,
         atrrs_gradelevel, atrrs_mos, atrrs_branch, atrrs_crstype, atrrs_numberofstudents)
    SELECT a.exception, a.atrm_other, a.atrm_oma, a.atrm_mpa, a.atrm_tmw_egrd, a.atrm_flying_hrs,
           a.atrm_frequency, a.atrm_modal_grade, a.atrm_egrads, a.atrm_courselengthweeks,
           a.atrm_coursetitle, a.atrm_coursenumber, a.atrm_schoolcode, a.atrm_versionid, a.atrm_key,
           a.atrrs_key, a.amcosversionid, a.atrrs_versionid, a.atrrs_schoolcode, a.atrrs_coursenumber,
           a.atrrs_component, a.atrrs_schoolname, a.atrrs_coursetitle, a.atrrs_gradelevel, a.atrrs_mos,
           a.atrrs_branch, a.atrrs_crstype, a.atrrs_numberofstudents
    FROM (
        SELECT v_exception AS exception,
               a.*,
               b.amcosversionid AS atrrs_versionid,
               b.schoolcode AS atrrs_schoolcode,
               b.crsph AS atrrs_coursenumber,
               b.cpbranch AS atrrs_component,
               b.schoolname AS atrrs_schoolname,
               b.coursetitle AS atrrs_coursetitle,
               b.pgrad AS atrrs_gradelevel,
               b.pmosen4 AS atrrs_mos,
               b.crmgof AS atrrs_branch,
               b.crstype AS atrrs_crstype,
               b.numberofstudents AS atrrs_numberofstudents
        FROM (
            SELECT a.*,
                   b.amcosversionid AS atrm_versionid,
                   b.schoolcode AS atrm_schoolcode,
                   b.coursenumber AS atrm_coursenumber,
                   b.coursetitle AS atrm_coursetitle,
                   b.courselengthweeks AS atrm_courselengthweeks,
                   b.egrads AS atrm_egrads,
                   b.modal_grade AS atrm_modal_grade,
                   b.frequency AS atrm_frequency,
                   b.flying_hours AS atrm_flying_hrs,
                   b.tmw_egrad AS atrm_tmw_egrd,
                   b.mpa AS atrm_mpa,
                   b.oma_civ + b.oma_non_pay AS atrm_oma,
                   b.other AS atrm_other
            FROM crunch_temp.training_xwalk_atrrs_atrm AS a
                FULL OUTER JOIN crunch_temp.atrm AS b
                    ON a.atrm_key = CONCAT(b.schoolcode, b.coursenumber)
                       AND a.amcosversionid = b.amcosversionid
        ) AS a
            FULL OUTER JOIN crunch_temp.atrrs AS b
                ON a.atrrs_key = CONCAT(b.schoolcode, b.crsph)
                   AND b.amcosversionid = a.amcosversionid
    ) AS a;

    -- business-rule exclusions. Self-scan on the same table: the source aliases the
    -- target as "a" in FROM but only filters it; PG references the columns directly.
    -- atrm_activity is always NULL (never populated) so the '091S detachment' clause
    -- is effectively inert, exactly as in the source.
    UPDATE crunch_temp.atrrs_atrm_raw
    SET exception = 'Exclude'
    WHERE right(atrm_coursenumber, 3) = '(X)'
          OR atrm_modal_grade LIKE '%FGN%'
          OR atrm_modal_grade LIKE '%FMS%'
          OR atrm_modal_grade LIKE '%S&F%'
          OR atrm_modal_grade LIKE '%SF%'
          OR atrm_schoolcode LIKE '%S&F%'
          OR atrm_schoolcode LIKE '%SF%'
          OR atrm_coursenumber LIKE '%(OS) (CT)%'
          OR right(atrm_coursenumber, 4) = '(OS)'
          OR atrm_coursenumber LIKE '%MI-17%'
          OR atrm_coursetitle LIKE '%MI-17%'
          OR atrrs_coursetitle LIKE '%MI-17%'
          OR (atrrs_coursetitle LIKE '%officer candidate%'
              AND atrrs_coursetitle NOT LIKE '%warrant%')
          OR atrrs_coursetitle LIKE '%DIRECT COMMISSION%'
          OR atrrs_gradelevel ~ '^[0-9]+$'   -- source ISNUMERIC(ATRRS_GradeLevel)=1 (civilian grade codes)
          OR (atrm_schoolcode = '091S'
              AND atrm_activity LIKE '%detachment%');

    -- =========================================================================
    -- bring in course and MOS/AOC/WOMOS mappings, then make final assignments
    -- =========================================================================
    INSERT INTO crunch_temp.atrrsatrmcoursemos
        (atrrs_numberofstudents, atrrs_crstype, atrrs_branch, atrrs_mos, atrrs_gradelevel,
         atrrs_coursetitle, atrrs_school, atrrs_component, atrrs_coursenumber, atrrs_schoolcode,
         atrrs_versionid, amcosversionid, atrrs_key, atrm_key, atrm_versionid, atrm_schoolcode,
         atrm_coursenumber, atrm_coursetitle, atrm_activity, atrm_courselengthweeks, atrm_egrads,
         atrm_modal_grade, atrm_frequency, atrm_flying_hrs, atrm_tmw_egrd, atrm_mpa, atrm_oma,
         atrm_other, exception, crs_type_o, crs_type_e, weaponsystemname, aoc, womos, mos,
         o_gradelevel_floor, o_gradelevel_ceiling, w_gradelevel_floor, w_gradelevel_ceiling,
         e_gradelevel_floor, e_gradelevel_ceiling, coursetypefinal, mosfinal, branchfinal, gradefinal,
         gradetypefinal, gradelevelfinal, payplan, atrrs_tot_students, numberofstudentsadjusted,
         running_adj_students, inventory, inventoryadjustment, total_inv_add, final_adj_inv,
         final_adj_students)
    SELECT a.atrrs_numberofstudents, a.atrrs_crstype, a.atrrs_branch, a.atrrs_mos, a.atrrs_gradelevel,
           a.atrrs_coursetitle, a.atrrs_school, a.atrrs_component, a.atrrs_coursenumber, a.atrrs_schoolcode,
           a.atrrs_versionid, a.amcosversionid, a.atrrs_key, a.atrm_key, a.atrm_versionid, a.atrm_schoolcode,
           a.atrm_coursenumber, a.atrm_coursetitle, a.atrm_activity, a.atrm_courselengthweeks, a.atrm_egrads,
           a.atrm_modal_grade, a.atrm_frequency, a.atrm_flying_hrs, a.atrm_tmw_egrd, a.atrm_mpa, a.atrm_oma,
           a.atrm_other, a.exception, a.crs_type_o, a.crs_type_e, a.weaponsystemname, a.aoc, a.womos, a.mos,
           a.o_gradelevel_floor, a.o_gradelevel_ceiling, a.w_gradelevel_floor, a.w_gradelevel_ceiling,
           a.e_gradelevel_floor, a.e_gradelevel_ceiling, a.coursetypefinal, a.mosfinal, a.branchfinal,
           a.gradefinal, a.gradetypefinal, a.gradelevelfinal, a.payplan, a.atrrs_tot_students,
           a.numberofstudentsadjusted, a.running_adj_students, a.inventory, a.inventoryadjustment,
           a.total_inv_add, a.final_adj_inv, a.final_adj_students
    FROM (
        SELECT a.exception, a.atrm_other, a.atrm_oma, a.atrm_mpa, a.atrm_tmw_egrd, a.atrm_flying_hrs,
               a.atrm_frequency, a.atrm_modal_grade, a.atrm_egrads, a.atrm_courselengthweeks,
               a.atrm_activity, a.atrm_coursetitle, a.atrm_coursenumber, a.atrm_schoolcode,
               a.atrm_versionid, a.atrm_key, a.atrrs_key, a.amcosversionid, a.atrrs_versionid,
               a.atrrs_schoolcode, a.atrrs_coursenumber, a.atrrs_component, a.atrrs_school,
               a.atrrs_coursetitle, a.atrrs_gradelevel, a.atrrs_mos, a.atrrs_branch, a.atrrs_crstype,
               a.atrrs_numberofstudents,
               b.crs_type_o, b.crs_type_e, b.weaponsystemname, b.aoc, b.womos, b.mos,
               b.o_gradelevel_floor, b.o_gradelevel_ceiling, b.w_gradelevel_floor, b.w_gradelevel_ceiling,
               b.e_gradelevel_floor, b.e_gradelevel_ceiling,
               NULL AS coursetypefinal,
               NULL AS mosfinal,
               NULL AS branchfinal,
               NULL AS gradefinal,
               NULL AS gradetypefinal,
               NULL AS gradelevelfinal,
               NULL AS payplan,
               NULL AS atrrs_tot_students,
               0.0 AS numberofstudentsadjusted,
               0.0 AS running_adj_students,
               NULL AS inventory,
               0.0 AS inventoryadjustment,
               0.0 AS total_inv_add,
               0.0 AS final_adj_inv,
               0.0 AS final_adj_students
        FROM crunch_temp.atrrs_atrm_raw AS a
            LEFT JOIN crunch_temp.training_xwalk_atrrs_crstype_mos AS b
                ON a.atrrs_coursenumber = b.atrrs_coursenumber
                   AND a.atrrs_schoolcode = b.atrrs_schoolcode
                   AND a.amcosversionid = b.amcosversionid
        WHERE a.exception IS NULL
              AND a.atrrs_key IS NOT NULL
    ) AS a;

    -- final grade-level assignments (grade comes from ATRRS with exceptions)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradefinal = atrrs_gradelevel;

    -- cadets become O1s
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradefinal = 'O1'
    WHERE atrrs_gradelevel = 'CD';

    -- warrant candidates become W1s
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradefinal = 'W1'
    WHERE atrrs_coursetitle LIKE '%warrant officer candidate%'
          OR atrrs_coursetitle LIKE '%WOBC%'
          OR atrrs_coursetitle LIKE '%wo basic%'
          OR atrrs_coursetitle LIKE '%warrant officer basic%';

    -- basic-officer attendees become O1 if not already an officer (excluding warrant basic)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradefinal = 'O1'
    WHERE left(atrrs_gradelevel, 1) <> 'O'
          AND atrrs_coursetitle LIKE '%basic officer%'
          AND (atrrs_coursetitle NOT LIKE '%WOBC%'
               AND atrrs_coursetitle NOT LIKE '%Warrant%');

    -- O/W & E course-type codes and grp/subgrp assignments
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET coursetypefinal = crs_type_o,
        mosfinal = aoc
    WHERE left(gradefinal, 1) = 'O';
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET coursetypefinal = crs_type_e,
        mosfinal = mos
    WHERE left(gradefinal, 1) = 'E';
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET coursetypefinal = crs_type_o,
        mosfinal = womos
    WHERE left(gradefinal, 1) = 'W';

    -- populate final grade type and level from the combined GradeFinal
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradetypefinal = left(gradefinal, 1),
        gradelevelfinal = right(gradefinal, 1);

    -- grade-level floor/ceiling adjustments per crosstype/MOS table (officer)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradelevelfinal = o_gradelevel_floor
    WHERE gradetypefinal = 'O'
          AND o_gradelevel_floor > gradelevelfinal::smallint
          AND o_gradelevel_floor IS NOT NULL;
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradelevelfinal = o_gradelevel_ceiling
    WHERE gradetypefinal = 'O'
          AND o_gradelevel_ceiling < gradelevelfinal::smallint
          AND o_gradelevel_ceiling IS NOT NULL;

    -- warrant floor/ceiling
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradelevelfinal = w_gradelevel_floor
    WHERE gradetypefinal = 'W'
          AND w_gradelevel_floor > gradelevelfinal::smallint
          AND w_gradelevel_floor IS NOT NULL;
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradelevelfinal = w_gradelevel_ceiling
    WHERE gradetypefinal = 'W'
          AND w_gradelevel_ceiling < gradelevelfinal::smallint
          AND w_gradelevel_ceiling IS NOT NULL;

    -- enlisted floor/ceiling
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradelevelfinal = e_gradelevel_floor
    WHERE gradetypefinal = 'E'
          AND e_gradelevel_floor > gradelevelfinal::smallint
          AND e_gradelevel_floor IS NOT NULL;
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradelevelfinal = e_gradelevel_ceiling
    WHERE gradetypefinal = 'E'
          AND e_gradelevel_ceiling < gradelevelfinal::smallint
          AND e_gradelevel_ceiling IS NOT NULL;

    -- copy any grade changes back into the combined GradeFinal
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradefinal = CONCAT(gradetypefinal, gradelevelfinal);

    -- turn ATRRS select values into who attended
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET mosfinal = CASE
                       WHEN length(atrrs_mos) > 3 THEN left(atrrs_mos, 3)
                       ELSE atrrs_mos
                   END
    WHERE left(atrrs_gradelevel, 1) <> 'W'
          AND mosfinal = 'ATRRS';
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET mosfinal = atrrs_mos
    WHERE left(atrrs_gradelevel, 1) = 'W'
          AND mosfinal = 'ATRRS';

    -- 3-char WOMOS on a warrant means an E->W conversion with unknown WOMOS -> XXX
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET mosfinal = 'XXX'
    WHERE gradetypefinal = 'W'
          AND length(mosfinal) = 3;

    -- a >3-char WOMOS in an enlisted row means the grade must also convert to W
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET gradetypefinal = 'W'
    WHERE gradetypefinal = 'E'
          AND length(mosfinal) > 3;

    -- bring in officer branch data (ATRRS has no officer AOC; use the 2-char branch CMF).
    -- LEFT-JOIN update whose target column (branchfinal) starts NULL -> inner-join
    -- UPDATE..FROM is equivalent; target not re-aliased in FROM.
    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET branchfinal = b.branch
    FROM crunch_temp.atrrsofficerbranchcodes b
    WHERE left(t.mosfinal, 2) = b.cmf
          AND b.amcosversionid = t.amcosversionid
          AND t.gradetypefinal = 'O';

    -- populate the pay-plan field
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET payplan = atrrs_component;
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET payplan = 'N'
    WHERE payplan = 'G';
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET payplan = CONCAT(payplan, gradetypefinal);
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET payplan = CONCAT(payplan, 'O')
    WHERE payplan LIKE '%W%';

    -- convert AOC/MOS/WOMOS via the G1 PAM conversion table. INNER JOIN self-join;
    -- target not re-aliased in FROM.
    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET mosfinal = b.newmos
    FROM crunch_temp.militaryconversions b
    WHERE t.mosfinal = b.oldmos
          AND right(t.atrrs_gradelevel, length(t.atrrs_gradelevel) - 1) = b.gradelevel
          AND left(t.atrrs_gradelevel, 1) = b.grade
          AND b.newmos NOT LIKE '%none%'
          AND b.amcosversionid = t.amcosversionid;

    -- =========================================================================
    -- bring in inventory (3-year moving average) at subgroup, group, pay-plan levels.
    -- Source uses LEFT-JOIN updates on a target column that starts NULL and whose
    -- WHERE-restricted rows are still NULL beforehand -> inner-join UPDATE..FROM is
    -- equivalent (unmatched rows stay NULL, cleaned to 0 below). Target not re-aliased.
    -- gradelevelfinal (varchar) compared to knowninventory.gradelevel (varchar): both
    -- text, no cast needed.
    -- =========================================================================
    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET inventory = b.inventory
    FROM (
        SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
               AVG(inventory) AS inventory
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
                   SUM(inventory) AS inventory, amcosversionid
            FROM data.knowninventory
            WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
                  AND amcosversionid BETWEEN p_amcosversionid - 200 AND p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, amcosversionid
        ) AS z
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
    ) AS b
    WHERE t.mosfinal = b.categorysubgroupcode
          AND t.gradelevelfinal = b.gradelevel
          AND t.payplan = b.payplan;

    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET inventory = b.inventory
    FROM (
        SELECT payplan, categorygroupcode, gradetype, gradelevel, AVG(inventory) AS inventory
        FROM (
            SELECT payplan, categorygroupcode, gradetype, gradelevel,
                   SUM(inventory) AS inventory, amcosversionid
            FROM data.knowninventory
            WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
                  AND amcosversionid BETWEEN p_amcosversionid - 200 AND p_amcosversionid
            GROUP BY payplan, categorygroupcode, gradetype, gradelevel, amcosversionid
        ) AS z
        GROUP BY payplan, categorygroupcode, gradetype, gradelevel
    ) AS b
    WHERE left(t.mosfinal, 2) = b.categorygroupcode
          AND t.gradelevelfinal = b.gradelevel
          AND t.payplan = b.payplan
          AND length(t.mosfinal) = 2;

    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET inventory = b.inventory
    FROM (
        SELECT payplan, gradetype, gradelevel, AVG(inventory) AS inventory
        FROM (
            SELECT payplan, gradetype, gradelevel,
                   SUM(inventory) AS inventory, amcosversionid
            FROM data.knowninventory
            WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
                  AND amcosversionid BETWEEN p_amcosversionid - 200 AND p_amcosversionid
            GROUP BY payplan, gradetype, gradelevel, amcosversionid
        ) AS z
        GROUP BY payplan, gradetype, gradelevel
    ) AS b
    WHERE t.gradelevelfinal = b.gradelevel
          AND t.payplan = b.payplan
          AND t.mosfinal = 'XXX';

    -- null inventory -> 0
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventory = 0
    WHERE inventory IS NULL;

    -- =========================================================================
    -- student adjustments: throttle ATRRS students down toward ATRM graduates
    -- =========================================================================
    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET atrrs_tot_students = b.atrrs_numberofstudents
    FROM (
        SELECT amcosversionid, atrrs_schoolcode, atrrs_coursenumber,
               SUM(COALESCE(atrrs_numberofstudents, 0)) AS atrrs_numberofstudents
        FROM crunch_temp.atrrsatrmcoursemos
        GROUP BY amcosversionid, atrrs_schoolcode, atrrs_coursenumber
    ) AS b
    WHERE t.atrrs_schoolcode = b.atrrs_schoolcode
          AND t.atrrs_coursenumber = b.atrrs_coursenumber
          AND t.amcosversionid = b.amcosversionid;

    -- seed adjusted students with the ATRRS count
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET numberofstudentsadjusted = atrrs_numberofstudents;

    -- reduce (never inflate) students where ATRM graduates fall short of ATRRS
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET numberofstudentsadjusted = (atrm_egrads / NULLIF(atrrs_tot_students, 0)) * atrrs_numberofstudents
    WHERE atrm_egrads < atrrs_tot_students;

    -- =========================================================================
    -- inventory adjustments: track conversions as additions to inventory
    -- =========================================================================
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventoryadjustment = 0;

    -- MOS-level adjustment for warrants (incoming MOS is exactly 4 digits)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventoryadjustment = numberofstudentsadjusted
    WHERE atrrs_mos <> mosfinal
          AND length(mosfinal) >= 3
          AND mosfinal <> 'XXX'
          AND gradetypefinal = 'W';

    -- enlisted and officers (ATRRS MOS may be 3-4 digits)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventoryadjustment = numberofstudentsadjusted
    WHERE left(atrrs_mos, 3) <> mosfinal
          AND atrrs_mos IS NOT NULL
          AND length(mosfinal) >= 3
          AND mosfinal <> 'XXX'
          AND gradetypefinal <> 'W';

    -- officers via branch
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventoryadjustment = numberofstudentsadjusted
    WHERE atrrs_branch <> branchfinal
          AND gradetypefinal = 'O'
          AND atrrs_branch IS NOT NULL
          AND mosfinal <> 'XXX';

    -- CMF-level adjustment
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventoryadjustment = numberofstudentsadjusted
    WHERE left(atrrs_mos, 2) <> left(mosfinal, 2)
          AND gradetypefinal <> 'O'
          AND length(mosfinal) = 2;

    -- no cost elements for 0-inventory records
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET inventoryadjustment = 0
    WHERE inventory = 0;

    -- running adjusted-student total per (version, payplan, atrrs_key, mos, gradelevel).
    -- Source updates a T-SQL window CTE; PG cannot UPDATE a CTE, so join back on ctid.
    -- (ORDER BY equals PARTITION BY -> all rows are peers -> each row gets the full
    -- partition sum, exactly as the source computes it.)
    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET running_adj_students = s.sumval
    FROM (
        SELECT ctid,
               SUM(COALESCE(numberofstudentsadjusted, 0)) OVER (
                   PARTITION BY amcosversionid, payplan, atrrs_key, mosfinal, gradelevelfinal
                   ORDER BY amcosversionid, payplan, atrrs_key, mosfinal, gradelevelfinal
               ) AS sumval
        FROM crunch_temp.atrrsatrmcoursemos
    ) AS s
    WHERE t.ctid = s.ctid;

    -- cumulative inventory additions per (version, atrrs_key, payplan, mos, gradefinal)
    UPDATE crunch_temp.atrrsatrmcoursemos t
    SET total_inv_add = s.invadd
    FROM (
        SELECT ctid,
               SUM(inventoryadjustment) OVER (
                   PARTITION BY amcosversionid, atrrs_key, payplan, mosfinal, gradefinal
                   ORDER BY atrrs_key, payplan, mosfinal, gradefinal
               ) AS invadd
        FROM crunch_temp.atrrsatrmcoursemos
    ) AS s
    WHERE t.ctid = s.ctid;

    -- final inventory = base + conversions
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET final_adj_inv = inventory + total_inv_add;
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET final_adj_students = 0;

    -- 1) row students within adjusted inventory -> average the whole row
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET final_adj_students = numberofstudentsadjusted
    WHERE running_adj_students <= final_adj_inv;

    -- 2a) row students exceed inventory but some headroom remains (CONVERT(INT)->trunc)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET final_adj_students = trunc(final_adj_inv - (running_adj_students - numberofstudentsadjusted))::integer
                             % NULLIF(trunc(numberofstudentsadjusted)::integer, 0)
    WHERE running_adj_students > final_adj_inv
          AND final_adj_inv - (running_adj_students - numberofstudentsadjusted) > 0;
    -- 2b) already over inventory in a prior row -> default 0 (no action)

    -- Basic Training only appears through GL4 (per COR guidance)
    UPDATE crunch_temp.atrrsatrmcoursemos
    SET numberofstudentsadjusted = 0
    WHERE coursetypefinal = 'B'
          AND gradelevelfinal::smallint >= 5
          AND gradetypefinal = 'E';

    -- =========================================================================
    -- roll up per-version course totals
    -- =========================================================================
    INSERT INTO crunch_temp.trainingcostsbyversion
        (amcosversionid, atrm_key, atrrs_key, atrm_coursetitle, atrm_mpa, atrm_oma, atrm_other,
         inventory, payplan, mosfinal, coursetypefinal, weaponsystemname, gradetypefinal,
         gradelevelfinal, numberofstudentsadjusted, mpa_total_cost, oma_total_cost, other_total_cost)
    SELECT amcosversionid, atrm_key, atrrs_key, atrm_coursetitle,
           MAX(COALESCE(atrm_mpa, 0)) AS atrm_mpa,
           MAX(COALESCE(atrm_oma, 0)) AS atrm_oma,
           MAX(COALESCE(atrm_other, 0)) AS atrm_other,
           MAX(inventory) AS inventory,
           payplan, mosfinal, coursetypefinal, weaponsystemname, gradetypefinal, gradelevelfinal,
           SUM(COALESCE(numberofstudentsadjusted, 0)) AS numberofstudentsadjusted,
           0.0 AS mpa_total_cost, 0.0 AS oma_total_cost, 0.0 AS other_total_cost
    FROM crunch_temp.atrrsatrmcoursemos
    GROUP BY amcosversionid, atrm_key, atrrs_key, atrm_coursetitle, payplan, mosfinal, coursetypefinal,
             weaponsystemname, gradetypefinal, gradelevelfinal;

    -- when students exceed inventory, cap the cost at inventory
    UPDATE crunch_temp.trainingcostsbyversion
    SET mpa_total_cost = CASE
                             WHEN numberofstudentsadjusted > inventory THEN inventory * atrm_mpa
                             ELSE numberofstudentsadjusted * atrm_mpa
                         END,
        oma_total_cost = CASE
                             WHEN numberofstudentsadjusted > inventory THEN inventory * atrm_oma
                             ELSE numberofstudentsadjusted * atrm_oma
                         END,
        other_total_cost = CASE
                               WHEN numberofstudentsadjusted > inventory THEN inventory * atrm_other
                               ELSE numberofstudentsadjusted * atrm_other
                           END;

    -- =========================================================================
    -- generate a 3-year moving-average cost table
    -- =========================================================================
    INSERT INTO crunch_temp.trainingcostsaverage
        (weaponsystemname, coursetypefinal, mosfinal, gradetypefinal, gradelevelfinal, payplan,
         inventory, mpa_total_avg_cost, oma_total_avg_cost, other_total_avg_cost, mpa_adj, oma_adj, other_adj)
    SELECT a.weaponsystemname, a.coursetypefinal, a.mosfinal, a.gradetypefinal, a.gradelevelfinal,
           a.payplan, a.inventory, a.mpa_total_avg_cost, a.oma_total_avg_cost, a.other_total_avg_cost,
           0.0 AS mpa_adj, 0.0 AS oma_adj, 0.0 AS other_adj
    FROM (
        SELECT weaponsystemname, coursetypefinal, mosfinal, gradetypefinal, gradelevelfinal, payplan,
               MAX(inventory) AS inventory,
               SUM(COALESCE(mpa_total_cost, 0)) / 3 AS mpa_total_avg_cost,
               SUM(COALESCE(oma_total_cost, 0)) / 3 AS oma_total_avg_cost,
               SUM(COALESCE(other_total_cost, 0)) / 3 AS other_total_avg_cost
        FROM crunch_temp.trainingcostsbyversion
        GROUP BY weaponsystemname, coursetypefinal, mosfinal, gradetypefinal, gradelevelfinal, payplan
    ) AS a;

    -- =========================================================================
    -- rebalance the average table to the Army budget by course type
    -- =========================================================================
    -- reporting codes (MOS starting with '0') do not get MOS-level ATRM/ATRRS costs
    UPDATE crunch_temp.trainingcostsaverage
    SET mpa_total_avg_cost = 0,
        oma_total_avg_cost = 0,
        other_total_avg_cost = 0
    WHERE left(mosfinal, 1) = '0';

    -- ATRM/ATRRS-generated course totals by type
    SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost) INTO v_osut_total
    FROM crunch_temp.trainingcostsaverage WHERE coursetypefinal IN ('OSUT');

    SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost) INTO v_b_total
    FROM crunch_temp.trainingcostsaverage WHERE coursetypefinal IN ('B');

    SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost) INTO v_pc_total
    FROM crunch_temp.trainingcostsaverage WHERE coursetypefinal IN ('P', 'C');

    SELECT SUM(oma_total_avg_cost) + SUM(other_total_avg_cost) INTO v_ait_iet_total
    FROM crunch_temp.trainingcostsaverage WHERE coursetypefinal IN ('IET', 'AIT');

    -- budget amounts
    v_osut_budget           := crunch.getarmybudgetsinglevalue('Training-OSUT', 'OMA', 'Avg', p_amcosversionid);
    v_b_budget              := crunch.getarmybudgetsinglevalue('Training-Recruit', 'OMA', 'Avg', p_amcosversionid);
    v_pc_budget             := crunch.getarmybudgetsinglevalue('Training-Professional Development Education', 'OMA', 'Avg', p_amcosversionid);
    v_ait_iet_budget        := crunch.getarmybudgetsinglevalue('Training-Specialized Skill', 'OMA', 'Avg', p_amcosversionid);
    v_budgettrainingflight  := crunch.getarmybudgetsinglevalue('Training-Flight', 'OMA', 'Avg', p_amcosversionid);
    v_budgettrainingsupport := crunch.getarmybudgetsinglevalue('Training-Support', 'OMA', 'Avg', p_amcosversionid);

    v_training_budget_total := v_osut_budget + v_b_budget + v_pc_budget + v_ait_iet_budget
                               + v_budgettrainingsupport + v_budgettrainingflight;

    -- rebalancing factors (NULLIF guards empty course-type totals)
    v_osut_perc    := v_osut_budget / NULLIF(v_osut_total, 0);
    v_b_perc       := v_b_budget / NULLIF(v_b_total, 0);
    v_pc_perc      := v_pc_budget / NULLIF(v_pc_total, 0);
    v_ait_iet_perc := v_ait_iet_budget / NULLIF(v_ait_iet_total, 0);

    -- apply factors
    UPDATE crunch_temp.trainingcostsaverage
    SET mpa_adj = mpa_total_avg_cost * v_osut_perc,
        oma_adj = oma_total_avg_cost * v_osut_perc,
        other_adj = other_total_avg_cost * v_osut_perc
    WHERE coursetypefinal IN ('OSUT');
    UPDATE crunch_temp.trainingcostsaverage
    SET mpa_adj = mpa_total_avg_cost * v_b_perc,
        oma_adj = oma_total_avg_cost * v_b_perc,
        other_adj = other_total_avg_cost * v_b_perc
    WHERE coursetypefinal IN ('B');
    UPDATE crunch_temp.trainingcostsaverage
    SET mpa_adj = mpa_total_avg_cost * v_pc_perc,
        oma_adj = oma_total_avg_cost * v_pc_perc,
        other_adj = other_total_avg_cost * v_pc_perc
    WHERE coursetypefinal IN ('P', 'C');
    UPDATE crunch_temp.trainingcostsaverage
    SET mpa_adj = mpa_total_avg_cost * v_ait_iet_perc,
        oma_adj = oma_total_avg_cost * v_ait_iet_perc,
        other_adj = other_total_avg_cost * v_ait_iet_perc
    WHERE coursetypefinal IN ('AIT', 'IET');
    UPDATE crunch_temp.trainingcostsaverage
    SET mpa_adj = mpa_total_avg_cost,
        oma_adj = oma_total_avg_cost,
        other_adj = other_total_avg_cost
    WHERE coursetypefinal IN ('W', 'F', 'O');

    SELECT v_training_budget_total - (SUM(oma_adj) + SUM(other_adj))
    INTO v_unallocated_training_budget
    FROM crunch_temp.trainingcostsaverage;

    SELECT v_unallocated_training_budget / NULLIF(SUM(inventory), 0)
    INTO v_unallocated_budget_per_soldier
    FROM data.inventory
    WHERE payplan IN ('AO', 'AWO', 'AE')
          AND amcosversionid = p_amcosversionid;

    -- =========================================================================
    -- generate final costs into crunch_temp.trainingcosts
    -- =========================================================================
    -- start from inventory (so MOSes with no MOS-specific cost still get CMF/PP costs)
    -- FULL OUTER JOIN with the average table's course-type/weapon combinations.
    -- gradelevel from knowninventory (varchar) cast ::smallint into the smallint column.
    INSERT INTO crunch_temp.trainingcosts
        (payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel, weaponsystemname,
         coursetype, inventory, mpa_mos, oma_mos, other_mos, mpa_cmf, oma_cmf, other_cmf, mpa_pp,
         oma_pp, other_pp, cgla_mos_inv, cgla_cmf_inv, cgla_pp_inv, cgla_mpa, cgla_oma, cgla_other,
         rpa_ngpa, omar_omng, weaponsystemid)
    SELECT a.payplan, a.categorygroupcode, a.categorysubgroupcode, a.gradetype, a.gradelevel::smallint,
           a.weaponsystemname, a.coursetype, a.inventory,
           0.0 AS mpa_mos, 0.0 AS oma_mos, 0.0 AS other_mos,
           0.0 AS mpa_cmf, 0.0 AS oma_cmf, 0.0 AS other_cmf,
           0.0 AS mpa_pp, 0.0 AS oma_pp, 0.0 AS other_pp,
           0.0 AS cgla_mos_inv, 0.0 AS cgla_cmf_inv, 0.0 AS cgla_pp_inv,
           0.0 AS cgla_mpa, 0.0 AS cgla_oma, 0.0 AS cgla_other,
           0.0 AS rpa_ngpa, 0.0 AS omar_omng,
           NULL::integer AS weaponsystemid
    FROM (
        SELECT a.*,
               b.coursetype,
               b.weaponsystemname
        FROM (
            SELECT payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel,
                   SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
                  AND amcosversionid = p_amcosversionid
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, gradetype, gradelevel
        ) AS a
            FULL OUTER JOIN (
                SELECT payplan, coursetypefinal AS coursetype, weaponsystemname
                FROM crunch_temp.trainingcostsaverage
                WHERE coursetypefinal IS NOT NULL
                GROUP BY payplan, coursetypefinal, weaponsystemname
                UNION SELECT 'AO', 'G', 'Not Applicable'
                UNION SELECT 'AE', 'G', 'Not Applicable'
                UNION SELECT 'AWO', 'G', 'Not Applicable'
                UNION SELECT 'RO', 'G', 'Not Applicable'
                UNION SELECT 'RE', 'G', 'Not Applicable'
                UNION SELECT 'RWO', 'G', 'Not Applicable'
                UNION SELECT 'NO', 'G', 'Not Applicable'
                UNION SELECT 'NE', 'G', 'Not Applicable'
                UNION SELECT 'NWO', 'G', 'Not Applicable'
                UNION SELECT 'RE', 'IET', 'Not Applicable'
                UNION SELECT 'NE', 'IET', 'Not Applicable'
            ) AS b
                ON a.payplan = b.payplan
    ) AS a;

    -- CGLA inventory at the category-subgroup level (reverse cumulative + parent inventory).
    -- Self-join rewritten: target not re-aliased in FROM; knowninventory.gradelevel (varchar)
    -- cast ::smallint in ORDER BY (numeric, not lexical, ordering) and in the join.
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mos_inv = b.inv_cumulative
    FROM (
        SELECT payplan, categorysubgroupcode, gradetype, gradelevel, inventory,
               SUM(inventory) OVER (
                   PARTITION BY payplan, categorysubgroupcode
                   ORDER BY payplan, categorysubgroupcode, gradelevel::smallint DESC
               ) + crunch.getparentinventory(payplan, categorysubgroupcode, p_amcosversionid) AS inv_cumulative
        FROM (
            SELECT payplan, categorysubgroupcode, gradetype, gradelevel, SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
                  AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
            GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel
        ) AS a
        GROUP BY payplan, categorysubgroupcode, gradetype, gradelevel, inventory
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel::smallint;

    -- CGLA inventory at the category-group level
    UPDATE crunch_temp.trainingcosts t
    SET cgla_cmf_inv = b.inv_cumulative
    FROM (
        SELECT payplan, categorygroupcode, gradetype, gradelevel, inventory,
               SUM(inventory) OVER (
                   PARTITION BY payplan, categorygroupcode
                   ORDER BY payplan, categorygroupcode, gradelevel::smallint DESC
               ) AS inv_cumulative
        FROM (
            SELECT payplan, categorygroupcode, gradetype, gradelevel, SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
                  AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
            GROUP BY payplan, categorygroupcode, gradetype, gradelevel
        ) AS a
        GROUP BY payplan, categorygroupcode, gradetype, gradelevel, inventory
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorygroupcode = b.categorygroupcode
          AND t.gradelevel = b.gradelevel::smallint;

    -- CGLA inventory at the pay-plan level
    UPDATE crunch_temp.trainingcosts t
    SET cgla_pp_inv = b.inv_cumulative
    FROM (
        SELECT payplan, gradetype, gradelevel, inventory,
               SUM(inventory) OVER (
                   PARTITION BY payplan
                   ORDER BY payplan, gradelevel::smallint DESC
               ) AS inv_cumulative
        FROM (
            SELECT payplan, gradetype, gradelevel, SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
                  AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
            GROUP BY payplan, gradetype, gradelevel
        ) AS a
        GROUP BY payplan, gradetype, gradelevel, inventory
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.gradelevel = b.gradelevel::smallint;

    -- bring in average total costs for MOS-level, weapon system only.
    -- Self-joins rewritten (target not re-aliased). A.gradelevel (smallint) compared to
    -- B.gradelevelfinal (varchar) -> cast ::smallint.
    UPDATE crunch_temp.trainingcosts t
    SET mpa_mos = COALESCE(b.mpa_adj, 0),
        oma_mos = COALESCE(b.oma_total_avg_cost, 0),
        other_mos = COALESCE(b.other_total_avg_cost, 0)
    FROM crunch_temp.trainingcostsaverage b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.mosfinal
          AND t.gradelevel = b.gradelevelfinal::smallint
          AND t.coursetype = b.coursetypefinal
          AND t.weaponsystemname = b.weaponsystemname
          AND t.coursetype = 'W';

    -- MOS-level, non-weapon
    UPDATE crunch_temp.trainingcosts t
    SET mpa_mos = COALESCE(b.mpa_adj, 0),
        oma_mos = COALESCE(b.oma_adj, 0),
        other_mos = COALESCE(b.other_adj, 0)
    FROM crunch_temp.trainingcostsaverage b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.mosfinal
          AND t.gradelevel = b.gradelevelfinal::smallint
          AND t.coursetype = b.coursetypefinal
          AND t.coursetype <> 'W';

    -- CMF-level, weapon system only
    UPDATE crunch_temp.trainingcosts t
    SET mpa_cmf = COALESCE(b.mpa_adj, 0),
        oma_cmf = COALESCE(b.oma_adj, 0),
        other_cmf = COALESCE(b.other_adj, 0)
    FROM crunch_temp.trainingcostsaverage b
    WHERE t.payplan = b.payplan
          AND t.categorygroupcode = b.mosfinal
          AND t.gradelevel = b.gradelevelfinal::smallint
          AND t.coursetype = b.coursetypefinal
          AND t.weaponsystemname = b.weaponsystemname
          AND t.coursetype = 'W';

    -- CMF-level, non-weapon
    UPDATE crunch_temp.trainingcosts t
    SET mpa_cmf = COALESCE(b.mpa_adj, 0),
        oma_cmf = COALESCE(b.oma_adj, 0),
        other_cmf = COALESCE(b.other_adj, 0)
    FROM crunch_temp.trainingcostsaverage b
    WHERE t.payplan = b.payplan
          AND t.categorygroupcode = b.mosfinal
          AND t.gradelevel = b.gradelevelfinal::smallint
          AND t.coursetype = b.coursetypefinal
          AND t.coursetype <> 'W';

    -- Pay-plan level, weapon system only
    UPDATE crunch_temp.trainingcosts t
    SET mpa_pp = COALESCE(b.mpa_adj, 0),
        oma_pp = COALESCE(b.oma_adj, 0),
        other_pp = COALESCE(b.other_adj, 0)
    FROM crunch_temp.trainingcostsaverage b
    WHERE t.payplan = b.payplan
          AND t.gradelevel = b.gradelevelfinal::smallint
          AND t.coursetype = b.coursetypefinal
          AND t.weaponsystemname = b.weaponsystemname
          AND b.mosfinal = 'XXX'
          AND t.coursetype = 'W';

    -- Pay-plan level, non-weapon
    UPDATE crunch_temp.trainingcosts t
    SET mpa_pp = COALESCE(b.mpa_adj, 0),
        oma_pp = COALESCE(b.oma_adj, 0),
        other_pp = COALESCE(b.other_adj, 0)
    FROM crunch_temp.trainingcostsaverage b
    WHERE t.payplan = b.payplan
          AND t.gradelevel = b.gradelevelfinal::smallint
          AND t.coursetype = b.coursetypefinal
          AND b.mosfinal = 'XXX'
          AND t.coursetype <> 'W';

    -- bring in the weapon system IDs
    UPDATE crunch_temp.trainingcosts t
    SET weaponsystemid = ws.weaponsystemid
    FROM lookup.weaponsystem ws
    WHERE t.weaponsystemname = ws.weaponsystemname
          AND t.coursetype = 'W'
          AND p_amcosversionid BETWEEN ws.amcosversionidstart AND ws.amcosversionidend;

    -- =========================================================================
    -- CGLA math: spread costs down grade levels (window sum of cost/CGLA-inventory
    -- plus the recursive child-training contribution). Self-joins rewritten so the
    -- target row's own CGLA_* value is read via the update alias t; the windowed
    -- source is a separate subquery scan in FROM. trainingcosts.gradelevel is smallint
    -- here, so the window ORDER BYs need no cast.
    -- =========================================================================
    -- category-subgroup level, with weapon system
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mpa = t.cgla_mpa + COALESCE(b.mpa, 0),
        cgla_oma = t.cgla_oma + COALESCE(b.oma, 0),
        cgla_other = t.cgla_other + COALESCE(b.other, 0)
    FROM (
        SELECT payplan, categorysubgroupcode, gradetype, gradelevel, weaponsystemname, coursetype,
               SUM(mpa_mos / NULLIF(cgla_mos_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC)
               + crunch.getchildtrainingweaponsrecursive(
                     payplan, categorysubgroupcode, gradetype, coursetype, weaponsystemname, gradelevel,
                     'TrainingMPA', p_amcosversionid) AS mpa,
               SUM(oma_mos / NULLIF(cgla_mos_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC)
               + crunch.getchildtrainingweaponsrecursive(
                     payplan, categorysubgroupcode, gradetype, coursetype, weaponsystemname, gradelevel,
                     'TrainingOMA', p_amcosversionid) AS oma,
               SUM(other_mos / NULLIF(cgla_mos_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC)
               + crunch.getchildtrainingweaponsrecursive(
                     payplan, categorysubgroupcode, gradetype, coursetype, weaponsystemname, gradelevel,
                     'TrainingOther', p_amcosversionid) AS other
        FROM crunch_temp.trainingcosts
        WHERE coursetype = 'W'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel
          AND t.weaponsystemname = b.weaponsystemname
          AND t.coursetype = b.coursetype;

    -- category-subgroup level, without weapon system
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mpa = t.cgla_mpa + COALESCE(b.mpa, 0),
        cgla_oma = t.cgla_oma + COALESCE(b.oma, 0),
        cgla_other = t.cgla_other + COALESCE(b.other, 0)
    FROM (
        SELECT payplan, categorysubgroupcode, gradetype, gradelevel, coursetype,
               SUM(mpa_mos / NULLIF(cgla_mos_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC)
               + crunch.getchildtrainingrecursive(
                     payplan, categorysubgroupcode, gradetype, coursetype, gradelevel,
                     'TrainingMPA', p_amcosversionid) AS mpa,
               SUM(oma_mos / NULLIF(cgla_mos_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC)
               + crunch.getchildtrainingrecursive(
                     payplan, categorysubgroupcode, gradetype, coursetype, gradelevel,
                     'TrainingOMA', p_amcosversionid) AS oma,
               SUM(other_mos / NULLIF(cgla_mos_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC)
               + crunch.getchildtrainingrecursive(
                     payplan, categorysubgroupcode, gradetype, coursetype, gradelevel,
                     'TrainingOther', p_amcosversionid) AS other
        FROM crunch_temp.trainingcosts
        WHERE coursetype <> 'W'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel
          AND t.coursetype = b.coursetype;

    -- category-group level, with weapon system
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mpa = t.cgla_mpa + COALESCE(b.mpa, 0),
        cgla_oma = t.cgla_oma + COALESCE(b.oma, 0),
        cgla_other = t.cgla_other + COALESCE(b.other, 0)
    FROM (
        SELECT payplan, categorysubgroupcode, gradelevel, weaponsystemname, coursetype,
               SUM(mpa_cmf / NULLIF(cgla_cmf_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC) AS mpa,
               SUM(oma_cmf / NULLIF(cgla_cmf_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC) AS oma,
               SUM(other_cmf / NULLIF(cgla_cmf_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC) AS other
        FROM crunch_temp.trainingcosts
        WHERE coursetype = 'W'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel
          AND t.weaponsystemname = b.weaponsystemname
          AND t.coursetype = b.coursetype;

    -- category-group level, without weapon system
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mpa = t.cgla_mpa + COALESCE(b.mpa, 0),
        cgla_oma = t.cgla_oma + COALESCE(b.oma, 0),
        cgla_other = t.cgla_other + COALESCE(b.other, 0)
    FROM (
        SELECT payplan, categorysubgroupcode, gradelevel, coursetype,
               SUM(mpa_cmf / NULLIF(cgla_cmf_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC) AS mpa,
               SUM(oma_cmf / NULLIF(cgla_cmf_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC) AS oma,
               SUM(other_cmf / NULLIF(cgla_cmf_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC) AS other
        FROM crunch_temp.trainingcosts
        WHERE coursetype <> 'W'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel
          AND t.coursetype = b.coursetype;

    -- pay-plan level, with weapon system
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mpa = t.cgla_mpa + COALESCE(b.mpa, 0),
        cgla_oma = t.cgla_oma + COALESCE(b.oma, 0),
        cgla_other = t.cgla_other + COALESCE(b.other, 0)
    FROM (
        SELECT payplan, categorysubgroupcode, gradelevel, weaponsystemname, coursetype,
               SUM(mpa_pp / NULLIF(cgla_pp_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC) AS mpa,
               SUM(oma_pp / NULLIF(cgla_pp_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC) AS oma,
               SUM(other_pp / NULLIF(cgla_pp_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                   ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC) AS other
        FROM crunch_temp.trainingcosts
        WHERE coursetype = 'W'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel
          AND t.weaponsystemname = b.weaponsystemname
          AND t.coursetype = b.coursetype;

    -- pay-plan level, without weapon system
    UPDATE crunch_temp.trainingcosts t
    SET cgla_mpa = t.cgla_mpa + COALESCE(b.mpa, 0),
        cgla_oma = t.cgla_oma + COALESCE(b.oma, 0),
        cgla_other = t.cgla_other + COALESCE(b.other, 0)
    FROM (
        SELECT payplan, categorysubgroupcode, gradelevel, coursetype,
               SUM(mpa_pp / NULLIF(cgla_pp_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC) AS mpa,
               SUM(oma_pp / NULLIF(cgla_pp_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC) AS oma,
               SUM(other_pp / NULLIF(cgla_pp_inv, 0)) OVER (
                   PARTITION BY payplan, categorysubgroupcode, coursetype
                   ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC) AS other
        FROM crunch_temp.trainingcosts
        WHERE coursetype <> 'W'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.categorysubgroupcode = b.categorysubgroupcode
          AND t.gradelevel = b.gradelevel
          AND t.coursetype = b.coursetype;

    -- assign the unallocated training budget to the 'G' course type (active only)
    UPDATE crunch_temp.trainingcosts
    SET cgla_oma = cgla_oma + v_unallocated_budget_per_soldier
    WHERE coursetype = 'G'
          AND payplan IN ('AO', 'AE', 'AWO');

    -- =========================================================================
    -- NG/R-specific budget costs.  Source sums KnownInventory with no version
    -- filter (preserved verbatim); NULLIF guards the per-soldier denominators.
    -- =========================================================================
    SELECT SUM(inventory) INTO v_ar_all FROM data.knowninventory WHERE payplan IN ('RO', 'RWO', 'RE');
    SELECT SUM(inventory) INTO v_ng_all FROM data.knowninventory WHERE payplan IN ('NO', 'NWO', 'NE');
    SELECT SUM(inventory) INTO v_ar_e   FROM data.knowninventory WHERE payplan IN ('RE');
    SELECT SUM(inventory) INTO v_ng_e   FROM data.knowninventory WHERE payplan IN ('NE');

    -- specific NG/R training budget elements existed only for FY2020-2022
    IF (p_amcosversionid BETWEEN 202001 AND 202201) THEN
        -- IET (non-prior-service enlisted)
        v_iet_rpa  := crunch.getarmybudgetsinglevalue('Training-IET', 'RPA', 'Avg', p_amcosversionid);
        v_iet_omar := crunch.getarmybudgetsinglevalue('Training-IET', 'OMAR', 'Avg', p_amcosversionid);
        v_iet_ngpa := crunch.getarmybudgetsinglevalue('Training-IET', 'NGPA', 'Avg', p_amcosversionid);
        v_iet_omng := crunch.getarmybudgetsinglevalue('Training-IET', 'OMNG', 'Avg', p_amcosversionid);

        v_iet_rpa_soldier  := v_iet_rpa / NULLIF(v_ar_e, 0);
        v_iet_omar_soldier := v_iet_omar / NULLIF(v_ar_e, 0);
        v_iet_ngpa_soldier := v_iet_ngpa / NULLIF(v_ng_e, 0);
        v_iet_omng_soldier := v_iet_omng / NULLIF(v_ar_e, 0);

        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_iet_rpa_soldier, omar_omng = v_iet_omar_soldier
        WHERE coursetype = 'IET' AND payplan IN ('RE');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_iet_ngpa_soldier, omar_omng = v_iet_omng_soldier
        WHERE coursetype = 'IET' AND payplan IN ('NE');

        -- AIT / initial skills (all soldiers; O/WO reclassed to IET below)
        v_ait_rpa  := crunch.getarmybudgetsinglevalue('Training-Initial SKills', 'RPA', 'Avg', p_amcosversionid);
        v_ait_omar := crunch.getarmybudgetsinglevalue('Training-Initial SKills', 'OMAR', 'Avg', p_amcosversionid);
        v_ait_ngpa := crunch.getarmybudgetsinglevalue('Training-Initial SKills', 'NGPA', 'Avg', p_amcosversionid);
        v_ait_omng := crunch.getarmybudgetsinglevalue('Training-Initial SKills', 'OMNG', 'Avg', p_amcosversionid);

        v_ait_rpa_soldier  := v_ait_rpa / NULLIF(v_ar_all, 0);
        v_ait_omar_soldier := v_ait_omar / NULLIF(v_ar_all, 0);
        v_ait_ngpa_soldier := v_ait_ngpa / NULLIF(v_ng_all, 0);
        v_ait_omng_soldier := v_ait_omng / NULLIF(v_ar_all, 0);

        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_ait_rpa_soldier, omar_omng = v_ait_omar_soldier
        WHERE coursetype = 'AIT' AND payplan IN ('RE');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_ait_ngpa_soldier, omar_omng = v_ait_omng_soldier
        WHERE coursetype = 'AIT' AND payplan IN ('NE');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = rpa_ngpa + v_ait_rpa_soldier, omar_omng = omar_omng + v_ait_omar_soldier
        WHERE coursetype = 'IET' AND payplan IN ('RO', 'RWO');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = rpa_ngpa + v_ait_ngpa_soldier, omar_omng = omar_omng + v_ait_omng_soldier
        WHERE coursetype = 'IET' AND payplan IN ('NO', 'NWO');

        -- MOS qualification (enlisted AIT)
        v_mos_qual_rpa  := crunch.getarmybudgetsinglevalue('Training-MOS Qualification', 'RPA', 'Avg', p_amcosversionid);
        v_mos_qual_omar := crunch.getarmybudgetsinglevalue('Training-MOS Qualification', 'OMAR', 'Avg', p_amcosversionid);
        v_mos_qual_ngpa := crunch.getarmybudgetsinglevalue('Training-MOS Qualification', 'NGPA', 'Avg', p_amcosversionid);
        v_mos_qual_omng := crunch.getarmybudgetsinglevalue('Training-MOS Qualification', 'OMNG', 'Avg', p_amcosversionid);

        v_mos_qual_rpa_soldier  := v_mos_qual_rpa / NULLIF(v_ar_e, 0);
        v_mos_qual_omar_soldier := v_mos_qual_omar / NULLIF(v_ar_e, 0);
        v_mos_qual_ngpa_soldier := v_mos_qual_ngpa / NULLIF(v_ng_e, 0);
        v_mos_qual_omng_soldier := v_mos_qual_omng / NULLIF(v_ar_e, 0);

        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = rpa_ngpa + v_mos_qual_rpa_soldier, omar_omng = omar_omng + v_mos_qual_omar_soldier
        WHERE coursetype = 'AIT' AND payplan IN ('RE');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = rpa_ngpa + v_mos_qual_ngpa_soldier, omar_omng = omar_omng + v_mos_qual_omng_soldier
        WHERE coursetype = 'AIT' AND payplan IN ('NE');

        -- professional (career development) education (all soldiers)
        v_p_rpa  := crunch.getarmybudgetsinglevalue('Training-Professional', 'RPA', 'Avg', p_amcosversionid);
        v_p_omar := crunch.getarmybudgetsinglevalue('Training-Professional', 'OMAR', 'Avg', p_amcosversionid);
        v_p_ngpa := crunch.getarmybudgetsinglevalue('Training-Professional', 'NGPA', 'Avg', p_amcosversionid);
        v_p_omng := crunch.getarmybudgetsinglevalue('Training-Professional', 'OMNG', 'Avg', p_amcosversionid);

        v_p_rpa_soldier  := v_p_rpa / NULLIF(v_ar_all, 0);
        v_p_omar_soldier := v_p_omar / NULLIF(v_ar_all, 0);
        v_p_ngpa_soldier := v_p_ngpa / NULLIF(v_ng_all, 0);
        v_p_omng_soldier := v_p_omng / NULLIF(v_ar_all, 0);

        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_p_rpa_soldier, omar_omng = v_p_omar_soldier
        WHERE coursetype = 'P' AND payplan IN ('RE', 'RO', 'RWO');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_p_ngpa_soldier, omar_omng = v_p_omng_soldier
        WHERE coursetype = 'P' AND payplan IN ('NE', 'NO', 'NWO');

        -- balance into a general training bucket (Support + Special Skills)
        v_g_rpa  := crunch.getarmybudgetsinglevalue('Training-Support', 'RPA', 'Avg', p_amcosversionid)
                    + crunch.getarmybudgetsinglevalue('Training-Special Skills Training', 'RPA', 'Avg', p_amcosversionid);
        v_g_omar := crunch.getarmybudgetsinglevalue('Training-Support', 'OMAR', 'Avg', p_amcosversionid)
                    + crunch.getarmybudgetsinglevalue('Training-Special Skills Training', 'OMAR', 'Avg', p_amcosversionid);
        v_g_ngpa := crunch.getarmybudgetsinglevalue('Training-Support', 'NGPA', 'Avg', p_amcosversionid)
                    + crunch.getarmybudgetsinglevalue('Training-Special Skills Training', 'NGPA', 'Avg', p_amcosversionid);
        v_g_omng := crunch.getarmybudgetsinglevalue('Training-Support', 'OMNG', 'Avg', p_amcosversionid)
                    + crunch.getarmybudgetsinglevalue('Training-Special Skills Training', 'OMNG', 'Avg', p_amcosversionid);

        v_g_rpa_soldier  := v_g_rpa / NULLIF(v_ar_all, 0);
        v_g_omar_soldier := v_g_omar / NULLIF(v_ar_all, 0);
        v_g_ngpa_soldier := v_g_ngpa / NULLIF(v_ng_all, 0);
        v_g_omng_soldier := v_g_omng / NULLIF(v_ar_all, 0);

        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_g_rpa_soldier, omar_omng = v_g_omar_soldier
        WHERE coursetype = 'G' AND payplan IN ('RE', 'RO', 'RWO');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = v_g_ngpa_soldier, omar_omng = v_g_omng_soldier
        WHERE coursetype = 'G' AND payplan IN ('NE', 'NO', 'NWO');
    END IF;

    -- FY2023+ uses a single general training element (NULLIF guards denominators)
    IF (p_amcosversionid >= 202301) THEN
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = crunch.getarmybudgetsinglevalue('General Training', 'RPA', 'Avg', p_amcosversionid) / NULLIF(v_ar_all, 0),
            omar_omng = crunch.getarmybudgetsinglevalue('General Training', 'OMAR', 'Avg', p_amcosversionid) / NULLIF(v_ar_all, 0)
        WHERE coursetype = 'G' AND payplan IN ('RE', 'RO', 'RWO');
        UPDATE crunch_temp.trainingcosts
        SET rpa_ngpa = crunch.getarmybudgetsinglevalue('General Training', 'NGPA', 'Avg', p_amcosversionid) / NULLIF(v_ng_all, 0),
            omar_omng = crunch.getarmybudgetsinglevalue('General Training', 'OMNG', 'Avg', p_amcosversionid) / NULLIF(v_ng_all, 0)
        WHERE coursetype = 'G' AND payplan IN ('NE', 'NO', 'NWO');
    END IF;

    -- 3/15/2021 weighted-average the three Apache WOMOS weapon costs back onto those
    -- subgroups (NG/R only) to damp cost swings from small, sporadic inventory.
    UPDATE crunch_temp.trainingcosts t
    SET mpa_mos = b.mpa_mos,
        oma_mos = b.oma_mos,
        other_mos = b.other_mos,
        cgla_mpa = b.cgla_mpa,
        cgla_oma = b.cgla_oma,
        cgla_other = b.cgla_other
    FROM (
        SELECT payplan, gradelevel, weaponsystemid,
               SUM(mpa_mos * inventory) / NULLIF(SUM(inventory), 0) AS mpa_mos,
               SUM(oma_mos * inventory) / NULLIF(SUM(inventory), 0) AS oma_mos,
               SUM(other_mos * inventory) / NULLIF(SUM(inventory), 0) AS other_mos,
               SUM(cgla_mpa * inventory) / NULLIF(SUM(inventory), 0) AS cgla_mpa,
               SUM(cgla_oma * inventory) / NULLIF(SUM(inventory), 0) AS cgla_oma,
               SUM(cgla_other * inventory) / NULLIF(SUM(inventory), 0) AS cgla_other
        FROM crunch_temp.trainingcosts
        WHERE payplan IN ('RWO', 'NWO')
              AND categorysubgroupcode IN ('152E', '152F', '152H')
              AND weaponsystemid IS NOT NULL
        GROUP BY payplan, gradelevel, weaponsystemid
    ) AS b
    WHERE b.gradelevel = t.gradelevel
          AND b.payplan = t.payplan
          AND b.weaponsystemid = t.weaponsystemid
          AND t.payplan IN ('RWO', 'NWO')
          AND t.categorysubgroupcode IN ('152E', '152F', '152H')
          AND t.weaponsystemid IS NOT NULL;

    -- drop all-zero rows for a concise final table
    DELETE FROM crunch_temp.trainingcosts
    WHERE cgla_mpa = 0
          AND cgla_oma = 0
          AND cgla_other = 0
          AND rpa_ngpa = 0
          AND omar_omng = 0;

    -- =========================================================================
    -- write the final military cost tables (dry run when p_debug = true)
    -- =========================================================================
    IF NOT p_debug THEN
        -- clear existing rows for every CE id we are about to (re)insert
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN ( 56, 58, 60, 62, 65, 91, 93, 95, 97, 100, 110, 112, 114, 116, 119, 3379, 3381, 3383,
                                 3385, 3387, 3389, 3957, 3958, 3959, 3960, 3961, 3962, 3983, 4022, 4041, 4044, 4059,
                                 4068, 4085, 4086, 4109, 4112, 4127, 4136, 4202, 4203
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN ( 163, 165, 167, 184, 186, 188, 194, 196, 198, 649, 650, 651, 670, 671, 672, 3391, 3393,
                                 3395, 3397, 3399, 3401, 3969, 3977, 3986, 3994, 4006, 4008, 4016, 4021, 4045, 4053,
                                 4062, 4071, 4083, 4087, 4113, 4121, 4130, 4139, 4151, 4153
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN ( 237, 239, 241, 252, 254, 256, 265, 267, 269, 686, 687, 688, 692, 693, 694, 3403, 3405,
                                 3407, 3409, 3411, 3413, 3970, 3978, 3987, 3995, 4007, 4009, 4017, 4023, 4046, 4054,
                                 4063, 4072, 4084, 4088, 4114, 4122, 4131, 4140, 4152, 4154
                               )
              AND AmcosVersionId = p_amcosversionid;
        --NG/R: Have additional APPNsMPA, OMA, OMA_1 for actual and avg costs
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN ( 309, 313, 318, 322, 347, 352, 3415, 3417, 3419, 3421, 3423, 3425, 3967, 3971, 3984,
                                 3993, 4004, 4010, 4019, 4028, 4033, 4034, 4037, 4039, 4042, 4047, 4060, 4070, 4081,
                                 4092, 4095, 4097, 4098, 4100, 4103, 4105, 4108, 4110, 4115, 4128, 4138, 4149, 4158,
                                 4162, 4168, 4173, 4176, 4177, 4183
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN ( 369, 371, 373, 378, 380, 382, 400, 404, 406, 3029, 3031, 3033, 3035, 3037, 3039, 3427,
                                 3429, 3431, 3433, 3471, 3472, 3972, 3979, 3990, 3996, 4000, 4011, 4018, 4027, 4048,
                                 4057, 4066, 4075, 4077, 4093, 4116, 4125, 4134, 4143, 4145, 4159, 4161, 4167, 4178,
                                 4184, 4208, 4210
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN ( 420, 422, 424, 429, 431, 433, 440, 444, 446, 3041, 3043, 3045, 3047, 3049, 3051, 3435,
                                 3437, 3439, 3441, 3475, 3476, 3973, 3980, 3991, 3997, 4001, 4012, 4020, 4029, 4049,
                                 4058, 4067, 4076, 4078, 4094, 4117, 4126, 4135, 4144, 4146, 4160, 4163, 4169, 4179,
                                 4185, 4209, 4211
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN ( 473, 477, 482, 486, 511, 516, 3443, 3445, 3447, 3449, 3451, 3453, 3968, 3974, 3985,
                                 3992, 4005, 4013, 4025, 4031, 4035, 4036, 4038, 4040, 4043, 4050, 4061, 4069, 4082,
                                 4089, 4096, 4099, 4101, 4102, 4104, 4106, 4107, 4111, 4118, 4129, 4137, 4150, 4155,
                                 4165, 4171, 4174, 4175, 4180, 4186
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN ( 533, 535, 537, 542, 544, 546, 564, 568, 570, 655, 656, 657, 673, 674, 675, 3455, 3457,
                                 3459, 3461, 3479, 3480, 3975, 3981, 3988, 3998, 4002, 4014, 4024, 4030, 4051, 4055,
                                 4064, 4073, 4079, 4090, 4119, 4123, 4132, 4141, 4147, 4156, 4164, 4170, 4181, 4187,
                                 4204, 4206
                               )
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN ( 584, 586, 588, 593, 595, 597, 604, 608, 610, 3017, 3019, 3021, 3023, 3025, 3027, 3463,
                                 3465, 3467, 3469, 3483, 3484, 3976, 3982, 3989, 3999, 4003, 4015, 4026, 4032, 4052,
                                 4056, 4065, 4074, 4080, 4091, 4120, 4124, 4133, 4142, 4148, 4157, 4166, 4172, 4182,
                                 4188, 4205, 4207
                               )
              AND AmcosVersionId = p_amcosversionid;
            --##########################  Actual cost of Basic Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3957,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3967,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3968,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4041,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4042,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4043,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4109,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4110,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4111,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';

            --##########################  Actual cost of Career Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3958,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3971,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3974,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4044,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4047,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4050,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4112,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4115,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4118,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3969,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3972,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3975,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4045,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4048,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4051,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4113,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4116,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4119,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3970,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3973,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3976,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4046,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4049,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4052,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4114,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4117,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4120,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';

            --##########################  Actual cost of Initial Entry Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3977,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3979,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3981,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4053,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4057,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4055,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4121,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4125,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4123,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3978,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3980,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3982,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4054,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4058,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4056,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4122,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4126,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4124,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';

            --##########################  Actual cost of Initial Skill Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3959,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3984,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3985,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4059,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4060,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4061,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4127,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4128,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4129,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';

            --##########################  Actual cost of Officer's Undergraduate Pilot Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3986,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3990,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3988,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4062,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4066,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4064,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4130,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4134,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4132,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3987,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3991,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3989,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4063,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4067,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4065,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4131,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4135,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4133,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';

            --##########################  Actual cost of One Station Unit Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3960,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3993,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3992,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4068,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4070,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4069,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4136,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4138,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4137,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';

            --##########################  Actual cost of Other Flight Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3994,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3996,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3998,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4071,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4075,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4073,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4139,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4143,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4141,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3995,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3997,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3999,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4072,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4076,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4074,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4140,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4144,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4142,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';

            --##########################  Actual cost of Professional Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3961,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4004,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4005,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4085,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4081,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4082,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4202,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4149,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4150,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4006,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4000,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4002,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4083,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4077,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4079,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4151,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4145,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4147,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4007,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4001,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4003,
                   GradeType,
                   GradeLevel,
                   -1,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4084,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4078,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4080,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4152,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4146,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4148,
                   GradeType,
                   GradeLevel,
                   -1,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';

            --##########################  Actual cost of Weapon System Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3962,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4010,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4013,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';

            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4086,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4092,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4089,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4203,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4158,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4155,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4008,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4011,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4014,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4087,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4093,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4090,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4153,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4159,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4156,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4009,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4012,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4015,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   MPA_PP + MPA_CMF + MPA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4088,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4094,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4091,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   OMA_PP + OMA_CMF + OMA_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4154,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4160,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4157,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   other_PP + Other_CMF + Other_MOS,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';

            --##########################  Avg cost of Basic Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   56,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4034,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4035,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   91,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4105,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4106,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   110,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'B';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4173,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'B';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4174,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'B';

            --##########################  Avg cost of Career Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   58,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   347,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   511,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   93,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   309,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   473,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   112,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   318,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   482,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'C';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   163,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   400,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   564,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   184,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   369,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   533,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   194,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   378,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   542,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'C';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   237,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   440,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   604,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   252,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   420,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   584,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   265,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'C';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   429,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'C';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   593,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'C';

            --##########################  Avg cost of General Training #################################
            -- ### ENLISTED ###
            -- ## MPA/RPA/NGPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3983,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'G';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4019,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4031,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'G';
            -- ## OMA/OMAR/OMNG ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4022,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'G';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4028,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4025,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'G';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4016,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'G';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4018,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4030,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'G';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4021,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'G';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4027,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4024,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'G';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4017,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'G';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4020,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4032,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'G';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4023,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'G';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4029,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'G';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4026,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'G';

            --##########################  Avg cost of Initial Entry Training #################################
            -- ### ENLISTED ### - NOTE enlisted costs are only for NG/R since they come directly from the JBooks
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4033,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4040,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'IET';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4039,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4038,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'IET';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3391,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3427,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3461,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3395,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3429,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3455,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3399,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3431,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3457,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3403,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3435,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3469,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3407,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3437,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3463,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3411,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'IET';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3439,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3465,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';

            --##########################  Avg cost of Initial Skill Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   60,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4095,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4096,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   95,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4098,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4099,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   114,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'AIT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4100,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4101,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';

            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4097,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4104,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4103,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'AIT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4102,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'AIT';

            --##########################  Avg cost of Officer's Undergraduate Pilot Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   670,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3029,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   673,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   671,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3031,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   674,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   672,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3033,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   675,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'F';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   692,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3041,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3017,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   693,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3043,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3019,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   694,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'F';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3045,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'F';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3021,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'F';

            --##########################  Avg cost of One Station Unit Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   62,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4037,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4036,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   97,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4108,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4107,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   116,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'OSUT';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4176,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'OSUT';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4175,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'OSUT';

            --##########################  Avg cost of Other Flight Training #################################
            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   649,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3035,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   655,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   650,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3037,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   656,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   651,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3039,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   657,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'O';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   686,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3047,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3023,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   687,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3049,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3025,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';
            -- ## Other ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   688,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'O';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3051,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'O';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3027,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'O';

            --##########################  Avg cost of Professional Training #################################
            -- ### ENLISTED ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4162,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4171,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4168,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4165,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3379,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3423,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3451,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3383,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3415,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3443,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3387,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3419,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3447,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'P';

            -- ### Officer ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4161,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4170,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4167,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4164,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   165,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   404,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   568,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   186,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   371,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   535,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   196,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   380,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   544,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'P';

            -- ### Warrant ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4163,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4172,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4169,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4166,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   239,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   444,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   608,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   254,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   422,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   586,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   267,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'P';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   431,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'P';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   595,
                   GradeType,
                   GradeLevel,
                   -1,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'P';

            --##########################  Average cost of Weapon System Training #################################
            -- ### ENLISTED ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3381,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3417,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3453,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3385,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3421,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3445,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3389,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3425,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3449,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
                  AND CourseType = 'W';

            -- ### Officer ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3393,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3471,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3479,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3397,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3472,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3480,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3401,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3433,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3459,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'W';

            -- ### Warrant ###
            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3405,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3475,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3483,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_MPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3409,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3476,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3484,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_OMA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3413,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
                  AND CourseType = 'W';
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3441,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'W';
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   3467,
                   GradeType,
                   GradeLevel,
                   WeaponSystemId,
                   CGLA_Other,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'W';

            --##########################  Avg cost of Training #################################
            -- ### ENLISTED ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4177,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4186,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4183,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4180,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   65,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   352,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   516,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   100,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   313,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   477,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   119,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   322,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   486,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RE'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;

            -- ### OFFICER ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4178,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4187,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4184,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4181,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   167,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   406,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   570,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   188,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   373,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   537,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   198,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   382,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   546,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;

            -- ### Warrant ###
            --## RPA/NGPA ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4179,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4188,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(RPA_NGPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --## OMAR/OMNG ##
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4185,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4182,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(OMAR_OMNG),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;

            -- ## MPA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   241,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   446,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   610,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_MPA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   256,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   424,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   588,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_OMA),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            -- ## OMA_1 ##
            --Active
            INSERT INTO crunch.Costs_AWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId,
                LocationId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   269,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid,
                   -1
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'AWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --NG
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   433,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            --Reserve
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   597,
                   GradeType,
                   GradeLevel,
                   -1,
                   SUM(CGLA_Other),
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeType,
                     GradeLevel;
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4208,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4210,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4209,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4211,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'NWO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4204,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4206,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4205,
                   GradeType,
                   GradeLevel,
                   -1,
                   RPA_NGPA,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
            INSERT INTO crunch.Costs_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime,
                AmcosVersionId
            )
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   4207,
                   GradeType,
                   GradeLevel,
                   -1,
                   OMAR_OMNG,
                   v_crunchtime,
                   p_amcosversionid
            FROM crunch_temp.TrainingCosts
            WHERE PayPlan = 'RWO'
                  AND CourseType = 'IET';
        --delete any costs which are zero
        DELETE FROM crunch.Costs_AE
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_AO
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_AWO
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_RE
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_RO
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_RWO
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_NE
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_NO
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
        DELETE FROM crunch.Costs_NWO
        WHERE Amount = 0
              AND AmcosVersionId = p_amcosversionid;
    END IF;
END;
$$;
