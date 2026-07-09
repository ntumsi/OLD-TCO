-- Cost-crunch PHASE 4 — the CrunchAll orchestrator (crunch.*).
-- Sequences every crunch/warehouse procedure in dependency order with per-object
-- timing into analysis.crunchtime (005f). CALL-invoked; p_whichtorun selects the
-- pay-plan-family subset ('All','OPM_G','SES','Wage','GFEBS','Mil','No Mil',...).
-- Runs LAST (after 006j). Source: crunch/Stored Procedures/CrunchAll.sql.

-- =============================================================================
-- crunch.crunchall  — crunch/warehouse orchestrator (PHASE 4).
--
-- Faithful PostgreSQL port of [crunch].[CrunchAll]
-- (AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchAll.sql).
--
-- Sequences every crunch/warehouse procedure in dependency order, timing each
-- with a clock_timestamp() pair and logging (objectname, amcosversionid,
-- starttime, endtime, debug) into analysis.crunchtime.
--
-- Port conventions:
--   * @AmcosVersionId -> p_amcosversionid; @Debug_mode -> p_debug_mode;
--     @WhichtoRun -> p_whichtorun. @CrunchAllStart (GETDATE captured once) ->
--     v_crunchallstart, passed as the @CrunchTime arg wherever a proc takes one.
--   * EXEC crunch.X @a=..,@b=.. -> CALL crunch.x(<ported params in named form>).
--     Each source @param is matched to the ported p_param by meaning.
--   * RAISERROR('msg',0,1) WITH NOWAIT -> RAISE NOTICE 'msg'.
--   * ValidateAmcosVersion(..) = 0 RETURN -> IF NOT crunch.validateamcosversion() THEN RETURN.
--   * NAME REMAPS: crunch.CrunchWASSInventory -> crunch.crunchinventorywass;
--     crunch.CrunchDMDCInventory -> crunch.crunchinventorydmdc. All other names
--     map by lowercasing. (objectname strings in the log keep the source spelling.)
--   * The trailing SELECT that displayed the CrunchTime result set is dropped
--     (a PROCEDURE cannot return a result set; no runtime effect).
--   * warehouse.* procs are the Phase-4j targets (not yet created); called with
--     the agreed signatures: updatelocationid(p_amcosversionid, p_debug),
--     populatecategory(p_amcosversionid), populatelocationbycategory(p_amcosversionid),
--     populateunitpersonnel(p_crunchtime), populateppxwalk(p_categorysubgroupcode,
--     p_crunchtime, p_debug).
-- =============================================================================
CREATE OR REPLACE PROCEDURE crunch.crunchall(
    p_amcosversionid integer DEFAULT -1,
    p_debug_mode boolean DEFAULT false,
    p_whichtorun varchar DEFAULT '-1')  -- 'All','All_no_mil_training','GFEBS','Mil','Mil_no_training','No Mil','OPM_G','SES','Wage'
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchallstart timestamp := now()::timestamp;  -- captured once; used as @CrunchTime
    v_ts_start       timestamp;
    v_ts_end         timestamp;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- Populate JIC
    RAISE NOTICE 'Populate JIC';
    v_ts_start := clock_timestamp();
    CALL crunch.jointinflationcalculator();
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.JointInflationCalculator', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    -- insert/update the warehouse table
    RAISE NOTICE 'UpdateLocationId';
    v_ts_start := clock_timestamp();
    CALL warehouse.updatelocationid(p_amcosversionid => p_amcosversionid, p_debug => false);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('warehouse.UpdateLocationId', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    RAISE NOTICE 'LoadGSAPerDiem';
    v_ts_start := clock_timestamp();
    CALL crunch.loadgsaperdiem(p_amcosversionid => p_amcosversionid);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.LoadGSAPerDiem', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    -- because many pay plans use the army budget data this must be run every time
    RAISE NOTICE 'ArmyBudget';
    v_ts_start := clock_timestamp();
    CALL crunch.armybudget(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.ArmyBudget', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    /* Anytime we crunch the costs we need to regenerate inventory in case anything changes */
    RAISE NOTICE 'CrunchWASSInventory';
    v_ts_start := clock_timestamp();
    CALL crunch.crunchinventorywass(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.CrunchWASSInventory', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    RAISE NOTICE 'CrunchDMDCInventory';
    v_ts_start := clock_timestamp();
    CALL crunch.crunchinventorydmdc(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.CrunchDMDCInventory', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    -- ===================== OPM G-series section =====================
    IF p_whichtorun IN ('OPM_G', 'All', 'No Mil')
       OR left(p_whichtorun, 3) = 'All'
    THEN
        RAISE NOTICE 'CrunchPayScheduleGSeries';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayschedulegseries(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleGSeries', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchGSeries';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchgseries(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchGSeries', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchPayScheduleCY';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayschedulecy(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleCY', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchCY';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchcy(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchCY', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchPayScheduleNF';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayschedulenf(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleNF', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchNF';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchnf(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchNF', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
    END IF; -- end OPM G series section

    -- ===================== SES section =====================
    IF p_whichtorun IN ('SES', 'All')
       OR left(p_whichtorun, 3) = 'All'
    THEN
        RAISE NOTICE 'CrunchSES';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchses(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchSES', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchPayScheduleCA';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayscheduleca(p_amcosversionid => p_amcosversionid);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleCA', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchPayScheduleEX';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayscheduleex(p_amcosversionid => p_amcosversionid);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleEX', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchPayScheduleIG';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayscheduleig(p_amcosversionid => p_amcosversionid);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleIG', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
    END IF;

    -- ===================== Wage section =====================
    IF p_whichtorun IN ('Wage', 'All', 'No Mil')
       OR left(p_whichtorun, 3) = 'All'
    THEN
        RAISE NOTICE 'CrunchPayScheduleWage';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayschedulewage(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleWage', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchWage';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchwage(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchWage', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
    END IF;

    -- ===================== GFEBS section =====================
    IF p_whichtorun IN ('All', 'GFEBS', 'No Mil')
       OR left(p_whichtorun, 3) = 'All'
    THEN
        -- NOTE: GFEBS inventory is populated inside the crunch.GFEBS object
        RAISE NOTICE 'GFEBS Crunch';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchgfebs(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchGFEBS', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CrunchPayScheduleGP';
        v_ts_start := clock_timestamp();
        CALL crunch.crunchpayschedulegp(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CrunchPayScheduleGP', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
    END IF;

    -- ===================== Military section =====================
    IF (
           p_whichtorun IN ('All', 'Mil', 'Mil_no_training')
           OR left(p_whichtorun, 3) = 'All'
       )
       AND p_whichtorun <> 'No Mil'
    THEN
        -- all military pay plans use the DMDC crunch so that must be run
        RAISE NOTICE 'DMDC Pay Crunch';
        v_ts_start := clock_timestamp();
        CALL crunch.dmdcpay(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.DMDCPay', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'Military Crunches';
        RAISE NOTICE 'CostOfBasePay';
        v_ts_start := clock_timestamp();
        CALL crunch.costofbasepay(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfBasePay', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfSimpleCEs';
        v_ts_start := clock_timestamp();
        CALL crunch.costofsimpleces(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfSimpleCEs', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        -- !! Other benefit/Misc crunches
        RAISE NOTICE 'CostOfFICAandRetiredPay';
        v_ts_start := clock_timestamp();
        CALL crunch.costofficaandretiredpay(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfFICAandRetiredPay', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfClothing';
        v_ts_start := clock_timestamp();
        CALL crunch.costofclothing(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfClothing', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        -- this must be run after all other benefit/misc crunches
        RAISE NOTICE 'CostOfMisc';
        v_ts_start := clock_timestamp();
        CALL crunch.costofmisc(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfMisc', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfPCS';
        v_ts_start := clock_timestamp();
        CALL crunch.costofpcs(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfPCS', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
        -- !! end other benefit/misc crunches

        RAISE NOTICE 'CostOfFamilySeparation';
        v_ts_start := clock_timestamp();
        CALL crunch.costoffamilyseparation(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfFamilySeparation', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfSeparationPay';
        v_ts_start := clock_timestamp();
        CALL crunch.costofseparationpay(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfSeparationPay', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfSpecialPays';
        v_ts_start := clock_timestamp();
        CALL crunch.costofspecialpays(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfSpecialPays', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfSelectiveRetentionBonus';
        v_ts_start := clock_timestamp();
        CALL crunch.costofselectiveretentionbonus(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfSelectiveRetentionBonus', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfRecruiting';
        v_ts_start := clock_timestamp();
        CALL crunch.costofrecruiting(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfRecruiting', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfOfficerAcquisition';
        v_ts_start := clock_timestamp();
        CALL crunch.costofofficeracquisition(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfOfficerAcquisition', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfBasicAllowanceforSubsistence';
        v_ts_start := clock_timestamp();
        CALL crunch.costofbasicallowanceforsubsistence(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfBasicAllowanceforSubsistence', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfBasicAllowanceforHousingandCOLA';
        v_ts_start := clock_timestamp();
        CALL crunch.costofbasicallowanceforhousingandcola(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfBasicAllowanceforHousingandCOLA', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        RAISE NOTICE 'CostOfOverseas';
        v_ts_start := clock_timestamp();
        CALL crunch.costofoverseas(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfOverseas', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        -- because the training crunch takes a really long time to run we may sometimes not want to run it with the other military crunches
        IF p_whichtorun NOT IN ('Mil_no_training', 'All_no_mil_training')
        THEN
            RAISE NOTICE 'CostOfTraining';
            v_ts_start := clock_timestamp();
            CALL crunch.costoftraining(p_amcosversionid => p_amcosversionid, p_crunchtime => v_crunchallstart, p_debug => p_debug_mode);
            v_ts_end := clock_timestamp();
            INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
            VALUES ('crunch.CostOfTraining', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
        END IF;

        -- compute all the military average costs
        RAISE NOTICE 'CostOfMilAverages';
        v_ts_start := clock_timestamp();
        CALL crunch.costofmilaverages(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.CostOfMilAverages', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

        -- once all the military crunches are run we run the 1 active day crunch for Project Manager NG/R
        RAISE NOTICE '1 active day crunch';
        v_ts_start := clock_timestamp();
        CALL crunch.crunch1activeday(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
        v_ts_end := clock_timestamp();
        INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
        VALUES ('crunch.Crunch1ActiveDay', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);
    END IF;

    /* Compute D and N series payschedules which rely on SES and GS payschedule data */
    RAISE NOTICE 'CrunchPayScheduleDSeriesNSeries';
    v_ts_start := clock_timestamp();
    CALL crunch.crunchpayscheduledseriesnseries(p_amcosversionid => p_amcosversionid, p_debug => p_debug_mode);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.CrunchPayScheduleDSeriesNSeries', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    -- Whenever the crunches are run we need to re-populate the tables that run the drop downs
    RAISE NOTICE 'Populate Categories';
    v_ts_start := clock_timestamp();
    CALL warehouse.populatecategory(p_amcosversionid => p_amcosversionid);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('warehouse.PopulateCategory', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    RAISE NOTICE 'Populate Category Locations';
    v_ts_start := clock_timestamp();
    CALL warehouse.populatelocationbycategory(p_amcosversionid => p_amcosversionid);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('warehouse.PopulateLocationByCategory', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    RAISE NOTICE 'CalculatePayPlanMinMax';
    v_ts_start := clock_timestamp();
    CALL crunch.calculatepayplanminmax(p_amcosversionid => p_amcosversionid);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('crunch.CalculatePayPlanMinMax', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    RAISE NOTICE 'PopulateUnitPersonnel';
    v_ts_start := clock_timestamp();
    CALL warehouse.populateunitpersonnel(p_crunchtime => v_crunchallstart);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('warehouse.PopulateUnitPersonnel', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    RAISE NOTICE 'PopulatePPXwalk';
    v_ts_start := clock_timestamp();
    CALL warehouse.populateppxwalk(p_categorysubgroupcode => '', p_crunchtime => v_crunchallstart, p_debug => NULL);
    v_ts_end := clock_timestamp();
    INSERT INTO analysis.crunchtime (objectname, amcosversionid, starttime, endtime, debug)
    VALUES ('warehouse.PopulatePPXwalk', p_amcosversionid, v_ts_start, v_ts_end, p_debug_mode);

    -- Source ended with a SELECT that displayed the CrunchTime result set; a
    -- PROCEDURE cannot return a result set, so it is intentionally dropped.
END;
$$;
