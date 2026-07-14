-- Cost-crunch PHASE 3 helper functions (crunch.*).
-- The 3 recursive MOS-tree bonus/training roll-up helpers + get1daycosts,
-- deferred from Phase 0 because they read the crunch_temp.* staging schema
-- (005e) and crunch.costs_1activeday.categorygroupcode (restored in 005b).
-- LANGUAGE plpgsql (deferred resolution). Runs after 006c + 005e.

-- ============================================================================
-- Phase 3 crunch HELPER functions (deferred from 006c).
--
-- Ports 4 SQL Server UDFs from AMCOS.AMCOS2020_MAR/crunch/Functions/:
--   * GetChildBonusRecursive           -> crunch.getchildbonusrecursive
--   * GetChildTrainingRecursive        -> crunch.getchildtrainingrecursive
--   * GetChildTrainingWeaponsRecursive -> crunch.getchildtrainingweaponsrecursive
--   * Get1DayCosts                     -> crunch.get1daycosts (table-valued)
--
-- All LANGUAGE plpgsql so name resolution is DEFERRED: the recursive three read
-- crunch_temp.* staging tables (costofrecruiting / costofofficeracquisitionbyaoc /
-- costofselectiveretentionbonus / trainingcosts) that exist but are seeded empty
-- by migration 005e; get1daycosts reads crunch.costs_* output tables.
--
-- T-SQL -> PG: ISNULL->COALESCE, TOP(1)->LIMIT 1, NVARCHAR->varchar,
-- TINYINT->smallint. The @TempMOS TABLE-variable + WHILE loop (which walks each
-- child MOS exactly once) is rewritten as a set-based FOR ... LOOP over the same
-- lookup.mos children; the running total is additive so child order is immaterial.
-- ============================================================================


------------------------------------------------------------------------------
-- Source: crunch/Functions/GetChildBonusRecursive.sql
-- Recursive: sums a child MOS subtree's per-CGLA bonus, weighting each child by
-- its inventory share (getchildinventorypercentage) and self-calling. @whichone
-- selects which crunch_temp staging table / column drives the child value.
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crunch.getchildbonusrecursive(
    p_payplan varchar,
    p_categorysubgroupcode varchar,
    p_gradetype varchar,
    p_gradelevel smallint,
    p_whichone varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS numeric(16, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_currentchild varchar(3);
    v_childvalue   numeric(16, 2);
    v_tempperc     numeric(16, 2);
    v_runningtotal numeric(16, 2) := 0.0;
BEGIN
    -- Walk each direct child MOS of the current node exactly once
    -- (replaces the @TempMOS table variable + WHILE/TOP(1) loop).
    FOR v_currentchild IN
        SELECT mos
        FROM lookup.mos
        WHERE parent_mos = p_categorysubgroupcode
          AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ORDER BY mos
    LOOP
        v_childvalue := 0.0;

        -- CostOfRecruiting
        IF p_whichone = 'Recruiting' THEN
            SELECT SUM(bonus_capped_amt / NULLIF(cglainventory, 0))
                       OVER (PARTITION BY payplan, categorysubgroupcode
                             ORDER BY payplan, categorysubgroupcode, gradelevel ASC)
            INTO v_childvalue
            FROM crunch_temp.costofrecruiting
            WHERE categorysubgroupcode = v_currentchild
              AND payplan = p_payplan
            ORDER BY gradelevel DESC
            LIMIT 1;
        END IF;

        -- CostOfOfficerAcquisition
        IF p_whichone = 'OfficerAcquisition' THEN
            SELECT SUM(bonus_mpa / NULLIF(cglainventory, 0))
                       OVER (PARTITION BY payplan, categorysubgroupcode
                             ORDER BY payplan, categorysubgroupcode, gradelevel ASC)
            INTO v_childvalue
            FROM crunch_temp.costofofficeracquisitionbyaoc
            WHERE categorysubgroupcode = v_currentchild
              AND payplan = p_payplan
            ORDER BY gradelevel DESC
            LIMIT 1;
        END IF;

        -- CostOfSelectiveRetentionBonus
        IF p_whichone = 'RetentionBonus' THEN
            SELECT SUM(averageannualpay / NULLIF(cglainventory, 0))
                       OVER (PARTITION BY payplan, categorysubgroupcode
                             ORDER BY payplan, categorysubgroupcode, gradelevel ASC)
            INTO v_childvalue
            FROM crunch_temp.costofselectiveretentionbonus
            WHERE categorysubgroupcode = v_currentchild
              AND payplan = p_payplan
            ORDER BY gradelevel DESC
            LIMIT 1;
        END IF;

        IF v_childvalue IS NULL THEN
            v_childvalue := 0;
        END IF;

        v_tempperc := crunch.getchildinventorypercentage(p_payplan, v_currentchild, p_amcosversionid);

        v_runningtotal := v_runningtotal
            + (v_tempperc
               * (v_childvalue
                  + crunch.getchildbonusrecursive(
                        p_payplan,
                        v_currentchild,
                        p_gradetype,
                        p_gradelevel,
                        p_whichone,
                        p_amcosversionid)));
    END LOOP;

    -- No children -> running total is still 0.0 (matches source RETURN 0).
    RETURN v_runningtotal;
END;
$$;


------------------------------------------------------------------------------
-- Source: crunch/Functions/GetChildTrainingRecursive.sql
-- Same recursive shape; reads crunch_temp.trainingcosts (CourseType <> 'W'),
-- filtered by an explicit p_coursetype, driven by @whichone (MPA/OMA/Other).
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crunch.getchildtrainingrecursive(
    p_payplan varchar,
    p_categorysubgroupcode varchar,
    p_gradetype varchar,
    p_coursetype varchar,
    p_gradelevel smallint,
    p_whichone varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS numeric(16, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_currentchild varchar(3);
    v_childvalue   numeric(16, 2);
    v_tempperc     numeric(16, 2);
    v_runningtotal numeric(16, 2) := 0.0;
BEGIN
    FOR v_currentchild IN
        SELECT mos
        FROM lookup.mos
        WHERE parent_mos = p_categorysubgroupcode
          AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ORDER BY mos
    LOOP
        SELECT CASE
                   WHEN p_whichone = 'TrainingMPA' THEN
                       SUM(mpa_mos / NULLIF(cgla_mos_inv, 0))
                           OVER (PARTITION BY payplan, categorysubgroupcode, coursetype
                                 ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC)
                   WHEN p_whichone = 'TrainingOMA' THEN
                       SUM(oma_mos / NULLIF(cgla_mos_inv, 0))
                           OVER (PARTITION BY payplan, categorysubgroupcode, coursetype
                                 ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC)
                   WHEN p_whichone = 'TrainingOther' THEN
                       SUM(other_mos / NULLIF(cgla_mos_inv, 0))
                           OVER (PARTITION BY payplan, categorysubgroupcode, coursetype
                                 ORDER BY payplan, categorysubgroupcode, coursetype, gradelevel ASC)
                   ELSE 0
               END
        INTO v_childvalue
        FROM crunch_temp.trainingcosts
        WHERE coursetype <> 'W'
          AND categorysubgroupcode = v_currentchild
          AND payplan = p_payplan
          AND coursetype = p_coursetype
        ORDER BY gradelevel DESC
        LIMIT 1;

        IF v_childvalue IS NULL THEN
            v_childvalue := 0;
        END IF;

        v_tempperc := crunch.getchildinventorypercentage(p_payplan, v_currentchild, p_amcosversionid);

        v_runningtotal := v_runningtotal
            + (v_tempperc
               * (v_childvalue
                  + crunch.getchildtrainingrecursive(
                        p_payplan,
                        v_currentchild,
                        p_gradetype,
                        p_coursetype,
                        p_gradelevel,
                        p_whichone,
                        p_amcosversionid)));
    END LOOP;

    RETURN v_runningtotal;
END;
$$;


------------------------------------------------------------------------------
-- Source: crunch/Functions/GetChildTrainingWeaponsRecursive.sql
-- As above but for weapon-system training: crunch_temp.trainingcosts filtered to
-- CourseType = 'W', partitioned additionally by WeaponSystemName.
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crunch.getchildtrainingweaponsrecursive(
    p_payplan varchar,
    p_categorysubgroupcode varchar,
    p_gradetype varchar,
    p_coursetype varchar,
    p_weaponsystemname varchar,
    p_gradelevel smallint,
    p_whichone varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS numeric(16, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_currentchild varchar(3);
    v_childvalue   numeric(16, 2);
    v_tempperc     numeric(16, 2);
    v_runningtotal numeric(16, 2) := 0.0;
BEGIN
    FOR v_currentchild IN
        SELECT mos
        FROM lookup.mos
        WHERE parent_mos = p_categorysubgroupcode
          AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ORDER BY mos
    LOOP
        SELECT CASE
                   WHEN p_whichone = 'TrainingMPA' THEN
                       SUM(mpa_mos / NULLIF(cgla_mos_inv, 0))
                           OVER (PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                                 ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC)
                   WHEN p_whichone = 'TrainingOMA' THEN
                       SUM(oma_mos / NULLIF(cgla_mos_inv, 0))
                           OVER (PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                                 ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC)
                   WHEN p_whichone = 'TrainingOther' THEN
                       SUM(other_mos / NULLIF(cgla_mos_inv, 0))
                           OVER (PARTITION BY payplan, categorysubgroupcode, coursetype, weaponsystemname
                                 ORDER BY payplan, categorysubgroupcode, coursetype, weaponsystemname, gradelevel ASC)
                   ELSE 0
               END
        INTO v_childvalue
        FROM crunch_temp.trainingcosts
        WHERE coursetype = 'W'
          AND categorysubgroupcode = v_currentchild
          AND payplan = p_payplan
          AND coursetype = p_coursetype
          AND weaponsystemname = p_weaponsystemname
        ORDER BY gradelevel DESC
        LIMIT 1;

        IF v_childvalue IS NULL THEN
            v_childvalue := 0;
        END IF;

        v_tempperc := crunch.getchildinventorypercentage(p_payplan, v_currentchild, p_amcosversionid);

        v_runningtotal := v_runningtotal
            + (v_tempperc
               * (v_childvalue
                  + crunch.getchildtrainingweaponsrecursive(
                        p_payplan,
                        v_currentchild,
                        p_gradetype,
                        p_coursetype,
                        p_weaponsystemname,
                        p_gradelevel,
                        p_whichone,
                        p_amcosversionid)));
    END LOOP;

    RETURN v_runningtotal;
END;
$$;


------------------------------------------------------------------------------
-- Source: crunch/Functions/Get1DayCosts.sql (Dan Hogan, 11/2/2019)
-- Table-valued. Returns the base 1-day reserve-component costs (Default
-- cost-summary elements only, 6-way UNION across crunch.costs_{ne,re,no,ro,nwo,rwo}),
-- adds ActiveDutyDays worth of crunch.costs_1activeday amounts, then caps the six
-- Social-Security-wage (SSW) elements at crunch.getsinglevalue('AA','Max_Wage_SSW').
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crunch.get1daycosts(
    p_amcosversionid integer DEFAULT -1,
    p_activedutydays integer DEFAULT -1)
RETURNS TABLE(
    payplan varchar(3),
    categorygroupcode char(2),
    categorysubgroupcode varchar(4),
    costelementid integer,
    gradetype varchar(3),
    gradelevel smallint,
    weaponsystemid integer,
    amount numeric(20, 2),
    crunchtime timestamp,
    amcosversionid integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_wage_ssw numeric(20, 2);
BEGIN
    DROP TABLE IF EXISTS tmp_reservecomponentcosts;
    CREATE TEMP TABLE tmp_reservecomponentcosts (
        payplan varchar(3) NOT NULL,
        categorygroupcode char(2) NOT NULL,
        categorysubgroupcode varchar(4) NOT NULL,
        costelementid integer NOT NULL,
        gradetype varchar(3) NOT NULL,
        gradelevel smallint NOT NULL,
        weaponsystemid integer NOT NULL,
        amount numeric(20, 2) NOT NULL,
        crunchtime timestamp NULL,
        amcosversionid integer NOT NULL
    );

    -- Base costs: 6-way UNION of the reserve-component output tables, restricted
    -- to the 'Default' cost-summary element set for each pay plan.
    INSERT INTO tmp_reservecomponentcosts
        (payplan, categorygroupcode, categorysubgroupcode, costelementid,
         gradetype, gradelevel, weaponsystemid, amount, crunchtime, amcosversionid)
    SELECT payplan, cmf, mos, costelementid, gradetype, gradelevel,
           weaponsystemid, amount, crunchtime, amcosversionid
    FROM crunch.costs_ne
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (
          SELECT a.costelementid
          FROM lookup.costsummaryelement AS a
              INNER JOIN lookup.costsummary AS b
                  ON a.summaryid = b.summaryid
                     AND b.name = 'Default'
                     AND b.payplan IN ('NE')
                     AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
                     AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
    UNION
    SELECT payplan, cmf, mos, costelementid, gradetype, gradelevel,
           weaponsystemid, amount, crunchtime, amcosversionid
    FROM crunch.costs_re
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (
          SELECT a.costelementid
          FROM lookup.costsummaryelement AS a
              INNER JOIN lookup.costsummary AS b
                  ON a.summaryid = b.summaryid
                     AND b.name = 'Default'
                     AND b.payplan IN ('RE')
                     AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
                     AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
    UNION
    SELECT payplan, cmf, aoc, costelementid, gradetype, gradelevel,
           weaponsystemid, amount, crunchtime, amcosversionid
    FROM crunch.costs_no
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (
          SELECT a.costelementid
          FROM lookup.costsummaryelement AS a
              INNER JOIN lookup.costsummary AS b
                  ON a.summaryid = b.summaryid
                     AND b.name = 'Default'
                     AND b.payplan IN ('NO')
                     AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
                     AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
    UNION
    SELECT payplan, cmf, aoc, costelementid, gradetype, gradelevel,
           weaponsystemid, amount, crunchtime, amcosversionid
    FROM crunch.costs_ro
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (
          SELECT a.costelementid
          FROM lookup.costsummaryelement AS a
              INNER JOIN lookup.costsummary AS b
                  ON a.summaryid = b.summaryid
                     AND b.name = 'Default'
                     AND b.payplan IN ('RO')
                     AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
                     AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
    UNION
    SELECT payplan, branch, womos, costelementid, gradetype, gradelevel,
           weaponsystemid, amount, crunchtime, amcosversionid
    FROM crunch.costs_nwo
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (
          SELECT a.costelementid
          FROM lookup.costsummaryelement AS a
              INNER JOIN lookup.costsummary AS b
                  ON a.summaryid = b.summaryid
                     AND b.name = 'Default'
                     AND b.payplan IN ('NWO')
                     AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
                     AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend)
    UNION
    SELECT payplan, branch, womos, costelementid, gradetype, gradelevel,
           weaponsystemid, amount, crunchtime, amcosversionid
    FROM crunch.costs_rwo
    WHERE amcosversionid = p_amcosversionid
      AND costelementid IN (
          SELECT a.costelementid
          FROM lookup.costsummaryelement AS a
              INNER JOIN lookup.costsummary AS b
                  ON a.summaryid = b.summaryid
                     AND b.name = 'Default'
                     AND b.payplan IN ('RWO')
                     AND p_amcosversionid BETWEEN a.amcosversionidstart AND a.amcosversionidend
                     AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend);

    -- Add the requested number of active-duty days of per-day cost.
    -- Source T-SQL re-aliases the UPDATE target in FROM (UPDATE @rcc SET.. FROM @rcc a
    -- INNER JOIN costs_1activeday b); PG forbids that, so the target is referenced
    -- directly and only costs_1activeday appears in FROM. Join carries categorygroupcode,
    -- which crunch.costs_1activeday now has.
    UPDATE tmp_reservecomponentcosts AS t
    SET amount = t.amount + b.amount * p_activedutydays
    FROM crunch.costs_1activeday AS b
    WHERE t.costelementid = b.costelementid
      AND t.amcosversionid = b.amcosversionid
      AND t.payplan = b.payplan
      AND t.categorygroupcode = b.categorygroupcode
      AND t.categorysubgroupcode = b.categorysubgroupcode
      AND t.gradelevel = b.gradelevel
      AND t.weaponsystemid = b.weaponsystemid;

    -- Temper the Social-Security-wage elements by the max allowed.
    v_max_wage_ssw := crunch.getsinglevalue('AA', 'Max_Wage_SSW', p_amcosversionid);

    UPDATE tmp_reservecomponentcosts AS t
    SET amount = CASE
                     WHEN t.amount > v_max_wage_ssw THEN v_max_wage_ssw
                     ELSE t.amount
                 END
    WHERE t.costelementid IN (290, 360, 414, 454, 524, 578);

    RETURN QUERY
    SELECT t.payplan, t.categorygroupcode, t.categorysubgroupcode, t.costelementid,
           t.gradetype, t.gradelevel, t.weaponsystemid, t.amount, t.crunchtime, t.amcosversionid
    FROM tmp_reservecomponentcosts AS t;

    DROP TABLE IF EXISTS tmp_reservecomponentcosts;
END;
$$;
