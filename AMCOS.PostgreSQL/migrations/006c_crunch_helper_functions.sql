-- Cost-crunch HELPER functions (crunch.*).
--
-- Phase 0 of porting the legacy SQL Server cost-crunch engine to PostgreSQL.
-- These are the scalar helper UDFs the crunch procedures call. Source:
-- AMCOS.AMCOS2020_MAR/crunch/Functions/. crunch.getsinglevalue is already
-- ported in 006b; this file adds the remaining 10 scalar helpers.
--
-- All are LANGUAGE plpgsql so name resolution is DEFERRED — several read tables
-- (payschedule.opmexraw, lookup.mos, data.inventory) that are populated by the
-- Python ETL or by later crunch phases and may be empty/absent at create time.
--
-- DEFERRED to later phases (documented in CRUNCH_PORT_PLAN.md):
--   * crunch.get1daycosts  — table-valued; its UPDATE joins crunch.costs_1activeday
--     on categorygroupcode, a column 005b's costs_1activeday does not yet carry
--     (schema reconciliation needed first). Not called by any ported web function.
--   * crunch.getchildbonusrecursive / getchildtrainingrecursive /
--     getchildtrainingweaponsrecursive — read the Tier-3 crunch_temp.* staging
--     schema (CostOfRecruiting / TrainingCosts / ...) that is created with the
--     training & bonus cost procs. Port them alongside those procs.
--
-- T-SQL -> PG: BIT->boolean, ISNULL->COALESCE, TOP(1)->LIMIT 1,
-- NVARCHAR->varchar, TINYINT->smallint, FLOAT->double precision.

------------------------------------------------------------------------------
-- Version guards
------------------------------------------------------------------------------

-- Source: crunch/Functions/ValidateAmcosVersion.sql
CREATE OR REPLACE FUNCTION crunch.validateamcosversion(p_amcosversionid integer)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_amcosversionid IS NULL THEN
        RETURN false;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM lookup.amcosversion WHERE amcosversionid = p_amcosversionid
    );
END;
$$;

-- Source: crunch/Functions/GetLatestAmcosVersionId.sql
CREATE OR REPLACE FUNCTION crunch.getlatestamcosversionid()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_result integer;
BEGIN
    SELECT MAX(amcosversionid) INTO v_result FROM lookup.amcosversion;
    RETURN v_result;
END;
$$;

------------------------------------------------------------------------------
-- Single-value lookups
------------------------------------------------------------------------------

-- Source: crunch/Functions/GetArmyBudgetSingleValue.sql
CREATE OR REPLACE FUNCTION crunch.getarmybudgetsinglevalue(
    p_parametername varchar,
    p_appropriation varchar,
    p_fy            varchar,
    p_amcosversionid integer)
RETURNS double precision
LANGUAGE plpgsql
AS $$
DECLARE
    v_result double precision;
BEGIN
    SELECT amount INTO v_result
    FROM crunch.armybudgetsinglevalues
    WHERE parametername = p_parametername
      AND appropriation = p_appropriation
      AND fy = p_fy
      AND amcosversionid = p_amcosversionid;

    RETURN v_result;
END;
$$;

-- Source: crunch/Functions/GetMaximumGSPayLimit.sql
-- Max G-series pay = EX Level IV annual rate (5 USC 5304 (g)(1)).
CREATE OR REPLACE FUNCTION crunch.getmaximumgspaylimit(p_amcosversionid integer)
RETURNS numeric(15, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_result numeric(15, 2);
BEGIN
    SELECT rate INTO v_result
    FROM "PaySchedule".opmexraw
    WHERE amcosversionid = p_amcosversionid
      AND ratetype = 'Annual'
      AND level = 'Level IV';

    -- Before 1994 there was no executive schedule; set an effectively infinite cap.
    IF v_result IS NULL AND p_amcosversionid < 199401 THEN
        v_result := 999999;
    END IF;

    RETURN v_result;
END;
$$;

-- Source: crunch/Functions/GetReserveComponentBAH.sql
-- Weighted-average BAH across members with / without dependents.
CREATE OR REPLACE FUNCTION crunch.getreservecomponentbah(
    p_ratewithdependents      numeric,
    p_ratewithoutdependents   numeric,
    p_totalmembers            numeric,
    p_memberswithdependents   numeric,
    p_memberswithoutdependents numeric)
RETURNS numeric(16, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_result numeric(16, 2);
BEGIN
    IF p_totalmembers = 0 OR p_totalmembers IS NULL THEN
        v_result := p_ratewithdependents;
    ELSE
        v_result := (p_ratewithdependents    * (p_memberswithdependents    / p_totalmembers))
                  + (p_ratewithoutdependents * (p_memberswithoutdependents / p_totalmembers));
    END IF;

    RETURN v_result;
END;
$$;

------------------------------------------------------------------------------
-- MOS-tree inventory helpers (feed the recursive Tier-3 functions)
------------------------------------------------------------------------------

-- Source: crunch/Functions/GetParentMOS.sql
CREATE OR REPLACE FUNCTION crunch.getparentmos(
    p_categorysubgroupcode varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS varchar
LANGUAGE plpgsql
AS $$
DECLARE
    v_result varchar(3);
BEGIN
    SELECT parent_mos INTO v_result
    FROM lookup.mos
    WHERE mos = p_categorysubgroupcode
      AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
    ORDER BY mos
    LIMIT 1;

    RETURN v_result;
END;
$$;

-- Source: crunch/Functions/GetInventoryByCategorySubgroup.sql
CREATE OR REPLACE FUNCTION crunch.getinventorybycategorysubgroup(
    p_payplan varchar,
    p_categorysubgroupcode varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_result integer;
BEGIN
    SELECT SUM(inventory) INTO v_result
    FROM data.inventory
    WHERE payplan = p_payplan
      AND categorysubgroupcode = p_categorysubgroupcode
      AND amcosversionid = p_amcosversionid;

    RETURN v_result;
END;
$$;

-- Source: crunch/Functions/GetTotalSiblingInventory.sql
CREATE OR REPLACE FUNCTION crunch.gettotalsiblinginventory(
    p_payplan varchar,
    p_parentmos varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_result integer;
BEGIN
    SELECT SUM(inv.inventory) INTO v_result
    FROM data.inventory inv
        LEFT OUTER JOIN lookup.mos m ON inv.categorysubgroupcode = m.mos
    WHERE inv.payplan = p_payplan
      AND m.parent_mos = p_parentmos
      AND p_amcosversionid BETWEEN m.amcosversionidstart AND m.amcosversionidend
      AND inv.amcosversionid = p_amcosversionid;

    RETURN v_result;
END;
$$;

-- Source: crunch/Functions/GetChildInventoryPercentage.sql
-- Child node's share of its parent's sibling-group inventory.
CREATE OR REPLACE FUNCTION crunch.getchildinventorypercentage(
    p_payplan varchar,
    p_categorysubgroupcode varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS numeric(3, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_parentmos varchar(3);
    v_childinventory integer;
    v_totalsiblinginventory integer;
BEGIN
    v_parentmos := crunch.getparentmos(p_categorysubgroupcode, p_amcosversionid);
    IF v_parentmos IS NULL THEN
        RETURN 0.0;
    END IF;

    v_childinventory := crunch.getinventorybycategorysubgroup(p_payplan, p_categorysubgroupcode, p_amcosversionid);
    IF v_childinventory IS NULL THEN
        RETURN 0.0;
    END IF;

    v_totalsiblinginventory := crunch.gettotalsiblinginventory(p_payplan, v_parentmos, p_amcosversionid);
    IF v_totalsiblinginventory IS NULL OR v_totalsiblinginventory = 0 THEN
        RETURN 0.0;
    END IF;

    RETURN CAST(v_childinventory AS numeric) / CAST(v_totalsiblinginventory AS numeric);
END;
$$;

-- Source: crunch/Functions/GetParentInventory.sql
-- Recursive: rolls parent inventory up the MOS tree (self-calls).
CREATE OR REPLACE FUNCTION crunch.getparentinventory(
    p_payplan varchar,
    p_categorysubgroupcode varchar,
    p_amcosversionid integer DEFAULT -1)
RETURNS numeric(16, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_parentmos varchar(3);
    v_parentinventory integer;
BEGIN
    SELECT parent_mos INTO v_parentmos
    FROM lookup.mos
    WHERE mos = p_categorysubgroupcode
      AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend;

    IF v_parentmos IS NULL THEN
        RETURN 0.0;
    END IF;

    SELECT COALESCE(SUM(inventory), 0) INTO v_parentinventory
    FROM data.inventory
    WHERE payplan = p_payplan
      AND categorysubgroupcode = v_parentmos
      AND amcosversionid = p_amcosversionid;

    RETURN crunch.getchildinventorypercentage(p_payplan, p_categorysubgroupcode, p_amcosversionid)
           * (v_parentinventory + crunch.getparentinventory(p_payplan, v_parentmos, p_amcosversionid));
END;
$$;
