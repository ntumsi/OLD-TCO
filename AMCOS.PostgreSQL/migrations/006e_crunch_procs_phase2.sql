-- Cost-crunch PHASE 2 procedures — pay-schedule / inventory / support (crunch.*).
--
-- Ports the ~25 pay-schedule-processing, inventory, civilian-cost, and support
-- procedures from AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/ to PostgreSQL.
-- Unlike Phase 1 (which emits the final crunch.Costs_* military tables), most of
-- these produce the PROCESSED/INTERMEDIATE tables the rest of the engine reads:
-- crunch.PayProcessed, ArmyBudgetSingleValues, GSAPerDiem, TimeInGrade,
-- PayScheduleMinMax, Inventory{DMDC,WASS,Processed}, Opm{Ca,Ex,Ig}Processed,
-- NfPayProcessed, and the civilian crunch.Costs_{G,CY,NF,SES,Wage,GFEBS} tables.
--
-- CREATE PROCEDURE, LANGUAGE plpgsql (invoked via CALL by CrunchAll in Phase 4;
-- p_debug = true is a dry run). Runs after 006d. Conventions and the T-SQL->PG
-- translation rules are documented in the Phase-1 file (006d) header.
--
-- INVENTORY NAMING (resolved 2026-07-09): CrunchAll EXECs crunch.CrunchWASSInventory
-- and crunch.CrunchDMDCInventory, but the source files define CrunchInventoryWASS
-- (writes crunch.InventoryWASS) and CrunchInventoryDMDC (writes crunch.InventoryDMDC);
-- CrunchDMDCVantageInventory (writes crunch.InventoryProcessed, the table data.Inventory
-- reads) is the newer Vantage variant NOT wired into the legacy CrunchAll. All three
-- are ported here under their real (file) names; the Phase-4 orchestrator decides
-- which to call (recommend CrunchDMDCVantageInventory as the authoritative one).
--
-- Wave 1 (foundational; feed Phase 1 + the web): armybudget, dmdcpay,
-- jointinflationcalculator, loadgsaperdiem, calculatepayplanminmax, createtimeingradetable.


------------------------------------------------------------------------------
-- crunch.armybudget  — port of [crunch].[ArmyBudget] (POM lock-file → single values)
--
-- Faithful structural port of the T-SQL proc. Reads the ETL budget input
-- dataload.armybudget, buckets Army TOA dollars (BO='1') and manpower counts
-- (BO='4') into named POM parameters, computes a per-parameter average across
-- fiscal years (FY='Avg'), and (when not a dry run) replaces the version's rows
-- in crunch.armybudgetsinglevalues.
--
-- Conventions (per PORT_CONVENTIONS.md / Phase-1 template):
--   * p_debug = true is a DRY RUN. The source's write block runs only under
--     "IF @Debug = 0"; guarded here with "IF NOT p_debug". The "IF @Debug = 1"
--     result-set dump has no runtime effect and is dropped. NOTE: the source
--     declares @Debug BIT = 1, so the DEFAULT is preserved as true (dry run).
--   * #temp -> CREATE TEMP TABLE; DROP TABLE IF EXISTS before create and at end.
--   * NVARCHAR->varchar, SMALLINT->smallint, FLOAT->double precision, BIT->boolean.
--   * SQL Server's default case-insensitive collation makes every LIKE (and the
--     equality/IN filters) case-insensitive. The mixed-case content patterns
--     ('%clothing%', '%Enlisted%', '%Officer%', '%enl%', '%off%', '%agr%') depend
--     on this, so every LIKE is ported as ILIKE to preserve matching behavior.
--   * The temp #ArmyBudget.fy is smallint (as declared in the source); it is cast
--     to varchar on the way into #pomdata (whose fy also holds the literal 'Avg').
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.armybudget(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS pomdata;
    CREATE TEMP TABLE pomdata (
        parametername  varchar(50) NOT NULL,
        appropriation  varchar(10) NOT NULL,
        fy             varchar(4)  NOT NULL,
        amcosversionid integer     NOT NULL,
        amount         double precision NULL
    );

    DROP TABLE IF EXISTS armybudget;
    CREATE TEMP TABLE armybudget (
        fy               smallint       NULL,
        amount           numeric(18, 0) NULL,
        bo               varchar(1)     NULL,
        appn             varchar(5)     NULL,
        tc               varchar(50)    NULL,
        rc               varchar(5)     NULL,
        ape              varchar(10)    NULL,
        ape_pt_desc      varchar(255)   NULL,
        amsco            varchar(255)   NULL,
        sag              varchar(255)   NULL,
        ba               varchar(50)    NULL,
        mdep             varchar(255)   NULL,
        roc              varchar(4)     NULL,
        cmd              varchar(2)     NULL,
        fsc              varchar(255)   NULL,
        osdpe            varchar(255)   NULL,
        ric              varchar(5)     NULL,
        mhc              varchar(50)    NULL,
        dollar_type      varchar(255)   NULL,
        dollar_type_desc varchar(255)   NULL,
        amcosversionid   integer        NULL
    );

    -- for dollars we only want Army TOA (BO=1) and base budget money; for BO=4 (people counts) the base budget criteria doesn't matter
    INSERT INTO armybudget
        (fy, amount, bo, appn, tc, rc, ape, ape_pt_desc, amsco, sag, ba, mdep, roc,
         cmd, fsc, osdpe, ric, mhc, dollar_type, dollar_type_desc, amcosversionid)
    SELECT fy, amount, bo, appn, tc, rc, ape, ape_pt_desc, amsco, sag, ba, mdep, roc,
           cmd, fsc, osdpe, ric, mhc, dollar_type, dollar_type_desc, amcosversionid
    FROM dataload.armybudget
    WHERE amcosversionid = p_amcosversionid
      AND (bo = '1' OR bo = '4');

    /* Advertising budget */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Advertising', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'OMA' AND ape = '331712000'
      AND bo = '1' AND mdep = 'VAMP'
    GROUP BY appn, fy;

    /* Active Recruiting OMA budget */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Recruiting', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '331' AND bo = '1'
      AND mdep <> 'VAMP' AND appn = 'OMA'
    GROUP BY appn, fy;

    /* Active Accession Travel Budget */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Accession_Travel_Enlisted', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape_pt_desc ILIKE '%Accession Tvl, Enlisted%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY appn, fy;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Accession_Travel_Officer', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape_pt_desc ILIKE '%Accession Tvl, Officer%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY appn, fy;

    /* Active recruiting MPA budget -- calculated from manpower (no POM entry) */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_Recruiters', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE rc IN ('AAEN') AND mdep IN ('FAAC', 'FARC', 'MS5Z') AND bo = '4'
      AND osdpe NOT IN ('0902498A', '0808610A')
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Recruiters', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE rc IN ('AAOF') AND mdep IN ('FAAC', 'FARC', 'MS5Z') AND bo = '4'
      AND osdpe NOT IN ('0902498A', '0808610A')
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Warrant_Recruiters', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE rc IN ('AAWO') AND mdep IN ('FAAC', 'FARC', 'MS5Z') AND bo = '4'
      AND osdpe NOT IN ('0902498A', '0808610A')
    GROUP BY fy, appn;

    -- NG recruiting NGPA budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Recruiting', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1GN' AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Retention', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1GP' AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    -- NGPA doesn't split out into retention and recruiting, they are one in the same
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Recruiting_Retention', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1J0' AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    -- Reserve Recruiting OMAR/OMNG budget
    -- (source compared CAST(SAG AS NVARCHAR(MAX)) = 434, i.e. numeric equality via
    --  T-SQL type precedence -> ported as sag = '434')
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Recruiting', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '434'
      AND osdpe IN ('0508891A', '0508991A') AND bo = '1'
      AND mdep IN ('FARC', 'FAAC', 'VAMP') AND appn IN ('OMAR', 'OMNG')
    GROUP BY fy, appn;

    -- USMA Military Staff (calculated from manpower)
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_USMA', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE roc = '171' AND mdep NOT IN ('VPUB', 'QSEC') AND rc = 'AAEN' AND bo = '4'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_USMA', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE roc = '171' AND mdep NOT IN ('VPUB', 'QSEC') AND rc = 'AAOF' AND bo = '4'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Warrant_USMA', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE roc = '171' AND mdep NOT IN ('VPUB', 'QSEC') AND rc = 'AAWO' AND bo = '4'
    GROUP BY fy, appn;

    -- USMA OMA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'USMA', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('USMA') AND bo = '1' AND appn = 'OMA'
    GROUP BY fy, appn;

    -- USMA MPA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'USMA', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ba = '03' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- NGOCS NGPA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NGOCS', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1F5' AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    -- NGOCS OMNG
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NGOCS', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TAOC', 'TROC') AND bo = '1' AND appn = 'OMNG'
    GROUP BY fy, appn;

    -- ROTC Scholarship MPA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'ROTC_Scholarship', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '6PB' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- ROTC NonScholarship MPA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'ROTC_NonScholarship', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '6PA' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- ROTC OMA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'ROTC', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep = 'TROT' AND bo = '1' AND appn = 'OMA'
    GROUP BY fy, appn;

    -- ROTC Scholarship OMA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'ROTC_Scholarship', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep = 'TRRS' AND bo = '1' AND appn = 'OMA'
    GROUP BY fy, appn;

    -- ROTC Military Staff (calculated from manpower)
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_ROTC', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE mdep IN ('TROT') AND rc = 'AAEN' AND bo = '4'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_ROTC', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE mdep IN ('TROT') AND rc = 'AAOF' AND bo = '4'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Warrant_ROTC', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE mdep IN ('TROT') AND rc = 'AAWO' AND bo = '4'
    GROUP BY fy, appn;

    -- Active Training Costs
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-OSUT', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('313') AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Recruit', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('312') AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Specialized Skill', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('321') AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Professional Development Education', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('323') AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Flight', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('322') AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Support', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('324') AND bo = '1'
    GROUP BY fy, appn;

    -- Reserve & NG OM & PA Training Costs (pre-2023 training-specific mdeps)
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-IET', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('PRTF')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid < 202301
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Professional', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TRNC', 'TRPD')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid < 202301
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Special Skills Training', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TFNC')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid < 202301
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Support', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TAVI', 'TSPU', 'TRCS')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid < 202301
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-Initial SKills', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TRIT')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid < 202301
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Training-MOS Qualification', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TRNM')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid < 202301
    GROUP BY fy, appn;

    -- TRNM mdep collapsed into TROC in 2023 -> generalized SV for >= 202301
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'General Training', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND mdep IN ('TROC', 'TRIT', 'PRTF', 'PRSA')
      AND appn IN ('OMAR', 'OMNG', 'NGPA', 'RPA') AND bo = '1'
      AND p_amcosversionid >= 202301
    GROUP BY fy, appn;

    -- Avg O & E end strength
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Avg_OE_End_Strength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Avg AO end strength
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Avg_AO_End_Strength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'MPA' AND rc = 'AAOF'
    GROUP BY fy, appn;

    -- Avg AE end strength
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Avg_AE_End_Strength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'MPA' AND rc = 'AAEN'
    GROUP BY fy, appn;

    -- Avg AWO end strength
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Avg_AWO_End_Strength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'MPA' AND rc = 'AAWO'
    GROUP BY fy, appn;

    -- Tot_MWR_Cost
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'MoraleWelfareRecreation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '131' AND bo = '1'
      AND appn = 'OMA' AND osdpe = '0208530A'
    GROUP BY fy, appn;

    -- PCS_ConusOverseas_30_Dep_Not_Auth
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'PCS_ConusOverseas_30_Dep_Not_Auth', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('2RB', '1RB') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- PCS_Operational_Move_Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_PCS_Operational_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5C%' AND ape_pt_desc ILIKE '%Enlisted%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_PCS_Operational_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5C%' AND ape_pt_desc ILIKE '%Officer%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- PCS_Rotational_Move_Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_PCS_Rotational_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape_pt_desc ILIKE '%Enlisted%' AND sag ILIKE '5D%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_PCS_Rotational_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5D%' AND ape_pt_desc ILIKE '%Officer%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- PCS_Separation_Move_Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_PCS_Separation_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5E%' AND ape_pt_desc ILIKE '%Enlisted%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_PCS_Separation_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5E%' AND ape_pt_desc ILIKE '%Officer%'
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Family Separation Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_Family_Separation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('2RD', '2RB') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Warrant_Family_Separation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('1RB', '1RD') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Terminal Leave Pay Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Warrant_Leave_pay', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('1SA') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_Leave_Pay', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('2SA') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Voluntary Separation Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Warrant_Voluntary_Separation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('1SJ') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_Voluntary_Separation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('2SJ') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Involuntary Separation Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Warrant_Involuntary_Separation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('1SH') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_Involuntary_Separation', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag IN ('2SH', '2SG') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- PCS_Training_Move_Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_PCS_Training_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5B%' AND ape_pt_desc ILIKE '%Enlisted%'
      AND appn = 'MPA' AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_PCS_Training_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5B%' AND ape_pt_desc ILIKE '%Officer%'
      AND appn = 'MPA' AND bo = '1'
    GROUP BY fy, appn;

    -- PCS_Unit_Move_Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_PCS_Unit_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5F%' AND ape_pt_desc ILIKE '%Enlisted%'
      AND appn = 'MPA' AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_PCS_Unit_Move_Budget', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag ILIKE '5F%' AND ape_pt_desc ILIKE '%Officer%'
      AND appn = 'MPA' AND bo = '1'
    GROUP BY fy, appn;

    -- Severence_Pay
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enlisted_Severence_Pay', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape = '2S2E00000' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Severence_Pay', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1SE' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- TDY_ConusOverseas_30_Dep_Not_Nearby
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'TDY_ConusOverseas_30_Dep_Not_Nearby', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type IN ('BASE', 'MSUP') AND ape = '2R2D00000' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Tot_Bdgt_For_Overseas_Station_Allowance
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Tot_Bdgt_For_Overseas_Station_Allowance', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('2P2C00000', '2P2A00000') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Enl_Bdgt_For OCONUS COLA OHA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Enl_Bdgt_OCONUS_COLA_OHA', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND ape IN ('2H2F00000', '2H2G00000', '2P2A00000', '2P2C00000')
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Officer & Warrant Bdgt_For_OCONUS COLA OHA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AO_AWO_Bdgt_OCONUS_COLA_OHA', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND ape IN ('1H1F00000', '1H1G00000', '1P1A00000', '1P1C00000')
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Officer & Warrant Bdgt_For_CONUS COLA OHA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AO_AWO_Bdgt_CONUS_COLA', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('1U1000000') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Enlisted & Warrant Bdgt_For_CONUS COLA OHA
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AE_Bdgt_CONUS_COLA', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('2U2000000') AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Separation Pay, Non-Disability, Active Officer
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_Sep_Pay_NonDis', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND ape IN ('1S1J00000', '1S1N00000', '1S1A00000', '1S1H00000', '1S1L00000')
      AND bo = '1' AND ba = '01' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Temp Duty > 30 Days w/Dep Not Near TD Station, Active Officers
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'Officer_TDY_30_Plus_Days_wDeps_Not_Near_Stn', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type IN ('BASE', 'MSUP') AND sag = '1RD' AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Basic Benefit Chapters 1606 + 1607
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NE_Basic_Benefit', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape = '1K33A2000' AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RE_Basic_Benefit', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape = '1S3300000' AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    -- Clothing
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NE_Clothing', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND (ape_pt_desc ILIKE '%clothing%' AND ape_pt_desc ILIKE '%enl%')
      AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RE_Clothing', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND (ape_pt_desc ILIKE '%clothing%' AND ape_pt_desc ILIKE '%enlisted%'
           AND ape_pt_desc NOT ILIKE '%agr%')
      AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RO_RWO_Clothing', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND (ape_pt_desc ILIKE '%clothing%' AND ape_pt_desc ILIKE '%officer%')
      AND ape_pt_desc NOT ILIKE '%AGR%'
      AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NO_NWO_Clothing', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND (ape_pt_desc ILIKE '%clothing%' AND ape_pt_desc ILIKE '%off%')
      AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AE_Clothing', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND ape IN ('2Q2A10A20', '2Q2A10A10', '2Q2B10200', '2Q2B20100', '2Q2B20200',
                  '2Q2B10100', '2Q2C00000', '2Q2Z20000', '2Q2Z40000', '2Q2Z30000')
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AO_AWO_Clothing', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('1Q1A10000', '1Q1B10000')
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Educational Benefit, Kicker
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NE_Edu_Kicker', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1K3' AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RE_Edu_Kicker', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND sag = '1S7' AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    -- Student Loan Repayment
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NE_Student_Loan_Repayment', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape = '1R33A2000' AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RE_Student_Loan_Repayment', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape = '1R33V0000' AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    -- Disability & Hospitalization, Death Gratuities (DHDG)
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NE_DHDG', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('1T3102000', '1U3112000')
      AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RE_DHDG', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('1T3300000', '1U3300000')
      AND appn = 'RPA' AND bo = '1'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NO_NWO_DHDG', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('1T1102000', '1U1112000')
      AND bo = '1' AND appn = 'NGPA'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RO_RWO_DHDG', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND ape IN ('1U1300000', '1T1300000')
      AND bo = '1' AND appn = 'RPA'
    GROUP BY fy, appn;

    -- End Strength
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NE_Endstrength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'NGPA' AND rc IN ('GEPD', 'GEPP', 'GEST', 'GPGF')
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RE_Endstrength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'RPA' AND rc ILIKE 'RE%'
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'NO_NWO_Endstrength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'NGPA' AND rc IN ('GOPD', 'GOST', 'GWPD', 'GWST')
    GROUP BY fy, appn;

    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'RO_RWO_Endstrength', appn, fy::varchar, p_amcosversionid, SUM(amount)
    FROM armybudget
    WHERE bo = '4' AND appn = 'RPA'
      AND rc IN ('ROMA', 'RODP', 'ROST', 'RWMA', 'RWPD', 'RWST')
    GROUP BY fy, appn;

    -- Misc Benefits (Enlisted)
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AE_Misc', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND ape IN ('6A0000000', '6B2000000', '6C2000000', '6D0000000')
      AND bo = '1' AND appn = 'MPA'
    GROUP BY fy, appn;

    -- Total Other Military Personnel Costs (Officer)
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'AO_Misc', appn, fy::varchar, p_amcosversionid, SUM(amount) * 1000
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%'
      AND sag IN ('6DA', '6QA', '6KA', '6CA', '6HA', '6AA', '6GA', '6BA', '6JA')
      AND bo = '1' AND appn = 'MPA' AND ape_pt_desc NOT ILIKE '%enl%'
    GROUP BY fy, appn;

    -- Amort of Education Benefits: intentionally omitted (source SV commented out 3/17/2023)

    /* Officer Domestic Basic Allowance for Housing Budget */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'BAH_Domestic_AO_AWO', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'MPA'
      AND sag IN ('1HE', '1HC', '1HA', '1HB') AND bo = '1'
    GROUP BY appn, fy;

    /* Officer Overseas Basic Allowance for Housing Budget */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'BAH_Overseas_AO_AWO', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'MPA'
      AND sag IN ('1HF', '1HG') AND bo = '1'
    GROUP BY appn, fy;

    /* Enlisted Domestic Basic Allowance for Housing Budget */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'BAH_Domestic_AE', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'MPA'
      AND sag IN ('2HE', '2HC', '2HA', '2HB') AND bo = '1'
    GROUP BY appn, fy;

    -- Enlisted Overseas Basic Allowance for Housing Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'BAH_Oveseas_AE', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'MPA'
      AND sag IN ('2HF', '2HG') AND bo = '1'
    GROUP BY appn, fy;

    -- Officer Domestic Basic Allowance for Subsistence Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'BAS_Domestic_AO_AWO', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'MPA'
      AND sag IN ('1KA') AND bo = '1'
    GROUP BY appn, fy;

    -- Enlisted Domestic Basic Allowance for Subsistence Budget
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT 'BAS_Domestic_AE', appn, fy::varchar, p_amcosversionid, SUM(amount * 1000)
    FROM armybudget
    WHERE dollar_type ILIKE 'BASE%' AND appn = 'MPA'
      AND ba = '04' AND bo = '1'
    GROUP BY appn, fy;

    /* Compute average values across fiscal years (FY = 'Avg') */
    INSERT INTO pomdata (parametername, appropriation, fy, amcosversionid, amount)
    SELECT parametername, appropriation, 'Avg' AS fy, amcosversionid, AVG(amount)
    FROM pomdata
    GROUP BY parametername, appropriation, amcosversionid;

    -- @Debug = 1 result-set dump dropped (no runtime effect).

    IF NOT p_debug THEN
        DELETE FROM crunch.armybudgetsinglevalues
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.armybudgetsinglevalues
            (parametername, appropriation, fy, amcosversionid, amount)
        SELECT parametername, appropriation, fy, amcosversionid, amount
        FROM pomdata;
    END IF;

    DROP TABLE IF EXISTS pomdata;
    DROP TABLE IF EXISTS armybudget;
END;
$$;

------------------------------------------------------------------------------
-- crunch.DMDCPay  (Phase 2)
--   Computes the 3-year average of DMDC military pay data and populates
--   crunch.PayProcessed for later per-cost-element calculations.
--
--   Faithful structural port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
--   DMDCPay.sql. The source has NO @CrunchTime, so this proc takes none.
--
--   * p_debug = true is a DRY RUN: the source only performs the DELETE + INSERT
--     writes under "IF @Debug = 0"; the "IF @Debug = 1" branch is a result-set
--     dump for interactive inspection and is dropped (no runtime effect).
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS first and again at proc end).
--   * Source [Count] column -> quoted "count" (reserved word).  DMDC.Pay ->
--     "DMDC".pay (case-sensitive schema).  data.Inventory -> data.inventory (view).
--   * The inventory bring-in "UPDATE #DMDCPayFinal ... FROM #DMDCPayFinal AS a
--     INNER JOIN (derived) MilitaryInventory" is rewritten to a PG
--     "UPDATE dmdcpayfinal t SET .. FROM (derived) WHERE .." — the self-scan of
--     the update target is dropped and the ON clause becomes the WHERE. This is
--     an INNER JOIN in the source too (unmatched rows keep their NULL inventory),
--     so the PG inner-join UPDATE..FROM is behavior-equivalent.
--   * data.inventory.gradelevel is text (the view UNIONs a smallint DMDC branch
--     with a text GFEBS branch), so the join casts it to smallint to match
--     dmdcpayfinal.gradelevel / the destination column.
--   * Denominators already wrapped in NULLIF(...,0) in the source are preserved.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.dmdcpay(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS dmdcpayraw;
    CREATE TEMP TABLE dmdcpayraw (
        amcosversionid               integer      NOT NULL,
        filedate                     varchar(10),
        payplan                      varchar(3),
        gradetype                    varchar(3),
        gradelevel                   smallint     NOT NULL,
        paytype                      varchar(300),
        primaryserviceoccupationcode varchar(20),
        number_rcv                   integer,
        totalpayamount               numeric(18, 2),
        inv_add                      double precision
    );

    INSERT INTO dmdcpayraw
        (amcosversionid, filedate, payplan, gradetype, gradelevel, paytype,
         primaryserviceoccupationcode, number_rcv, totalpayamount)
    SELECT amcosversionid,
           filedate,
           payplan,
           gradetype,
           gradelevel,
           paytype,
           primaryserviceoccupationcode,
           "count" AS number_rcv,
           totalpayamount
    FROM "DMDC".pay
    WHERE amcosversionid IN
          (
              -- get the most recent 3 years for a 3 year moving average
              SELECT amcosversionid
              FROM "DMDC".pay
              WHERE amcosversionid <= p_amcosversionid
              GROUP BY amcosversionid
              ORDER BY amcosversionid DESC
              LIMIT 3
          )
      AND (
              "count" <> 0
              AND totalpayamount <> 0
          );

    -- =============================================
    -- Generate final table
    -- =============================================
    DROP TABLE IF EXISTS dmdcpayfinal;
    CREATE TEMP TABLE dmdcpayfinal (
        paytype              varchar(300),
        payplan              varchar(3),
        categorygroupcode    varchar(4),
        categorysubgroupcode varchar(4),
        gradetype            varchar(3),
        gradelevel           smallint,
        avg_3yr_pay          numeric(18, 2),
        avg_3yr_payments     numeric(18, 2),
        inventory            integer,
        avg_mpa_cost         numeric(18, 2)
    );

    INSERT INTO dmdcpayfinal
        (paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
         gradelevel, avg_3yr_pay, avg_3yr_payments, inventory, avg_mpa_cost)
    SELECT paytype,
           payplan,
           NULL AS categorygroupcode,
           primaryserviceoccupationcode,
           gradetype,
           gradelevel,
           -- 2020-02-04 changed from AVG(...) to SUM(...)/3 to handle years with
           -- no pay (which would otherwise skew a straight 3-year average)
           SUM(avg_annual_pay) / 3 AS avg_3yr_pay,
           SUM(avg_annual_payments * 1.0) / 3 AS avg_3yr_payments,
           NULL AS inventory,
           0.0 AS avg_mpa_cost
    FROM
    (
        -- aggregate up to annual figures before we average across years
        SELECT amcosversionid,
               paytype,
               payplan,
               NULL AS categorygroupcode,
               primaryserviceoccupationcode,
               gradetype,
               gradelevel,
               SUM(totalpayamount) AS avg_annual_pay,
               SUM(number_rcv) AS avg_annual_payments,
               NULL AS inventory,
               0.0 AS avg_mpa_cost
        FROM dmdcpayraw
        GROUP BY amcosversionid,
                 paytype,
                 payplan,
                 primaryserviceoccupationcode,
                 gradetype,
                 gradelevel
    ) AS a
    GROUP BY paytype,
             payplan,
             primaryserviceoccupationcode,
             gradetype,
             gradelevel;

    -- =============================================
    -- Generate CMF (left two of the sub group)
    -- =============================================
    UPDATE dmdcpayfinal
    SET categorygroupcode = left(categorysubgroupcode, 2);

    -- =============================================
    -- bring in inventory (3-year moving inventory average as the denominator)
    -- =============================================
    -- Rewritten from the source self-join UPDATE..FROM: the "#DMDCPayFinal AS a"
    -- self-scan is dropped, the derived MilitaryInventory stays in FROM, and the
    -- ON clause becomes the WHERE against the update target. INNER JOIN in the
    -- source too, so unmatched rows keep their NULL inventory (behavior-equivalent).
    UPDATE dmdcpayfinal t
    SET inventory = militaryinventory.inventory
    FROM
    (
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               gradetype,
               gradelevel,
               AVG(inventory * 1.00) AS inventory
        FROM
        (
            SELECT payplan,
                   categorygroupcode,
                   categorysubgroupcode,
                   gradetype,
                   gradelevel,
                   SUM(inventory) AS inventory,
                   amcosversionid
            FROM data.inventory
            WHERE payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
              AND amcosversionid BETWEEN p_amcosversionid - 200 AND p_amcosversionid
            GROUP BY payplan,
                     categorygroupcode,
                     categorysubgroupcode,
                     gradetype,
                     gradelevel,
                     amcosversionid
        ) AS a
        GROUP BY payplan,
                 categorygroupcode,
                 categorysubgroupcode,
                 gradetype,
                 gradelevel
    ) AS militaryinventory
    WHERE t.categorysubgroupcode = militaryinventory.categorysubgroupcode
      AND t.gradelevel = militaryinventory.gradelevel::smallint
      AND t.payplan = militaryinventory.payplan;

    -- when there is no inventory the value is NULL; make those 0
    UPDATE dmdcpayfinal
    SET inventory = 0
    WHERE inventory IS NULL;

    -- when the number receiving exceeds inventory, use rcv as the denominator
    -- so we aren't inflating costs
    UPDATE dmdcpayfinal
    SET avg_mpa_cost = avg_3yr_pay / NULLIF(avg_3yr_payments, 0)
    WHERE (inventory) < avg_3yr_payments
      AND inventory > 0;

    -- when inventory is >= number receiving, use inventory as the denominator
    UPDATE dmdcpayfinal
    SET avg_mpa_cost = avg_3yr_pay / NULLIF(inventory, 0)
    WHERE (inventory) >= avg_3yr_payments
      AND inventory > 0;

    -- we don't allow negative costs, so make those zero
    UPDATE dmdcpayfinal
    SET avg_mpa_cost = 0
    WHERE avg_mpa_cost < 0;

    -- populate crunch.PayProcessed for use by individual cost element calculations
    IF NOT p_debug THEN
        DELETE FROM crunch.payprocessed
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.payprocessed
            (paytype, payplan, categorygroupcode, categorysubgroupcode, gradetype,
             gradelevel, avg_cost, amcosversionid, avg_annual_pay, avg_annual_payments)
        SELECT paytype,
               payplan,
               categorygroupcode,
               categorysubgroupcode,
               gradetype AS gradetype,
               gradelevel,
               avg_mpa_cost AS avg_cost,
               p_amcosversionid AS amcosversionid,
               avg_3yr_pay,
               avg_3yr_payments
        FROM dmdcpayfinal;
    END IF;

    DROP TABLE IF EXISTS dmdcpayraw;
    DROP TABLE IF EXISTS dmdcpayfinal;
END;
$$;

------------------------------------------------------------------------------
-- crunch.jointinflationcalculator
--
-- Port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/JointInflationCalculator.sql
-- (Dan Hogan, Apr 2021). Populates the new JIC table (warehouse.jointinflationcalculator)
-- and the legacy lookup table (lookup.jicinflationrates) from the latest AmcosVersionId
-- release in data.asafmcjointinflationrates.
--
-- Faithful structural port. The source proc takes NO parameters and has NO @Debug /
-- @CrunchTime, so this procedure keeps an empty parameter list, performs its DELETE +
-- INSERT writes unconditionally (matching the source), and does not call
-- crunch.validateamcosversion (there is no p_amcosversionid to validate).
--
-- LANGUAGE plpgsql (deferred name resolution): reads data.asafmcjointinflationrates /
-- lookup.amcosversion inputs that the ETL / earlier phases populate.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.jointinflationcalculator()
LANGUAGE plpgsql
AS $$
DECLARE
    v_commonminbaseyear   varchar(4);
    v_commonmintargetyear varchar(4);
BEGIN
    -- Highest per-appropriation MIN(BaseYear) common to all appropriations
    -- (excluding '197T', which would skew the min calc).
    SELECT MAX(myyear)
    INTO v_commonminbaseyear
    FROM (
             SELECT MIN(baseyear) AS myyear,
                    appropriation
             FROM data.asafmcjointinflationrates
             WHERE baseyear <> '197T'
             GROUP BY appropriation
         ) AS a;

    -- Highest per-appropriation MIN(TargetYear) common to all appropriations.
    SELECT MAX(myyear)
    INTO v_commonmintargetyear
    FROM (
             SELECT MIN(targetyear) AS myyear,
                    appropriation
             FROM data.asafmcjointinflationrates
             WHERE targetyear <> '197T'
             GROUP BY appropriation
         ) AS a;

    -- New JIC table: latest version, only the common minimum base/target years.
    DELETE FROM warehouse.jointinflationcalculator;

    INSERT INTO warehouse.jointinflationcalculator
        (conversiontype, baseyear, targetyear, appropriation, amount)
    SELECT conversiontype,
           baseyear,
           targetyear,
           appropriation,
           amount
    FROM data.asafmcjointinflationrates
    WHERE amcosversionid IN (
              SELECT MAX(amcosversionid) FROM data.asafmcjointinflationrates
          )
      AND baseyear >= v_commonminbaseyear
      AND targetyear >= v_commonmintargetyear;

    -- Legacy lookup table (kept to avoid programming changes before the Spring 2021
    -- release): latest version, no '197T', current-release base year only.
    DELETE FROM lookup.jicinflationrates
    WHERE amcosversionid = (
              SELECT MAX(amcosversionid) FROM lookup.amcosversion
          );

    INSERT INTO lookup.jicinflationrates
        (conversiontype, "year", appropriation, amount, amcosversionid)
    -- lookup.jicinflationrates.year is smallint; targetyear is a varchar FY code.
    -- The WHERE excludes the only non-numeric code ('197T'), so the remaining
    -- 4-digit year strings cast cleanly to smallint.
    SELECT conversiontype,
           targetyear::smallint,
           appropriation,
           amount,
           amcosversionid
    FROM data.asafmcjointinflationrates
    WHERE targetyear <> '197T'
      AND amcosversionid IN (
              SELECT MAX(amcosversionid) FROM data.asafmcjointinflationrates
          )
      AND baseyear = (
              SELECT left(MAX(amcosversionid)::text, 4) FROM lookup.amcosversion
          )
      AND targetyear >= v_commonmintargetyear;
END;
$$;

------------------------------------------------------------------------------
-- crunch.loadgsaperdiem
-- Port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/LoadGSAPerDiem.sql
--
-- Rebuilds crunch.gsaperdiem for one AMCOS version from three ETL inputs:
--   1. dataload.gsaperdiem_raw          -- CONUS GSA rates (per-month lodging cols)
--   2. dataload.dodoconusperdiem_raw    -- DoD OCONUS areas the US "owns"
--                                          (AK/HI/AS/PR, then GUAM separately)
-- joined to lookup.fips_zip for ZIP resolution. Faithful structural port; no
-- @Debug / @CrunchTime in the source, so no dry-run guard and DateEffective
-- uses now()::timestamp (was GETDATE()).
--
-- Source T-SQL took MAX across the 12 month columns via an inline
-- VALUES(...)/MAX(vals) subquery; ported to GREATEST(MAX(oct),...,MAX(sep)),
-- which is equivalent (PG GREATEST ignores NULL inputs, matching the T-SQL
-- MAX-over-VALUES behavior).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.loadgsaperdiem(
    p_amcosversionid integer DEFAULT -1)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DELETE FROM crunch.gsaperdiem
    WHERE amcosversionid = p_amcosversionid;

    -- CONUS GSA rates: annual max lodging is the max across the 12 monthly cols
    INSERT INTO crunch.gsaperdiem
        (zipcode, fiscalyear, maximumlodgingrate,
         maximummealsandincidentalsrate, dateeffective, amcosversionid)
    SELECT zip,
           fiscalyear,
           GREATEST(MAX(oct), MAX(nov), MAX("dec"), MAX(jan), MAX(feb),
                    MAX(mar), MAX(apr), MAX(may), MAX(jun), MAX(jul),
                    MAX(aug), MAX(sep)),
           MAX(meals),
           now()::timestamp,
           p_amcosversionid
    FROM dataload.gsaperdiem_raw
    WHERE amcosversionid = p_amcosversionid
    GROUP BY zip,
             fiscalyear;

    -- DoD OCONUS areas the US 'owns' that don't come from GSA (AK/HI/AS/PR)
    INSERT INTO crunch.gsaperdiem
        (zipcode, fiscalyear, maximumlodgingrate,
         maximummealsandincidentalsrate, dateeffective, amcosversionid)
    SELECT DISTINCT
           b.zipcode,
           left(a.amcosversionid::text, 4)::smallint AS fiscalyear,
           MAX(a.lodging),
           MAX(a.maximumperdiem - a.lodging),
           now()::timestamp,
           p_amcosversionid
    FROM dataload.dodoconusperdiem_raw AS a
        INNER JOIN lookup.fips_zip AS b
            ON LOWER(a.location) = LOWER(b.city)
               AND LOWER(a.statecounty) = LOWER(b.statename)
    WHERE a.amcosversionid = p_amcosversionid
          AND p_amcosversionid
          BETWEEN b.amcosversionidstart AND b.amcosversionidend
          -- DoD data ships with other countries; keep only our OCONUS states/territories
          AND a.statecounty IN ('Alaska', 'HAWAII', 'AMERICAN SAMOA', 'PUERTO RICO')
    GROUP BY b.zipcode,
             left(a.amcosversionid::text, 4);

    -- Guam handled separately (special naming: matched on state only, not city)
    INSERT INTO crunch.gsaperdiem
        (zipcode, fiscalyear, maximumlodgingrate,
         maximummealsandincidentalsrate, dateeffective, amcosversionid)
    SELECT DISTINCT
           b.zipcode,
           left(a.amcosversionid::text, 4)::smallint AS fiscalyear,
           MAX(a.lodging),
           MAX(a.maximumperdiem - a.lodging),
           now()::timestamp,
           p_amcosversionid
    FROM dataload.dodoconusperdiem_raw AS a
        INNER JOIN lookup.fips_zip AS b
            ON LOWER(a.statecounty) = LOWER(b.statename)
    WHERE a.amcosversionid = p_amcosversionid
          AND p_amcosversionid
          BETWEEN b.amcosversionidstart AND b.amcosversionidend
          AND a.statecounty IN ('GUAM')
    GROUP BY b.zipcode,
             left(a.amcosversionid::text, 4);
END;
$$;

------------------------------------------------------------------------------
-- crunch.calculatepayplanminmax
--
-- Port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CalculatePayPlanMinMax.sql
-- Populates crunch.payscheduleminmax with the min/max annualized pay rate for
-- every payplan / group / subgroup / career-program / location / STRL / grade
-- combination found in data.costs, using data.payschedules, crunch.inventorywass,
-- "PaySchedule".opmsesraw and data.costs as pay sources.
--
-- Faithful structural port. Conventions:
--   * p_debug = true is a DRY RUN. The source writes (DELETE + INSERT into
--     crunch.payscheduleminmax) only under "IF @Debug = 0"; guarded here with
--     "IF NOT p_debug". All "IF @Debug = 1" result-set dumps are dropped (no
--     runtime effect in a procedure); the load-bearing DELETE of NULL rows that
--     was nested inside the final @Debug diagnostic block is preserved.
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS first and at proc end).
--   * "UPDATE #t ... FROM #t a JOIN ..." rewrites: PG forbids re-aliasing the
--     UPDATE target in FROM. Self-aggregations over the target are kept as a
--     sub-SELECT in FROM (allowed). See DECISIONS/RISKS.
--   * ISNULL->COALESCE, LIKE patterns / literals / pay-plan lists preserved verbatim.
--
-- COLUMN MISMATCH: the destination crunch.payscheduleminmax has NO
-- careerprogramnumber column (and no aggregationtype). The source's final INSERT
-- wrote careerprogramnumber; it is dropped from the write here. careerprogramnumber
-- is still carried as an internal temp column because the aggregation logic needs
-- it. appropriation (source APPN) is COALESCEd to '-1' to satisfy the NOT NULL
-- DEFAULT '-1' destination column.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.calculatepayplanminmax(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_annualhours   numeric(16, 2);
    v_monthsinayear integer := 12;
    v_daysinamonth  integer := 30;
    v_activedays    integer;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    v_annualhours := crunch.getsinglevalue('GP', 'annualPaidHours', p_amcosversionid);

    DROP TABLE IF EXISTS paymm;
    CREATE TEMP TABLE paymm (
        payplan              varchar(3),
        gradetype            varchar(3),
        categorysubgroupcode varchar(5),
        locationid           integer,
        strl                 varchar(20),
        gradelevel           smallint,
        minrate              numeric(16, 2),
        maxrate              numeric(16, 2),
        amcosversionid       integer
    );

    /* Insert minimum and maximum pay for category subgroup for military pay plans */
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           a.locationid,
           a.strl,
           a.gradelevel,
           MAX(CASE
                   WHEN a.ratetype = 'Monthly' THEN a.rate * 12    -- active mil
                   WHEN a.ratetype = '4 Drills' THEN a.rate * 12   -- NG/R 1 weekend a month
                   ELSE a.rate
               END) AS maxrate,
           MIN(CASE
                   WHEN a.ratetype = 'Monthly' THEN a.rate * 12
                   WHEN a.ratetype = '4 Drills' THEN a.rate * 12
                   ELSE a.rate
               END) AS minrate,
           a.amcosversionid
    FROM data.payschedules AS a
        INNER JOIN lookup.payplantags AS b
            ON b.payplan = a.payplan
               AND b.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND b.tag = 'Military'
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, a.locationid, a.strl, a.gradelevel, a.amcosversionid;

    /* min/max by subgroup for WAGE CONUS
       (NF amounts are already annual while other wage is hourly, so NF/Annual keep multiplier 1) */
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           a.locationid,
           a.strl,
           a.gradelevel,
           MAX(CASE WHEN a.payplan = 'NF' OR a.ratetype = 'Annual' THEN 1 ELSE v_annualhours END * a.rate) AS maxrate,
           MIN(CASE WHEN a.payplan = 'NF' OR a.ratetype = 'Annual' THEN 1 ELSE v_annualhours END * a.rate) AS minrate,
           a.amcosversionid
    FROM data.payschedules a
        INNER JOIN warehouse.location b
            ON b.locationid = a.locationid
        INNER JOIN lookup.payplantags AS c
            ON c.payplan = a.payplan
               AND c.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND c.tag = 'Wage'
          AND a.locationid <> -1
          AND b.displayname <> 'Foreign Areas'
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, a.locationid, a.strl, a.gradelevel, a.amcosversionid;

    -- min/max by subgroup for WAGE OCONUS
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           a.locationid,
           a.strl,
           a.gradelevel,
           MAX(v_annualhours * a.rate) AS maxrate,
           MIN(v_annualhours * a.rate) AS minrate,
           a.amcosversionid
    FROM data.payschedules AS a
        INNER JOIN warehouse.location AS b
            ON b.locationid = a.locationid
        INNER JOIN lookup.payplantags AS c
            ON c.payplan = a.payplan
               AND c.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND c.tag = 'Wage'
          AND a.locationid <> -1
          AND b.locationtype IN ('Federal Wage System AF', 'Federal Wage System NAF')
          AND b.displayname = 'Foreign Areas'
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, a.locationid, a.strl, a.gradelevel, a.amcosversionid;

    /* min/max by subgroup for WAGE ALL (-1) */
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           -1 AS locationid,
           a.strl,
           a.gradelevel,
           MAX(v_annualhours * a.rate) AS maxrate,
           MIN(v_annualhours * a.rate) AS minrate,
           a.amcosversionid
    FROM data.payschedules AS a
        INNER JOIN lookup.payplantags AS b
            ON b.payplan = a.payplan
               AND b.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND b.tag = 'Wage'
          AND a.ratetype <> 'Annual'
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, a.strl, a.gradelevel, a.amcosversionid;

    /* min/max by subgroup for CIV CONUS (no overseas areas) */
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           a.locationid,
           a.strl,
           a.gradelevel,
           MAX(a.rate) AS maxrate,
           MIN(a.rate) AS minrate,
           a.amcosversionid
    FROM data.payschedules AS a
        INNER JOIN lookup.payplantags AS b
            ON b.payplan = a.payplan
               AND b.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND b.tag IN ('GFEBS', 'Civilian')
          AND a.locationid <> -1
          AND a.locationid IN
              (
                  SELECT locationid
                  FROM warehouse.location
                  WHERE displayname NOT IN ('Civilian Overseas')
              )
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, a.locationid, a.strl, a.gradelevel, a.amcosversionid;

    -- min/max by subgroup for CIV OCONUS
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           b.locationid,
           a.strl,
           a.gradelevel,
           MAX(a.rate) AS maxrate,
           MIN(a.rate) AS minrate,
           a.amcosversionid
    FROM data.payschedules AS a
        CROSS JOIN warehouse.location AS b
    WHERE a.amcosversionid = p_amcosversionid
          AND a.payplan IN
              (
                  SELECT payplan FROM lookup.payplantags WHERE tag IN ('GFEBS', 'Civilian')
              )
          AND a.locationid = -1
          AND b.locationtype = 'Civilian Overseas'
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, b.locationid, a.strl, a.gradelevel, a.amcosversionid;

    -- min/max by subgroup for CIV ALL (-1)
    -- NOTE: source predicate "b.Tag = 'GFEBS' AND b.Tag = 'Civilian'" is always
    -- false (a row's Tag cannot equal both) so this INSERT yields zero rows.
    -- Preserved verbatim as a source bug.
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT a.payplan,
           a.gradetype,
           a.categorysubgroupcode,
           -1,
           a.strl,
           a.gradelevel,
           MAX(a.rate) AS maxrate,
           MIN(a.rate) AS minrate,
           a.amcosversionid
    FROM data.payschedules AS a
        INNER JOIN lookup.payplantags AS b
            ON b.payplan = a.payplan
               AND b.amcosversionid = a.amcosversionid
    WHERE a.amcosversionid = p_amcosversionid
          AND b.tag = 'GFEBS' AND b.tag = 'Civilian'
    GROUP BY a.payplan, a.gradetype, a.categorysubgroupcode, a.strl, a.gradelevel, a.amcosversionid;

    -- WASS based pay has no payschedule so it comes directly from the wass source
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT payplan,
           gradetype,
           occupationalseriesnumber,
           locationid,
           '-1' AS strl,
           gradelevel,
           CASE
               WHEN MAX(averagepay) > 1000 THEN MAX(averagepay)    -- likely annual: don't multiply
               ELSE MAX(averagepay) * v_annualhours
           END,
           CASE
               WHEN MIN(averagepay) > 1000 THEN MIN(averagepay)    -- likely annual: don't multiply
               ELSE MIN(averagepay) * v_annualhours
           END,
           amcosversionid
    FROM crunch.inventorywass
    WHERE amcosversionid = p_amcosversionid
    GROUP BY payplan, gradetype, occupationalseriesnumber, locationid, gradelevel, amcosversionid;

    /* AD pay plans have no payschedule; use whatever we already generated at the
       subgroup + location level so the next step can generate the individual min/max */
    INSERT INTO paymm
        (payplan, gradetype, categorysubgroupcode, locationid, strl, gradelevel, maxrate, minrate, amcosversionid)
    SELECT payplan,
           gradetype,
           categorysubgroupcode,
           locationid,
           '-1',
           gradelevel,
           amount AS maxpay,
           amount AS minpay,
           amcosversionid
    FROM data.costs
    WHERE amcosversionid = p_amcosversionid
          AND payplan = 'AD'
          AND locationid <> -1
          AND categorysubgroupcode <> '-1'
          AND careerprogramnumber = '-1'
          AND costelementname LIKE '%base%pay%';

    v_activedays := crunch.getsinglevalue('AA', 'activedays', p_amcosversionid);

    -- add 2 weeks active pay to NG/R (self-aggregation of AE/AO/AWO grade min/max).
    -- REWRITE: T-SQL "UPDATE #PayMinMax ... FROM #PayMinMax a INNER JOIN (agg over
    -- #PayMinMax) b" -> UPDATE target directly, self-scan kept in the FROM sub-SELECT.
    UPDATE paymm
    SET minrate = paymm.minrate + (b.minrate / v_monthsinayear / v_daysinamonth * v_activedays),
        maxrate = paymm.maxrate + (b.maxrate / v_monthsinayear / v_daysinamonth * v_activedays)
    FROM (
             SELECT MIN(minrate) AS minrate,
                    MAX(maxrate) AS maxrate,
                    gradetype,
                    gradelevel
             FROM paymm
             WHERE payplan IN ('AE', 'AO', 'AWO')
             GROUP BY gradetype, gradelevel
         ) AS b
    WHERE paymm.gradetype = b.gradetype
      AND paymm.gradelevel = b.gradelevel
      AND paymm.payplan IN ('NO', 'NE', 'NWO', 'RE', 'RO', 'RWO');

    /* Anything still missing a min/max gets the min/max cost from the cost table
       (assumed to have no payschedule if unset at this point). */
    UPDATE paymm
    SET minrate = b.amount,
        maxrate = b.amount
    FROM data.costs AS b
    WHERE b.amcosversionid = paymm.amcosversionid
      AND b.categorysubgroupcode = paymm.categorysubgroupcode
      AND b.gradelevel = paymm.gradelevel
      AND b.locationid = paymm.locationid
      AND b.payplan = paymm.payplan
      AND b.strl = paymm.strl
      AND paymm.minrate IS NULL
      AND paymm.maxrate IS NULL
      AND b.costelementname LIKE '%base%pay%';

    DROP TABLE IF EXISTS finaltable;
    CREATE TEMP TABLE finaltable (
        payplan              varchar(3),
        categorygroupcode    varchar(4),
        categorysubgroupcode varchar(5),
        careerprogramnumber  char(2),
        locationid           integer,
        strl                 varchar(20),
        gradetype            varchar(3),
        gradelevel           smallint,
        minrate              numeric(16, 2),
        maxrate              numeric(16, 2),
        amcosversionid       integer,
        aggregationtype      varchar(50)
    );

    -- master list of all possible combinations from the cost table
    INSERT INTO finaltable
        (payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
         locationid, strl, gradetype, gradelevel, amcosversionid)
    SELECT DISTINCT
           payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
           locationid, strl, gradetype, gradelevel, amcosversionid
    FROM data.costs
    WHERE amcosversionid = p_amcosversionid;

    /* SES is a set min/max in ALL cases (scalar subqueries over OpmSesRaw).
       Source's redundant "FROM #finaltable" self-reference dropped; source ran this
       block twice identically -- both kept for faithfulness (idempotent). */
    UPDATE finaltable
    SET minrate = (SELECT minpay FROM "PaySchedule".opmsesraw WHERE ratetype = 'Annual' AND amcosversionid = p_amcosversionid),
        maxrate = (SELECT maxpay FROM "PaySchedule".opmsesraw WHERE ratetype = 'Annual' AND amcosversionid = p_amcosversionid)
    WHERE payplan = 'SES';

    UPDATE finaltable
    SET minrate = (SELECT minpay FROM "PaySchedule".opmsesraw WHERE ratetype = 'Annual' AND amcosversionid = p_amcosversionid),
        maxrate = (SELECT maxpay FROM "PaySchedule".opmsesraw WHERE ratetype = 'Annual' AND amcosversionid = p_amcosversionid)
    WHERE payplan = 'SES';

    -- these pay plans use min/max like SES (annual payschedule min/max per grade)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT payplan,
                    gradelevel,
                    amcosversionid,
                    MAX(rate) AS maxrate,
                    MIN(rate) AS minrate
             FROM data.payschedules
             WHERE ratetype = 'Annual'
                   AND amcosversionid = p_amcosversionid
             GROUP BY payplan, gradelevel, amcosversionid
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.payplan IN ('EX', 'IE', 'IG', 'IP', 'SL', 'ST');

    -- Military is the same pay regardless of location
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b,
         lookup.payplantags AS c
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND c.payplan = finaltable.payplan
      AND c.amcosversionid = finaltable.amcosversionid
      AND c.tag = 'Military';

    -- GP is base pay regardless (no locality pay)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.payplan = 'GP';

    -- special pay scenarios (location + subgroup specific)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.categorysubgroupcode = b.categorysubgroupcode
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag = 'SpecialPay'
          )
      AND finaltable.categorysubgroupcode <> '-1'
      AND finaltable.maxrate IS NULL
      AND finaltable.locationid <> -1;

    -- MAX non-special-pay G series plans (simple location based)
    UPDATE finaltable
    SET maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.payplan <> 'GP'
      AND finaltable.payplan LIKE 'G%'
      AND (finaltable.maxrate IS NULL OR finaltable.maxrate < b.maxrate)
      AND b.categorysubgroupcode = '-1'
      AND finaltable.categorysubgroupcode <> '-1'
      AND finaltable.locationid <> -1
      AND finaltable.locationid NOT IN
          (
              SELECT locationid FROM warehouse.location WHERE locationtype = 'Civilian Overseas'
          );

    -- MIN non-special-pay G series plans (simple location based)
    UPDATE finaltable
    SET minrate = b.minrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.payplan <> 'GP'
      AND finaltable.payplan LIKE 'G%'
      AND (finaltable.minrate IS NULL OR finaltable.minrate < b.minrate)
      AND b.categorysubgroupcode = '-1'
      AND finaltable.categorysubgroupcode <> '-1'
      AND finaltable.locationid <> -1
      AND finaltable.locationid NOT IN
          (
              SELECT locationid FROM warehouse.location WHERE locationtype = 'Civilian Overseas'
          );

    -- overseas G series where pay location is -1 and cost location floats
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.payplan <> 'GP'
      AND finaltable.payplan LIKE 'G%'
      AND finaltable.maxrate IS NULL
      AND b.categorysubgroupcode = '-1'
      AND b.locationid = -1
      AND finaltable.locationid IN
          (
              SELECT locationid FROM warehouse.location WHERE locationtype = 'Civilian Overseas'
          );

    -- Acq Demo (location based)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag = 'Acq Demo'
          );

    -- Lab Demo (location based, includes STRL)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag = 'Lab Demo'
          );

    -- Wage DMDC (location based, subgroup irrelevant)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag IN ('Wage AF', 'Wage NAF')
          )
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag = 'DMDC'
          );

    -- Wage WASS (location based, subgroup specific -- uses actuals, no payschedule)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.categorysubgroupcode = b.categorysubgroupcode
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag IN ('Wage AF', 'Wage NAF')
          )
      AND finaltable.payplan IN
          (
              SELECT payplan FROM lookup.payplantags WHERE tag = 'WASS'
          );

    -- GFEBS county locations get the GS base-pay equivalent for their payschedule
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE b.amcosversionid = finaltable.amcosversionid
      AND b.gradelevel = finaltable.gradelevel
      AND b.payplan = finaltable.payplan
      AND finaltable.strl = b.strl
      AND b.locationid = -1
      AND finaltable.locationid IN
          (
              SELECT locationid FROM warehouse.location WHERE locationtype = 'GFEBS Country'
          )
      AND finaltable.categorysubgroupcode <> '-1'
      AND b.categorysubgroupcode = '-1'
      AND finaltable.maxrate IS NULL;

    -- ZZ pay plan: min/max from actual costs (no payschedule)
    UPDATE finaltable
    SET minrate = b.amount,
        maxrate = b.amount
    FROM (
             SELECT *
             FROM data.costs
             WHERE payplan = 'ZZ'
                   AND costelementname LIKE '%base%pay%'
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid;

    -- #### aggregate-level min/max for anything not yet set ####

    -- ### SUBGROUP ### subgroup without location (aggregate of paymm, not self)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    strl,
                    categorysubgroupcode
             FROM paymm
             WHERE categorysubgroupcode <> '-1'
             GROUP BY payplan, gradelevel, strl, categorysubgroupcode
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.strl = b.strl
      AND finaltable.categorysubgroupcode = b.categorysubgroupcode
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.locationid = -1;

    -- ### GROUP ### group with location (self-aggregation of finaltable -> sub-SELECT)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    locationid,
                    strl,
                    categorygroupcode
             FROM finaltable
             WHERE categorysubgroupcode <> '-1'
             GROUP BY payplan, gradelevel, locationid, strl, categorygroupcode
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.categorygroupcode = b.categorygroupcode
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.categorysubgroupcode = '-1'
      AND finaltable.categorygroupcode <> '-1';

    -- group without location (self-aggregation of finaltable)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    strl,
                    categorygroupcode
             FROM finaltable
             GROUP BY payplan, gradelevel, strl, categorygroupcode
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.strl = b.strl
      AND finaltable.categorygroupcode = b.categorygroupcode
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.categorygroupcode <> '-1'
      AND finaltable.categorysubgroupcode = '-1'
      AND finaltable.locationid = -1;

    -- #### PAY PLAN #### pp with location (self-aggregation of finaltable)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    locationid,
                    strl
             FROM finaltable
             GROUP BY payplan, gradelevel, locationid, strl
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.categorygroupcode = '-1'
      AND finaltable.locationid <> -1;

    -- pp without location (self-aggregation of finaltable)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    strl
             FROM finaltable
             GROUP BY payplan, gradelevel, strl
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.strl = b.strl
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.locationid = -1;

    -- #### CAREER PROGRAMS #### cp with location (self-aggregation of finaltable)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    locationid,
                    strl,
                    careerprogramnumber
             FROM finaltable
             GROUP BY payplan, gradelevel, locationid, strl, careerprogramnumber
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.strl = b.strl
      AND finaltable.careerprogramnumber = b.careerprogramnumber
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.careerprogramnumber <> '-1'
      AND finaltable.locationid <> -1;

    -- cp without location (self-aggregation of finaltable)
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM (
             SELECT MAX(maxrate) AS maxrate,
                    MIN(minrate) AS minrate,
                    payplan,
                    gradelevel,
                    strl,
                    careerprogramnumber
             FROM finaltable
             GROUP BY payplan, gradelevel, strl, careerprogramnumber
         ) AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.strl = b.strl
      AND finaltable.careerprogramnumber = b.careerprogramnumber
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL
      AND finaltable.careerprogramnumber <> '-1'
      AND finaltable.locationid = -1;

    -- location fill-in-the-blanks: no underlying inventory at a location, so pull
    -- the payschedule for it (from paymm) at the payplan/grade/location level
    UPDATE finaltable
    SET minrate = b.minrate,
        maxrate = b.maxrate
    FROM paymm AS b
    WHERE finaltable.payplan = b.payplan
      AND finaltable.gradelevel = b.gradelevel
      AND finaltable.locationid = b.locationid
      AND finaltable.minrate IS NULL
      AND finaltable.maxrate IS NULL;

    -- Records with no resolvable min/max are not allowed; drop them.
    -- (In the source this DELETE lived inside an @Debug diagnostic block, but it
    --  runs regardless -- the surrounding IF EXISTS is equivalent to this DELETE.)
    DELETE FROM finaltable WHERE minrate IS NULL OR maxrate IS NULL;

    IF NOT p_debug THEN
        DELETE FROM crunch.payscheduleminmax
        WHERE amcosversionid = p_amcosversionid;

        -- NOTE: destination has no careerprogramnumber column, so it is omitted
        -- from the write. appropriation (source APPN, LEFT JOIN -> possibly NULL)
        -- COALESCEd to '-1' to satisfy the NOT NULL DEFAULT '-1' destination column.
        INSERT INTO crunch.payscheduleminmax
            (payplan, categorygroupcode, categorysubgroupcode, locationid, strl,
             gradetype, gradelevel, minrate, maxrate, amcosversionid, appropriation)
        SELECT a.payplan,
               a.categorygroupcode,
               a.categorysubgroupcode,
               a.locationid,
               a.strl,
               a.gradetype,
               a.gradelevel,
               a.minrate,
               a.maxrate,
               a.amcosversionid,
               COALESCE(b.appn, '-1')
        FROM finaltable AS a
            LEFT OUTER JOIN
            (
                SELECT DISTINCT
                       payplan,
                       appn
                FROM lookup.costelement
                WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
                      AND
                      (
                          costelementname LIKE '%base pay%'
                          OR costelementname LIKE '%civ hourly%'
                      )
            ) AS b
                ON a.payplan = b.payplan;
    END IF;

    DROP TABLE IF EXISTS paymm;
    DROP TABLE IF EXISTS finaltable;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CreateTimeInGradeTable  ->  crunch.createtimeingradetable
--
-- Ports AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CreateTimeInGradeTable.sql
-- (Dan Hogan, 10/2/2019) to PostgreSQL LANGUAGE plpgsql.
--
-- Estimates Time in Grade (TIG) by grade level (GL) for each military pay plan.
-- We have no longitudinal personnel data, so TIG is approximated from the
-- inventory frequency table + a median YOS: the frequency table is "un-grouped"
-- into one row per person, the median (50th pct, PERCENTILE_DISC) YOS is taken
-- per pay plan / GL, and TIG is the difference between a GL's median YOS and the
-- median YOS at the next-higher GL, with hand-tuned special cases.
--
-- Faithful-translation notes (see DECISIONS/RISKS in the port report):
--   * The source CURSOR + inner WHILE loop (insert one #tempinv row per unit of
--     inventory) is rewritten set-based as generate_series(1, SUM(inventory)) —
--     cleanly equivalent (WHILE @i<=@inv <=> generate_series(1,@inv) rows).
--   * PERCENTILE_DISC used with an OVER() window in T-SQL is rewritten as an
--     ordered-set aggregate with GROUP BY (PG has no window form) — same result
--     as the source SELECT DISTINCT + partitioned percentile.
--   * The self-join "UPDATE #TIG .. FROM #TIG a JOIN (subquery of #TIG) b" is
--     rewritten with the derived (LEAD) self-scan in FROM and no re-alias of the
--     UPDATE target (PG forbids aliasing the target in FROM).
--   * p_debug = true is a DRY RUN: the DELETE/INSERT into crunch.timeingrade run
--     only under "IF NOT p_debug"; the source @Debug result-set dump is dropped.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.createtimeingradetable(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- row-based (non-frequency) inventory data
    DROP TABLE IF EXISTS tempinv;
    CREATE TEMP TABLE tempinv (
        amcosversionid integer NOT NULL,
        pp             varchar(3) NOT NULL,
        gl             integer NOT NULL,
        yos            integer NOT NULL
    );

    -- Un-group the inventory frequency table into one row per person.
    -- Set-based rewrite of the source cursor + inner WHILE loop: for each
    -- (pp, gl, yos) with SUM(inventory) = N, generate_series(1, N) yields N rows.
    INSERT INTO tempinv (amcosversionid, pp, gl, yos)
    -- data.inventory.gradelevel is varchar (the view unions a text GFEBS branch);
    -- these military pay plans carry numeric grade strings, so cast to integer.
    SELECT p_amcosversionid, g.payplan, g.gradelevel::integer, g.yos
    FROM (
        SELECT payplan,
               gradelevel,
               yos,
               SUM(inventory) AS inventory
        FROM data.inventory
        WHERE payplan IN ('AE', 'AO', 'AWO', 'RE', 'RO', 'RWO', 'NE', 'NO', 'NWO')
          AND yos <> 99
          AND amcosversionid = p_amcosversionid
        GROUP BY payplan, gradelevel, yos
    ) g
    CROSS JOIN generate_series(1, g.inventory) AS s;

    -- table to hold the TIG calculation
    DROP TABLE IF EXISTS tig;
    CREATE TEMP TABLE tig (
        amcosversionid integer NOT NULL,
        pp             varchar(3) NOT NULL,
        gl             integer NOT NULL,
        median         numeric(6, 1) NOT NULL,
        mytig          numeric(6, 1) NULL
    );

    -- median (50th percentile) YOS by pay plan and GL.
    -- Rewritten from the source's PERCENTILE_DISC OVER()+DISTINCT to an
    -- ordered-set aggregate with GROUP BY (equivalent; PG has no window form).
    INSERT INTO tig (amcosversionid, pp, gl, median)
    SELECT amcosversionid,
           pp,
           gl,
           percentile_disc(0.5) WITHIN GROUP (ORDER BY yos)
    FROM tempinv
    GROUP BY amcosversionid, pp, gl;

    -- calculate the TIG: median YOS at next-higher GL minus this GL's median.
    -- Self-join UPDATE rewritten: derived LEAD scan of tig moved into FROM,
    -- target not re-aliased. mytig starts NULL and the source used an INNER
    -- JOIN, so an inner-join UPDATE..FROM is equivalent (unmatched stay NULL).
    UPDATE tig t
    SET mytig = b.mytig
    FROM (
        SELECT amcosversionid,
               pp,
               gl,
               median,
               LEAD(median, 1, 0) OVER (PARTITION BY amcosversionid, pp
                                        ORDER BY amcosversionid, pp, gl)
               - median AS mytig
        FROM tig
    ) b
    WHERE t.amcosversionid = b.amcosversionid
      AND t.pp = b.pp
      AND t.gl = b.gl
      AND t.median = b.median;

    -- special cases -----------------------------------------------------------
    -- AE tend to be E2/E3 by end of year 1: assume TIG .5 each for GL1 & 2
    UPDATE tig
    SET mytig = .5
    WHERE gl IN (1, 2)
      AND pp = 'AE';

    -- AO tend to be O2 after 18 months and O3 after 4 years
    UPDATE tig
    SET mytig = 1.5
    WHERE gl IN (1)
      AND pp = 'AO';
    UPDATE tig
    SET mytig = 4 - 1.5
    WHERE gl IN (2)
      AND pp = 'AO';

    -- max GLs: the math needs a next-higher GL that does not exist.
    -- officers: mandatory retirement age 62 minus assumed commission age 22
    UPDATE tig
    SET mytig = 62 - 22 - median
    WHERE gl = 10
      AND pp = 'AO';
    -- enlisted: assume a 30-year max career
    UPDATE tig
    SET mytig = CASE
                    WHEN median > 30 THEN 30
                    ELSE 30 - median
                END
    WHERE gl = 9
      AND pp = 'AE';

    -- any negative TIG -> uniform -1 (unknown TIG)
    UPDATE tig
    SET mytig = -1
    WHERE mytig < 0;

    -- warrants spend a lot of time in GL1, so just use the median YOS there
    UPDATE tig
    SET mytig = median
    WHERE gl = 1
      AND pp IN ('AWO', 'NWO', 'RWO');

    -- write the result into the crunch table (skipped on dry run)
    IF NOT p_debug THEN
        DELETE FROM crunch.timeingrade
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.timeingrade (amcosversionid, payplan, gradelevel, medianyos, tig)
        SELECT amcosversionid, pp, gl, median, mytig
        FROM tig;
    END IF;

    DROP TABLE IF EXISTS tempinv;
    DROP TABLE IF EXISTS tig;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CrunchInventoryWASS  ->  crunch.crunchinventorywass
--   Converts raw WASS civilian data into the standard inventory format, runs the
--   occupational-series validity checks and the multi-pass location mapping
--   (overseas DoS, locality pay areas incl. RUS, and Federal Wage AF/NAF), then
--   rolls the result up to the location + subgroup level into crunch.inventorywass.
--
-- Faithful structural port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/
-- CrunchInventoryWASS.sql (author Dan Hogan). Source has @AmcosVersionId + @Debug
-- only (no @CrunchTime), so this proc takes no crunchtime.
--
-- Conventions applied:
--   * p_debug = true is a DRY RUN: the source performs its DELETE + INSERT only
--     under "IF @Debug = 0"; guarded here by "IF NOT p_debug". The two "IF EXISTS
--     ... SELECT" interactive diagnostic dumps (missing-location / invalid-subgroup
--     rows) are result-set dumps with no runtime effect and are dropped.
--   * #WASSRaw -> CREATE TEMP TABLE wassraw (DROP IF EXISTS before create + at end).
--   * "UPDATE #WASSRaw ... FROM #WASSRaw a INNER JOIN other ..." rewritten as
--     "UPDATE wassraw t ... FROM other ... WHERE <join>" (PG forbids re-aliasing
--     the UPDATE target in FROM). No self-join of the target existed, so each
--     rewrite simply drops the redundant self-reference and moves its join
--     predicates into WHERE.
--   * ISNULL->COALESCE, string "+"->"||", BIT->boolean, NVARCHAR->varchar,
--     SMALLINT->smallint, [Count] reserved word -> "count".
--   * Case-sensitive schemas: none of the referenced schemas are quoted
--     (load_inventory, lookup, xwalk, warehouse, crunch are all lowercase).
--     "DMDC"/"PaySchedule" are NOT used by this proc.
--   * Divisions spreading a pay total across an inventory/count denominator are
--     wrapped in NULLIF(denominator, 0) (behavior-preserving guard).
--
-- PRESERVED SOURCE QUIRK: #WASSRaw.LocationId is declared NOT NULL and the initial
--   INSERT seeds it with the literal -1 (never NULL). Consequently every location
--   UPDATE guarded by "LocationId IS NULL" (the overseas-DoS pass, the RUS pass,
--   and the final catch-all "SET LocationId = -1 WHERE LocationId IS NULL") can
--   never match and is effectively dead code. This is reproduced verbatim.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchinventorywass(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS wassraw;
    CREATE TEMP TABLE wassraw (
        payplan                         varchar(3)    NOT NULL,
        fundtype                        varchar(3)    NOT NULL,
        occupationalgroupnumber         varchar(4)    NOT NULL,
        occupationalseriesnumber        varchar(4)    NOT NULL,
        isvalidoccupationalseriesnumber boolean       NOT NULL,
        grade                           varchar(3)    NOT NULL,
        step                            varchar(2)    NOT NULL,
        statecode                       varchar(2)    NOT NULL,
        countycode                      varchar(3)    NOT NULL,
        citycode                        varchar(4)    NOT NULL,
        locationid                      integer       NOT NULL,
        locationname                    varchar(150)  NULL,
        averagepay                      numeric(18, 2) NOT NULL,
        inventory                       smallint      NOT NULL,
        amcosversionid                  integer       NOT NULL
    );

    /* we only care about those pay plans where we need actual pay data because we
       don't have a payschedule for them; otherwise DMDC is the far better source */
    INSERT INTO wassraw
        (payplan, fundtype, occupationalgroupnumber, occupationalseriesnumber,
         isvalidoccupationalseriesnumber, grade, step, statecode, countycode,
         citycode, locationid, locationname, averagepay, inventory, amcosversionid)
    SELECT CASE payplan WHEN 'ES' THEN 'SES' ELSE payplan END,
           '-1',
           left(right('0000' || occupationalseriesnumber, 4), 2) || '00',
           right('0000' || occupationalseriesnumber, 4),
           false,
           gradelevel,
           step,
           CASE statecode WHEN 'RQ' THEN '72' ELSE statecode END,
           countycode,
           citycode,
           -1,
           NULL,
           SUM(sal_wag * "count") / NULLIF(SUM("count"), 0),
           SUM("count"),
           amcosversionid
    FROM load_inventory.wass_raw
    WHERE amcosversionid = p_amcosversionid
    GROUP BY payplan, occupationalseriesnumber, gradelevel, step,
             statecode, countycode, citycode, amcosversionid;

    /* White Collar Occupational Series */
    UPDATE wassraw
    SET isvalidoccupationalseriesnumber = true
    WHERE payplan IN ('SES', 'NF')
      AND occupationalseriesnumber IN (
              SELECT occupationalseriesnumber
              FROM lookup.gs_occupationalseries
              WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    /* Craft, Trade, or Labor Occupational Series */
    UPDATE wassraw
    SET isvalidoccupationalseriesnumber = true
    WHERE payplan NOT IN ('SES', 'NF')
      AND occupationalseriesnumber IN (
              SELECT occupationalseriesnumber
              FROM lookup.wage_occupationalseries
              WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    /* Overseas: map civilians to Department of State overseas areas, by DLOC first */
    UPDATE wassraw t
    SET locationid   = d.locationid,
        locationname = d.displayname
    FROM xwalk.dloctodos b
        INNER JOIN lookup.doslocations c
            ON c.locationcode = b.doslocation
        INNER JOIN warehouse.location d
            ON d.sourcesystemcode = c.locationcode
    WHERE b.dloc = t.statecode || t.citycode || t.countycode
      AND t.locationid IS NULL   -- only update locationids we don't already know (dead: seeded -1)
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND d.locationtype = 'Civilian Overseas';

    /* White Collar (Locality Area) non-RUS first */
    UPDATE wassraw t
    SET locationid   = e.locationid,
        locationname = e.displayname
    FROM xwalk.localitypayareatofips c
        INNER JOIN warehouse.location e
            ON e.sourcesystemcode = c.localitycode
    WHERE c.statecode = t.statecode
      AND c.countycode = t.countycode
      AND c.amcosversionid = t.amcosversionid
      AND p_amcosversionid = c.amcosversionid
      AND e.locationtype = 'Locality Pay Area'
      AND t.payplan IN ('GS', 'SES');

    /* now assign RUS */
    UPDATE wassraw t
    SET locationid   = c.locationid,
        locationname = c.displayname
    FROM lookup.fips_zip b
        CROSS JOIN (
            SELECT *
            FROM warehouse.location
            WHERE locationtype = 'Locality Pay Area'
              AND sourcesystemcode = 'RUS'
        ) c
    WHERE t.statecode || t.countycode = b.fipscode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND t.payplan = 'SES'
      AND t.locationid IS NULL;   -- dead: seeded -1

    /* Federal Wage Schedule AF */
    UPDATE wassraw t
    SET locationid   = c.locationid,
        locationname = c.displayname
    FROM xwalk.wageareatofips b
        INNER JOIN warehouse.location c
            ON b.schedulearea = c.sourcesystemcode
    WHERE t.statecode = b.statecode
      AND t.countycode = b.countycode
      AND t.amcosversionid = b.amcosversionid
      AND t.amcosversionid = p_amcosversionid
      AND c.locationtype IN ('Federal Wage System AF', 'Federal Wage System AF Overseas')
      AND t.payplan IN (SELECT right(payplan, 2) FROM lookup.payplantags WHERE tag = 'Wage AF')
      AND b.fundtype = 'AF';

    /* Federal Wage Schedule NAF */
    UPDATE wassraw t
    SET locationid   = c.locationid,
        locationname = c.displayname
    FROM xwalk.wageareatofips b
        INNER JOIN warehouse.location c
            ON b.schedulearea = c.sourcesystemcode
    WHERE t.statecode = b.statecode
      AND t.countycode = b.countycode
      AND t.amcosversionid = b.amcosversionid
      AND t.amcosversionid = p_amcosversionid
      AND c.locationtype IN ('Federal Wage System NAF')
      AND t.payplan IN (SELECT right(payplan, 2) FROM lookup.payplantags WHERE tag = 'Wage NAF')
      AND b.fundtype = 'NAF';

    /* Federal Wage Schedule NAF Overseas
       (source joins on StateCode + AmcosVersionId only -- no CountyCode; preserved) */
    UPDATE wassraw t
    SET locationid   = c.locationid,
        locationname = c.displayname
    FROM xwalk.wageareatofips b
        INNER JOIN warehouse.location c
            ON b.schedulearea = c.sourcesystemcode
    WHERE t.statecode = b.statecode
      AND t.amcosversionid = b.amcosversionid
      AND t.amcosversionid = p_amcosversionid
      AND c.locationtype IN ('Federal Wage System NAF Overseas')
      AND t.payplan IN (SELECT right(payplan, 2) FROM lookup.payplantags WHERE tag = 'Wage NAF')
      AND b.fundtype = 'NAF';

    /* so anything that doesn't have a locationid gets a -1 and is unknown */
    UPDATE wassraw
    SET locationid = -1
    WHERE locationid IS NULL;   -- dead: seeded -1

    IF NOT p_debug THEN
        --#### Delete and Insert
        DELETE FROM crunch.inventorywass
        WHERE amcosversionid = p_amcosversionid;

        --sum up to the location and subgroup level
        INSERT INTO crunch.inventorywass
            (payplan, occupationalgroupnumber, occupationalseriesnumber, gradetype,
             gradelevel, step, locationid, inventory, averagepay, amcosversionid)
        SELECT payplan,
               occupationalgroupnumber,
               occupationalseriesnumber,
               payplan,
               grade,
               step,
               locationid,
               SUM(inventory),
               SUM(averagepay * inventory) / NULLIF(SUM(inventory), 0),
               amcosversionid
        FROM wassraw
        WHERE locationid <> -1
        GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber,
                 grade, step, locationid, amcosversionid;
    END IF;

    DROP TABLE IF EXISTS wassraw;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchinventorydmdc  (source: AMCOS.AMCOS2020_MAR/crunch/Stored
--   Procedures/CrunchInventoryDMDC.sql — Dan Hogan, 2020-01-08)
--
-- Converts raw DMDC inventory (load_inventory.dmdc_raw) into the canonical
-- crunch.inventorydmdc format: cleans grade types/steps, validates and remaps
-- MOS/AOC/WOMOS/occupational-series subgroups, derives group codes, and assigns
-- a warehouse Location id through the full military-MHA / overseas-DoS /
-- white-collar-locality / blue-collar-wage-area cascade. Finally sums to the
-- (location, subgroup) grain and (re)writes crunch.inventorydmdc for the version.
--
-- Faithful structural port. Notes:
--   * No @CrunchTime in the source -> no v_crunchtime / crunchtime column.
--   * p_debug = true is a DRY RUN: the source performs its DELETE/INSERT only
--     under "IF @Debug = 0"; guarded here by "IF NOT p_debug". The "IF @Debug=1"
--     and unconditional "SELECT ..." result-set dumps have no write effect and
--     are dropped.
--   * Every "UPDATE #DMDCRaw ... FROM #DMDCRaw a INNER/LEFT JOIN x b ..." is
--     rewritten to "UPDATE dmdcraw t SET .. FROM x b WHERE <join>" (PG forbids
--     re-aliasing the UPDATE target in FROM). All are inner-join updates whose
--     "a.LocationId IS NULL" guards become plain WHERE predicates.
--   * Case-sensitive schema "PaySchedule" and "DMDC" are quoted; lookup / xwalk /
--     warehouse / data / crunch / load_inventory are lowercase (unquoted).
--   * dmdcraw.gradelevel / .step are varchar (faithful to source NVARCHAR): the
--     final insert casts gradelevel::smallint to match the target column.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchinventorydmdc(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS dmdcraw;
    CREATE TEMP TABLE dmdcraw (
        civtype               varchar(3),
        payplan               varchar(3),
        mygroup               varchar(4),
        categorysubgroup      varchar(4),
        validcategorysubgroup varchar(4),
        gradetype             varchar(2),
        gradelevel            varchar(2),
        step                  varchar(2),
        uic                   char(6),
        uiczipcode            varchar(5),
        uicdrrszipcodestate   varchar(50),
        dutylocationcode      char(9),
        dutystationcity       varchar(200),
        dutystationcounty     varchar(200),
        dutystationstate      varchar(200),
        dutystationcountry    varchar(200),
        dutystationzipcode    varchar(5),
        locationid            integer,
        locationname          varchar(150),
        locationtype          varchar(150),
        payplantype           varchar(100),
        yos                   smallint,
        inventory             integer,
        amcosversionid        integer
    );

    INSERT INTO dmdcraw
        (civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
         dutylocationcode, yos, inventory, amcosversionid)
    SELECT civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
           dutylocationcode, yos, SUM("count"), amcosversionid
    FROM load_inventory.dmdc_raw
    WHERE amcosversionid = p_amcosversionid
    GROUP BY civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
             dutylocationcode, yos, amcosversionid;

    -- 04/18/2022 military grade-level 0 delete: commented out in source (kept out).
    -- 09/17/2025 grade level 0 retained (West Point / ROTC cadets).

    /* For reference, bring in the duty-station identity for the DutyLocationCode */
    UPDATE dmdcraw t
    SET dutystationcity    = ds.city,
        dutystationcounty  = ds.county,
        dutystationstate   = ds.state,
        dutystationcountry = ds.country
    FROM lookup.dutystation ds
    WHERE t.dutylocationcode = ds.dutystationcode;

    /* Fill in missing grade types */
    UPDATE dmdcraw SET gradetype = 'W' WHERE payplan IN ('AWO', 'RWO', 'NWO');
    UPDATE dmdcraw SET gradetype = 'O' WHERE payplan IN ('AO', 'RO', 'NO');
    UPDATE dmdcraw SET gradetype = 'E' WHERE payplan IN ('AE', 'RE', 'NE');

    -- Assign a pay plan type which we will use later
    UPDATE dmdcraw
    SET payplantype = 'AF White Collar'
    WHERE gradetype NOT IN ('E', 'O', 'W')
      AND payplan NOT LIKE 'X%'
      AND payplan NOT IN ('NA', 'NL', 'NS')
      AND payplan NOT IN ('NF')
      AND payplan NOT LIKE 'W%';

    -- CY is a NAF White Collar plan but uses GS locations; treated as AF WC here.
    UPDATE dmdcraw SET payplantype = 'NAF White Collar' WHERE payplan IN ('NF');

    UPDATE dmdcraw
    SET payplantype = 'AF Blue Collar'
    WHERE gradetype NOT IN ('E', 'O', 'W')
      AND (payplan LIKE 'X%' OR payplan LIKE 'W%');

    UPDATE dmdcraw SET payplantype = 'Military' WHERE gradetype IN ('W', 'O', 'E');

    UPDATE dmdcraw
    SET payplantype = 'NAF Blue Collar'
    WHERE gradetype NOT IN ('E', 'O', 'W')
      AND payplan IN ('NA', 'NL', 'NS');

    -- ######################################### Military
    UPDATE dmdcraw
    SET step = '-1'
    WHERE payplan IN ('AWO', 'RWO', 'NWO', 'AO', 'RO', 'NO', 'AE', 'RE', 'NE');

    --#### Process WOMOS Conversions
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE gradetype = 'W'
      AND categorysubgroup IN (
          SELECT womos FROM lookup.womos
          WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    UPDATE dmdcraw t
    SET validcategorysubgroup = b.womosnew
    FROM lookup.womosconversion b
    WHERE t.categorysubgroup = b.womosold
      AND b.amcosversionid = p_amcosversionid
      AND t.gradetype = 'W'
      AND t.gradelevel = b.gradelevel;

    --#### Process MOS Conversions
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE gradetype = 'E'
      AND categorysubgroup IN (
          SELECT mos FROM lookup.mos
          WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    UPDATE dmdcraw t
    SET validcategorysubgroup = b.mosnew
    FROM lookup.mosconversion b
    WHERE t.categorysubgroup = b.mosold
      AND b.amcosversionid = p_amcosversionid
      AND t.gradetype = 'E'
      AND t.gradelevel = b.gradelevel;

    --#### Process AOC Conversions
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE gradetype = 'O'
      AND categorysubgroup IN (
          SELECT aoc FROM lookup.aoc
          WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    UPDATE dmdcraw t
    SET validcategorysubgroup = b.aocnew
    FROM lookup.aocconversion b
    WHERE t.categorysubgroup = b.aocold
      AND b.amcosversionid = p_amcosversionid
      AND t.gradetype = 'O'
      AND t.gradelevel = b.gradelevel;

    /* Convert unknown steps/gradelevels to 99 (universal unknown) */
    UPDATE dmdcraw
    SET step = '99'
    WHERE payplantype IN ('NAF White Collar', 'AF White Collar', 'AF Blue Collar', 'NAF Blue Collar')
      AND step = '42';
    UPDATE dmdcraw
    SET gradelevel = '99'
    WHERE payplantype IN ('NAF White Collar', 'AF White Collar', 'AF Blue Collar', 'NAF Blue Collar')
      AND gradelevel = '42';

    -- ######################################### OPM White Collar
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE payplantype IN ('AF White Collar', 'NAF White Collar')
      AND categorysubgroup IN (
          SELECT occupationalseriesnumber FROM lookup.gs_occupationalseries
          WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    -- CY -> only valid subgroup 1702 (DODI 1400.25-V1407); step meaningless -> -1
    UPDATE dmdcraw
    SET validcategorysubgroup = '1702',
        mygroup = '1700',
        step = '-1'
    WHERE payplan IN ('CY');

    -- ######################################### OPM Blue Collar
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE payplantype IN ('AF Blue Collar', 'NAF Blue Collar')
      AND categorysubgroup IN (
          SELECT occupationalseriesnumber FROM lookup.wage_occupationalseries
          WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    -- these pay plans get a pass since they don't have group/subgroups
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ', mygroup = 'ZZZZ'
    WHERE payplan IN ('ZZ');

    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ', mygroup = 'ZZZZ'
    WHERE categorysubgroup IN ('0000');

    -- Mark all unknown subgroups as the same unknown code
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ'
    WHERE categorysubgroup LIKE 'ZZZ%';

    -- set group codes: military 2 digits, all others 4 digits (last two = '00')
    UPDATE dmdcraw
    SET mygroup = left(validcategorysubgroup, 2)
    WHERE payplantype = 'Military';
    UPDATE dmdcraw
    SET mygroup = left(validcategorysubgroup, 2) || '00'
    WHERE payplantype <> 'Military';

    -- If we have an unidentified subgroup we need to call that out (abort)
    IF EXISTS (
        SELECT 1 FROM dmdcraw
        WHERE validcategorysubgroup IS NULL
           OR validcategorysubgroup = '-1'
           OR mygroup IS NULL
           OR mygroup = '-1'
    ) THEN
        RAISE EXCEPTION 'Invalid group/subgroup codes';
    END IF;

    -- ################## Bring in UIC data as backup
    UPDATE dmdcraw t
    SET uiczipcode = left(b.zip, 5),
        uicdrrszipcodestate = b.state
    FROM lookup.uiclocation b
    WHERE t.uic = b.uic
      AND b.effectivedate = (SELECT max(c.effectivedate) FROM lookup.uiclocation c WHERE c.uic = b.uic);

    -- ################## Location Map FIPS to Zip
    UPDATE dmdcraw t
    SET dutystationzipcode = b.zipcode
    FROM lookup.fips_zip b
    WHERE left(t.dutylocationcode, 2) || right(t.dutylocationcode, 3) = b.fipscode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    --####### Military Location (MHA) — DutyLocationCode first
    UPDATE dmdcraw t
    SET locationid = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM xwalk.ziptomha b
    INNER JOIN warehouse.location c ON b.mha = c.sourcesystemcode
    WHERE t.dutystationzipcode = b.zipcode
      AND p_amcosversionid = b.amcosversionid
      AND c.locationtype = 'CONUS Military Housing Area'
      AND t.payplantype = 'Military';

    -- Use the UIC Zip as backup
    UPDATE dmdcraw t
    SET locationid = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM xwalk.ziptomha b
    INNER JOIN warehouse.location c ON b.mha = c.sourcesystemcode
    WHERE t.uiczipcode = b.zipcode
      AND p_amcosversionid = b.amcosversionid
      AND c.locationtype = 'CONUS Military Housing Area'
      AND t.payplantype = 'Military'
      AND t.locationid IS NULL;

    --##################### Overseas — DoS by DutyLocationCode first
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM xwalk.dloctodos b
    INNER JOIN lookup.doslocations c ON c.locationcode = b.doslocation
    INNER JOIN warehouse.location d ON d.sourcesystemcode = c.locationcode
    WHERE b.dloc = t.dutylocationcode
      AND t.locationid IS NULL
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND t.payplantype <> 'Military'
      AND d.locationtype = 'Civilian Overseas';

    -- map civs to zip next in case the dloc didn't map
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM xwalk.ziptodos b
    INNER JOIN lookup.doslocations c ON c.locationcode = b.doslocation
    INNER JOIN warehouse.location d ON d.sourcesystemcode = c.locationcode
    WHERE b.zipcode = left(t.uiczipcode, 5)
      AND t.locationid IS NULL
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND t.payplantype <> 'Military'
      AND d.locationtype = 'Civilian Overseas';

    --##################### White Collar — Special Pay by DutyLocationCode first
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.specialratetablesbylocation c ON b.fipscode = c.state || c.countycode
    INNER JOIN warehouse.location d ON d.sourcesystemcode = c.locationname
    WHERE t.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND d.locationtype = 'OPM Special Pay Locations'
      AND t.payplantype = 'AF White Collar'
      AND t.payplan IN ('GS', 'GL');

    -- Special Pay locations using UIC
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.specialratetablesbylocation c ON b.fipscode = c.state || c.countycode
    INNER JOIN warehouse.location d ON d.sourcesystemcode = c.locationname
    WHERE t.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND d.locationtype = 'OPM Special Pay Locations'
      AND t.payplantype = 'AF White Collar'
      AND t.payplan IN ('GS', 'GL')
      AND t.locationid IS NULL;

    -- non-RUS next using DutyLocationCode
    UPDATE dmdcraw t
    SET locationid = e.locationid,
        locationname = e.displayname,
        locationtype = e.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.localitypayareatofips c ON b.fipscode = c.statecode || c.countycode
    INNER JOIN "PaySchedule".localitypay d ON c.localitycode = d.localitycode
    INNER JOIN warehouse.location e ON e.sourcesystemcode = d.localitycode
    WHERE t.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND p_amcosversionid = d.amcosversionid
      AND e.locationtype = 'Locality Pay Area'
      AND t.payplantype = 'AF White Collar'
      AND t.locationid IS NULL;

    -- non-RUS for certain US territories
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM (
        SELECT DISTINCT
               z.locationid,
               z.locationtype,
               z.sourcesystemcode,
               z.displayname,
               CASE
                   WHEN z.sourcesystemcode = 'PR'   THEN 'RQ'
                   WHEN z.sourcesystemcode = 'USVI' THEN 'VQ'
                   WHEN z.sourcesystemcode = 'GNM'  THEN 'GQ'
                   ELSE '!!'
               END AS dloc2
        FROM warehouse.location z
        WHERE z.locationtype = 'Locality Pay Area'
    ) b
    WHERE left(t.dutylocationcode, 2) = b.dloc2
      AND t.payplantype = 'AF White Collar'
      AND t.locationid IS NULL;

    -- non-RUS next using UIC
    UPDATE dmdcraw t
    SET locationid = e.locationid,
        locationname = e.displayname,
        locationtype = e.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.localitypayareatofips c ON b.fipscode = c.statecode || c.countycode
    INNER JOIN "PaySchedule".localitypay d ON c.localitycode = d.localitycode
    INNER JOIN warehouse.location e ON e.sourcesystemcode = d.localitycode
    WHERE t.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND p_amcosversionid = d.amcosversionid
      AND e.locationtype = 'Locality Pay Area'
      AND t.payplantype = 'AF White Collar'
      AND t.locationid IS NULL;

    -- now assign RUS (by DutyStationZIPCode)
    UPDATE dmdcraw t
    SET locationid = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM lookup.fips_zip b
    CROSS JOIN (
        SELECT * FROM warehouse.location
        WHERE locationtype = 'Locality Pay Area' AND sourcesystemcode = 'RUS'
    ) c
    WHERE t.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND t.payplantype = 'AF White Collar'
      AND b.state NOT IN ('AA', 'AE', '')
      AND t.locationid IS NULL;

    -- assign RUS for incorrect DutyLocationCode based on UIC state
    UPDATE dmdcraw t
    SET locationid = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM (
        SELECT * FROM warehouse.location
        WHERE locationtype = 'Locality Pay Area' AND sourcesystemcode = 'RUS'
    ) c
    WHERE t.payplantype = 'AF White Collar'
      AND t.uicdrrszipcodestate NOT IN ('AA', 'AE', '')
      AND t.locationid IS NULL;

    --##################### Blue Collar (Federal Wage System AF) — DutyLocationCode zip first
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
    INNER JOIN warehouse.location d ON c.schedulearea = d.sourcesystemcode
    WHERE t.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND c.fundtype = 'AF'
      AND d.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar';

    -- UIC zip next
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
    INNER JOIN warehouse.location d ON c.schedulearea = d.sourcesystemcode
    WHERE t.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND d.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND c.fundtype = 'AF'
      AND t.locationid IS NULL;

    -- Regardless of the UIC's location these pay plans are only for schedule area 124
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND b.sourcesystemcode = '124'
      AND t.payplan IN ('XR', 'XT', 'XU');

    -- non-RUS for certain US territories
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM (
        SELECT DISTINCT
               z.displayname,
               z.sourcesystemcode,
               z.locationtype,
               z.locationid,
               CASE
                   WHEN z.sourcesystemcode = '151' THEN 'RQ'
                   WHEN z.sourcesystemcode = '903' THEN 'VQ'
                   WHEN z.sourcesystemcode = '901' THEN 'GQ'
                   ELSE '!!'
               END AS dloc2
        FROM warehouse.location z
        WHERE z.locationtype = 'Federal Wage System AF'
    ) b
    WHERE left(t.dutylocationcode, 2) = b.dloc2
      AND t.payplantype = 'AF Blue Collar'
      AND t.locationid IS NULL;

    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND b.sourcesystemcode = '151'
      AND t.payplan IN ('WU', 'WR', 'WQ');

    -- special locations for Blue Collar — Guam 969xx -> schedule 901
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND t.dutystationzipcode LIKE '969%'
      AND b.sourcesystemcode = '901';

    -- American Samoa 96799 -> schedule 904
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND t.dutystationzipcode = '96799'
      AND b.sourcesystemcode = '904';

    -- Virgin Islands 008xx -> schedule 903
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND t.dutystationzipcode LIKE '008%'
      AND b.sourcesystemcode = '903';

    -- zip codes not in the fips zip table: map by cutting off the last digit
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM (
        SELECT MIN(fipscode) AS fipscode,
               MIN(left(zipcode, 4)) AS zip4
        FROM lookup.fips_zip
        WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        GROUP BY left(zipcode, 4)
    ) b
    INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
    INNER JOIN warehouse.location d ON c.schedulearea = d.sourcesystemcode
    WHERE left(t.dutystationzipcode, 4) = b.zip4
      AND p_amcosversionid = c.amcosversionid
      AND d.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND c.fundtype = 'AF'
      AND t.locationid IS NULL;

    -- some that even the zip-digit trick doesn't resolve: match on city and state
    UPDATE dmdcraw t
    SET locationid = e.locationid,
        locationname = e.displayname,
        locationtype = e.locationtype
    FROM lookup.uiclocation b
    INNER JOIN (
        SELECT MIN(fipscode) AS fipscode,
               MIN(city) AS city,
               MIN(state) AS state
        FROM lookup.fips_zip
        WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        GROUP BY city, state
    ) c ON b.city = c.city AND b.state = c.state
    INNER JOIN xwalk.wageareatofips d ON c.fipscode = concat(d.statecode, d.countycode)
    INNER JOIN warehouse.location e ON d.schedulearea = e.sourcesystemcode
    WHERE t.dutystationzipcode = b.zip
      AND b.effectivedate = (SELECT max(uic.effectivedate) FROM lookup.uiclocation uic WHERE uic.uic = b.uic)
      AND p_amcosversionid = d.amcosversionid
      AND e.locationtype = 'Federal Wage System AF'
      AND t.payplantype = 'AF Blue Collar'
      AND t.locationid IS NULL;

    --##################### Federal Wage System NAF (Blue + White Collar NAF)
    -- DutyLocationCode zip first
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
    INNER JOIN warehouse.location d ON c.schedulearea = d.sourcesystemcode
    WHERE t.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND c.fundtype = 'NAF'
      AND d.locationtype = 'Federal Wage System NAF'
      AND t.payplantype IN ('NAF Blue Collar', 'NAF White Collar');

    -- non-RUS for certain US territories
    UPDATE dmdcraw t
    SET locationid = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM (
        SELECT DISTINCT
               z.locationid,
               z.sourcesystemcode,
               z.locationtype,
               z.displayname,
               CASE
                   WHEN z.sourcesystemcode = '155' THEN 'RQ'
                   WHEN z.sourcesystemcode = '!!'  THEN 'VQ'
                   WHEN z.sourcesystemcode = '150' THEN 'GQ'
                   ELSE '!!'
               END AS dloc2
        FROM warehouse.location z
        WHERE z.locationtype = 'Federal Wage System NAF'
    ) b
    WHERE left(t.dutylocationcode, 2) = b.dloc2
      AND t.payplantype IN ('NAF Blue Collar', 'NAF White Collar')
      AND t.locationid IS NULL;

    -- UIC zip next
    UPDATE dmdcraw t
    SET locationid = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
    INNER JOIN xwalk.wageareatofips c ON b.fipscode = concat(c.statecode, c.countycode)
    INNER JOIN warehouse.location d ON c.schedulearea = d.sourcesystemcode
    WHERE t.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND c.fundtype = 'NAF'
      AND d.locationtype = 'Federal Wage System NAF'
      AND t.payplantype IN ('NAF Blue Collar', 'NAF White Collar')
      AND t.locationid IS NULL;

    -- what remains for AF White Collar is unknown/overseas: label, no id
    UPDATE dmdcraw
    SET locationname = 'Unknown/Overseas',
        locationid = -1
    WHERE payplantype = 'AF White Collar'
      AND locationid IS NULL;

    -- anything else without a LocationId gets -1 (unknown)
    UPDATE dmdcraw
    SET locationid = -1
    WHERE locationid IS NULL;

    -- any YOS that is not an integer gets an unknown step
    UPDATE dmdcraw
    SET step = '99'
    WHERE step = 'YO';

    -- 03/16/2021 floating plants (XF/XG/XH) with no local wage schedule: resolve
    -- to another schedule in the same wage area that has an active payschedule.
    -- Source is a multi-LEFT-JOIN update keyed off #DMDCRaw; rewritten with the
    -- target out of FROM. The "own payschedule" LEFT JOIN + "c.LocationId IS NULL"
    -- anti-condition becomes NOT EXISTS; the alternate-schedule LEFT JOIN +
    -- "d.LocationId IS NOT NULL" is an inner join (b needed for d's wage-area keys).
    WITH payschedulecte AS (
        SELECT ps.gradelevel,
               ps.amcosversionid,
               ps.locationid,
               ps.payplan,
               ps.step,
               wa.wagearea,
               wa.schedulearea
        FROM data.payschedules ps
        LEFT OUTER JOIN warehouse.location loc ON ps.locationid = loc.locationid
        LEFT OUTER JOIN lookup.wagearea wa ON loc.sourcesystemcode = wa.schedulearea
        WHERE loc.locationtype = 'Federal Wage System AF'
          AND wa.fundtype = 'AF'
          AND ps.payplan IN ('XF', 'XG', 'XH')
    )
    UPDATE dmdcraw t
    SET locationid = d.locationid
    FROM (
        SELECT loc.locationid, wa.wagearea, wa.schedulearea
        FROM warehouse.location loc
        INNER JOIN lookup.wagearea wa
            ON wa.schedulearea = loc.sourcesystemcode
           AND wa.fundtype = 'AF'
           AND loc.locationtype = 'Federal Wage System AF'
    ) b
    INNER JOIN payschedulecte d
        ON b.wagearea = d.wagearea
       AND b.schedulearea <> d.schedulearea
       AND right(b.schedulearea, 2) = right(d.schedulearea, 2)
    WHERE t.locationid = b.locationid
      AND t.gradelevel = d.gradelevel
      AND t.amcosversionid = d.amcosversionid
      AND t.payplan = d.payplan
      AND t.payplan IN ('XF', 'XG', 'XH')
      AND d.locationid IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM payschedulecte c
          WHERE t.gradelevel = c.gradelevel
            AND t.amcosversionid = c.amcosversionid
            AND t.locationid = c.locationid
            AND t.payplan = c.payplan
            AND t.step = c.step
      );

    IF NOT p_debug THEN
        --#### Delete and Insert
        DELETE FROM crunch.inventorydmdc
        WHERE amcosversionid = p_amcosversionid;

        -- sum up to the location and subgroup level
        INSERT INTO crunch.inventorydmdc
            (civtype, payplan, categorygroup, categorysubgroup, gradetype,
             gradelevel, step, locationid, yos, inventory, amcosversionid)
        SELECT civtype,
               payplan,
               mygroup,
               validcategorysubgroup,
               gradetype,
               gradelevel::smallint,
               step,
               locationid,
               yos,
               SUM(inventory),
               amcosversionid
        FROM dmdcraw
        GROUP BY civtype, payplan, mygroup, validcategorysubgroup, gradetype,
                 gradelevel, step, locationid, yos, amcosversionid;

        -- ensure the Chief of the Army Reserve (RO GL 9) exists; else carry
        -- forward from last year (version - 100)
        IF NOT EXISTS (
            SELECT 1 FROM crunch.inventorydmdc
            WHERE payplan = 'RO' AND gradelevel = 9 AND amcosversionid = p_amcosversionid
        ) THEN
            INSERT INTO crunch.inventorydmdc
                (civtype, payplan, categorygroup, categorysubgroup, gradetype,
                 gradelevel, step, locationid, yos, inventory, amcosversionid)
            SELECT civtype, payplan, categorygroup, categorysubgroup, gradetype,
                   gradelevel, step, locationid, yos, inventory, p_amcosversionid
            FROM crunch.inventorydmdc
            WHERE payplan = 'RO' AND gradelevel = 9 AND amcosversionid = p_amcosversionid - 100;
        END IF;
    END IF;

    DROP TABLE IF EXISTS dmdcraw;
END;
$$;

------------------------------------------------------------------------------
-- Cost-crunch PHASE 2 procedure — crunch.crunchdmdcvantageinventory.
--
-- Ports AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchDMDCVantageInventory.sql
-- (the newer "Vantage" inventory-processing variant) to PostgreSQL. Loads raw DMDC +
-- Vantage staged inventory into a working temp table, normalizes grade types / subgroups /
-- pay-plan codes, resolves each record to a warehouse.location, then writes the web-facing
-- crunch.inventoryprocessed table.
--
-- Faithful-translation conventions (see the 006d Phase-1 header):
--   * p_debug = true is a DRY RUN: the source performs its final DELETE/INSERT only under
--     "IF @Debug = 0"; guarded here by "IF NOT p_debug". The "IF @Debug = 1" branch and the
--     bare interactive SELECT result-set dumps are dropped (no runtime effect).
--   * #DMDCRaw / #milsubgroups -> CREATE TEMP TABLE (DROP IF EXISTS first + at proc end).
--   * "UPDATE #DMDCRaw ... FROM #DMDCRaw a JOIN other b ON .." -> "UPDATE dmdcraw SET ..
--     FROM other b WHERE <join>" (PG forbids re-aliasing the UPDATE target in FROM). None of
--     the source UPDATE..FROMs self-join #DMDCRaw, so each is a straight target/other rewrite:
--     the target's join predicates move into the WHERE, other-table joins stay in FROM.
--   * Case-sensitive schemas quoted exactly: "PaySchedule", "POS". Lowercase schemas as-is.
--   * The source stores GradeLevel/Step as nvarchar(2) but compares them numerically (T-SQL
--     implicit int conversion). Where a numeric comparison is intended (<=0, >5, =9, and joins
--     to smallint/int keys) the varchar temp column is cast ::integer to preserve semantics.
--   * ISNULL->COALESCE, LEN->length, LEFT/RIGHT->left/right, string '+'->'||', BIT->boolean.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchdmdcvantageinventory(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS dmdcraw;
    CREATE TEMP TABLE dmdcraw (
        civtype               varchar(3),
        payplan               varchar(3),
        mygroup               varchar(4),
        categorysubgroup      varchar(4),
        validcategorysubgroup varchar(4),
        gradetype             varchar(2),
        originalgradetype     varchar(2),
        originalpayplan       varchar(3),
        gradelevel            varchar(2),
        step                  varchar(2),
        uic                   varchar(20),
        uiczipcode            varchar(5),
        uicdrrszipcodestate   varchar(50),
        dutylocationcode      varchar(9),
        dutystationcity       varchar(200),
        dutystationcounty     varchar(200),
        dutystationstate      varchar(200),
        dutystationcountry    varchar(200),
        dutystationzipcode    varchar(5),
        locationid            integer,
        locationname          varchar(150),
        locationtype          varchar(150),
        payplantype           varchar(100),
        yos                   smallint,
        inventory             integer,   -- source #DMDCRaw is SMALLINT; widened to integer to
                                         -- avoid SUM overflow (behavior-preserving safeguard)
        amcosversionid        integer
    );

    -- civilians (everything that is not a military pay plan) come from DMDC_Raw
    INSERT INTO dmdcraw
        (civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
         dutylocationcode, yos, inventory, amcosversionid)
    SELECT civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
           dutylocationcode, yos, SUM("count"), amcosversionid
    FROM load_inventory.dmdc_raw
    WHERE amcosversionid = p_amcosversionid
      AND payplan NOT IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO')
    GROUP BY civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
             dutylocationcode, yos, amcosversionid;

    -- prototype: bring in Vantage staged data for the military pay plans
    INSERT INTO dmdcraw
        (civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
         dutylocationcode, yos, inventory, amcosversionid)
    SELECT 'MIL' AS civtype, payplan, categorysubgroup, gradetype, gradelevel, step, uic,
           dutylocationcode, yos, "count", amcosversionid
    FROM load_inventory.vantage_staged
    WHERE amcosversionid = p_amcosversionid;

    -- military grade level 0s coming from DMDC make no sense, so remove them
    DELETE FROM dmdcraw
    WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'military')
      AND gradelevel::integer <= 0;

    /* reference the duty-station identity for the DutyLocationCode */
    UPDATE dmdcraw
    SET dutystationcity    = dutystation.city,
        dutystationcounty  = dutystation.county,
        dutystationstate   = dutystation.state,
        dutystationcountry = dutystation.country
    FROM lookup.dutystation dutystation
    WHERE dmdcraw.dutylocationcode = dutystation.dutystationcode;

    /* fill in missing grade types */
    UPDATE dmdcraw SET gradetype = 'W' WHERE payplan IN ('AWO', 'RWO', 'NWO');
    UPDATE dmdcraw SET gradetype = 'O' WHERE payplan IN ('AO', 'RO', 'NO');
    UPDATE dmdcraw SET gradetype = 'E' WHERE payplan IN ('AE', 'RE', 'NE');

    -- assign a pay plan type which we will use later
    UPDATE dmdcraw
    SET payplantype = 'AF White Collar'
    WHERE gradetype NOT IN ('E', 'O', 'W')
      AND payplan NOT LIKE 'X%'
      AND payplan NOT IN ('NA', 'NL', 'NS')
      AND payplan NOT IN ('NF')
      AND payplan NOT LIKE 'W%';

    -- CY is technically NAF White Collar but uses GS locations, so treat as one
    UPDATE dmdcraw SET payplantype = 'NAF White Collar' WHERE payplan IN ('NF');

    UPDATE dmdcraw
    SET payplantype = 'AF Blue Collar'
    WHERE gradetype NOT IN ('E', 'O', 'W')
      AND (payplan LIKE 'X%' OR payplan LIKE 'W%');

    UPDATE dmdcraw SET payplantype = 'Military' WHERE gradetype IN ('W', 'O', 'E');

    UPDATE dmdcraw
    SET payplantype = 'NAF Blue Collar'
    WHERE gradetype NOT IN ('E', 'O', 'W')
      AND payplan IN ('NA', 'NL', 'NS');

    -- ######################################### Military
    UPDATE dmdcraw
    SET step = '-1'
    WHERE payplan IN ('AWO', 'RWO', 'NWO', 'AO', 'RO', 'NO', 'AE', 'RE', 'NE');

    DROP TABLE IF EXISTS milsubgroups;
    CREATE TEMP TABLE milsubgroups (
        subgroup  varchar(4),
        gradetype varchar(3)
    );
    INSERT INTO milsubgroups
    SELECT mos, 'E' AS gradetype
    FROM lookup.mos
    WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
    UNION
    SELECT aoc, 'O' AS gradetype
    FROM lookup.aoc
    WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
    UNION
    SELECT womos, 'W' AS gradetype
    FROM lookup.womos
    WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend;

    -- save the original values before we start changing things
    UPDATE dmdcraw SET originalpayplan   = payplan;
    UPDATE dmdcraw SET originalgradetype = gradetype;

    -- Vantage has 4-digit subgroups that are clearly warrants; fix that
    UPDATE dmdcraw
    SET gradetype = 'W',
        payplan   = left(payplan, 1) || 'WO'
    WHERE length(categorysubgroup) = 4
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- try swapping O to E and check whether that matches a known subgroup
    UPDATE dmdcraw
    SET gradetype = 'E'
    WHERE gradetype = 'O'
      AND gradetype || categorysubgroup NOT IN
          (SELECT gradetype || subgroup FROM milsubgroups WHERE gradetype = 'O')
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    UPDATE dmdcraw
    SET gradetype = 'O'
    WHERE gradetype = 'E'
      AND gradetype || categorysubgroup NOT IN
          (SELECT gradetype || subgroup FROM milsubgroups WHERE gradetype = 'E')
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- two-digit subgroups that come in as warrants
    UPDATE dmdcraw
    SET gradetype = 'O'
    WHERE gradetype = 'W'
      AND length(categorysubgroup) = 3
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- try still-unmatched original warrants as enlisted
    UPDATE dmdcraw
    SET gradetype = 'E'
    WHERE originalgradetype = 'W'
      AND gradetype = 'O'
      AND length(categorysubgroup) = 3
      AND gradetype || categorysubgroup NOT IN
          (SELECT gradetype || subgroup FROM milsubgroups WHERE gradetype = 'O')
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- return still-unmatched records to their original grade type
    UPDATE dmdcraw
    SET gradetype = originalgradetype
    WHERE gradetype || categorysubgroup NOT IN
          (SELECT gradetype || subgroup FROM milsubgroups)
      AND (
              (originalgradetype = 'O' AND gradetype = 'E')
           OR (originalgradetype = 'E' AND gradetype = 'O')
          )
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- reset pay plans now that we've made grade-type adjustments
    UPDATE dmdcraw
    SET payplan = left(payplan, 1) || gradetype
    WHERE gradetype IN ('O', 'E')
      AND payplan IN ('AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO');

    -- #### Process WOMOS Conversions
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE gradetype = 'W'
      AND categorysubgroup IN
          (SELECT womos FROM lookup.womos
           WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    UPDATE dmdcraw
    SET validcategorysubgroup = b.womosnew
    FROM lookup.womosconversion b
    WHERE dmdcraw.categorysubgroup = b.womosold
      AND b.amcosversionid = p_amcosversionid
      AND dmdcraw.gradetype = 'W'
      AND dmdcraw.gradelevel::integer = b.gradelevel;

    -- #### Process MOS Conversions
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE gradetype = 'E'
      AND categorysubgroup IN
          (SELECT mos FROM lookup.mos
           WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    UPDATE dmdcraw
    SET validcategorysubgroup = b.mosnew
    FROM lookup.mosconversion b
    WHERE dmdcraw.categorysubgroup = b.mosold
      AND b.amcosversionid = p_amcosversionid
      AND dmdcraw.gradetype = 'E'
      AND dmdcraw.gradelevel::integer = b.gradelevel
      AND dmdcraw.validcategorysubgroup IS NULL;

    -- try to match enlisted as officer
    UPDATE dmdcraw
    SET validcategorysubgroup = b.aocnew,
        gradetype = 'O',
        payplan   = left(dmdcraw.payplan, 1) || 'O'
    FROM lookup.aocconversion b
    WHERE dmdcraw.categorysubgroup = b.aocold
      AND b.amcosversionid = p_amcosversionid
      AND dmdcraw.gradetype = 'E'
      AND dmdcraw.gradelevel::integer = b.gradelevel
      AND dmdcraw.validcategorysubgroup IS NULL;

    -- #### Process AOC Conversions
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE gradetype = 'O'
      AND categorysubgroup IN
          (SELECT aoc FROM lookup.aoc
           WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    UPDATE dmdcraw
    SET validcategorysubgroup = b.aocnew
    FROM lookup.aocconversion b
    WHERE dmdcraw.categorysubgroup = b.aocold
      AND b.amcosversionid = p_amcosversionid
      AND dmdcraw.gradetype = 'O'
      AND dmdcraw.gradelevel::integer = b.gradelevel;

    -- try to match officer as enlisted
    UPDATE dmdcraw
    SET validcategorysubgroup = b.mosnew,
        gradetype = 'E',
        payplan   = left(dmdcraw.payplan, 1) || 'E'
    FROM lookup.mosconversion b
    WHERE dmdcraw.categorysubgroup = b.mosold
      AND b.amcosversionid = p_amcosversionid
      AND dmdcraw.gradetype = 'O'
      AND dmdcraw.gradelevel::integer = b.gradelevel
      AND dmdcraw.validcategorysubgroup IS NULL;

    -- warrants above GL5 cannot exist, so kill those off
    DELETE FROM dmdcraw
    WHERE gradelevel::integer > 5
      AND gradetype = 'W';

    -- anything not in the G1 master file (POS.711) is marked unknown
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ'
    WHERE gradetype = 'E'
      AND categorysubgroup NOT IN
          (SELECT left("mos-aoc", 3) FROM "POS"."711" WHERE "rec-type" = 'E');
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ'
    WHERE gradetype = 'O'
      AND categorysubgroup NOT IN
          (SELECT left("mos-aoc", 3) FROM "POS"."711" WHERE "rec-type" = 'O');
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ'
    WHERE gradetype = 'W'
      AND categorysubgroup NOT IN
          (SELECT left("mos-aoc", 4) FROM "POS"."711" WHERE "rec-type" = 'W');

    /* convert unknown steps / grade levels to 99 (universal unknown) */
    UPDATE dmdcraw
    SET step = '99'
    WHERE payplantype IN ('NAF White Collar', 'AF White Collar', 'AF Blue Collar', 'NAF Blue Collar')
      AND step = '42';
    UPDATE dmdcraw
    SET gradelevel = '99'
    WHERE payplantype IN ('NAF White Collar', 'AF White Collar', 'AF Blue Collar', 'NAF Blue Collar')
      AND gradelevel = '42';

    -- ######################################### OPM White Collar
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE payplantype IN ('AF White Collar', 'NAF White Collar')
      AND categorysubgroup IN
          (SELECT occupationalseriesnumber FROM lookup.gs_occupationalseries
           WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    -- CY: per DODI 1400.25-V1407 the only valid subgroup is 1702
    UPDATE dmdcraw
    SET validcategorysubgroup = '1702',
        mygroup = '1700',
        step = '-1'
    WHERE payplan IN ('CY');

    -- ######################################### OPM Blue Collar
    UPDATE dmdcraw
    SET validcategorysubgroup = categorysubgroup
    WHERE payplantype IN ('AF Blue Collar', 'NAF Blue Collar')
      AND categorysubgroup IN
          (SELECT occupationalseriesnumber FROM lookup.wage_occupationalseries
           WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend);

    -- ZZ pay plan gets a pass since it has no group/subgroups
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ', mygroup = 'ZZZZ'
    WHERE payplan IN ('ZZ');

    -- 0000 subgroup gets a pass as well
    UPDATE dmdcraw
    SET validcategorysubgroup = 'ZZZZ', mygroup = 'ZZZZ'
    WHERE categorysubgroup IN ('0000');

    -- mark all unknown subgroups with the same unknown code
    UPDATE dmdcraw SET validcategorysubgroup = 'ZZZZ' WHERE categorysubgroup LIKE 'ZZZ%';
    UPDATE dmdcraw SET validcategorysubgroup = 'ZZZZ' WHERE categorysubgroup LIKE '9999';

    -- set our group codes: military groups are 2 digits, all others 4 digits ending in 00
    UPDATE dmdcraw
    SET mygroup = left(validcategorysubgroup, 2)
    WHERE payplantype = 'Military';
    UPDATE dmdcraw
    SET mygroup = left(validcategorysubgroup, 2) || '00'
    WHERE payplantype <> 'Military';

    -- an unidentified group/subgroup is not allowed; abort the crunch
    IF EXISTS (
        SELECT 1 FROM dmdcraw
        WHERE validcategorysubgroup IS NULL
           OR validcategorysubgroup = '-1'
           OR mygroup IS NULL
           OR mygroup = '-1'
    ) THEN
        RAISE EXCEPTION 'Invalid group/subgroup codes';
    END IF;

    -- ################## Bring in UIC data as backup
    UPDATE dmdcraw
    SET uiczipcode          = left(b.zip, 5),
        uicdrrszipcodestate = b.drrszipcdstate
    FROM lookup.uiclocation b
    WHERE dmdcraw.uic = b.uic;

    -- handle derivative UICs by matching on left 4 (goes up to AA level)
    UPDATE dmdcraw
    SET uiczipcode          = left(b.zip, 5),
        uicdrrszipcodestate = b.drrszipcdstate
    FROM lookup.uiclocation b
    WHERE left(dmdcraw.uic, 4) = left(b.uic, 4)
      AND dmdcraw.uiczipcode IS NULL;

    /* bring in the zip code from the FIPS code derived from DutyLocationCode */
    UPDATE dmdcraw
    SET dutystationzipcode = b.zipcode
    FROM lookup.fips_zip b
    WHERE left(dmdcraw.dutylocationcode, 2) || right(dmdcraw.dutylocationcode, 3) = b.fipscode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- ####### Military Location (MHA) — DutyLocationCode-derived zip first
    UPDATE dmdcraw
    SET locationid   = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM xwalk.ziptomha b
        INNER JOIN warehouse.location c ON b.mha = c.sourcesystemcode
    WHERE dmdcraw.dutystationzipcode = b.zipcode
      AND p_amcosversionid = b.amcosversionid
      AND c.locationtype = 'CONUS Military Housing Area'
      AND dmdcraw.payplantype = 'Military';

    -- use the UIC zip as backup
    UPDATE dmdcraw
    SET locationid   = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM xwalk.ziptomha b
        INNER JOIN warehouse.location c ON b.mha = c.sourcesystemcode
    WHERE dmdcraw.uiczipcode = b.zipcode
      AND p_amcosversionid = b.amcosversionid
      AND c.locationtype = 'CONUS Military Housing Area'
      AND dmdcraw.payplantype = 'Military'
      AND dmdcraw.locationid IS NULL;

    -- ##################### Overseas — map civilians to DoS areas, DutyLocationCode first
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM xwalk.dloctodos b
        INNER JOIN lookup.doslocations c ON c.locationcode = b.doslocation
        INNER JOIN warehouse.location d  ON d.sourcesystemcode = c.locationcode
    WHERE b.dloc = dmdcraw.dutylocationcode
      AND dmdcraw.locationid IS NULL
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND dmdcraw.payplantype <> 'Military'
      AND d.locationtype = 'Civilian Overseas';

    -- map civs to zip next in case the dloc didn't map
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM xwalk.ziptodos b
        INNER JOIN lookup.doslocations c ON c.locationcode = b.doslocation
        INNER JOIN warehouse.location d  ON d.sourcesystemcode = c.locationcode
    WHERE b.zipcode = left(dmdcraw.uiczipcode, 5)
      AND dmdcraw.locationid IS NULL
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND dmdcraw.payplantype <> 'Military'
      AND d.locationtype = 'Civilian Overseas';

    /* White Collar — Special Pay locations first using DutyLocationCode-derived zip */
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.specialratetablesbylocation c ON b.fipscode = c.state || c.countycode
        INNER JOIN warehouse.location d ON d.sourcesystemcode = c.locationname
    WHERE dmdcraw.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND d.locationtype = 'OPM Special Pay Locations'
      AND dmdcraw.payplantype = 'AF White Collar'
      AND dmdcraw.payplan IN ('GS', 'GL');

    /* Special Pay locations using UIC zip */
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.specialratetablesbylocation c ON b.fipscode = c.state || c.countycode
        INNER JOIN warehouse.location d ON d.sourcesystemcode = c.locationname
    WHERE dmdcraw.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid = c.amcosversionid
      AND d.locationtype = 'OPM Special Pay Locations'
      AND dmdcraw.payplantype = 'AF White Collar'
      AND dmdcraw.payplan IN ('GS', 'GL')
      AND dmdcraw.locationid IS NULL;

    /* Non-RUS locality next using DutyLocationCode-derived zip */
    UPDATE dmdcraw
    SET locationid   = e.locationid,
        locationname = e.displayname,
        locationtype = e.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.localitypayareatofips c ON b.fipscode = c.statecode || c.countycode
        INNER JOIN "PaySchedule".localitypay d   ON c.localitycode = d.localitycode
        INNER JOIN warehouse.location e          ON e.sourcesystemcode = d.localitycode
    WHERE dmdcraw.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND p_amcosversionid = d.amcosversionid
      AND e.locationtype = 'Locality Pay Area'
      AND dmdcraw.payplantype = 'AF White Collar'
      AND dmdcraw.locationid IS NULL;

    -- non-RUS for certain US territories (DutyLocationCode prefix)
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM (
        SELECT DISTINCT
               z.locationid,
               z.locationtype,
               z.sourcesystemcode,
               z.displayname,
               CASE
                   WHEN z.sourcesystemcode = 'PR'   THEN 'RQ'
                   WHEN z.sourcesystemcode = 'USVI' THEN 'VQ'
                   WHEN z.sourcesystemcode = 'GNM'  THEN 'GQ'
                   ELSE '!!'
               END AS dloc2
        FROM warehouse.location z
        WHERE z.locationtype = 'Locality Pay Area'
    ) b
    WHERE left(dmdcraw.dutylocationcode, 2) = b.dloc2
      AND dmdcraw.payplantype = 'AF White Collar'
      AND dmdcraw.locationid IS NULL;

    -- non-RUS locality next using UIC zip
    UPDATE dmdcraw
    SET locationid   = e.locationid,
        locationname = e.displayname,
        locationtype = e.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.localitypayareatofips c ON b.fipscode = c.statecode || c.countycode
        INNER JOIN "PaySchedule".localitypay d   ON c.localitycode = d.localitycode
        INNER JOIN warehouse.location e          ON e.sourcesystemcode = d.localitycode
    WHERE dmdcraw.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND p_amcosversionid = d.amcosversionid
      AND e.locationtype = 'Locality Pay Area'
      AND dmdcraw.payplantype = 'AF White Collar'
      AND dmdcraw.locationid IS NULL;

    -- now assign RUS (rest of US) by DutyLocationCode-derived zip
    UPDATE dmdcraw
    SET locationid   = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM lookup.fips_zip b
        CROSS JOIN (
            SELECT * FROM warehouse.location
            WHERE locationtype = 'Locality Pay Area' AND sourcesystemcode = 'RUS'
        ) c
    WHERE dmdcraw.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND dmdcraw.payplantype = 'AF White Collar'
      AND b.state NOT IN ('AA', 'AE', '')
      AND dmdcraw.locationid IS NULL;

    -- assign RUS for incorrect DutyLocationCode based on UIC DRRS zip state
    UPDATE dmdcraw
    SET locationid   = c.locationid,
        locationname = c.displayname,
        locationtype = c.locationtype
    FROM (
        SELECT * FROM warehouse.location
        WHERE locationtype = 'Locality Pay Area' AND sourcesystemcode = 'RUS'
    ) c
    WHERE dmdcraw.payplantype = 'AF White Collar'
      AND dmdcraw.uicdrrszipcodestate NOT IN ('AA', 'AE', '')
      AND dmdcraw.locationid IS NULL;

    /* Appropriated Fund (AF) Wage schedules — DutyLocationCode State+County to FIPS */
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM xwalk.fips_wagearea b
        INNER JOIN warehouse.location d ON b.wage_schedule = d.sourcesystemcode
    WHERE left(dmdcraw.dutylocationcode, 2) || right(dmdcraw.dutylocationcode, 3) = b.fips
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND b.fundtype = 'AF'
      AND d.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar';

    /* UIC zip next */
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.fips_wagearea c ON b.fipscode = c.fips
        INNER JOIN warehouse.location d  ON c.wage_schedule = d.sourcesystemcode
    WHERE dmdcraw.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND d.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND c.fundtype = 'AF'
      AND dmdcraw.locationid IS NULL;

    -- regardless of the UIC location, these pay plans are only for schedule area 124
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND b.sourcesystemcode = '124'
      AND dmdcraw.payplan IN ('XR', 'XT', 'XU');

    -- non-RUS for certain US territories (AF Wage Schedule)
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM (
        SELECT DISTINCT
               z.displayname,
               z.sourcesystemcode,
               z.locationtype,
               z.locationid,
               CASE
                   WHEN z.sourcesystemcode = '151' THEN 'RQ'
                   WHEN z.sourcesystemcode = '903' THEN 'VQ'
                   WHEN z.sourcesystemcode = '901' THEN 'GQ'
                   ELSE '!!'
               END AS dloc2
        FROM warehouse.location z
        WHERE z.locationtype = 'AF Wage Schedule'
    ) b
    WHERE left(dmdcraw.dutylocationcode, 2) = b.dloc2
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND dmdcraw.locationid IS NULL;

    -- regardless of the UIC location, these pay plans are only for schedule area 151
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND b.sourcesystemcode = '151'
      AND dmdcraw.payplan IN ('WU', 'WR', 'WQ');

    -- special locations for Blue Collar: Guam 969xx -> schedule 901
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND dmdcraw.dutystationzipcode LIKE '969%'
      AND b.sourcesystemcode = '901';

    -- American Samoa 96799 -> schedule 904
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND dmdcraw.dutystationzipcode = '96799'
      AND b.sourcesystemcode = '904';

    -- Virgin Islands 008xx -> schedule 903
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location b
    WHERE b.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND dmdcraw.dutystationzipcode LIKE '008%'
      AND b.sourcesystemcode = '903';

    -- zip codes not in the FIPS zip table: map by cutting off the last digit
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM (
        SELECT MIN(fipscode) AS fipscode,
               MIN(left(zipcode, 4)) AS zip4
        FROM lookup.fips_zip
        WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        GROUP BY left(zipcode, 4)
    ) b
        INNER JOIN xwalk.fips_wagearea c ON b.fipscode = c.fips
        INNER JOIN warehouse.location d  ON c.wage_schedule = d.sourcesystemcode
    WHERE left(dmdcraw.dutystationzipcode, 4) = b.zip4
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND d.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND c.fundtype = 'AF'
      AND dmdcraw.locationid IS NULL;

    -- last resort: match on city and state
    UPDATE dmdcraw
    SET locationid   = e.locationid,
        locationname = e.displayname,
        locationtype = e.locationtype
    FROM lookup.uiclocation b
        INNER JOIN (
            SELECT MIN(fipscode) AS fipscode,
                   MIN(city) AS city,
                   MIN(state) AS state
            FROM lookup.fips_zip
            WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
            GROUP BY city, state
        ) c ON b.city = c.city AND b.state = c.state
        INNER JOIN xwalk.fips_wagearea d ON c.fipscode = d.fips
        INNER JOIN warehouse.location e  ON d.wage_schedule = e.sourcesystemcode
    WHERE dmdcraw.dutystationzipcode = b.zip
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN d.amcosversionidstart AND d.amcosversionidend
      AND e.locationtype = 'AF Wage Schedule'
      AND dmdcraw.payplantype = 'AF Blue Collar'
      AND dmdcraw.locationid IS NULL;

    -- ##################### NAF Blue/White Collar (NAF Wage Schedule) — DutyLocationCode zip first
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.fips_wagearea c ON b.fipscode = c.fips
        INNER JOIN warehouse.location d  ON c.wage_schedule = d.sourcesystemcode
    WHERE dmdcraw.dutystationzipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND c.fundtype = 'NAF'
      AND d.locationtype = 'NAF Wage Schedule'
      AND dmdcraw.payplantype IN ('NAF Blue Collar', 'NAF White Collar');

    -- non-RUS for certain US territories (NAF Wage Schedule)
    UPDATE dmdcraw
    SET locationid   = b.locationid,
        locationname = b.displayname,
        locationtype = b.locationtype
    FROM (
        SELECT DISTINCT
               z.locationid,
               z.sourcesystemcode,
               z.locationtype,
               z.displayname,
               CASE
                   WHEN z.sourcesystemcode = '155' THEN 'RQ'
                   WHEN z.sourcesystemcode = '!!'  THEN 'VQ'
                   WHEN z.sourcesystemcode = '150' THEN 'GQ'
                   ELSE '!!'
               END AS dloc2
        FROM warehouse.location z
        WHERE z.locationtype = 'NAF Wage Schedule'
    ) b
    WHERE left(dmdcraw.dutylocationcode, 2) = b.dloc2
      AND dmdcraw.payplantype IN ('NAF Blue Collar', 'NAF White Collar')
      AND dmdcraw.locationid IS NULL;

    -- UIC zip next
    UPDATE dmdcraw
    SET locationid   = d.locationid,
        locationname = d.displayname,
        locationtype = d.locationtype
    FROM lookup.fips_zip b
        INNER JOIN xwalk.fips_wagearea c ON b.fipscode = c.fips
        INNER JOIN warehouse.location d  ON c.wage_schedule = d.sourcesystemcode
    WHERE dmdcraw.uiczipcode = b.zipcode
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND p_amcosversionid BETWEEN c.amcosversionidstart AND c.amcosversionidend
      AND c.fundtype = 'NAF'
      AND d.locationtype = 'NAF Wage Schedule'
      AND dmdcraw.payplantype IN ('NAF Blue Collar', 'NAF White Collar')
      AND dmdcraw.locationid IS NULL;

    -- remaining AF White Collar with no id is unknown/overseas (label, no id)
    UPDATE dmdcraw
    SET locationname = 'Unknown/Overseas',
        locationid   = -1
    WHERE payplantype = 'AF White Collar'
      AND locationid IS NULL;

    -- anything still without a LocationId gets -1 (unknown)
    UPDATE dmdcraw SET locationid = -1 WHERE locationid IS NULL;

    -- any non-integer YOS gets an unknown step
    UPDATE dmdcraw SET step = '99' WHERE step = 'YO';

    -- any active YOS greater than 50 gets 99
    UPDATE dmdcraw
    SET yos = 99
    WHERE yos > 50
      AND payplan IN ('AO', 'AWO', 'AE', 'RO', 'RWO', 'RE', 'NE', 'NO', 'NWO');

    -- floating plants (XF/XG/XH) have fewer wage schedules than the broader wage pay plans;
    -- resolve them to the closest wage schedule in the same wage area that has a valid pay
    -- schedule. Source used #DMDCRaw AS a LEFT JOINed to a wage-area subquery (b), and TWICE
    -- to payscheduleCTE (c = current location's schedule, must be absent; d = an alternate
    -- schedule in the same wage area, must be present). Rewritten for PG: b and d (required,
    -- guarded by "d.LocationId IS NOT NULL") become an inner-join FROM; the target's join
    -- predicates move to WHERE; the c anti-join ("c.LocationId IS NULL") becomes NOT EXISTS.
    WITH payschedulecte AS (
        SELECT ps.*, wa.wagearea, wa.schedulearea
        FROM data.payschedules ps
            LEFT JOIN warehouse.location b ON ps.locationid = b.locationid
            LEFT JOIN lookup.wagearea wa   ON b.sourcesystemcode = wa.schedulearea
        WHERE b.locationtype = 'AF Wage Schedule'
          AND wa.fundtype = 'AF'
          AND p_amcosversionid BETWEEN wa.amcosversionidstart AND wa.amcosversionidend
          AND ps.payplan IN ('XF', 'XG', 'XH')
    )
    UPDATE dmdcraw
    SET locationid = d.locationid
    FROM (
            SELECT loc.locationid, wa.wagearea, wa.schedulearea
            FROM warehouse.location loc
                INNER JOIN lookup.wagearea wa
                    ON wa.schedulearea = loc.sourcesystemcode
                   AND wa.fundtype = 'AF'
                   AND loc.locationtype = 'AF Wage Schedule'
                   AND p_amcosversionid BETWEEN wa.amcosversionidstart AND wa.amcosversionidend
         ) b
         INNER JOIN payschedulecte d
             ON b.wagearea = d.wagearea
            AND b.schedulearea <> d.schedulearea
            AND right(b.schedulearea, 2) = right(d.schedulearea, 2)
    WHERE dmdcraw.payplan IN ('XF', 'XG', 'XH')
      AND dmdcraw.locationid = b.locationid
      AND dmdcraw.gradelevel::integer = d.gradelevel
      AND dmdcraw.amcosversionid = d.amcosversionid
      AND dmdcraw.payplan = d.payplan
      AND d.locationid IS NOT NULL
      AND NOT EXISTS (
            SELECT 1 FROM payschedulecte c
            WHERE c.gradelevel = dmdcraw.gradelevel::integer
              AND c.amcosversionid = dmdcraw.amcosversionid
              AND c.locationid = dmdcraw.locationid
              AND c.payplan = dmdcraw.payplan
              AND c.step = dmdcraw.step::integer
          );

    IF NOT p_debug THEN
        -- #### Delete and Insert
        DELETE FROM crunch.inventoryprocessed
        WHERE amcosversionid = p_amcosversionid;

        -- sum up to the location and subgroup level
        INSERT INTO crunch.inventoryprocessed
            (civtype, payplan, categorygroup, categorysubgroup, gradetype, gradelevel,
             step, locationid, yos, inventory, amcosversionid)
        SELECT civtype, payplan, mygroup, validcategorysubgroup, gradetype, gradelevel,
               step, locationid, yos, SUM(inventory), amcosversionid
        FROM dmdcraw
        GROUP BY civtype, payplan, mygroup, validcategorysubgroup, gradetype, gradelevel,
                 step, locationid, yos, amcosversionid;

        -- make sure we have the Chief of the Army Reserve (LTG); if not, carry last year's
        IF NOT EXISTS (
            SELECT 1 FROM crunch.inventoryprocessed
            WHERE payplan = 'RO'
              AND gradelevel::integer = 9
              AND amcosversionid = p_amcosversionid
        ) THEN
            INSERT INTO crunch.inventoryprocessed
                (civtype, payplan, categorygroup, categorysubgroup, gradetype, gradelevel,
                 step, locationid, yos, inventory, amcosversionid)
            SELECT civtype, payplan, categorygroup, categorysubgroup, gradetype, gradelevel,
                   step, locationid, yos, inventory, p_amcosversionid
            FROM crunch.inventoryprocessed
            WHERE payplan = 'RO'
              AND gradelevel::integer = 9
              AND amcosversionid = p_amcosversionid - 100;
        END IF;
    END IF;

    DROP TABLE IF EXISTS dmdcraw;
    DROP TABLE IF EXISTS milsubgroups;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchgseries  (GS-series civilian costs)
--
-- Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchGSeries.sql
-- (SQL Server) to PostgreSQL plpgsql. Builds a master pay-by-location table for
-- the G pay plans (GS/GG/GL), layers on every civilian cost element (base pay,
-- firefighter premium pay, non-foreign COLA, overseas LQA/post allowance/hardship/
-- danger/groceries, benefits, retirement accrual, training, etc.), then rolls the
-- results up along several occupation/location/career-program dimensions into the
-- final crunch.costs_g table.
--
-- Port conventions (see PORT_CONVENTIONS.md):
--   * Source params: @AmcosVersionId INT = -1, @Debug BIT = 0. Source has NO
--     @CrunchTime; a local v_crunchtime := now()::timestamp replaces the repeated
--     CONVERT(SMALLDATETIME, GETDATE()).
--   * p_debug = true is a DRY RUN: source performs its DELETE/INSERT to crunch.Costs_G
--     only under "IF @Debug = 0"; guarded here by "IF NOT p_debug". The temp-table
--     computations always run. "IF @Debug = 1" result-set dumps are dropped.
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS before create and at proc end).
--   * "UPDATE #t SET .. FROM #t a JOIN other b" -> "UPDATE t SET .. FROM other b
--     WHERE <join>" (PG forbids re-aliasing the UPDATE target in FROM). Every such
--     rewrite is noted in the DECISIONS/RISKS list.
--   * ISNULL->COALESCE, GETDATE()->now()::timestamp, string + -> ||, LEN->length,
--     [Group] (reserved) -> "group", CostElementId / pay-plan literals preserved.
--   * Divisions that spread a pay total across an inventory/count denominator are
--     wrapped in NULLIF(denom, 0) (behavior-preserving; avoids div-by-zero).
--   * Case-correct ETL schema names: "PaySchedule".* (quoted), lookup/data/dataload/
--     warehouse/xwalk lowercased & unquoted.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchgseries(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime               timestamp := now()::timestamp;

    v_postrethealthins         numeric(17, 2);
    v_postretlifeins           numeric(17, 2);
    v_training                 numeric(17, 2);
    v_groceries                numeric(17, 2);

    v_firefighterhours         numeric(8, 2);
    v_firefighternonothours    numeric(8, 2);
    v_firefighterbasicpay2hours numeric(8, 2);
    v_firefighter144hrregothrs numeric(8, 2);
    v_annualhours              numeric(8, 2);

    -- averaging assumptions from the source (COR decision 8/24/2020)
    v_conusdep                 integer := -1;
    v_oconusdep                integer := 1;
    v_avgdepnumber             integer := -1;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    /* Integrate payschedule, all possible series types, and inventory */
    DROP TABLE IF EXISTS pay_inv;
    CREATE TEMP TABLE pay_inv (
        payplan              varchar(3)  NOT NULL,
        gradelevel           smallint    NULL,
        categorygroupcode    varchar(4)  NOT NULL,
        categorysubgroupcode varchar(5)  NOT NULL,
        step                 integer     NOT NULL,
        inventory            integer     NULL,
        locationid           integer     NOT NULL,
        locationcode         varchar(150) NULL,
        locationname         varchar(300) NULL,
        numberofdependents   integer     NOT NULL DEFAULT -1,
        amcosversionid       integer     NOT NULL,
        pay                  numeric(15, 2) NULL,
        datasource           varchar(25) NULL,
        valid                boolean     NULL
    );

    -- Bring in regular pay: generate all the series combinations from inventory,
    -- take the highest rate/inventory per group
    INSERT INTO pay_inv
        (payplan, gradelevel, categorygroupcode, categorysubgroupcode, step,
         locationid, amcosversionid, pay, datasource, numberofdependents, inventory)
    SELECT payplan,
           gradelevel,
           mygroup,
           series::varchar(5),
           step,
           locationid,
           amcosversionid,
           MAX(rate),
           'inventory',
           -1 AS numberofdependents,
           MAX(inventory) AS inventory
    FROM (
        SELECT a.payplan,
               a.gradelevel,
               left(b.categorysubgroupcode, 2) || '00' AS mygroup,
               b.categorysubgroupcode::varchar(5) AS series,
               a.step,
               a.locationid,
               a.amcosversionid,
               a.rate,
               'inventory' AS datasource,
               b.inventory
        FROM "PaySchedule".payschedule_g_series AS a
            INNER JOIN (
                SELECT payplan, categorygroupcode, categorysubgroupcode, locationid,
                       gradelevel, step, amcosversionid, SUM(inventory) AS inventory
                FROM data.knowninventory
                WHERE amcosversionid = p_amcosversionid
                      AND payplan IN ('GS', 'GG', 'GL')
                GROUP BY payplan, categorygroupcode, categorysubgroupcode, locationid,
                         gradelevel, step, amcosversionid
            ) AS b
                ON a.gradelevel = b.gradelevel
                   AND b.payplan = a.payplan
                   AND b.locationid = a.locationid
                   AND a.step = b.step
                   AND (a.categorysubgroupcode = b.categorysubgroupcode
                        OR a.categorysubgroupcode = '-1')
        WHERE a.amcosversionid = p_amcosversionid
              AND b.amcosversionid = p_amcosversionid
              AND a.locationid <> -1
    ) AS a
    GROUP BY payplan, gradelevel, mygroup, series, step, locationid, amcosversionid;

    -- firefighters: assign step 5, generate for all locations (no inventory,
    -- AMCOS uses custom 5-digit subgroups with no inventory)
    INSERT INTO pay_inv
        (payplan, gradelevel, categorygroupcode, categorysubgroupcode, step,
         locationid, amcosversionid, pay, datasource, numberofdependents, inventory)
    SELECT a.payplan,
           a.gradelevel,
           left(b.occupationalseriesnumber, 2) || '00',
           b.occupationalseriesnumber,
           a.step,
           a.locationid,
           a.amcosversionid,
           a.rate,
           'fill-in',
           -1 AS numberofdependents,
           0 AS inventory
    FROM "PaySchedule".payschedule_g_series AS a
        CROSS JOIN (
            SELECT occupationalseriesnumber
            FROM lookup.gs_occupationalseries
            WHERE occupationalseriesnumber LIKE '0081%'
                  AND length(occupationalseriesnumber) = 5
                  AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'GS'
          AND a.amcosversionid = p_amcosversionid
          AND a.categorysubgroupcode = '-1'
          AND a.locationid <> -1
          AND a.step = 5;

    -- overseas where we know we have inventory
    INSERT INTO pay_inv
        (payplan, gradelevel, categorygroupcode, categorysubgroupcode, step,
         locationid, amcosversionid, pay, datasource, numberofdependents, inventory)
    SELECT a.payplan,
           a.gradelevel,
           b.categorygroupcode AS mygroup,
           b.categorysubgroupcode AS series,
           b.step,
           b.locationid,
           b.amcosversionid,
           a.rate,
           'inventory' AS datasource,
           d.numberofdependents,
           b.inventory
    FROM "PaySchedule".payschedule_g_series AS a
        INNER JOIN (
            SELECT payplan, categorygroupcode, categorysubgroupcode, locationid,
                   gradelevel, step, amcosversionid, SUM(inventory) AS inventory
            FROM data.knowninventory
            WHERE amcosversionid = p_amcosversionid
                  AND payplan IN ('GS', 'GG')
            GROUP BY payplan, categorygroupcode, categorysubgroupcode, locationid,
                     gradelevel, step, amcosversionid
        ) AS b
            ON b.amcosversionid = a.amcosversionid
               AND b.gradelevel = a.gradelevel
               AND b.step = a.step
               AND b.payplan = a.payplan
        INNER JOIN (
            SELECT a.locationcode, c.locationid
            FROM lookup.doslocations AS a
                LEFT OUTER JOIN (
                    SELECT locationcode,
                           CASE WHEN amt > 0 THEN 1 ELSE 0 END AS costs
                    FROM dataload.doslivingallowance
                    WHERE amcosversionid = p_amcosversionid
                    UNION
                    SELECT locationcode,
                           CASE WHEN dangerpay > 0 OR postallowance > 0 OR hardship > 0
                                THEN 1 ELSE 0 END AS costs
                    FROM dataload.dospostallowance
                    WHERE amcosversionid = p_amcosversionid
                ) AS b
                    ON a.locationcode = b.locationcode
                LEFT OUTER JOIN warehouse.location AS c
                    ON a.locationcode = c.sourcesystemcode
            WHERE c.locationtype = 'Civilian Overseas'
                  AND b.costs = 1
        ) AS c
            ON c.locationid = b.locationid
        CROSS JOIN (
            SELECT DISTINCT numberofdependents
            FROM dataload.militaryspendableincome
            WHERE amcosversionid = p_amcosversionid
        ) AS d
    WHERE a.amcosversionid = p_amcosversionid
          AND a.locationid = -1
          AND a.categorysubgroupcode = '-1';

    -- remove null/zero inventory 'inventory' rows so they don't become fill-in later
    DELETE FROM pay_inv
    WHERE (inventory = 0 OR inventory IS NULL)
          AND datasource = 'inventory';

    -- overseas + conus areas where we are missing inventory (fill-in)
    INSERT INTO pay_inv
        (payplan, gradelevel, categorygroupcode, categorysubgroupcode, step,
         locationid, amcosversionid, pay, valid, numberofdependents, datasource, inventory)
    SELECT c.payplan,
           d.gradelevel,
           '-1' AS mygroup,
           '-1' AS series,
           5,
           a.locationid,
           p_amcosversionid,
           e.rate,
           true,
           b.numberofdependents,
           'fill-in',
           NULL AS inventory
    FROM (
        SELECT a.locationcode, c.locationid
        FROM lookup.doslocations AS a
            LEFT OUTER JOIN (
                SELECT locationcode,
                       CASE WHEN amt > 0 THEN 1 ELSE 0 END AS costs
                FROM dataload.doslivingallowance
                WHERE amcosversionid = p_amcosversionid
                UNION
                SELECT locationcode,
                       CASE WHEN dangerpay > 0 OR postallowance > 0 OR hardship > 0
                            THEN 1 ELSE 0 END AS costs
                FROM dataload.dospostallowance
                WHERE amcosversionid = p_amcosversionid
            ) AS b
                ON a.locationcode = b.locationcode
            LEFT OUTER JOIN warehouse.location AS c
                ON a.locationcode = c.sourcesystemcode
        WHERE c.locationtype = 'Civilian Overseas'
              AND b.costs = 1
    ) AS a
        CROSS JOIN (
            SELECT DISTINCT numberofdependents
            FROM dataload.militaryspendableincome
            WHERE amcosversionid = p_amcosversionid
        ) AS b
        CROSS JOIN (SELECT 'GS' AS payplan UNION SELECT 'GG') AS c
        CROSS JOIN (
            SELECT DISTINCT gradelevel
            FROM lookup.valid_opm_series_gradelevels
            WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS d
        INNER JOIN (
            SELECT *
            FROM "PaySchedule".payschedule_g_series
            WHERE step = 5
                  AND categorysubgroupcode = '-1'
                  AND locationid = -1
                  AND amcosversionid = p_amcosversionid
        ) AS e
            ON e.payplan = c.payplan
               AND e.gradelevel = d.gradelevel
    WHERE CONCAT(e.payplan, e.gradelevel, e.locationid) NOT IN (
              SELECT DISTINCT CONCAT(payplan, gradelevel, locationid)
              FROM pay_inv AS z
              WHERE datasource = 'inventory'
          )
    UNION
    -- conus areas where we are missing inventory
    SELECT a.payplan,
           a.gradelevel,
           '-1' AS mygroup,
           '-1' AS series,
           a.step,
           a.locationid,
           p_amcosversionid,
           a.rate,
           true,
           -1 AS numberofdependents,
           'fill-in',
           NULL AS inventory
    FROM (
        SELECT *
        FROM "PaySchedule".payschedule_g_series
        WHERE step = 5
              AND categorysubgroupcode = '-1'
              AND locationid <> -1
              AND amcosversionid = p_amcosversionid
              AND CONCAT(payplan, gradelevel, locationid) NOT IN (
                      SELECT DISTINCT CONCAT(payplan, gradelevel, locationid)
                      FROM pay_inv AS z
                      WHERE datasource = 'inventory'
                  )
    ) AS a;

    -- normalize zero inventory to NULL
    UPDATE pay_inv
    SET inventory = NULL
    WHERE inventory = 0;

    -- get single values for later use in special pay and non-special pay calculations
    v_postrethealthins := crunch.getsinglevalue('AA', 'PostRetHealthIns', p_amcosversionid);
    v_postretlifeins   := crunch.getsinglevalue('AA', 'PostRetLifeIns', p_amcosversionid);
    v_training         := crunch.getsinglevalue('AA', 'Training', p_amcosversionid);
    v_groceries        := crunch.getsinglevalue('AA', 'DiscountGroceries', p_amcosversionid);

    -- master table to hold costs
    DROP TABLE IF EXISTS paybylocationcosts;
    CREATE TEMP TABLE paybylocationcosts (
        payplan              varchar(3)  NOT NULL,
        gradelevel           smallint    NULL,
        categorygroupcode    varchar(4)  NOT NULL,
        categorysubgroupcode varchar(5)  NOT NULL,
        subgrouptitle        varchar(150) NULL,
        basepay              numeric(15, 2) NOT NULL,
        costamount           numeric(15, 2) NOT NULL,
        locationname         varchar(250) NULL,
        locationcode         varchar(100) NULL,
        locationtype         varchar(500) NULL,
        costelementid        integer     NOT NULL,
        costelementname      varchar(150) NOT NULL,
        costelementcategory  varchar(150) NOT NULL,
        appn                 varchar(25) NOT NULL,
        amcosversionid       integer     NOT NULL,
        locationid           integer     NOT NULL,
        numberofdependents   integer     NOT NULL,
        datasource           varchar(50) NOT NULL,
        inventory            integer     NOT NULL
    );

    -- cross join of all locations / their inventory-weighted base pay and all cost elements
    INSERT INTO paybylocationcosts
        (payplan, gradelevel, categorygroupcode, categorysubgroupcode, basepay,
         costamount, costelementid, costelementname, costelementcategory, appn,
         amcosversionid, locationid, numberofdependents, datasource, inventory)
    SELECT DISTINCT
           a.payplan,
           a.gradelevel,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.avgpay,
           0,
           b.costelementid,
           b.costelementname,
           b.costelementcategory,
           b.appn,
           a.amcosversionid,
           a.locationid,
           a.numberofdependents,
           a.datasource,
           a.inventory
    FROM (
        SELECT payplan, gradelevel, categorygroupcode, categorysubgroupcode,
               locationid, amcosversionid,
               SUM(pay * COALESCE(inventory, 1)) / NULLIF(SUM(COALESCE(inventory, 1)), 0) AS avgpay,
               numberofdependents, datasource,
               SUM(COALESCE(inventory, 0)) AS inventory
        FROM pay_inv
        GROUP BY payplan, gradelevel, categorygroupcode, categorysubgroupcode,
                 locationid, amcosversionid, numberofdependents, datasource
    ) AS a
        INNER JOIN lookup.costelement AS b
            ON a.payplan = b.payplan
    WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- attach location descriptors (rewritten: PG forbids re-aliasing the UPDATE target in FROM)
    UPDATE paybylocationcosts t
    SET locationname = b.displayname,
        locationcode = b.sourcesystemcode,
        locationtype = b.locationtype
    FROM warehouse.location AS b
    WHERE t.locationid = b.locationid;

    v_firefighterhours          := crunch.getsinglevalue('GS', 'FirefighterHours', p_amcosversionid);
    v_firefighternonothours     := crunch.getsinglevalue('GS', 'FirefighterNonOTHours', p_amcosversionid);
    v_firefighterbasicpay2hours := crunch.getsinglevalue('GS', 'FirefighterBasicPay2Hours', p_amcosversionid);

    --Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian)
    UPDATE paybylocationcosts
    SET costamount = basepay
    WHERE costelementid IN (275, 3492, 3505)
          AND left(categorysubgroupcode, 4) <> '0081';

    --144 hours non-exempt firefighter
    UPDATE paybylocationcosts
    SET costamount = basepay / v_firefighterhours * v_firefighternonothours * 26
    WHERE costelementid IN (275)
          AND categorysubgroupcode = '0081a';

    --all other firefighters
    UPDATE paybylocationcosts
    SET costamount = basepay
    WHERE costelementid IN (275)
          AND categorysubgroupcode IN ('0081b', '0081c', '0081d', '0081e');

    --Basic Pay 2 - firefighters only
    UPDATE paybylocationcosts
    SET costamount = basepay / v_firefighterhours * v_firefighterbasicpay2hours * 26
    WHERE costelementid IN (4894)
          AND categorysubgroupcode IN ('0081b', '0081d');

    --Non-foreign COLA = base pay * cola % (rewritten: target re-alias removed;
    -- the warehouse.Location / lookup.NonforeignArea / PaySchedule join lives in FROM)
    UPDATE paybylocationcosts t
    SET costamount = COALESCE(c.colarate / 100, 0) * t.basepay
    FROM warehouse.location AS b
        INNER JOIN lookup.nonforeignarea x
            ON x.localitycode = b.sourcesystemcode
        INNER JOIN "PaySchedule".nonforeignareacostoflivingallowances AS c
            ON x.nonforeignareacode = c.nonforeignareacode
    WHERE t.locationid = b.locationid
          AND p_amcosversionid = c.amcosversionid
          AND b.locationtype IN ('Nonforeign Area', 'Locality Pay Area')
          AND t.costelementid IN (4856, 4857, 4858);

    --###################       Overseas costs                    #######################

    --LQA Costs (group 4: GS1-9)
    UPDATE paybylocationcosts t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
          AND t.gradelevel BETWEEN 1 AND 9
          AND b."group" = 4
          AND b.amcosversionid = p_amcosversionid
          AND b.family = 0
          AND t.numberofdependents = 0
          AND t.costelementid IN (4859, 4860, 4861)
          AND t.locationtype = 'Civilian Overseas';

    UPDATE paybylocationcosts t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
          AND t.gradelevel BETWEEN 1 AND 9
          AND b."group" = 4
          AND b.amcosversionid = p_amcosversionid
          AND b.family = 1
          AND t.numberofdependents >= 1
          AND t.costelementid IN (4859, 4860, 4861)
          AND t.locationtype = 'Civilian Overseas';

    --group 3: GS10-13
    UPDATE paybylocationcosts t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
          AND t.gradelevel BETWEEN 10 AND 13
          AND b."group" = 3
          AND b.amcosversionid = p_amcosversionid
          AND b.family = 0
          AND t.numberofdependents = 0
          AND t.costelementid IN (4859, 4860, 4861)
          AND t.locationtype = 'Civilian Overseas';

    UPDATE paybylocationcosts t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
          AND t.gradelevel BETWEEN 10 AND 13
          AND b."group" = 3
          AND b.amcosversionid = p_amcosversionid
          AND b.family = 1
          AND t.numberofdependents >= 1
          AND t.costelementid IN (4859, 4860, 4861)
          AND t.locationtype = 'Civilian Overseas';

    --group 2: GS14-15
    UPDATE paybylocationcosts t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
          AND t.gradelevel BETWEEN 14 AND 15
          AND b."group" = 2
          AND b.amcosversionid = p_amcosversionid
          AND b.family = 0
          AND t.numberofdependents = 0
          AND t.costelementid IN (4859, 4860, 4861)
          AND t.locationtype = 'Civilian Overseas';

    UPDATE paybylocationcosts t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
          AND t.gradelevel BETWEEN 14 AND 15
          AND b."group" = 2
          AND b.amcosversionid = p_amcosversionid
          AND b.family = 1
          AND t.numberofdependents >= 1
          AND t.costelementid IN (4859, 4860, 4861)
          AND t.locationtype = 'Civilian Overseas';

    --Post Allowance costs (percentage of spendable income)
    UPDATE paybylocationcosts t
    SET costamount = b.spendableincome * c.postallowance
    FROM dataload.militaryspendableincome AS b,
         dataload.dospostallowance AS c
    WHERE t.basepay BETWEEN b.lowerlimit AND b.upperlimit
          AND b.numberofdependents = t.numberofdependents
          AND t.locationcode = c.locationcode
          AND b.amcosversionid = p_amcosversionid
          AND c.amcosversionid = p_amcosversionid
          AND t.costelementid IN (4862, 4863, 4864)
          AND t.locationtype = 'Civilian Overseas';

    --Post Hardship Differential (percentage of basic compensation)
    UPDATE paybylocationcosts t
    SET costamount = t.basepay * b.hardship
    FROM dataload.dospostallowance AS b
    WHERE t.locationcode = b.locationcode
          AND b.amcosversionid = p_amcosversionid
          AND t.costelementid IN (4865, 4866, 4867);

    --Danger Pay Allowance (percentage of basic compensation)
    UPDATE paybylocationcosts t
    SET costamount = t.basepay * b.dangerpay
    FROM dataload.dospostallowance AS b
    WHERE t.locationcode = b.locationcode
          AND b.amcosversionid = p_amcosversionid
          AND t.costelementid IN (4868, 4869, 4870)
          AND t.locationtype = 'Civilian Overseas';

    --Discount Groceries
    UPDATE paybylocationcosts
    SET costamount = v_groceries
    WHERE costelementid IN (4871, 4872, 4873)
          AND locationtype = 'Civilian Overseas';

    --###################       End overseas costs                    #######################

    --Army CivPay; Compensation - Other; Avg Cost of Other Compensation
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'OtherComp', p_amcosversionid)
    WHERE costelementid IN (284, 3493, 3506)
          AND left(categorysubgroupcode, 4) <> '0081';

    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'OtherCompNoPremium', p_amcosversionid)
    WHERE costelementid IN (284, 3493, 3506)
          AND left(categorysubgroupcode, 4) = '0081';

    --Army CivPay; Benefits; Avg Cost of Benefits
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'BenefitsRet', p_amcosversionid)
    WHERE costelementid IN (286, 3487, 3500);

    --Army CivPay; Benefits; Avg Cost of Former Employee Compensation
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'FormerEmp', p_amcosversionid)
    WHERE costelementid IN (282, 3503, 3490);

    --Army CivPay; Cash Awards; Avg Cost of Cash Awards
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'CashAwards', p_amcosversionid)
    WHERE costelementid IN (279, 3491, 3504);

    --Army CivPay; Holiday Pay; Avg Cost of Holiday Pay
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'Holiday', p_amcosversionid)
    WHERE costelementid IN (276, 3494, 3507)
          AND left(categorysubgroupcode, 4) <> '0081';

    --Army CivPay; Overtime Pay; Avg Cost of Overtime Pay
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(payplan, 'Ovrt', p_amcosversionid)
    WHERE costelementid IN (277, 3508, 3495)
          AND left(categorysubgroupcode, 4) <> '0081';

    v_firefighter144hrregothrs := crunch.getsinglevalue('GS', 'Firefighter144hrRegOTHrs', p_amcosversionid);

    --Firefighter Regular OT (144 hr firefighter only)
    UPDATE paybylocationcosts
    SET costamount = basepay / v_firefighterhours * 1.5 * v_firefighter144hrregothrs * 26
    WHERE costelementid IN (4895)
          AND categorysubgroupcode IN ('0081a');

    --Firefighter OT (non-exempt), 1 hour
    UPDATE paybylocationcosts
    SET costamount = basepay / v_firefighterhours * 1.5 * 1
    WHERE costelementid IN (277)
          AND categorysubgroupcode IN ('0081a', '0081b', '0081c');

    v_annualhours := crunch.getsinglevalue('GP', 'annualPaidHours', p_amcosversionid);

    --Firefighter OT (exempt) compared against GS10 Step 1 hourly rate
    -- (rewritten: target re-alias removed; GS10S1 payschedule subquery lives in FROM)
    UPDATE paybylocationcosts t
    SET costamount =
        CASE
            WHEN (t.basepay / v_firefighterhours > b.rate / v_annualhours)
                 AND (1.5 * b.rate / v_annualhours > t.basepay / v_firefighterhours) THEN
                1.5 * b.rate / v_annualhours
            WHEN (t.basepay / v_firefighterhours > b.rate / v_annualhours)
                 AND (1.5 * b.rate / v_annualhours < t.basepay / v_firefighterhours) THEN
                t.basepay / v_firefighterhours
            ELSE
                t.basepay / v_firefighterhours * 1.5
        END * 1
    FROM (
        SELECT *
        FROM data.payschedules
        WHERE payplan = 'GS'
              AND amcosversionid = p_amcosversionid
              AND gradelevel = 10
              AND step = 1
              AND ratetype = 'Annual'
    ) AS b
    WHERE t.payplan = b.payplan
          AND t.locationid = b.locationid
          AND t.costelementid IN (277)
          AND t.categorysubgroupcode IN ('0081d', '0081e');

    --OMA; Training Costs; Training
    UPDATE paybylocationcosts
    SET costamount = v_training
    WHERE costelementid IN (735, 3512, 3499);

    --Federal OM; Retired Pay Accrual; Post Retirement Health Insurance
    UPDATE paybylocationcosts
    SET costamount = v_postrethealthins
    WHERE costelementid IN (952, 3510, 3497);

    --Federal OM; Retired Pay Accrual; Post Retirement Life Insurance
    UPDATE paybylocationcosts
    SET costamount = v_postretlifeins
    WHERE costelementid IN (951, 3498, 3511);

    DELETE FROM paybylocationcosts
    WHERE costamount < 0;

    --there should be no costs for 0081 firefighter placeholder subgroup
    DELETE FROM paybylocationcosts
    WHERE categorysubgroupcode = '0081';

    --convert 0081x to 'inventory' tag so all locations are populated
    UPDATE paybylocationcosts
    SET datasource = 'inventory'
    WHERE categorysubgroupcode LIKE '0081%';

    IF NOT p_debug THEN
        --remove the old costs for this version before inserting the new costs
        DELETE FROM crunch.costs_g
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_g
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid,
             locationid, numberofdependents)
        --subgroup with location, no fill-in but include special
        SELECT payplan, categorygroupcode, categorysubgroupcode, '-1',
               costelementid, payplan, gradelevel, costamount, v_crunchtime,
               p_amcosversionid, locationid, numberofdependents
        FROM paybylocationcosts
        WHERE datasource <> 'fill-in'
        UNION
        --subgroup without location, no fill-in, no 0-inventory special pay in the avg
        SELECT payplan, categorygroupcode, categorysubgroupcode, '-1',
               costelementid, payplan, gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, -1, v_avgdepnumber
        FROM paybylocationcosts
        WHERE (datasource <> 'fill-in'
               AND inventory > 0
               AND numberofdependents IN (v_conusdep, v_oconusdep))
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradelevel
        UNION
        --group with location, no fill-in, no 0-inventory special pay in the avg
        SELECT payplan, categorygroupcode, '-1', '-1',
               costelementid, payplan, gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, locationid, numberofdependents
        FROM paybylocationcosts
        WHERE datasource <> 'fill-in'
              AND inventory > 0
        GROUP BY payplan, categorygroupcode, costelementid, gradelevel, numberofdependents, locationid
        UNION
        --group without location, no fill-in
        SELECT payplan, categorygroupcode, '-1', '-1',
               costelementid, payplan, gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, -1, v_avgdepnumber
        FROM paybylocationcosts
        WHERE datasource <> 'fill-in'
              AND inventory > 0
              AND numberofdependents IN (v_conusdep, v_oconusdep)
        GROUP BY payplan, categorygroupcode, costelementid, gradelevel
        UNION
        --pp with location, fill-in allowed
        SELECT payplan, '-1', '-1', '-1',
               costelementid, payplan, gradelevel,
               SUM(costamount * CASE inventory WHEN 0 THEN 1 ELSE inventory END)
                   / NULLIF(SUM(CASE inventory WHEN 0 THEN 1 ELSE inventory END), 0),
               v_crunchtime, p_amcosversionid, locationid, numberofdependents
        FROM paybylocationcosts
        GROUP BY payplan, costelementid, gradelevel, numberofdependents, locationid
        UNION
        --pp without location, no fill-in
        SELECT payplan, '-1', '-1', '-1',
               costelementid, payplan, gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, -1, v_avgdepnumber
        FROM paybylocationcosts
        WHERE datasource <> 'fill-in'
              AND inventory > 0
              AND numberofdependents IN (v_conusdep, v_oconusdep)
        GROUP BY payplan, costelementid, gradelevel
        UNION
        --career program without location, no fill-in
        SELECT a.payplan, '-1', '-1', b.careerprogramnumber,
               a.costelementid, a.payplan, a.gradelevel,
               SUM(a.costamount * a.inventory) / NULLIF(SUM(a.inventory), 0),
               v_crunchtime, p_amcosversionid, -1, v_avgdepnumber
        FROM paybylocationcosts AS a
            INNER JOIN xwalk.occupationalseriestocareerprogram AS b
                ON a.categorysubgroupcode = b.occupationalseriesnumber
        WHERE a.datasource <> 'fill-in'
              AND a.inventory > 0
              AND a.numberofdependents IN (v_conusdep, v_oconusdep)
        GROUP BY a.payplan, a.costelementid, a.gradelevel, b.careerprogramnumber
        UNION
        --career program with location, fill-in allowed
        SELECT a.payplan, '-1', '-1', b.careerprogramnumber,
               a.costelementid, a.payplan, a.gradelevel,
               SUM(a.costamount * CASE a.inventory WHEN 0 THEN 1 ELSE a.inventory END)
                   / NULLIF(SUM(CASE a.inventory WHEN 0 THEN 1 ELSE a.inventory END), 0),
               v_crunchtime, p_amcosversionid, a.locationid, a.numberofdependents
        FROM paybylocationcosts AS a
            INNER JOIN xwalk.occupationalseriestocareerprogram AS b
                ON a.categorysubgroupcode = b.occupationalseriesnumber
        GROUP BY a.payplan, a.costelementid, a.gradelevel, a.numberofdependents,
                 b.careerprogramnumber, a.locationid;

        --one final insert to catch location non-specific subgroups we didn't generate
        --costs for due to lack of inventory (special pay and 5-digit subgroups)
        INSERT INTO crunch.costs_g
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid,
             locationid, numberofdependents)
        SELECT payplan, categorygroupcode, categorysubgroupcode, '-1',
               costelementid, payplan, gradelevel, AVG(costamount), v_crunchtime,
               p_amcosversionid, -1, v_conusdep AS numberofdependents
        FROM paybylocationcosts
        WHERE CONCAT(CONCAT(payplan, categorysubgroupcode), gradelevel) NOT IN (
                  SELECT DISTINCT CONCAT(CONCAT(payplan, occupationalseriesnumber), gradelevel)
                  FROM crunch.costs_g
                  WHERE locationid = -1
                        AND p_amcosversionid = amcosversionid
              )
              AND numberofdependents = v_conusdep
              AND locationid <> -1
              AND inventory = 0
              AND categorysubgroupcode <> '-1'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, gradelevel;

        --remove costs which are zero
        DELETE FROM crunch.costs_g
        WHERE amount <= 0
              AND amcosversionid = p_amcosversionid;
    END IF;

    DROP TABLE IF EXISTS pay_inv;
    DROP TABLE IF EXISTS paybylocationcosts;
END;
$$;

-- =============================================================================
-- crunch.crunchwage  — Wage-grade civilian cost crunch (WG/WS/WL and related
--   NA/NL/NS/WA/WD/WN/WO/WY/XF/XG/XH/XR/XT/XU wage pay plans).
--
-- Faithful PostgreSQL port of [crunch].[CrunchWage] (AMCOS.AMCOS2020_MAR).
--   Author (source): Dan Hogan, 10/11/2019. 3/2/2020 added overtime-pay CE.
--
-- Builds inventory + payschedule/WASS pay, computes every wage cost element
-- (base pay, premium, overtime, FEGLI/FEGHI, retirement, FICA w/ cap, LQA, post
-- allowance, hardship/danger pay, discount groceries, training, etc.), then
-- writes actuals + five weighted-average roll-ups into crunch.costs_wage.
--
-- Port conventions (Phase 2/3):
--   * p_debug boolean DEFAULT false. p_debug = true is a DRY RUN: the source
--     performs its DELETE/INSERT writes to crunch.Costs_Wage only under
--     "IF @Debug = 0", so those are guarded by "IF NOT p_debug". The interactive
--     "IF @Debug = 1" result-set dumps are dropped (no runtime effect). The two
--     data-validation "RAISERROR + RETURN" guards run in BOTH modes (they sit
--     before the @Debug=0 block in the source) and are ported as RAISE EXCEPTION.
--   * Source has NO @CrunchTime parameter — none added. CONVERT(SMALLDATETIME,
--     GETDATE()) -> a single v_crunchtime := now()::timestamp used for all rows.
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS first + at proc end).
--   * "UPDATE #t SET .. FROM #t a JOIN other b" -> "UPDATE t SET .. FROM other b
--     WHERE .." (PG forbids re-aliasing the UPDATE target in FROM). The FICA
--     self-join keeps its aggregate self-scan as a subquery in FROM.
--   * ISNULL->COALESCE; BIT->boolean; NVARCHAR->varchar; string '+'->'||';
--     LEFT()->left(); every "budget/total / SUM(inventory)" denominator wrapped
--     in NULLIF(..,0) (behavior-preserving div-by-zero guard).
--   * Integer literal -1 assigned to the varchar OccupationalGroupNumber /
--     OccupationalSeriesNumber / WageArea / WageSchedule average-roll-up columns
--     is written as text '-1' (PG has no implicit int->varchar assignment cast;
--     SQL Server converted these implicitly — same resulting value).
--   * Case-corrected schemas: "PaySchedule".payschedule_wage; crunch.*, data.*,
--     lookup.*, dataload.*, warehouse.* are lowercase-unquoted. Reserved word
--     [Group] -> "group".
-- =============================================================================
CREATE OR REPLACE PROCEDURE crunch.crunchwage(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime      timestamp     := now()::timestamp;
    v_annualhours     numeric(18, 2);

    v_fica            numeric(20, 6);
    v_max_wage_ssw    numeric(20, 6);
    v_postrethealthins numeric(20, 6);
    v_postretlifeins  numeric(20, 6);
    v_training        numeric(20, 6);
    v_armyret         numeric(20, 6);
    v_cashawards      numeric(20, 6);
    v_fegli           numeric(20, 6);
    v_formeremp       numeric(20, 6);
    v_misc            numeric(20, 6);
    v_prem            numeric(20, 6);
    v_ot              numeric(20, 6);
    v_feghi           numeric(20, 6);
    v_groceries       numeric(20, 6);

    -- averaging assumptions (see COR guidance 8/24/2020 comment in source)
    v_numberofdependentsconus   integer := -1;
    v_numberofdependentsoconus  integer := 1;
    v_numberofdependentsaverage integer := -1;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    v_annualhours := crunch.getsinglevalue('GP', 'annualpaidhours', p_amcosversionid);

    /* This crunch is only for the wage-tagged pay plans:
       NA, NL, NS, WA, WB, WD, WG, WJ, WK, WL, WN, WO, WQ, WR, WS, WT, WU, WY,
       XF, XG, XH, XR, XT, XU */
    DROP TABLE IF EXISTS payplans;
    CREATE TEMP TABLE payplans (
        payplan     varchar(2)   NOT NULL,
        displaytitle varchar(100) NOT NULL,
        explanation varchar(500) NOT NULL
    );

    INSERT INTO payplans (payplan, displaytitle, explanation)
    SELECT payplan, displaytitle, explanation
    FROM lookup.payplan
    WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage')
      AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend;

    /* Wage inventory: WASS pay must be aggregated to series/location/grade/step
       before use, so build a dedicated table. */
    DROP TABLE IF EXISTS wageinventory;
    CREATE TEMP TABLE wageinventory (
        payplan                  varchar(3)   NOT NULL,
        fundtype                 varchar(3)   NOT NULL,
        occupationalgroupnumber  varchar(4)   NOT NULL,
        occupationalseriesnumber varchar(4)   NOT NULL,
        gradelevel               integer      NOT NULL,
        step                     integer      NOT NULL,
        locationid               integer      NOT NULL,
        locationtype             varchar(500) NOT NULL,
        locationname             varchar(500) NULL,
        inventory                integer      NOT NULL,
        salary                   numeric(18, 2) NULL,
        amcosversionid           integer      NOT NULL
    );

    /* Appropriated Fund pay plans from WASS */
    INSERT INTO wageinventory
        (payplan, fundtype, occupationalgroupnumber, occupationalseriesnumber,
         gradelevel, step, locationid, locationtype, locationname, inventory, salary, amcosversionid)
    SELECT a.payplan,
           'AF',
           a.occupationalgroupnumber,
           a.occupationalseriesnumber,
           a.gradelevel,
           a.step,
           a.locationid,
           b.locationtype,
           b.displayname,
           a.inventory,
           a.averagepay * v_annualhours,
           a.amcosversionid
    FROM crunch.inventorywass AS a
        LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
    WHERE a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'WASS')
      AND a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage AF')
      AND a.amcosversionid = p_amcosversionid
      AND b.locationtype = 'Federal Wage System AF';

    /* Appropriated Fund pay plans from DMDC */
    INSERT INTO wageinventory
        (payplan, fundtype, occupationalgroupnumber, occupationalseriesnumber,
         gradelevel, step, locationid, locationtype, locationname, inventory, amcosversionid)
    SELECT a.payplan,
           'AF',
           a.categorygroup,
           a.categorysubgroup,
           a.gradelevel,
           a.step,
           a.locationid,
           b.locationtype,
           b.displayname,
           a.inventory,
           a.amcosversionid
    FROM crunch.inventorydmdc AS a
        LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
    WHERE a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'DMDC')
      AND a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage AF')
      AND a.amcosversionid = p_amcosversionid
      AND b.locationtype IN ('Federal Wage System AF', 'Federal Wage System AF Overseas');

    /* Nonappropriated Fund (NAF) pay plans from WASS (exclude CY, NF) */
    INSERT INTO wageinventory
        (payplan, fundtype, occupationalgroupnumber, occupationalseriesnumber,
         gradelevel, step, locationid, locationtype, locationname, inventory, salary, amcosversionid)
    SELECT a.payplan,
           'NAF',
           a.occupationalgroupnumber,
           a.occupationalseriesnumber,
           a.gradelevel,
           a.step,
           a.locationid,
           b.locationtype,
           b.displayname,
           a.inventory,
           a.averagepay * v_annualhours,
           a.amcosversionid
    FROM crunch.inventorywass AS a
        LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
    WHERE a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'WASS')
      AND a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage NAF')
      AND a.payplan NOT IN ('CY', 'NF')
      AND a.amcosversionid = p_amcosversionid
      AND b.locationtype IN ('Federal Wage System NAF');

    /* Nonappropriated Fund (NAF) pay plans from DMDC (exclude CY, NF) */
    INSERT INTO wageinventory
        (payplan, fundtype, occupationalgroupnumber, occupationalseriesnumber,
         locationid, locationname, locationtype, gradelevel, step, inventory, amcosversionid)
    SELECT a.payplan,
           'NAF',
           a.categorygroup,
           a.categorysubgroup,
           a.locationid,
           b.displayname,
           b.locationtype,
           a.gradelevel,
           a.step,
           a.inventory,
           a.amcosversionid
    FROM crunch.inventorydmdc AS a
        LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
    WHERE a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'DMDC')
      AND a.payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Wage NAF')
      AND a.payplan NOT IN ('CY', 'NF')
      AND a.amcosversionid = p_amcosversionid
      AND b.locationtype IN ('Federal Wage System NAF', 'Federal Wage System NAF Overseas');

    /* Combined pay + inventory table */
    DROP TABLE IF EXISTS payandinventory;
    CREATE TEMP TABLE payandinventory (
        payplan                  varchar(2)   NOT NULL,
        fundtype                 varchar(3)   NOT NULL,
        occupationalseriesnumber varchar(4)   NOT NULL,
        schedulearea             varchar(4)   NOT NULL,
        locationid               integer      NOT NULL,
        locationtype             varchar(500) NOT NULL,
        locationname             varchar(500) NOT NULL,
        gradelevel               integer      NOT NULL,
        step                     integer      NOT NULL,
        inventory                integer      NULL DEFAULT 0,
        salarywass               numeric(18, 2) NULL,
        salarypayschedule        numeric(18, 2) NULL,
        numberofdependents       integer      NOT NULL DEFAULT -1,
        datasource               varchar(50)  NOT NULL,
        amcosversionid           integer      NOT NULL
    );

    /* Start from payschedule data, joined to inventory location/series so only
       inventory-valid records survive. UNION brings in foreign (overseas) areas. */
    INSERT INTO payandinventory
        (payplan, fundtype, occupationalseriesnumber, schedulearea, locationid, locationtype,
         locationname, gradelevel, step, inventory, salarypayschedule, numberofdependents,
         datasource, amcosversionid)
    SELECT a.payplan,
           a.fundtype,
           b.occupationalseriesnumber,
           a.areacode,
           a.locationid,
           c.locationtype,
           c.displayname,
           a.gradelevel,
           a.step,
           COALESCE(b.inventory, 0),
           a.salarypayschedule,
           -1 AS numberofdependents,
           'Inventory',
           p_amcosversionid
    FROM (
        SELECT a.payplan,
               a.fundtype,
               a.areacode,
               a.locationid,
               a.gradelevel,
               a.step,
               a.rate * v_annualhours AS salarypayschedule
        FROM "PaySchedule".payschedule_wage a
            INNER JOIN lookup.wagearea b ON a.areacode = b.schedulearea
        WHERE a.amcosversionid = p_amcosversionid
          AND b.areaname <> 'Foreign Areas'   -- foreign areas handled separately
    ) AS a
        INNER JOIN (
            SELECT payplan, fundtype, locationid, occupationalseriesnumber, gradelevel, step,
                   SUM(inventory) AS inventory
            FROM wageinventory
            GROUP BY payplan, fundtype, locationid, occupationalseriesnumber, gradelevel, step
        ) AS b
            ON a.payplan = b.payplan
               AND a.locationid = b.locationid
               AND a.gradelevel = b.gradelevel
               AND a.step = b.step
        LEFT OUTER JOIN warehouse.location AS c
            ON a.locationid = c.locationid
               AND c.locationtype IN ('Federal Wage System AF', 'Federal Wage System NAF')
    UNION
    SELECT a.payplan,
           a.fundtype,
           b.occupationalseriesnumber,
           a.areacode,
           e.locationid,
           e.locationtype,
           e.displayname,
           a.gradelevel,
           a.step,
           COALESCE(b.inventory, 0),
           a.rate * v_annualhours,
           d.numberofdependents,
           'Inventory',
           p_amcosversionid
    FROM "PaySchedule".payschedule_wage AS a
        CROSS JOIN (   -- only DoS locations whose CEs will yield a value > 1
            SELECT locationcode,
                   CASE WHEN amt > 0 THEN 1 ELSE 0 END AS costs
            FROM dataload.doslivingallowance
            WHERE amcosversionid = p_amcosversionid
            UNION
            SELECT locationcode,
                   CASE WHEN dangerpay > 0 OR postallowance > 0 OR hardship > 0 THEN 1 ELSE 0 END AS costs
            FROM dataload.dospostallowance
            WHERE amcosversionid = p_amcosversionid
        ) AS c
        CROSS JOIN (   -- number of possible dependents
            SELECT DISTINCT numberofdependents
            FROM dataload.militaryspendableincome
            WHERE amcosversionid = p_amcosversionid
        ) AS d
        LEFT OUTER JOIN warehouse.location AS e ON c.locationcode = e.sourcesystemcode
        INNER JOIN (
            SELECT payplan, locationid, occupationalseriesnumber, step, gradelevel,
                   SUM(inventory) AS inventory
            FROM wageinventory
            GROUP BY payplan, locationid, occupationalseriesnumber, step, gradelevel
        ) AS b
            ON a.payplan = b.payplan
               AND e.locationid = b.locationid
               AND a.step = b.step
               AND a.gradelevel = b.gradelevel
    WHERE c.costs = 1
      AND a.amcosversionid = p_amcosversionid
      AND e.locationtype = 'Civilian Overseas'
      AND a.wagearea = 'FA'
      AND a.payplan IN ('WG', 'WL', 'WS');

    /* Some payschedules we don't have / are manual entry, so WASS is authoritative.
       Only insert inventory records whose pay plan has no payschedule record yet. */
    INSERT INTO payandinventory
        (payplan, fundtype, schedulearea, locationid, locationname, locationtype, gradelevel,
         step, salarywass, occupationalseriesnumber, amcosversionid, datasource, numberofdependents, inventory)
    SELECT a.payplan,
           a.fundtype,
           b.sourcesystemcode,
           a.locationid,
           a.locationname,
           a.locationtype,
           a.gradelevel,
           a.step,
           a.salary,
           a.occupationalseriesnumber,
           p_amcosversionid,
           'Inventory',
           -1,
           a.inventory
    FROM wageinventory AS a
        LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
    WHERE a.payplan NOT IN (SELECT DISTINCT payplan FROM payandinventory);

    /* Backfill WASS salary where neither WASS nor payschedule pay is set.
       Source: "UPDATE #PayAndInventory .. FROM #PayAndInventory a JOIN crunch.InventoryWASS b".
       Rewritten to drop the target self-alias (PG rule); INNER JOIN, salarywass
       is guaranteed NULL for the matched rows (IS NULL guard) so semantics match. */
    UPDATE payandinventory t
    SET salarywass = b.averagepay * v_annualhours
    FROM crunch.inventorywass b
    WHERE t.payplan = b.payplan
      AND t.locationid = b.locationid
      AND t.gradelevel = b.gradelevel
      AND t.step = b.step
      AND t.occupationalseriesnumber = b.occupationalseriesnumber
      AND t.salarywass IS NULL
      AND t.salarypayschedule IS NULL;

    /* Fill in the blanks at the pay-plan level for locations missing inventory */
    INSERT INTO payandinventory
        (payplan, fundtype, occupationalseriesnumber, schedulearea, locationid, locationname,
         locationtype, gradelevel, step, inventory, salarywass, salarypayschedule, amcosversionid,
         datasource, numberofdependents)
    SELECT a.payplan,
           a.fundtype,
           '-1' AS occupationalseriesnumber,
           a.areacode,
           a.locationid,
           a.locationname,
           a.locationtype,
           a.gradelevel,
           a.step,
           1 AS inventory,
           NULL AS salarywass,
           a.rate * v_annualhours,
           p_amcosversionid,
           'Fill-in',
           a.numberofdependents
    FROM (
        -- first non-overseas
        SELECT a.payplan,
               a.fundtype,
               a.areacode,
               a.locationid,
               b.displayname AS locationname,
               b.locationtype,
               a.gradelevel,
               a.step,
               a.rate,
               -1 AS numberofdependents
        FROM "PaySchedule".payschedule_wage AS a
            LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
        WHERE a.step = 3
          AND b.locationtype IN ('Federal Wage System AF', 'Federal Wage System NAF')
          AND a.locationid <> -1
          AND a.amcosversionid = p_amcosversionid
        UNION
        -- Federal Wage System AF/NAF Overseas
        SELECT a.payplan,
               a.fundtype,
               a.areacode,
               b.locationid,
               b.displayname,
               b.locationtype,
               a.gradelevel,
               a.step,
               a.rate,
               d.numberofdependents
        FROM "PaySchedule".payschedule_wage AS a
            LEFT OUTER JOIN warehouse.location AS b ON a.locationid = b.locationid
            CROSS JOIN (
                SELECT DISTINCT numberofdependents
                FROM dataload.militaryspendableincome
                WHERE amcosversionid = p_amcosversionid
            ) AS d
        WHERE a.step = 3
          AND b.locationtype IN ('Federal Wage System AF Overseas', 'Federal Wage System NAF Overseas')
          AND a.locationid <> -1
          AND a.amcosversionid = p_amcosversionid
    ) AS a
    WHERE NOT EXISTS (
        SELECT DISTINCT z.payplan, z.gradelevel, z.locationid
        FROM payandinventory AS z
        WHERE z.payplan = a.payplan
          AND z.gradelevel = a.gradelevel
          AND z.locationid = a.locationid
    )
      AND a.locationname IS NOT NULL;

    -- rows still without at least one inventory head are no longer needed
    DELETE FROM payandinventory WHERE inventory = 0;

    /* A record with neither payschedule nor WASS pay is a hard error (except the
       WB/WQ/WU/WK plans DCPAS stopped issuing on 9/17/25, gated to version 202501). */
    IF EXISTS (
        SELECT 1 FROM payandinventory
        WHERE salarypayschedule IS NULL
          AND salarywass IS NULL
          AND payplan NOT IN ('WB', 'WQ', 'WU', 'WK')
          AND amcosversionid = 202501
    ) THEN
        RAISE EXCEPTION 'Missing a pay amount';
    END IF;

    DELETE FROM payandinventory
    WHERE salarypayschedule IS NULL
      AND salarywass IS NULL
      AND payplan IN ('WB', 'WQ', 'WU', 'WK')
      AND amcosversionid = 202501;

    /* Explode to one row per cost element and compute inventory-weighted base pay */
    DROP TABLE IF EXISTS costswage;
    CREATE TEMP TABLE costswage (
        payplan                  varchar(2)   NOT NULL,
        payplantitle             varchar(100) NULL,
        fundtype                 varchar(3)   NOT NULL,
        occupationalgroupnumber  varchar(4)   NOT NULL DEFAULT '0000',
        occupationalseriesnumber varchar(4)   NOT NULL,
        wagearea                 varchar(3)   NULL,
        schedulearea             varchar(4)   NOT NULL,
        gradelevel               integer      NOT NULL,
        inventory                integer      NOT NULL,
        basepay                  numeric(18, 2) NOT NULL,
        costelementid            integer      NOT NULL,
        costamount               numeric(16, 2) NULL DEFAULT 0,
        amcosversionid           integer      NOT NULL,
        datasource               varchar(50)  NOT NULL,
        locationid               integer      NULL,
        locationcode             varchar(500) NULL,
        locationtype             varchar(500) NULL,
        numberofdependents       integer      NOT NULL,
        taxable                  boolean      NOT NULL DEFAULT false
    );

    INSERT INTO costswage
        (payplan, fundtype, occupationalseriesnumber, schedulearea, gradelevel, inventory, basepay,
         costelementid, amcosversionid, datasource, numberofdependents, locationid, locationcode, locationtype)
    SELECT a.payplan,
           a.fundtype,
           a.occupationalseriesnumber,
           a.schedulearea,
           a.gradelevel,
           a.inventory,
           a.basepay,
           b.costelementid,
           a.amcosversionid,
           a.datasource,
           a.numberofdependents,
           a.locationid,
           c.sourcesystemcode,
           a.locationtype
    FROM (
        SELECT a.payplan,
               a.fundtype,
               a.occupationalseriesnumber,
               a.schedulearea,
               a.gradelevel,
               SUM(a.inventory) AS inventory,
               SUM(a.inventory * COALESCE(a.salarypayschedule, a.salarywass)) / NULLIF(SUM(a.inventory), 0) AS basepay,
               a.amcosversionid,
               a.datasource,
               a.numberofdependents,
               a.locationid,
               a.locationname,
               a.locationtype
        FROM payandinventory AS a
        GROUP BY a.payplan, a.fundtype, a.occupationalseriesnumber, a.schedulearea, a.gradelevel,
                 a.amcosversionid, a.datasource, a.numberofdependents, a.locationid, a.locationname, a.locationtype
    ) AS a
        CROSS JOIN lookup.costelement AS b
        LEFT OUTER JOIN warehouse.location AS c ON a.locationid = c.locationid
    WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND b.payplan = a.payplan;

    -- Every data row must resolve to a valid location
    IF EXISTS (SELECT 1 FROM costswage WHERE locationid IS NULL OR locationid = -1) THEN
        RAISE EXCEPTION 'Invalid location codes';
    END IF;

    -- Cost-factor single values
    v_fica            := crunch.getsinglevalue('AAw', 'FICA', p_amcosversionid);
    v_max_wage_ssw    := crunch.getsinglevalue('AA', 'Max_Wage_SSW', p_amcosversionid);
    v_postrethealthins := crunch.getsinglevalue('AA', 'PostRetHealthIns', p_amcosversionid);
    v_postretlifeins  := crunch.getsinglevalue('AA', 'PostRetLifeIns', p_amcosversionid);
    v_training        := crunch.getsinglevalue('AA', 'Training', p_amcosversionid);
    v_armyret         := crunch.getsinglevalue('AAw', 'ArmyRet', p_amcosversionid);
    v_cashawards      := crunch.getsinglevalue('AAw', 'CashAwards', p_amcosversionid);
    v_fegli           := crunch.getsinglevalue('AAw', 'FEGLI', p_amcosversionid);
    v_formeremp       := crunch.getsinglevalue('AAw', 'FormerEmp', p_amcosversionid);
    v_misc            := crunch.getsinglevalue('AAw', 'Misc', p_amcosversionid);
    v_prem            := crunch.getsinglevalue('AAw', 'Prem', p_amcosversionid);
    v_ot              := crunch.getsinglevalue('AAw', 'Ovrt', p_amcosversionid);
    v_feghi           := crunch.getsinglevalue('AAw', 'FEGHI', p_amcosversionid);
    v_groceries       := crunch.getsinglevalue('AA', 'DiscountGroceries', p_amcosversionid);

    -- Base pay, taxable
    UPDATE costswage
    SET costamount = basepay,
        taxable = true
    WHERE costelementid IN (4226, 4238, 4250, 628, 4262, 4274, 635, 4286, 4298, 4310, 4322, 642, 4334, 4346, 4358,
                            4370, 4382, 4394, 4406, 4418, 4430, 4463, 4476, 4489);

    /* LQA costs (per DTMO). Group 4: WG 1-13; WL 1-11; WS 1-10.
       Source used "UPDATE #CostsWage .. FROM #CostsWage a JOIN dataload.DoSLivingAllowance b";
       rewritten to drop the target self-alias (single external join, INNER-JOIN
       semantics preserved). */
    UPDATE costswage t
    SET costamount = b.amt
    FROM dataload.doslivingallowance b
    WHERE t.locationcode = b.locationcode
      AND (
              (t.gradelevel BETWEEN 1 AND 13 AND t.payplan = 'WG')
           OR (t.gradelevel BETWEEN 1 AND 11 AND t.payplan = 'WL')
           OR (t.gradelevel BETWEEN 1 AND 10 AND t.payplan = 'WS')
          )
      AND b."group" = 4
      AND b.amcosversionid = p_amcosversionid
      AND b.family = 0
      AND t.numberofdependents = 0
      AND t.costelementid IN (4884, 4874, 4879)
      AND t.locationtype = 'Civilian Overseas';

    UPDATE costswage t
    SET costamount = b.amt
    FROM dataload.doslivingallowance b
    WHERE t.locationcode = b.locationcode
      AND (
              (t.gradelevel BETWEEN 1 AND 13 AND t.payplan = 'WG')
           OR (t.gradelevel BETWEEN 1 AND 11 AND t.payplan = 'WL')
           OR (t.gradelevel BETWEEN 1 AND 10 AND t.payplan = 'WS')
          )
      AND b."group" = 4
      AND b.amcosversionid = p_amcosversionid
      AND b.family = 1
      AND t.numberofdependents >= 1
      AND t.costelementid IN (4884, 4874, 4879)
      AND t.locationtype = 'Civilian Overseas';

    -- Group 3: WG 14-15; WL 12-15; WS 11-19
    UPDATE costswage t
    SET costamount = b.amt
    FROM dataload.doslivingallowance b
    WHERE t.locationcode = b.locationcode
      AND (
              (t.gradelevel BETWEEN 14 AND 15 AND t.payplan = 'WG')
           OR (t.gradelevel BETWEEN 12 AND 15 AND t.payplan = 'WL')
           OR (t.gradelevel BETWEEN 11 AND 19 AND t.payplan = 'WS')
          )
      AND b."group" = 3
      AND b.amcosversionid = p_amcosversionid
      AND b.family = 0
      AND t.numberofdependents = 0
      AND t.costelementid IN (4884, 4874, 4879)
      AND t.locationtype = 'Civilian Overseas';

    UPDATE costswage t
    SET costamount = b.amt
    FROM dataload.doslivingallowance b
    WHERE t.locationcode = b.locationcode
      AND (
              (t.gradelevel BETWEEN 14 AND 15 AND t.payplan = 'WG')
           OR (t.gradelevel BETWEEN 12 AND 15 AND t.payplan = 'WL')
           OR (t.gradelevel BETWEEN 11 AND 19 AND t.payplan = 'WS')
          )
      AND b."group" = 3
      AND b.amcosversionid = p_amcosversionid
      AND b.family = 1
      AND t.numberofdependents >= 1
      AND t.costelementid IN (4884, 4874, 4879)
      AND t.locationtype = 'Civilian Overseas';

    /* Post Allowance (percentage of spendable income; NOT taxable per DSSR 054.1).
       Two external joins; target self-alias dropped. */
    UPDATE costswage t
    SET costamount = b.spendableincome * c.postallowance
    FROM dataload.militaryspendableincome b,
         dataload.dospostallowance c
    WHERE t.basepay BETWEEN b.lowerlimit AND b.upperlimit
      AND b.numberofdependents = t.numberofdependents
      AND t.locationcode = c.locationcode
      AND b.amcosversionid = p_amcosversionid
      AND c.amcosversionid = p_amcosversionid
      AND t.costelementid IN (4885, 4875, 4880)
      AND t.locationtype = 'Civilian Overseas';

    /* Post Hardship Differential (% of basic compensation; taxable per DSSR 045.2) */
    UPDATE costswage t
    SET costamount = t.basepay * b.hardship,
        taxable = true
    FROM dataload.dospostallowance b
    WHERE t.locationcode = b.locationcode
      AND b.amcosversionid = p_amcosversionid
      AND t.costelementid IN (4886, 4876, 4881)
      AND t.locationtype = 'Civilian Overseas';

    /* Danger Pay Allowance (% of basic compensation; taxable per DSSR 054.2) */
    UPDATE costswage t
    SET costamount = t.basepay * b.dangerpay,
        taxable = true
    FROM dataload.dospostallowance b
    WHERE t.locationcode = b.locationcode
      AND b.amcosversionid = p_amcosversionid
      AND t.costelementid IN (4887, 4877, 4882)
      AND t.locationtype = 'Civilian Overseas';

    -- Discount Groceries
    UPDATE costswage
    SET costamount = v_groceries
    WHERE costelementid IN (4888, 4878, 4883)
      AND locationtype = 'Civilian Overseas';

    -- Avg Cost of Premium Pay, taxable
    UPDATE costswage
    SET costamount = basepay * v_prem,
        taxable = true
    WHERE costelementid IN (4227, 4239, 4251, 629, 4263, 4275, 636, 4287, 4299, 4311, 4323, 643, 4335, 4347, 4359,
                            4371, 4383, 4395, 4407, 4419, 4431, 4465, 4478, 4491);

    -- Avg Cost of Overtime Pay, taxable
    UPDATE costswage
    SET costamount = basepay * v_ot,
        taxable = true
    WHERE costelementid IN (4436, 4437, 4438, 4439, 4440, 4441, 4442, 4443, 4444, 4445, 4446, 4447, 4448, 4449, 4450,
                            4451, 4452, 4453, 4454, 4455, 4456, 4464, 4477, 4490);

    -- Avg Cost of Federal Employees' Gov't Life Insurance
    UPDATE costswage
    SET costamount = basepay * v_fegli
    WHERE costelementid IN (4223, 4235, 4247, 631, 4259, 4271, 638, 4283, 4295, 4307, 4319, 645, 4331, 4343, 4355,
                            4367, 4379, 4391, 4403, 4415, 4427, 4460, 4473, 4486);

    -- Avg Cost of Federal Employees' Gov't Health Insurance
    UPDATE costswage
    SET costamount = v_feghi
    WHERE costelementid IN (4222, 4234, 4246, 630, 4258, 4270, 637, 4282, 4294, 4306, 4318, 644, 4330, 4342, 4354,
                            4366, 4378, 4390, 4402, 4414, 4426, 4459, 4472, 4485);

    -- Avg Cost of Miscellaneous Pay
    UPDATE costswage
    SET costamount = basepay * v_misc
    WHERE costelementid IN (4224, 4236, 4248, 632, 4260, 4272, 639, 4284, 4296, 4308, 4320, 646, 4332, 4344, 4356,
                            4368, 4380, 4392, 4404, 4416, 4428, 4461, 4474, 4487);

    -- Post-retirement life
    UPDATE costswage
    SET costamount = v_postretlifeins
    WHERE costelementid IN (4230, 4242, 4254, 976, 4266, 4278, 986, 4290, 4302, 4314, 4326, 996, 4338, 4350, 4362,
                            4374, 4386, 4398, 4410, 4422, 4434, 4468, 4481, 4494);

    -- Post-retirement health
    UPDATE costswage
    SET costamount = v_postrethealthins
    WHERE costelementid IN (4229, 4241, 4253, 977, 4265, 4277, 987, 4289, 4301, 4313, 4325, 997, 4337, 4349, 4361,
                            4373, 4385, 4397, 4409, 4421, 4433, 4467, 4480, 4493);

    -- Cash awards, taxable
    UPDATE costswage
    SET costamount = basepay * v_cashawards,
        taxable = true
    WHERE costelementid IN (4225, 4237, 4249, 971, 4261, 4273, 981, 4285, 4297, 4309, 4321, 991, 4333, 4345, 4357,
                            4369, 4381, 4393, 4405, 4417, 4429, 4462, 4475, 4488);

    /* FICA = rate * sum of the taxable cost elements for the same grouping.
       Source self-joined #CostsWage to an aggregate subquery of #CostsWage; the
       target self-alias is dropped and the aggregate self-scan kept as a FROM
       subquery (PG rule). Note: OccupationalGroupNumber is still '0000' here
       because its assignment happens later in the source — grouping is faithful. */
    UPDATE costswage t
    SET costamount = v_fica * b.taxablecosts
    FROM (
        SELECT SUM(costamount) AS taxablecosts,
               payplan,
               occupationalgroupnumber,
               occupationalseriesnumber,
               gradelevel,
               locationid,
               datasource,
               numberofdependents
        FROM costswage
        WHERE taxable = true
        GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber, gradelevel,
                 locationid, datasource, numberofdependents
    ) AS b
    WHERE b.gradelevel = t.gradelevel
      AND b.locationid = t.locationid
      AND b.occupationalgroupnumber = t.occupationalgroupnumber
      AND b.numberofdependents = t.numberofdependents
      AND b.payplan = t.payplan
      AND b.occupationalseriesnumber = t.occupationalseriesnumber
      AND b.datasource = t.datasource
      AND t.costelementid IN (972, 982, 992, 4220, 4232, 4244, 4256, 4268, 4280, 4292, 4304, 4316, 4328, 4340, 4352,
                              4364, 4376, 4388, 4400, 4412, 4424, 4457, 4470, 4483);

    -- Cap on FICA
    UPDATE costswage
    SET costamount = v_max_wage_ssw * v_fica
    WHERE costamount > (v_max_wage_ssw * v_fica)
      AND costelementid IN (972, 982, 992, 4220, 4232, 4244, 4256, 4268, 4280, 4292, 4304, 4316, 4328, 4340,
                            4352, 4364, 4376, 4388, 4400, 4412, 4424, 4457, 4470, 4483);

    -- Former Employee Compensation
    UPDATE costswage
    SET costamount = basepay * v_formeremp
    WHERE costelementid IN (4228, 4240, 4252, 973, 4264, 4276, 983, 4288, 4300, 4312, 4324, 993, 4336, 4348, 4360,
                            4372, 4384, 4396, 4408, 4420, 4432, 4466, 4479, 4492);

    -- Avg Cost of Army-Funded Retirement
    UPDATE costswage
    SET costamount = basepay * v_armyret
    WHERE costelementid IN (4221, 4233, 4245, 633, 4257, 4269, 640, 4281, 4293, 4305, 4317, 647, 4329, 4341, 4353,
                            4365, 4377, 4389, 4401, 4413, 4425, 4458, 4471, 4484);

    -- OSD CAPE DODI: Training
    UPDATE costswage
    SET costamount = v_training
    WHERE costelementid IN (4231, 4243, 4255, 756, 4267, 4279, 763, 4291, 4303, 4315, 4327, 749, 4339, 4351, 4363,
                            4375, 4387, 4399, 4411, 4423, 4435, 4469, 4482, 4495);

    -- Bring in pay-plan title (external join; target self-alias dropped)
    UPDATE costswage t
    SET payplantitle = b.displaytitle
    FROM lookup.payplan b
    WHERE t.payplan = b.payplan
      AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- Set occupational group number
    UPDATE costswage
    SET occupationalgroupnumber = left(occupationalseriesnumber, 2) || '00'
    WHERE occupationalseriesnumber <> '-1';

    UPDATE costswage
    SET occupationalgroupnumber = '-1'
    WHERE occupationalseriesnumber = '-1';

    -- Bring in wage area (external join; target self-alias dropped)
    UPDATE costswage t
    SET wagearea = b.wagearea
    FROM lookup.wagearea b
    WHERE t.schedulearea = b.schedulearea
      AND t.fundtype = b.fundtype;

    IF NOT p_debug THEN
        /* Clear existing values (incl. averages) for this version */
        DELETE FROM crunch.costs_wage WHERE amcosversionid = p_amcosversionid;

        /* Insert actual costs (exclude fill-in rows). GradeType := PayPlan. */
        INSERT INTO crunch.costs_wage
            (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid, locationid, numberofdependents)
        SELECT payplan,
               occupationalgroupnumber,
               occupationalseriesnumber,
               wagearea,
               schedulearea,
               costelementid,
               payplan,
               gradelevel,
               costamount,
               v_crunchtime,
               amcosversionid,
               locationid,
               numberofdependents
        FROM costswage
        WHERE datasource = 'Inventory';

        /* Average by PayPlan, OccupationalGroupNumber, OccupationalSeriesNumber
           (location non-specific; exclude fill-in rows) */
        INSERT INTO crunch.costs_wage
            (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid, locationid, numberofdependents)
        SELECT payplan,
               occupationalgroupnumber,
               occupationalseriesnumber,
               '-1' AS wagearea,
               '-1' AS wageschedule,
               costelementid,
               payplan,
               gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0) AS amount,
               v_crunchtime,
               amcosversionid,
               -1 AS locationid,
               v_numberofdependentsaverage
        FROM costswage
        WHERE datasource = 'Inventory'
          AND numberofdependents IN (v_numberofdependentsconus, v_numberofdependentsoconus)
        GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid, gradelevel, amcosversionid;

        /* Average by PayPlan, OccupationalGroupNumber (location non-specific) */
        INSERT INTO crunch.costs_wage
            (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid, locationid, numberofdependents)
        SELECT payplan,
               occupationalgroupnumber,
               '-1' AS occupationalseriesnumber,
               '-1' AS wagearea,
               '-1' AS wageschedule,
               costelementid,
               payplan,
               gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0) AS amount,
               v_crunchtime,
               amcosversionid,
               -1 AS locationid,
               v_numberofdependentsaverage
        FROM costswage
        WHERE datasource = 'Inventory'
          AND numberofdependents IN (v_numberofdependentsconus, v_numberofdependentsoconus)
        GROUP BY payplan, occupationalgroupnumber, costelementid, gradelevel, amcosversionid;

        /* Average by PayPlan, OccupationalGroupNumber (location-specific) */
        INSERT INTO crunch.costs_wage
            (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid, locationid, numberofdependents)
        SELECT payplan,
               occupationalgroupnumber,
               '-1' AS occupationalseriesnumber,
               '-1' AS wagearea,
               '-1' AS wageschedule,
               costelementid,
               payplan,
               gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0) AS amount,
               v_crunchtime,
               amcosversionid,
               locationid,
               numberofdependents
        FROM costswage
        WHERE datasource = 'Inventory'
        GROUP BY payplan, occupationalgroupnumber, costelementid, gradelevel, amcosversionid, locationid, numberofdependents;

        /* Average by PayPlan (location non-specific) */
        INSERT INTO crunch.costs_wage
            (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid, locationid, numberofdependents)
        SELECT payplan,
               '-1' AS occupationalgroupnumber,
               '-1' AS occupationalseriesnumber,
               '-1' AS wagearea,
               '-1' AS wageschedule,
               costelementid,
               payplan,
               gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0) AS amount,
               v_crunchtime,
               amcosversionid,
               -1 AS locationid,
               v_numberofdependentsaverage
        FROM costswage
        WHERE datasource = 'Inventory'
          AND numberofdependents IN (v_numberofdependentsconus, v_numberofdependentsoconus)
        GROUP BY payplan, costelementid, gradelevel, amcosversionid;

        /* Average by PayPlan (location-specific) */
        INSERT INTO crunch.costs_wage
            (payplan, occupationalgroupnumber, occupationalseriesnumber, wagearea, wageschedule,
             costelementid, gradetype, gradelevel, amount, crunchtime, amcosversionid, locationid, numberofdependents)
        SELECT payplan,
               '-1' AS occupationalgroupnumber,
               '-1' AS occupationalseriesnumber,
               '-1' AS wagearea,
               '-1' AS wageschedule,
               costelementid,
               payplan,
               gradelevel,
               SUM(costamount * inventory) / NULLIF(SUM(inventory), 0) AS amount,
               v_crunchtime,
               amcosversionid,
               locationid,
               numberofdependents
        FROM costswage
        WHERE datasource = 'Inventory'
        GROUP BY payplan, costelementid, gradelevel, amcosversionid, locationid, numberofdependents;

        -- zeros were kept only to weight the averages correctly; drop them now
        DELETE FROM crunch.costs_wage
        WHERE amount = 0
          AND amcosversionid = p_amcosversionid;
    END IF;

    DROP TABLE IF EXISTS payplans;
    DROP TABLE IF EXISTS wageinventory;
    DROP TABLE IF EXISTS payandinventory;
    DROP TABLE IF EXISTS costswage;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchgfebs  (Wave-3 port of crunch.CrunchGFEBS)
--
-- GFEBS civilian cost crunch for the GFEBS-based pay plans (D/N/GP series,
-- AD/CA/EE/EF/EX/IP/IE/IG/SL/ST/ZZ, ...). Reads "load_GFEBS".cleaned pay
-- records, validates them against the pay schedules, writes headcount to
-- crunch.inventory_gfebs, then computes every civilian cost element and writes
-- the rolled-up costs to crunch.costs_gfebs.
--
-- Faithful structural port. Conventions applied:
--   * p_debug boolean DEFAULT false; p_debug = true is a DRY RUN (all
--     DELETE/INSERT writes guarded by "IF NOT p_debug"). @Debug=1 result-set
--     dumps dropped (no runtime effect). Bare "SELECT 'TEST...'" dumps dropped.
--   * #temp -> CREATE TEMP TABLE (DROP IF EXISTS first and at proc end).
--   * "UPDATE #Cost a FROM #Cost a JOIN x b" self-target rewritten to
--     "UPDATE costs SET .. FROM x b WHERE .." (PG forbids re-aliasing target).
--   * T-SQL PIVOT(MAX(Rate) FOR Step IN([1],[10])) -> GROUP BY key columns with
--     MAX(rate) FILTER (WHERE step=1/10).
--   * PERCENTILE_CONT(..) OVER(..) window (invalid in PG) -> GROUP BY aggregate
--     joined back to the row set.
--   * ISNULL->COALESCE, GETDATE()->now()::timestamp, BIT->boolean,
--     NVARCHAR->varchar, TINYINT->smallint. Case-sensitive schemas quoted.
--   * Count/inventory denominators wrapped in NULLIF(..,0) (behavior-preserving).
--   * The #Cost temp table is named "costs" so the plain "cost" column is never
--     ambiguous with a table name inside self-referencing subqueries.
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchgfebs(
    p_amcosversionid integer DEFAULT -1,
    p_crunchtime timestamp DEFAULT NULL,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime                 timestamp := COALESCE(p_crunchtime, now()::timestamp);
    -- Could just use zero but this allows for a huge negative number for testing
    v_zerovalue                  integer := 0;
    -- GFEBS uses 2080: amountpaid*26 / hourlyrate = 2080
    v_annualhours                numeric(18, 2) := 2080;
    v_percentilelimit            numeric(4, 2);
    v_percentcivcashawards       numeric(18, 4);
    v_percentsocialsecurity      numeric(9, 8);
    v_max_wage_ssw               numeric(6, 0);
    v_maxsocialsecuritydeduction numeric(18, 2);
    v_medicare                   numeric(18, 4);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    DROP TABLE IF EXISTS workinprogress;
    CREATE TEMP TABLE workinprogress (
        payplan                  varchar(3)   NOT NULL,
        occupationalgroupnumber  varchar(4)   NOT NULL,
        occupationalseriesnumber varchar(4)   NOT NULL,
        country                  varchar(50)  NOT NULL,
        uicucformanpower         varchar(50)  NULL,
        strl                     varchar(20)  NOT NULL DEFAULT '-1',
        strlname                 varchar(200) NOT NULL DEFAULT '-1',
        gradelevel               smallint     NOT NULL,
        payperiodenddate         date         NOT NULL,
        personnelnumber          varchar(10)  NOT NULL,
        costelementcode          varchar(50)  NOT NULL,
        amountpaid               numeric(18, 4) NULL,
        paidhours                numeric(18, 4) NULL,
        actualhourlyrate         numeric(18, 4) NULL,
        originalhourlyrate       numeric(18, 4) NULL,
        localitycode             varchar(6)   NULL,
        localityrate             numeric(18, 2) NULL,
        payschedulemin           numeric(18, 4) NULL,
        payschedulemax           numeric(18, 4) NULL,
        locationid               integer      NULL,
        amcosversionid           integer      NOT NULL,
        excluderecord            boolean      NOT NULL DEFAULT false,
        step                     integer      NOT NULL
    );

    INSERT INTO workinprogress
        (payplan, occupationalgroupnumber, occupationalseriesnumber, country,
         uicucformanpower, localitycode, gradelevel, payperiodenddate,
         personnelnumber, costelementcode, amountpaid, paidhours,
         actualhourlyrate, originalhourlyrate, amcosversionid, step)
    SELECT payplan,
           occupationalgroupnumber,
           occupationalseriesnumber,
           country,
           uicucformanpower,
           localitycode,
           gradelevel,
           payperiodenddate,
           personnelnumber,
           costelementcode,
           SUM(amountpaid)         AS amountpaid,
           SUM(paidhours)          AS paidhours,
           MAX(actualhourlyrate)   AS maxrate,
           MAX(actualhourlyrate)   AS maxrate,
           amcosversionid,
           COALESCE(step::int, -1)
    FROM "load_GFEBS".cleaned
    WHERE amcosversionid = p_amcosversionid
    GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber, country,
             uicucformanpower, localitycode, activitytypecode, gradelevel, step,
             payperiodenddate, personnelnumber, costelementcode, amcosversionid;

    -- bring in STRL for D series plans (strl starts '-1', so inner-join update ok)
    UPDATE workinprogress
    SET strl = b.strl,
        strlname = b.strlname
    FROM xwalk.uictostrl AS b
    WHERE left(workinprogress.uicucformanpower, 4) = b.uic
      AND workinprogress.amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
      AND workinprogress.payplan LIKE 'D%';

    -- delete data for unknown STRLs
    DELETE FROM workinprogress
    WHERE strlname = 'Unknown'
      AND payplan LIKE 'D%';

    -- bring in locality pay amount
    UPDATE workinprogress
    SET localityrate = b.localityrate
    FROM "PaySchedule".localitypay AS b
    WHERE workinprogress.localitycode = b.localitycode
      AND workinprogress.amcosversionid = b.amcosversionid
      AND workinprogress.localitycode <> '-1';

    -- bring in locality pay area location data
    UPDATE workinprogress
    SET locationid = b.locationid
    FROM warehouse.location AS b
    WHERE workinprogress.localitycode = b.sourcesystemcode
      AND b.locationtype = 'Locality Pay Area'
      AND workinprogress.localitycode <> '-1';

    -- bring in Country location data
    UPDATE workinprogress
    SET locationid = b.locationid
    FROM warehouse.location AS b
    WHERE workinprogress.country = b.sourcesystemcode
      AND b.locationtype = 'GFEBS Country'
      AND workinprogress.locationid IS NULL
      AND workinprogress.country <> '-1';

    -- abort if any D-series record is still missing an STRL
    IF EXISTS (
        SELECT 1
        FROM workinprogress
        WHERE payplan LIKE 'D%'
          AND (strl IS NULL OR strl = '-1')
    ) THEN
        RAISE EXCEPTION 'Missing UIC TO STRL. To fix add to xwalk.uictostrl. Use unknown if not known.';
    END IF;

    -- bring in payschedule data for D/N series (PIVOT -> FILTER on step 1/10)
    UPDATE workinprogress
    SET payschedulemin = b.step1rate,
        payschedulemax = b.step10rate
    FROM (
        SELECT payplan, locationid, strl, gradelevel,
               MAX(rate) FILTER (WHERE step = 1)  AS step1rate,
               MAX(rate) FILTER (WHERE step = 10) AS step10rate
        FROM data.payschedules
        WHERE amcosversionid = p_amcosversionid
          AND categorysubgroupcode = '-1'
          AND (payplan LIKE 'D%' OR payplan IN ('NK', 'NJ', 'NH'))
        GROUP BY payplan, locationid, strl, gradelevel
    ) AS b
    WHERE workinprogress.payplan = b.payplan
      AND workinprogress.locationid = b.locationid
      AND workinprogress.strl = b.strl
      AND workinprogress.gradelevel = b.gradelevel
      AND workinprogress.costelementcode = '6100.11B1';

    -- bring in payschedule data for GP (PIVOT -> FILTER; join has no locationid)
    UPDATE workinprogress
    SET payschedulemin = b.step1rate,
        payschedulemax = b.step10rate
    FROM (
        SELECT payplan, locationid, strl, gradelevel,
               MAX(rate) FILTER (WHERE step = 1)  AS step1rate,
               MAX(rate) FILTER (WHERE step = 10) AS step10rate
        FROM data.payschedules
        WHERE amcosversionid = p_amcosversionid
          AND categorysubgroupcode = '-1'
          AND payplan = 'GP'
        GROUP BY payplan, locationid, strl, gradelevel
    ) AS b
    WHERE workinprogress.payplan = b.payplan
      AND workinprogress.strl = b.strl
      AND workinprogress.gradelevel = b.gradelevel
      AND workinprogress.costelementcode = '6100.11B1';

    -- bring in the pay schedule for some pay plans which don't vary by locationid
    UPDATE workinprogress
    SET payschedulemin = CASE
                             WHEN workinprogress.payplan IN ('IE', 'IP', 'ST', 'SL') THEN 0
                             ELSE b.rate
                         END,
        payschedulemax = b.rate
    FROM (
        SELECT * FROM data.payschedules p
        WHERE p.amcosversionid = p_amcosversionid
          AND p.payplan IN ('EX', 'IG', 'IE', 'IP', 'SL', 'ST')
          AND p.ratetype = 'Annual'
    ) AS b
    WHERE workinprogress.payplan = b.payplan
      AND workinprogress.strl = b.strl
      AND workinprogress.gradelevel = b.gradelevel
      AND workinprogress.costelementcode = '6100.11B1';

    -- these payschedules vary by locationid
    UPDATE workinprogress
    SET payschedulemin = CASE
                             WHEN workinprogress.payplan IN ('EE', 'EF') THEN 0
                             ELSE b.rate
                         END,
        payschedulemax = b.rate
    FROM (
        SELECT * FROM data.payschedules
        WHERE amcosversionid = p_amcosversionid
          AND payplan IN ('CA', 'EE', 'EF')
          AND ratetype = 'Annual'
    ) AS b
    WHERE workinprogress.payplan = b.payplan
      AND workinprogress.locationid = b.locationid
      AND workinprogress.strl = b.strl
      AND workinprogress.gradelevel = b.gradelevel
      AND workinprogress.costelementcode = '6100.11B1';

    -- pay just over the max is set to the max
    UPDATE workinprogress
    SET actualhourlyrate = payschedulemax / v_annualhours
    WHERE costelementcode = '6100.11B1'
      AND (actualhourlyrate * v_annualhours) > payschedulemax
      AND ((actualhourlyrate * v_annualhours) / payschedulemax) <= 1.025;

    -- pay just under the min is set to the min
    -- NOTE: preserved source behavior - comment says "min" but the source assigns
    --       payschedulemax / v_annualhours here (kept verbatim).
    UPDATE workinprogress
    SET actualhourlyrate = payschedulemax / v_annualhours
    WHERE costelementcode = '6100.11B1'
      AND actualhourlyrate * v_annualhours < payschedulemin
      AND (actualhourlyrate * v_annualhours) / payschedulemin >= 0.975;

    -- when the annualized max hourly rate is outside the bounds of known pay
    -- schedules we exclude that record so it can't skew the numbers
    UPDATE workinprogress
    SET excluderecord = true
    WHERE costelementcode = '6100.11B1'
      AND payplan NOT IN ('AD', 'ZZ', 'EX', 'EF', 'EE')
      AND (
          ROUND(CAST(actualhourlyrate AS decimal(10, 4)) * v_annualhours, 0)::int
          NOT BETWEEN floor(payschedulemin) AND ceil(payschedulemax)
      );

    -- excluding a base-pay record must exclude the whole personnel record too
    UPDATE workinprogress
    SET excluderecord = true
    WHERE personnelnumber IN (
        SELECT DISTINCT personnelnumber
        FROM workinprogress
        WHERE excluderecord = true
    );

    -- D/N series do not get market pay (6100.11T0); exclude those records.
    -- Source used a FROM-less correlated subquery equivalent to this direct
    -- row predicate (personnelnumber IN (its own value) is true iff the row
    -- matches payplan LIKE 'D%' AND costelementcode='6100.11T0').
    UPDATE workinprogress
    SET excluderecord = true
    WHERE payplan LIKE 'D%'
      AND costelementcode = '6100.11T0';

    -- delete all records that now need to be excluded
    DELETE FROM workinprogress
    WHERE personnelnumber IN (
        SELECT DISTINCT personnelnumber
        FROM workinprogress
        WHERE excluderecord = true
    );

    -- the records we are going to use for cost calculations go right into inventory
    IF NOT p_debug THEN
        DELETE FROM crunch.inventory_gfebs
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.inventory_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid,
             strl, gradetype, gradelevel, step, yos, inventory, amcosversionid)
        SELECT payplan,
               occupationalgroupnumber,
               occupationalseriesnumber,
               locationid,
               strl,
               gradetype,
               gradelevel,
               step,
               -1,
               SUM(inventory),
               p_amcosversionid
        FROM (
            SELECT DISTINCT
                   personnelnumber,
                   payplan,
                   occupationalgroupnumber,
                   occupationalseriesnumber,
                   locationid,
                   strl,
                   payplan AS gradetype,
                   gradelevel,
                   step,
                   1 AS inventory
            FROM workinprogress
            WHERE (costelementcode = '6100.11B1' AND payplan <> 'AD')
               OR (costelementcode IN ('6100.11B1', '6100.11B3')
                   AND payplan IN ('AD', 'EF', 'EE', 'IP'))
        ) AS a
        GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber,
                 locationid, strl, gradetype, gradelevel, step;
    END IF;

    DROP TABLE IF EXISTS costs;
    CREATE TEMP TABLE costs (
        payplan                  varchar(3)   NOT NULL,
        occupationalgroupnumber  varchar(4)   NOT NULL,
        occupationalseriesnumber varchar(4)   NOT NULL,
        country                  varchar(50)  NULL,
        strl                     varchar(20),
        strlname                 varchar(200) NULL,
        gradelevel               smallint     NOT NULL,
        localitycode             varchar(50)  NULL,
        cost                     numeric(18, 4) NULL,
        personnelcount           integer      NULL,
        locationname             varchar(100) NULL,
        costelementid            integer      NOT NULL,
        costelementcategory      varchar(50)  NOT NULL,
        costelementname          varchar(250) NOT NULL,
        locationid               integer      NULL,
        inventory                integer      NULL,
        locationtype             varchar(100) NULL
    );

    INSERT INTO costs
        (payplan, occupationalgroupnumber, occupationalseriesnumber, strl,
         gradelevel, costelementid, costelementcategory, costelementname,
         locationid, inventory)
    SELECT a.payplan,
           a.occupationalgroupnumber,
           a.occupationalseriesnumber,
           a.strl,
           a.gradelevel,
           b.costelementid,
           b.costelementcategory,
           b.costelementname,
           a.locationid,
           a.inventory
    FROM (
        SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, strl,
               gradelevel, locationid, SUM(inventory) AS inventory
        FROM crunch.inventory_gfebs
        WHERE amcosversionid = p_amcosversionid
        GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber, strl,
                 gradelevel, locationid
    ) AS a
    INNER JOIN lookup.costelement AS b
        ON a.payplan = b.payplan
       AND p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- bring in the location display/type for locality acronyms
    UPDATE costs
    SET locationname = b.displayname,
        locationtype = b.locationtype
    FROM warehouse.location AS b
    WHERE costs.locationid = b.locationid;

    -- base pay rules (BIT -> boolean); locality/_11b1/_11b3 map 1->true, 0->false
    DROP TABLE IF EXISTS ppbasepayrules;
    CREATE TEMP TABLE ppbasepayrules (
        payplan   varchar(2)  NULL,
        locality  boolean     NULL,
        _11b1     boolean     NULL,
        _11b3     boolean     NULL,
        frequency varchar(20) NULL
    );
    INSERT INTO ppbasepayrules (payplan, locality, _11b1, _11b3, frequency)
    VALUES ('DB', true,  true, false, 'annual'),
           ('DE', true,  true, false, 'annual'),
           ('DJ', true,  true, false, 'annual'),
           ('DK', true,  true, false, 'annual'),
           ('NH', true,  true, false, 'annual'),
           ('NJ', true,  true, false, 'annual'),
           ('NK', true,  true, false, 'annual'),
           ('GP', false, true, false, 'annual'),
           ('AD', false, true, true,  'annual'),
           ('CA', true,  true, false, 'annual'),
           ('EE', false, true, true,  'hourly'),
           ('EF', false, true, true,  'hourly'),
           ('EX', false, true, false, 'annual'),
           ('IP', false, true, false, 'annual'),
           ('IE', false, true, false, 'annual'),
           ('IG', false, true, false, 'annual'),
           ('SL', false, true, false, 'annual'),
           ('ST', false, true, false, 'annual'),
           ('ZZ', false, true, false, 'annual');

    v_percentilelimit := crunch.getsinglevalue('GFEBS', 'PercentileLimit', p_amcosversionid);

    --#######################################
    -- Base Pay and Locality Pay Section
    --#######################################

    -- base pay for records who get locality
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
               AVG(amountpaid) / (1 + MAX(localityrate) / 100) AS amountpaid,
               SUM(personnelcount) AS personnelcount
        FROM (
            SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
                   personnelnumber,
                   CASE
                       WHEN payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                           THEN MAX(actualhourlyrate) * v_annualhours
                       ELSE MAX(actualhourlyrate)
                   END AS amountpaid,
                   1 AS personnelcount,
                   MAX(localityrate) AS localityrate
            FROM workinprogress
            WHERE (
                      (costelementcode = '6100.11B1'
                       AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b1 AND locality))
                      OR
                      (costelementcode = '6100.11B3'
                       AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b3 AND locality))
                  )
              AND personnelnumber NOT IN (
                  SELECT DISTINCT personnelnumber
                  FROM workinprogress
                  WHERE costelementcode IN ('6100.11T0', '6100.11J0', '6100.12B0')
              )
              AND localitycode <> '-1'
            GROUP BY payplan, occupationalseriesnumber, personnelnumber, country, strl,
                     gradelevel, locationid
        ) AS x
        GROUP BY payplan, occupationalseriesnumber, country, strl, gradelevel, locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE (costelementname LIKE '%6100.11B1%' OR costelementname LIKE '%6100.11B3%')
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- locality pay
    UPDATE costs
    SET cost = b.amount,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.strl, a.gradelevel, a.locationid,
               a.cost * (b.localityrate / 100) AS amount,
               a.personnelcount
        FROM costs AS a
        INNER JOIN (SELECT DISTINCT locationid, localityrate FROM workinprogress) AS b
            ON a.locationid = b.locationid
        WHERE (
                  (a.costelementname LIKE '%6100.11B1%'
                   AND a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b1 AND locality))
                  OR
                  (a.costelementname LIKE '%6100.11B3%'
                   AND a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b3 AND locality))
              )
          AND COALESCE(a.cost, 0) > 0
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.locationid = b.locationid
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname = 'Civ Locality Pay'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- base pay for everyone else is just the amount from GFEBS
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
               AVG(amountpaid) AS amountpaid,
               SUM(personnelcount) AS personnelcount
        FROM (
            SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
                   CASE
                       WHEN payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                           THEN MAX(actualhourlyrate) * v_annualhours
                       ELSE MAX(actualhourlyrate)
                   END AS amountpaid,
                   1 AS personnelcount
            FROM workinprogress
            GROUP BY payplan, occupationalseriesnumber, personnelnumber, country, strl,
                     gradelevel, locationid
        ) AS x
        GROUP BY payplan, occupationalseriesnumber, country, strl, gradelevel, locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE (costs.costelementname LIKE '%6100.11B1%' OR costs.costelementname LIKE '%6100.11B3%')
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      )
      AND costs.cost IS NULL;

    --#######################################
    -- Amount Paid Annualized (*26) CEs
    --#######################################

    -- Civilian Overseas Allowances (6100.12B0)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.12B0'
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costs.costelementname LIKE '%6100.12B%'
            AND costs.payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Civilian Physician Comparability Pay (6100.11T0)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.11T0'
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costs.costelementname LIKE '%6100.11T0%'
            AND costs.payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Civilian Hazardous Duty Pay (6100.11H0)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
               AVG(amountpaid) * 26 AS amountpaid,
               COUNT(DISTINCT personnelnumber) AS personnelcount
        FROM workinprogress
        WHERE costelementcode = '6100.11H0'
        GROUP BY payplan, occupationalseriesnumber, country, strl, gradelevel, locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costs.costelementname LIKE '%6100.11H0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- FEGLI (6400.12K0), excludes EE/EF (experts/consultants ineligible per DoD reg)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6400.12K0'
          AND a.payplan NOT IN ('EE', 'EF')
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costs.costelementname LIKE '%6400.12K0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- fill missing 12K with a grade-level average
    UPDATE costs
    SET cost = b.amount,
        personnelcount = 1
    FROM (
        SELECT payplan, gradelevel,
               SUM(cost * personnelcount) / NULLIF(SUM(personnelcount), 0) AS amount
        FROM costs
        WHERE costelementid IN (
                  SELECT costelementid FROM lookup.costelement
                  WHERE costelementname LIKE '%6400.12K0%'
                    AND payplan IN (SELECT payplan FROM ppbasepayrules)
              )
          AND COALESCE(cost, 0) > 0
        GROUP BY payplan, gradelevel
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.gradelevel = b.gradelevel
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6400.12K0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      )
      AND COALESCE(costs.cost, 0) = 0;

    -- Medical Premium Pay (6100.11N0)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.11N0'
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.11N0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Non-foreign COLA (6100.12C0); only for locality-pay-area locations
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.12C0'
          AND a.locationid IN (
              SELECT lb.locationid
              FROM "PaySchedule".localitypay AS la
              INNER JOIN warehouse.location AS lb
                  ON la.localitycode = lb.sourcesystemcode
                 AND lb.locationtype = 'Locality Pay Area'
              WHERE p_amcosversionid = la.amcosversionid
          )
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.locationid = b.locationid
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.12C0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Other Benefits (6100.12S2); outliers above the percentile cap are dropped.
    -- Source used PERCENTILE_CONT(..) OVER(PARTITION BY ce,gl,pp); PG has no such
    -- window, so the percentile is computed as a GROUP BY aggregate joined back.
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.12S2'
          AND a.personnelnumber NOT IN (
              SELECT personnelnumber
              FROM (
                  SELECT src.personnelnumber,
                         src.amountpaid,
                         grp.cap
                  FROM "load_GFEBS".cleaned AS src
                  INNER JOIN (
                      SELECT costelementcode, gradelevel, payplan,
                             percentile_cont(v_percentilelimit) WITHIN GROUP (ORDER BY amountpaid) AS cap
                      FROM "load_GFEBS".cleaned
                      WHERE costelementcode IN ('6100.12S2')
                        AND amcosversionid BETWEEN p_amcosversionid - 200 AND p_amcosversionid
                      GROUP BY costelementcode, gradelevel, payplan
                  ) AS grp
                      ON grp.costelementcode = src.costelementcode
                     AND grp.gradelevel = src.gradelevel
                     AND grp.payplan = src.payplan
                  WHERE src.costelementcode IN ('6100.12S2')
                    AND src.amcosversionid BETWEEN p_amcosversionid - 200 AND p_amcosversionid
              ) AS cap_calc
              WHERE amountpaid > cap
          )
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.12S2%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Civilian Supervisory Special Pay (6100.11Q0)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.11Q0'
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.11Q0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Civilian Post Differential Pay (6100.11J0)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6100.11J0'
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.11J0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    --#######################################
    -- Single Value Fixed Amount Section
    --#######################################

    -- Civilian Post Retirement Health (single value; divisor stays 1)
    UPDATE costs
    SET cost = crunch.getsinglevalue('GP', 'postRetirementHealth', p_amcosversionid),
        personnelcount = 1,
        inventory = 1
    WHERE costelementid IN (
              SELECT costelementid FROM lookup.costelement
              WHERE costelementname LIKE '%Post Retirement health insurance%'
                AND payplan IN (SELECT payplan FROM ppbasepayrules)
          )
      AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual');

    -- Civilian Post Retirement Life Insurance (single value)
    UPDATE costs
    SET cost = crunch.getsinglevalue('GP', 'postRetirementLifeInsurance', p_amcosversionid),
        personnelcount = 1,
        inventory = 1
    WHERE costelementid IN (
              SELECT costelementid FROM lookup.costelement
              WHERE costelementname LIKE '%post retirement life insurance%'
                AND payplan IN (SELECT payplan FROM ppbasepayrules)
          )
      AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual');

    -- Civilian Training (single value)
    UPDATE costs
    SET cost = crunch.getsinglevalue('GP', 'training', p_amcosversionid),
        personnelcount = 1,
        inventory = 1
    WHERE costelementid IN (
              SELECT costelementid FROM lookup.costelement
              WHERE costelementname LIKE '%training%'
                AND payplan IN (SELECT payplan FROM ppbasepayrules)
          )
      AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual');

    v_percentcivcashawards := crunch.getsinglevalue('GP', 'percentCivCashAwards', p_amcosversionid) / 100;

    -- Cash Awards: pay plans with their own cash-award value first
    UPDATE costs
    SET cost = c.cashawards * b.totalbase,
        personnelcount = b.personnelcount
    FROM (
        SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
               MAX(personnelcount) AS personnelcount,
               SUM(cost) AS totalbase
        FROM costs
        WHERE costelementid IN (
                  SELECT costelementid FROM lookup.costelement
                  WHERE (costelementname LIKE '%cash award%'
                         OR costelementname LIKE '%base%'
                         OR costelementname LIKE '%locality%'
                         OR costelementname LIKE '%hourly%')
                    AND payplan IN (SELECT payplan FROM ppbasepayrules)
                    AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
              )
        GROUP BY payplan, occupationalseriesnumber, country, strl, gradelevel, locationid
    ) AS b,
    (
        SELECT payplan, paramvalue AS cashawards
        FROM dataload.singlevalues
        WHERE paramname = 'CashAwards'
          AND p_amcosversionid = amcosversionid
          AND payplan IN (SELECT payplan FROM ppbasepayrules)
    ) AS c
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND c.payplan = costs.payplan
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.11K0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- Cash Awards: default percentage for everyone not touched above
    UPDATE costs
    SET cost = b.amountpaid * v_percentcivcashawards,
        personnelcount = b.personnelcount
    FROM (
        SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
               AVG(amountpaid) * 26 AS amountpaid,
               COUNT(DISTINCT personnelnumber) AS personnelcount
        FROM workinprogress
        WHERE (
                  (costelementcode = '6100.11B1'
                   AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b1))
                  OR (costelementcode = '6100.11B3'
                      AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b3))
                  OR costelementcode = '6100.11T0'
              )
          AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
        GROUP BY payplan, occupationalseriesnumber, country, strl, gradelevel, locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.11K0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      )
      AND costs.cost IS NULL;

    --#######################################
    -- More Complex Calculations Section
    --#######################################

    -- Civilian Employer Share Retirement (6100.12Y%)
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT payplan, occupationalseriesnumber, country, strl, gradelevel, locationid,
               AVG(amountpaid) * 26 AS amountpaid,
               COUNT(DISTINCT personnelnumber) AS personnelcount
        FROM workinprogress
        WHERE costelementcode IN ('6100.12Y0', '6400.12L0', '6400.12M0', '6400.12X0')
          AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
        GROUP BY payplan, occupationalseriesnumber, country, strl, gradelevel, locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.12Y%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- fill missing 12Y with a grade-level average
    UPDATE costs
    SET cost = b.amount,
        personnelcount = 1
    FROM (
        SELECT payplan, gradelevel,
               SUM(cost * personnelcount) / NULLIF(SUM(personnelcount), 0) AS amount
        FROM costs
        WHERE costelementid IN (
                  SELECT costelementid FROM lookup.costelement
                  WHERE costelementname LIKE '%6100.12Y%'
                    AND payplan IN (SELECT payplan FROM ppbasepayrules)
              )
          AND COALESCE(cost, 0) > 0
        GROUP BY payplan, gradelevel
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.gradelevel = b.gradelevel
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6100.12Y%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      )
      AND COALESCE(costs.cost, 0) = 0;

    -- FEHB (6400.12N0); the paid-hours join keeps only >= 65 hr personnel
    UPDATE costs
    SET cost = b.amountpaid,
        personnelcount = b.personnelcount
    FROM (
        SELECT a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid,
               CASE
                   WHEN a.payplan IN (SELECT payplan FROM ppbasepayrules WHERE frequency = 'annual')
                       THEN AVG(a.amountpaid) * 26
                   ELSE COALESCE(SUM(a.amountpaid) / NULLIF(SUM(b.paidhours), 0), v_zerovalue)
               END AS amountpaid,
               COUNT(DISTINCT a.personnelnumber) AS personnelcount
        FROM workinprogress AS a
        LEFT OUTER JOIN (
            SELECT personnelnumber, SUM(paidhours) AS paidhours
            FROM workinprogress
            WHERE costelementcode IN ('6100.11B1', '6100.11B3')
            GROUP BY personnelnumber
            HAVING SUM(paidhours) >= 65
        ) AS b ON b.personnelnumber = a.personnelnumber
        WHERE a.costelementcode = '6400.12N0'
        GROUP BY a.payplan, a.occupationalseriesnumber, a.country, a.strl, a.gradelevel, a.locationid
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6400.12N0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- fill missing 12N with a grade-level average
    UPDATE costs
    SET cost = b.amount,
        personnelcount = 1
    FROM (
        SELECT payplan, gradelevel,
               SUM(cost * personnelcount) / NULLIF(SUM(personnelcount), 0) AS amount
        FROM costs
        WHERE costelementid IN (
                  SELECT costelementid FROM lookup.costelement
                  WHERE costelementname LIKE '%6400.12N0%'
                    AND payplan IN (SELECT payplan FROM ppbasepayrules)
              )
          AND COALESCE(cost, 0) > 0
        GROUP BY payplan, gradelevel
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.gradelevel = b.gradelevel
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6400.12N0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      )
      AND COALESCE(costs.cost, 0) = 0;

    -- FICA (6400.12Q0): capped Social Security + uncapped Medicare on total pay
    v_percentsocialsecurity      := crunch.getsinglevalue('AA', 'PercentSocialSecurity', p_amcosversionid);
    v_max_wage_ssw               := crunch.getsinglevalue('AA', 'Max_Wage_SSW', p_amcosversionid);
    v_maxsocialsecuritydeduction := v_percentsocialsecurity * v_max_wage_ssw;
    v_medicare                   := crunch.getsinglevalue('AA', 'percentMedicare', p_amcosversionid);

    UPDATE costs
    SET cost = CASE
                   WHEN b.amountpaid * v_percentsocialsecurity > v_maxsocialsecuritydeduction
                       THEN v_maxsocialsecuritydeduction
                   ELSE b.amountpaid * v_percentsocialsecurity
               END + (b.amountpaid * v_medicare)
    FROM (
        SELECT payplan, occupationalseriesnumber, locationid, strl, gradelevel,
               COALESCE(SUM(cost), 0) AS amountpaid
        FROM costs
        WHERE costelementid IN (
                  SELECT costelementid FROM lookup.costelement
                  WHERE (costelementname LIKE '%6100.11B1%'
                         OR costelementname LIKE '%6100.11B3%'
                         OR costelementname LIKE '%locality%'
                         OR costelementname LIKE '%6100.11H0%'
                         OR costelementname LIKE '%6100.11J0%'
                         OR costelementname LIKE '%6100.11K0%'
                         OR costelementname LIKE '%6100.11N0%'
                         OR costelementname LIKE '%6100.11Q0%'
                         OR costelementname LIKE '%6100.11T0%'
                         OR costelementname LIKE '%6100.12B0%'
                         OR costelementname LIKE '%6100.12C0%')
                    AND payplan IN (SELECT payplan FROM ppbasepayrules)
              )
        GROUP BY payplan, occupationalseriesnumber, locationid, strl, gradelevel
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.gradelevel = b.gradelevel
      AND costs.strl = b.strl
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6400.12Q0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- FICA record count should equal the 11B1/11B3 base-pay record count
    UPDATE costs
    SET personnelcount = b.personnelcount
    FROM (
        SELECT * FROM costs
        WHERE (costelementname LIKE '%6100.11B1%'
               AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b1))
           OR (costelementname LIKE '%6100.11B3%'
               AND payplan IN (SELECT payplan FROM ppbasepayrules WHERE _11b3))
    ) AS b
    WHERE costs.payplan = b.payplan
      AND costs.occupationalseriesnumber = b.occupationalseriesnumber
      AND costs.locationid = b.locationid
      AND costs.strl = b.strl
      AND costs.gradelevel = b.gradelevel
      AND costs.costelementid IN (
          SELECT costelementid FROM lookup.costelement
          WHERE costelementname LIKE '%6400.12Q0%'
            AND payplan IN (SELECT payplan FROM ppbasepayrules)
      );

    -- zero out null costs (keep them + their inventory for correct averaging)
    UPDATE costs
    SET cost = 0
    WHERE cost IS NULL;

    -- remove only negative costs (zero costs are needed for averaging)
    DELETE FROM costs
    WHERE COALESCE(cost, 0) < 0;

    -- bring in country/locality acronym codes
    UPDATE costs
    SET localitycode = b.sourcesystemcode,
        country = '-1'
    FROM warehouse.location AS b
    WHERE b.locationid = costs.locationid
      AND b.locationtype = 'Locality Pay Area';

    UPDATE costs
    SET country = b.sourcesystemcode,
        localitycode = '-1'
    FROM warehouse.location AS b
    WHERE b.locationid = costs.locationid
      AND b.locationtype = 'GFEBS Country';

    IF NOT p_debug THEN
        DELETE FROM crunch.costs_gfebs
        WHERE amcosversionid = p_amcosversionid;

        -- series/location level costs
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, '-1',
               costelementid, gradelevel, locationid, strl, cost, v_crunchtime, p_amcosversionid,
               localitycode, country
        FROM costs
        WHERE cost > 0;

        -- series level costs without location
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, '-1',
               costelementid, gradelevel, -1, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, '-1', '-1'
        FROM costs
        WHERE cost > 0
        GROUP BY payplan, occupationalgroupnumber, occupationalseriesnumber,
                 costelementid, gradelevel, strl;

        -- group level costs by location (STRL kept in GROUP BY - D series vary by STRL)
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, occupationalgroupnumber, '-1', '-1',
               costelementid, gradelevel, locationid, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, localitycode, country
        FROM costs
        WHERE cost > 0
        GROUP BY payplan, occupationalgroupnumber, costelementid, gradelevel, locationid,
                 strl, localitycode, country;

        -- group level costs without location
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, occupationalgroupnumber, '-1', '-1',
               costelementid, gradelevel, -1, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, '-1', '-1'
        FROM costs AS a
        WHERE cost > 0
        GROUP BY payplan, occupationalgroupnumber, costelementid, gradelevel, strl;

        -- pay plan level costs without location
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, '-1', '-1', '-1',
               costelementid, gradelevel, -1, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, '-1', '-1-'
        FROM costs
        WHERE cost > 0
        GROUP BY payplan, costelementid, gradelevel, strl;

        -- pay plan level costs with location
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, '-1', '-1', '-1',
               costelementid, gradelevel, locationid, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, localitycode, country
        FROM costs
        WHERE cost > 0
        GROUP BY payplan, costelementid, gradelevel, locationid, strl, localitycode, country;

        -- career program level average costs without location
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, '-1', '-1', careerprogramnumber,
               costelementid, gradelevel, -1, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, '-1', '-1'
        FROM (
            SELECT a.*, b.careerprogramnumber
            FROM costs AS a
            INNER JOIN xwalk.occupationalseriestocareerprogram AS b
                ON b.occupationalseriesnumber = a.occupationalseriesnumber
            WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
        ) AS a
        WHERE cost > 0
        GROUP BY payplan, costelementid, gradelevel, strl, careerprogramnumber;

        -- career program level average costs with location
        INSERT INTO crunch.costs_gfebs
            (payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber,
             costelementid, gradelevel, locationid, strl, amount, crunchtime, amcosversionid,
             localitycode, country)
        SELECT payplan, '-1', '-1', careerprogramnumber,
               costelementid, gradelevel, locationid, strl,
               SUM(cost * inventory) / NULLIF(SUM(inventory), 0),
               v_crunchtime, p_amcosversionid, localitycode, country
        FROM (
            SELECT a.*, b.careerprogramnumber
            FROM costs AS a
            INNER JOIN xwalk.occupationalseriestocareerprogram AS b
                ON b.occupationalseriesnumber = a.occupationalseriesnumber
            WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend
        ) AS a
        WHERE cost > 0
        GROUP BY payplan, careerprogramnumber, costelementid, gradelevel, locationid,
                 strl, localitycode, country;

        -- get rid of the zero costs we allowed in to make averaging work correctly
        DELETE FROM crunch.costs_gfebs
        WHERE amount = 0
          AND amcosversionid = p_amcosversionid;
    END IF;

    DROP TABLE IF EXISTS workinprogress;
    DROP TABLE IF EXISTS costs;
    DROP TABLE IF EXISTS ppbasepayrules;
END;
$$;

------------------------------------------------------------------------------
-- crunch.CrunchSES  ->  crunch.crunchses
--   Average Cost factors for the Civilian Senior Executive Schedule (SES).
--   Source: AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchSES.sql
--
-- Faithful structural port (Phase 2 conventions):
--   * Source param order kept (@debug, @AmcosVersionId); @debug -> p_debug
--     boolean DEFAULT false (dry run: writes to crunch.costs_ses guarded by
--     "IF NOT p_debug"; the "IF @debug = 1" result-set dumps are dropped).
--   * #Costs_SES -> TEMP TABLE costs_ses_tmp (named distinctly so it does NOT
--     shadow the schema-qualified target crunch.costs_ses).
--   * All "UPDATE #Costs_SES ... FROM #Costs_SES a INNER JOIN other b" rewritten
--     to "UPDATE costs_ses_tmp t ... FROM other b WHERE <join>" (PG forbids
--     re-aliasing the UPDATE target in FROM). All were INNER-join updates, so the
--     FROM rewrite is exact. The FICA update's self-aggregating derived table
--     (CashCompensation) is kept as a subquery in FROM, which is legal.
--   * ISNULL->COALESCE, GETDATE()->now()::timestamp, NVARCHAR->varchar,
--     TINYINT->smallint, FLOAT->double precision, MONEY->numeric, [Group]->"group",
--     [Source]/[Count]->quoted "source"/"count". LEFT/RIGHT preserved lowercase.
--   * Every CostElementId and pay-plan literal ('SES','ES') preserved verbatim.
--   * The commented-out PaySchedule.PaySchedule_SES block in the source is dropped.
--   * PRESERVED SOURCE ODDITY: the PayPlan-level MAX branch selects "-SUM(count)"
--     (negated inventory). Kept verbatim (that row is later marked 'delete' since
--     inventory<=0, so it never reaches the final table).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchses(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mingl integer := 1;
    v_avggl integer := 2;
    v_maxgl integer := 3;
    v_ses_min integer;
    v_ses_max integer;

    v_fegli                 double precision;
    v_armyret               double precision;
    v_cashawards            double precision;
    v_feghi                 double precision;
    v_training              double precision;
    v_postretlifeins        double precision;
    v_postrethealthins      double precision;
    v_percentmedicare       double precision;
    v_percentsocialsecurity double precision;
    v_max_wage_ssw          numeric;
    v_groceries             double precision;
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    SELECT minpay INTO v_ses_min
    FROM "PaySchedule".opmsesraw
    WHERE ratetype = 'Annual' AND amcosversionid = p_amcosversionid;

    SELECT maxpay INTO v_ses_max
    FROM "PaySchedule".opmsesraw
    WHERE ratetype = 'Annual' AND amcosversionid = p_amcosversionid;

    DROP TABLE IF EXISTS costs_ses_tmp;
    CREATE TEMP TABLE costs_ses_tmp (
        payplan                  varchar(3)     NOT NULL,
        occupationalgroupnumber  varchar(4)     NOT NULL,
        occupationalseriesnumber varchar(4)     NOT NULL,
        costelementid            integer        NOT NULL,
        costelementname          varchar(150)   NOT NULL,
        costelementcategory      varchar(150)   NOT NULL,
        gradetype                varchar(3)     NOT NULL,
        gradelevel               smallint       NOT NULL,
        basepay                  numeric(18, 2) NOT NULL,
        costamount               numeric(18, 2) NOT NULL DEFAULT (-1000000),
        inventory                integer        NOT NULL,
        locationid               integer        NOT NULL,
        locationname             varchar(500)   NOT NULL,
        locationtype             varchar(500)   NOT NULL,
        locationcode             varchar(500)   NOT NULL,
        numberofdependents       integer        NOT NULL DEFAULT (-1),
        amcosversionid           integer        NOT NULL,
        "source"                 varchar(50)    NOT NULL
    );

    --############### Raw values are needed to compute min/max, so use the raw
    --## inventory file (load_inventory.wass_raw), not the processed inventory.
    INSERT INTO costs_ses_tmp
        (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid,
         costelementname, costelementcategory, gradetype, gradelevel, basepay,
         inventory, locationid, locationname, locationtype, locationcode,
         amcosversionid, "source")
    --## Series Level Values -- minimum
    SELECT 'SES',
           left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
           right('00' || a.occupationalseriesnumber::varchar(4), 4),
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_mingl,
           CASE WHEN MIN(a.sal_wag) < v_ses_min THEN v_ses_min ELSE MIN(a.sal_wag) END,
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY a.occupationalseriesnumber, b.costelementid, b.costelementname,
             b.costelementcategory, a.amcosversionid
    UNION
    --## Series Level Values -- average
    SELECT 'SES',
           left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
           right('00' || a.occupationalseriesnumber::varchar(4), 4),
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_avggl,
           AVG(CASE WHEN a.sal_wag < v_ses_min THEN v_ses_min
                    WHEN a.sal_wag > v_ses_max THEN v_ses_max
                    ELSE a.sal_wag END),
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY a.occupationalseriesnumber, b.costelementid, b.costelementname,
             b.costelementcategory, a.amcosversionid
    UNION
    --## Series Level Values -- max
    SELECT 'SES',
           left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
           right('00' || a.occupationalseriesnumber::varchar(4), 4),
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_maxgl,
           CASE WHEN MAX(a.sal_wag) > v_ses_max THEN v_ses_max ELSE MAX(a.sal_wag) END,
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY a.occupationalseriesnumber, b.costelementid, b.costelementname,
             b.costelementcategory, a.amcosversionid
    UNION
    --## Group Level Values -- minimum
    SELECT 'SES',
           left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
           '-1',
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_mingl,
           CASE WHEN MIN(a.sal_wag) < v_ses_min THEN v_ses_min ELSE MIN(a.sal_wag) END,
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
             b.costelementid, b.costelementname, b.costelementcategory, a.amcosversionid
    UNION
    --## Group Level Values -- average
    SELECT 'SES',
           left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
           '-1',
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_avggl,
           AVG(CASE WHEN a.sal_wag < v_ses_min THEN v_ses_min
                    WHEN a.sal_wag > v_ses_max THEN v_ses_max
                    ELSE a.sal_wag END),
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
             b.costelementid, b.costelementname, b.costelementcategory, a.amcosversionid
    UNION
    --## Group Level Values -- max
    SELECT 'SES',
           left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
           '-1',
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_maxgl,
           CASE WHEN MAX(a.sal_wag) > v_ses_max THEN v_ses_max ELSE MAX(a.sal_wag) END,
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY left(right('00' || a.occupationalseriesnumber::varchar(4), 4), 2) || '00',
             b.costelementid, b.costelementname, b.costelementcategory, a.amcosversionid
    UNION
    --## PayPlan Level Values -- minimum
    SELECT 'SES', '-1', '-1',
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_mingl,
           CASE WHEN MIN(a.sal_wag) < v_ses_min THEN v_ses_min ELSE MIN(a.sal_wag) END,
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY b.costelementid, b.costelementname, b.costelementcategory, a.amcosversionid
    UNION
    --## PayPlan Level Values -- average
    SELECT 'SES', '-1', '-1',
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_avggl,
           AVG(CASE WHEN a.sal_wag < v_ses_min THEN v_ses_min
                    WHEN a.sal_wag > v_ses_max THEN v_ses_max
                    ELSE a.sal_wag END),
           SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY b.costelementid, b.costelementname, b.costelementcategory, a.amcosversionid
    UNION
    --## PayPlan Level Values -- max (NOTE: source negates SUM(count); preserved verbatim)
    SELECT 'SES', '-1', '-1',
           b.costelementid, b.costelementname, b.costelementcategory,
           'SES', v_maxgl,
           CASE WHEN MAX(a.sal_wag) > v_ses_max THEN v_ses_max ELSE MAX(a.sal_wag) END,
           -SUM(a."count"), -1, 'na', 'na', 'na', a.amcosversionid, 'inventory'
    FROM load_inventory.wass_raw AS a
        CROSS JOIN (
            SELECT costelementid, costelementname, costelementcategory
            FROM lookup.costelement
            WHERE payplan = 'SES'
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS b
    WHERE a.payplan = 'ES' AND a.amcosversionid = p_amcosversionid
    GROUP BY b.costelementid, b.costelementname, b.costelementcategory, a.amcosversionid;

    -- now we insert foreign locations from the Dept of State
    INSERT INTO costs_ses_tmp
        (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid,
         costelementname, costelementcategory, gradetype, gradelevel, basepay,
         inventory, locationid, locationname, locationtype, locationcode,
         numberofdependents, amcosversionid, "source")
    SELECT a.payplan, a.occupationalgroupnumber, a.occupationalseriesnumber,
           a.costelementid, a.costelementname, a.costelementcategory,
           a.gradetype, a.gradelevel, a.basepay,
           0 AS inventory,
           e.locationid, e.displayname, e.locationtype, e.sourcesystemcode,
           d.numberofdependents, a.amcosversionid, 'fill in'
    FROM costs_ses_tmp AS a
        CROSS JOIN (
            SELECT DISTINCT dl.locationcode
            FROM lookup.doslocations AS dl
                LEFT OUTER JOIN (
                    SELECT locationcode,
                           CASE WHEN amt > 0 THEN 1 ELSE 0 END AS costs
                    FROM dataload.doslivingallowance
                    WHERE amcosversionid = p_amcosversionid
                    UNION
                    SELECT locationcode,
                           CASE WHEN dangerpay > 0 OR postallowance > 0 OR hardship > 0 THEN 1 ELSE 0 END AS costs
                    FROM dataload.dospostallowance
                    WHERE amcosversionid = p_amcosversionid
                ) AS bb ON dl.locationcode = bb.locationcode
            WHERE bb.costs = 1
        ) AS c
        CROSS JOIN (
            -- get number of possible dependents
            SELECT DISTINCT numberofdependents
            FROM dataload.militaryspendableincome
            WHERE amcosversionid = p_amcosversionid
        ) AS d
        LEFT OUTER JOIN warehouse.location AS e
            ON c.locationcode = e.sourcesystemcode
    WHERE e.locationtype = 'Civilian Overseas';

    -- next we bring in foreign inventory
    -- (INNER-join UPDATE..FROM; self-reference to the temp target dropped per PG rule)
    UPDATE costs_ses_tmp t
    SET inventory = b.inventory,
        "source"  = 'inventory'
    FROM data.inventory AS b
    WHERE t.payplan = b.payplan
      AND t.occupationalseriesnumber = b.categorysubgroupcode
      AND t.locationid = b.locationid
      AND t.numberofdependents <> -1; -- overseas location-based costs only

    -- remove non-inventory-based locations (keep 'all' rows without inventory)
    UPDATE costs_ses_tmp
    SET "source" = 'delete'
    WHERE inventory <= 0
      AND "source" <> 'inventory';

    -- if a locationid has no inventory under it, fill in the blanks at the 'all' level
    UPDATE costs_ses_tmp
    SET "source" = 'fill in'
    WHERE "source" = 'delete'
      AND occupationalgroupnumber = '-1'
      AND locationid NOT IN (
              SELECT DISTINCT locationid FROM costs_ses_tmp WHERE "source" = 'inventory'
          );

    DELETE FROM costs_ses_tmp
    WHERE "source" = 'delete';

    v_fegli                 := crunch.getsinglevalue('SES', 'FEGLI', p_amcosversionid);
    v_armyret               := crunch.getsinglevalue('SES', 'ArmyRet', p_amcosversionid);
    v_cashawards            := crunch.getsinglevalue('SES', 'CashAwards', p_amcosversionid);
    v_feghi                 := crunch.getsinglevalue('SES', 'FEGHI', p_amcosversionid);
    v_training              := crunch.getsinglevalue('AA', 'Training', p_amcosversionid);
    v_postretlifeins        := crunch.getsinglevalue('AA', 'PostRetLifeIns', p_amcosversionid);
    v_postrethealthins      := crunch.getsinglevalue('AA', 'PostRetHealthIns', p_amcosversionid);
    v_percentmedicare       := crunch.getsinglevalue('AA', 'percentMedicare', p_amcosversionid);
    v_percentsocialsecurity := crunch.getsinglevalue('AA', 'PercentSocialSecurity', p_amcosversionid);
    v_max_wage_ssw          := crunch.getsinglevalue('AA', 'Max_Wage_SSW', p_amcosversionid);
    v_groceries             := crunch.getsinglevalue('AA', 'DiscountGroceries', p_amcosversionid);

    -- Avg Cost of Base Pay (Civilian)
    UPDATE costs_ses_tmp
    SET costamount = basepay
    WHERE costelementid = 616;

    -- LQA Costs (DTMO). group 2 all SES, no dependents / family=0
    UPDATE costs_ses_tmp t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
      AND b."group" = 2
      AND b.amcosversionid = p_amcosversionid
      AND b.family = 0
      AND t.numberofdependents = 0
      AND t.costelementid IN (4889);

    -- LQA Costs, family=1, with dependents
    UPDATE costs_ses_tmp t
    SET costamount = b.amt
    FROM dataload.doslivingallowance AS b
    WHERE t.locationcode = b.locationcode
      AND b."group" = 2
      AND b.amcosversionid = p_amcosversionid
      AND b.family = 1
      AND t.numberofdependents >= 1
      AND t.costelementid IN (4889);

    -- Post Allowance (percentage of spendable income; per DSSR 054.1 not taxable)
    UPDATE costs_ses_tmp t
    SET costamount = b.spendableincome * c.postallowance
    FROM dataload.militaryspendableincome AS b,
         dataload.dospostallowance AS c
    WHERE t.basepay BETWEEN b.lowerlimit AND b.upperlimit
      AND b.numberofdependents = t.numberofdependents
      AND t.locationcode = c.locationcode
      AND b.amcosversionid = p_amcosversionid
      AND c.amcosversionid = p_amcosversionid
      AND t.costelementid IN (4890);

    -- Post Hardship Differential (percentage of basic compensation; per DSSR 045.2 taxable)
    UPDATE costs_ses_tmp t
    SET costamount = t.basepay * b.hardship
    FROM dataload.dospostallowance AS b
    WHERE t.locationcode = b.locationcode
      AND b.amcosversionid = p_amcosversionid
      AND t.costelementid IN (4891);

    -- Danger Pay Allowance (percentage of basic compensation; per DSSR 054.2 taxable)
    UPDATE costs_ses_tmp t
    SET costamount = t.basepay * b.dangerpay
    FROM dataload.dospostallowance AS b
    WHERE t.locationcode = b.locationcode
      AND b.amcosversionid = p_amcosversionid
      AND t.costelementid IN (4892);

    -- Discount Groceries
    UPDATE costs_ses_tmp
    SET costamount = v_groceries
    WHERE costelementid IN (4893)
      AND locationtype = 'Civilian Overseas';

    -- Other Benefits
    -- Avg Cost of Federal Employees Gov't Life Insurance
    UPDATE costs_ses_tmp
    SET costamount = basepay * v_fegli
    WHERE costelementid = 621;

    -- Avg Cost of Federal Employees Gov't Health Insurance
    UPDATE costs_ses_tmp
    SET costamount = v_feghi
    WHERE costelementid = 620;

    -- Avg Cost of Cash Awards
    UPDATE costs_ses_tmp
    SET costamount = basepay * v_cashawards
    WHERE costelementid = 619;

    -- Avg Cost of Army-Funded Retirement
    UPDATE costs_ses_tmp
    SET costamount = basepay * v_armyret
    WHERE costelementid = 625;

    -- Training
    UPDATE costs_ses_tmp
    SET costamount = v_training
    WHERE costelementid = 902;

    -- FICA = Social Security (capped) + Medicare (uncapped)
    -- CashCompensation self-aggregation kept as a subquery in FROM (legal in PG).
    UPDATE costs_ses_tmp t
    SET costamount = CASE
                         WHEN cc.costamount > v_max_wage_ssw THEN
                             COALESCE(v_max_wage_ssw * v_percentsocialsecurity, 0)
                             + COALESCE(v_max_wage_ssw * v_percentmedicare, 0)
                         ELSE
                             COALESCE(cc.costamount * v_percentsocialsecurity, 0)
                             + COALESCE(cc.costamount * v_percentmedicare, 0)
                     END
    FROM (
        SELECT SUM(costamount) AS costamount,
               occupationalseriesnumber,
               gradelevel,
               locationid
        FROM costs_ses_tmp
        WHERE costelementid IN (616, 4891, 4892, 619)
          AND costamount > 0
        GROUP BY occupationalseriesnumber, gradelevel, locationid
    ) AS cc
    WHERE cc.gradelevel = t.gradelevel
      AND cc.locationid = t.locationid
      AND cc.occupationalseriesnumber = t.occupationalseriesnumber
      AND t.costelementid = 961;

    -- Post retirement life
    UPDATE costs_ses_tmp
    SET costamount = v_postretlifeins
    WHERE costelementid = 962;

    -- Post retirement health
    UPDATE costs_ses_tmp
    SET costamount = v_postrethealthins
    WHERE costelementid = 963;

    -- get rid of costs which are 0 or negative
    DELETE FROM costs_ses_tmp
    WHERE costamount <= 0;

    IF NOT p_debug THEN
        -- clear out existing costs
        DELETE FROM crunch.costs_ses
        WHERE amcosversionid = p_amcosversionid;

        -- insert new costs
        INSERT INTO crunch.costs_ses
            (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid,
             gradetype, gradelevel, amount, crunchtime, amcosversionid,
             locationid, numberofdependents)
        SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid,
               gradetype, gradelevel, costamount, now()::timestamp AS crunchtime,
               amcosversionid, locationid, numberofdependents
        FROM costs_ses_tmp;
    END IF;

    DROP TABLE IF EXISTS costs_ses_tmp;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchcy  — CY (NAF China-Lake pay-band civilian) cost crunch.
--
-- Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchCY.sql.
-- Builds an average base pay per pay band/location from "PaySchedule".payschedule_cy
-- ((MinPay+MaxPay)/2), fans it out to every applicable lookup.costelement row, sets
-- each cost element from GS ratios (crunch.getsinglevalue, pay plan 'GS') / single
-- values, applies nonforeign-area COLA, then writes crunch.costs_cy with the base
-- rows plus five roll-up AVG aggregations (group/pay-plan x location/no-location).
--
-- Conventions: p_debug = true is a DRY RUN (writes guarded by IF NOT p_debug); the
-- source @Debug=1 result-set dumps are dropped. Source has no @CrunchTime, so none
-- is added; crunchtime uses a single now()::timestamp captured once. #temp ->
-- CREATE TEMP TABLE. The COLA UPDATE..FROM keeps the target only in UPDATE (not FROM).
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchcy(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime          timestamp := now()::timestamp;
    v_large_negative_value numeric(16, 2) := -1000000;
    v_cy_start_version    integer;
    v_postrethealthins    numeric(17, 2);
    v_postretlifeins      numeric(17, 2);
    v_training            numeric(17, 2);
    v_payplan             varchar(3) := 'GS';  -- use the same ratios and data as GS
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    -- skip if this version predates the creation of pay plan CY
    SELECT CONCAT(EXTRACT(YEAR FROM opmstartdate)::int, '01')::int
    INTO v_cy_start_version
    FROM lookup.payplan
    WHERE payplan = 'CY';

    IF p_amcosversionid < v_cy_start_version THEN
        RAISE NOTICE '% is before creation date of pay plan CY, crunch skipped', p_amcosversionid;
        RETURN;
    END IF;

    /* Integrate payschedule, all possible occupational series, and inventory */
    DROP TABLE IF EXISTS payschedulewithinventory;
    CREATE TEMP TABLE payschedulewithinventory (
        payplan              varchar(3)   NOT NULL,
        payband              smallint     NULL,
        categorygroupcode    varchar(4)   NOT NULL,
        categorysubgroupcode varchar(5)   NOT NULL,
        inventory            integer      NOT NULL DEFAULT 0,
        locationid           integer      NOT NULL,
        locationname         varchar(150) NULL,
        amcosversionid       integer      NOT NULL,
        pay                  numeric(16, 2) NULL
    );

    INSERT INTO payschedulewithinventory
        (payplan, payband, categorygroupcode, categorysubgroupcode, locationid, amcosversionid, pay)
    SELECT payplan,
           payband,
           '1700',
           '1702',
           locationid,
           amcosversionid,
           (maxpay + minpay) / 2 AS rate  -- straight average of min/max (DMDC gives no step/amount)
    FROM "PaySchedule".payschedule_cy
    WHERE locationid <> -1  -- base pay without locality pay is not an allowed cost
      AND amcosversionid = p_amcosversionid;

    /* Bring in inventory (used for location non-specific averages).
       Source is an INNER-JOIN UPDATE..FROM whose target self-references; rewritten
       with the target only in UPDATE and the aggregate in FROM. inventory starts at
       its DEFAULT 0, so unmatched rows keep 0 exactly as the T-SQL inner join left them.
       The source GROUP BY includes gradelevel while the join key does not (a source
       quirk that can match several aggregate rows to one target row) — preserved. */
    UPDATE payschedulewithinventory t
    SET inventory = COALESCE(b.inventory, 0)
    FROM (
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               locationid,
               gradelevel,
               SUM(inventory) AS inventory,
               amcosversionid
        FROM data.knowninventory
        WHERE amcosversionid = p_amcosversionid
          AND payplan = 'CY'
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, locationid, gradelevel, amcosversionid
    ) AS b
    WHERE b.amcosversionid = t.amcosversionid
      AND b.categorygroupcode = t.categorygroupcode
      AND b.categorysubgroupcode = t.categorysubgroupcode
      AND b.locationid = t.locationid
      AND b.payplan = t.payplan;

    -- single values used across the special / non-special pay calculations
    v_postrethealthins := crunch.getsinglevalue('AA', 'PostRetHealthIns', p_amcosversionid);
    v_postretlifeins   := crunch.getsinglevalue('AA', 'PostRetLifeIns', p_amcosversionid);
    v_training         := crunch.getsinglevalue('AA', 'Training', p_amcosversionid);

    -- master table to hold costs
    DROP TABLE IF EXISTS costs;
    CREATE TEMP TABLE costs (
        payplan              varchar(3)   NOT NULL,
        payband              smallint     NULL,
        categorygroupcode    varchar(4)   NOT NULL,
        categorysubgroupcode varchar(5)   NOT NULL,
        basepay              numeric(16, 2) NOT NULL,
        costamount           numeric(16, 2) NOT NULL,
        locationname         varchar(100) NULL,
        costelementid        integer      NOT NULL,
        costelementname      varchar(150) NOT NULL,
        costelementcategory  varchar(150) NOT NULL,
        appn                 varchar(25)  NOT NULL,
        amcosversionid       integer      NOT NULL,
        locationid           integer      NOT NULL
    );

    /* Insert all locations, their base pay, and every applicable cost element.
       costamount is seeded with the large-negative sentinel to detect updates that
       did not fire. */
    INSERT INTO costs
        (payplan, payband, categorygroupcode, categorysubgroupcode, basepay, costamount,
         costelementid, costelementname, costelementcategory, appn, amcosversionid, locationid)
    SELECT a.payplan,
           a.payband,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.pay,
           v_large_negative_value,
           b.costelementid,
           b.costelementname,
           b.costelementcategory,
           b.appn,
           a.amcosversionid,
           a.locationid
    FROM (
        SELECT payplan, payband, categorygroupcode, categorysubgroupcode, locationid, amcosversionid, pay
        FROM payschedulewithinventory
        GROUP BY payplan, payband, categorygroupcode, categorysubgroupcode, locationid, amcosversionid, pay
    ) AS a
    INNER JOIN lookup.costelement AS b
        ON a.payplan = b.payplan
    WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    -- Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian)
    UPDATE costs SET costamount = basepay WHERE costelementid IN (4846);

    /* COLA for white-collar civilians in nonforeign areas. base pay * COLA%.
       Source is an INNER-JOIN UPDATE..FROM; the target stays only in UPDATE, the
       lookups move to FROM. costamount starts at the sentinel and only matched rows
       are updated, matching the T-SQL inner join. */
    UPDATE costs a
    SET costamount = COALESCE(c.colarate / 100, 0) * a.basepay
    FROM warehouse.location AS b
        INNER JOIN lookup.nonforeignarea AS x
            ON x.localitycode = b.sourcesystemcode
        INNER JOIN "PaySchedule".nonforeignareacostoflivingallowances AS c
            ON x.nonforeignareacode = c.nonforeignareacode
    WHERE a.locationid = b.locationid
      AND p_amcosversionid = c.amcosversionid
      AND b.locationtype IN ('Nonforeign Area', 'Locality Pay Area')
      AND a.costelementid IN (4896);

    -- Remove 4896 values that are not in a nonforeign area
    DELETE FROM costs
    WHERE costelementid = 4896
      AND locationid NOT IN (
          SELECT a.locationid
          FROM warehouse.location a
          JOIN lookup.nonforeignarea b ON b.localitycode = a.sourcesystemcode
          WHERE p_amcosversionid = b.amcosversionid
      );

    -- Army CivPay; Compensation - Other; Avg Cost of Other Compensation
    UPDATE costs SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'OtherComp', p_amcosversionid)
    WHERE costelementid IN (4851);

    -- Army CivPay; Benefits; Avg Cost of Benefits
    UPDATE costs SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'BenefitsRet', p_amcosversionid)
    WHERE costelementid IN (4852);

    -- Army CivPay; Benefits; Avg Cost of Former Employee Compensation
    UPDATE costs SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'FormerEmp', p_amcosversionid)
    WHERE costelementid IN (4850);

    -- Army CivPay; Cash Awards; Avg Cost of Cash Awards
    UPDATE costs SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'CashAwards', p_amcosversionid)
    WHERE costelementid IN (4849);

    -- Army CivPay; Holiday Pay; Avg Cost of Holiday Pay
    UPDATE costs SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'Holiday', p_amcosversionid)
    WHERE costelementid IN (4847);

    -- Army CivPay; Overtime Pay; Avg Cost of Overtime Pay
    UPDATE costs SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'Ovrt', p_amcosversionid)
    WHERE costelementid IN (4848);

    -- OMA; Training Costs; Training
    UPDATE costs SET costamount = v_training WHERE costelementid IN (4853);

    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance
    UPDATE costs SET costamount = v_postrethealthins WHERE costelementid IN (4855);

    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance
    UPDATE costs SET costamount = v_postretlifeins WHERE costelementid IN (4854);

    IF NOT p_debug THEN
        /* Remove old costs for this version before inserting the new costs */
        DELETE FROM crunch.costs_cy WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_cy
            (payplan, occupationalgroupnumber, occupationalseriesnumber, costelementid,
             gradetype, payband, amount, crunchtime, amcosversionid, locationid)
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               costelementid,
               payplan,
               payband,
               costamount,
               v_crunchtime,
               p_amcosversionid,
               locationid
        FROM costs
        UNION
        /* Category group with location average */
        SELECT payplan,
               categorygroupcode,
               '-1',
               costelementid,
               payplan,
               payband,
               AVG(costamount),
               v_crunchtime,
               p_amcosversionid,
               locationid
        FROM costs
        GROUP BY payplan, categorygroupcode, costelementid, payplan, payband, locationid
        UNION
        /* Pay Plan with location average */
        SELECT payplan,
               '-1',
               '-1',
               costelementid,
               payplan,
               payband,
               AVG(costamount),
               v_crunchtime,
               p_amcosversionid,
               locationid
        FROM costs
        GROUP BY payplan, costelementid, payplan, payband, locationid
        UNION
        /* Category subgroup without location average */
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               costelementid,
               payplan,
               payband,
               AVG(costamount),
               v_crunchtime,
               p_amcosversionid,
               -1
        FROM costs
        GROUP BY payplan, categorygroupcode, categorysubgroupcode, costelementid, payplan, payband
        UNION
        /* Category group without location average */
        SELECT payplan,
               categorygroupcode,
               '-1',
               costelementid,
               payplan,
               payband,
               AVG(costamount),
               v_crunchtime,
               p_amcosversionid,
               -1
        FROM costs
        GROUP BY payplan, categorygroupcode, costelementid, payplan, payband
        UNION
        /* Pay plan without location average */
        SELECT payplan,
               '-1',
               '-1',
               costelementid,
               payplan,
               payband,
               AVG(costamount),
               v_crunchtime,
               p_amcosversionid,
               -1
        FROM costs
        GROUP BY payplan, costelementid, payplan, payband;

        /* get rid of zero costs */
        DELETE FROM crunch.costs_cy
        WHERE amount = 0
          AND amcosversionid = p_amcosversionid;
    END IF;

    DROP TABLE IF EXISTS payschedulewithinventory;
    DROP TABLE IF EXISTS costs;
END;
$$;

------------------------------------------------------------------------------
-- crunch.crunchnf  (NF non-appropriated pay-band civilian costs)
--
-- Faithful port of AMCOS.AMCOS2020_MAR/crunch/Stored Procedures/CrunchNF.sql.
-- Similar to the CY pay plan: builds a location/subgroup pay+inventory table
-- (with rolled-up averages and "fill in the blank" rows), cross-joins it to the
-- applicable NF cost elements, computes each element (base pay, non-foreign COLA,
-- and GS-ratio-based benefit elements), then writes crunch.costs_nf.
--
-- Source has NO @CrunchTime parameter -> none added (crunchtime := now()).
-- @Debug = 1 branches are result-set dumps (no runtime effect) and are dropped;
-- the DELETE/INSERT writes run only under "IF @Debug = 0" -> "IF NOT p_debug".
-- NF uses the GS pay plan's ratios/single-values (source @PayPlan = 'GS').
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE crunch.crunchnf(
    p_amcosversionid integer DEFAULT -1,
    p_debug boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_crunchtime         timestamp     := now()::timestamp;
    v_largenegativevalue numeric(15, 2) := -1000000; -- detects cost updates that didn't happen
    v_payplan            varchar(3)    := 'GS';       -- use the same ratios and data as GS
    v_postrethealthins   numeric(26, 6);
    v_postretlifeins     numeric(26, 6);
    v_training           numeric(26, 6);
BEGIN
    IF NOT crunch.validateamcosversion(p_amcosversionid) THEN
        RETURN;
    END IF;

    ------------------------------------------------------------------------
    -- pay + inventory by subgroup/location
    ------------------------------------------------------------------------
    DROP TABLE IF EXISTS temppay;
    CREATE TEMP TABLE temppay (
        payplan              varchar(2),
        payband              smallint,
        categorygroupcode    varchar(4),
        categorysubgroupcode varchar(4),
        locationid           integer,
        amcosversionid       integer,
        inventory            integer,
        minpay               numeric(18, 2),
        maxpay               numeric(18, 2),
        avgpay               numeric(18, 2)
    );

    -- inventory subgroup/location based specific costs
    INSERT INTO temppay
        (payplan, payband, categorygroupcode, categorysubgroupcode, locationid,
         amcosversionid, inventory, minpay, maxpay, avgpay)
    SELECT a.payplan,
           a.payband,
           b.categorygroupcode,
           b.categorysubgroupcode,
           b.locationid,
           b.amcosversionid,
           b.inventory,
           a.minpay,
           a.maxpay,
           (a.minpay + a.maxpay) / 2
    FROM crunch.nfpayprocessed AS a
        INNER JOIN (
            SELECT payplan,
                   categorygroupcode,
                   categorysubgroupcode,
                   locationid,
                   gradelevel,
                   amcosversionid,
                   SUM(inventory) AS inventory
            FROM data.inventory
            WHERE amcosversionid = p_amcosversionid
              AND payplan = 'NF'
            GROUP BY payplan, categorygroupcode, categorysubgroupcode,
                     locationid, gradelevel, amcosversionid
        ) AS b
            ON b.amcosversionid = a.amcosversionid
               -- data.inventory.gradelevel is varchar; NF pay bands are numeric,
               -- so cast to smallint to match a.payband (SQL Server compared these
               -- numerically via implicit int precedence).
               AND b.gradelevel::smallint = a.payband
               AND b.locationid = a.locationid
               AND b.payplan = a.payplan
    WHERE a.payplan = 'NF'
      AND a.amcosversionid = p_amcosversionid;

    -- now insert a bunch of the averages (inventory-weighted; denominators wrapped
    -- in NULLIF to avoid div-by-zero — identical result when inventory is non-zero,
    -- which the source relied on)
    INSERT INTO temppay
        (payplan, payband, categorygroupcode, categorysubgroupcode, locationid,
         amcosversionid, inventory, minpay, maxpay, avgpay)
    -- subgroup, no location
    SELECT payplan,
           payband,
           categorygroupcode,
           categorysubgroupcode,
           -1,
           amcosversionid,
           SUM(inventory),
           SUM(minpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(maxpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(avgpay * inventory) / NULLIF(SUM(inventory), 0)
    FROM temppay
    GROUP BY payplan, payband, categorygroupcode, categorysubgroupcode, amcosversionid
    UNION ALL
    -- group with location
    SELECT payplan,
           payband,
           categorygroupcode,
           '-1',
           locationid,
           amcosversionid,
           SUM(inventory),
           SUM(minpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(maxpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(avgpay * inventory) / NULLIF(SUM(inventory), 0)
    FROM temppay
    GROUP BY payplan, payband, categorygroupcode, locationid, amcosversionid
    UNION ALL
    -- group without location
    SELECT payplan,
           payband,
           categorygroupcode,
           '-1',
           -1,
           amcosversionid,
           SUM(inventory),
           SUM(minpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(maxpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(avgpay * inventory) / NULLIF(SUM(inventory), 0)
    FROM temppay
    GROUP BY payplan, payband, categorygroupcode, amcosversionid
    UNION ALL
    -- pp with location
    SELECT payplan,
           payband,
           '-1',
           '-1',
           locationid,
           amcosversionid,
           SUM(inventory),
           SUM(minpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(maxpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(avgpay * inventory) / NULLIF(SUM(inventory), 0)
    FROM temppay
    GROUP BY payplan, payband, locationid, amcosversionid
    UNION ALL
    -- pp without location
    SELECT payplan,
           payband,
           '-1',
           '-1',
           '-1',
           amcosversionid,
           SUM(inventory),
           SUM(minpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(maxpay * inventory) / NULLIF(SUM(inventory), 0),
           SUM(avgpay * inventory) / NULLIF(SUM(inventory), 0)
    FROM temppay
    GROUP BY payplan, payband, amcosversionid;

    -- now fill in the blanks in inventory at the PP, location specific level
    INSERT INTO temppay
        (payplan, payband, categorygroupcode, categorysubgroupcode, locationid,
         amcosversionid, inventory, minpay, maxpay, avgpay)
    SELECT payplan,
           payband,
           '-1' AS categorygroupcode,
           '-1' AS categorysubgroupcode,
           locationid,
           amcosversionid,
           0,
           minpay,
           maxpay,
           (maxpay + minpay) / 2 AS avgpay
    FROM crunch.nfpayprocessed
    WHERE amcosversionid = p_amcosversionid
      AND locationid NOT IN (
          SELECT locationid FROM temppay WHERE categorygroupcode = '-1'
      );

    ------------------------------------------------------------------------
    -- single values used across the cost elements (same for every pay plan)
    ------------------------------------------------------------------------
    v_postrethealthins := crunch.getsinglevalue('AA', 'PostRetHealthIns', p_amcosversionid);
    v_postretlifeins   := crunch.getsinglevalue('AA', 'PostRetLifeIns', p_amcosversionid);
    v_training         := crunch.getsinglevalue('AA', 'Training', p_amcosversionid);

    ------------------------------------------------------------------------
    -- master cost table: cross join of every location/base-pay row and every
    -- applicable cost element; CostAmount seeded to the large-negative sentinel
    ------------------------------------------------------------------------
    DROP TABLE IF EXISTS paybylocationcosts;
    CREATE TEMP TABLE paybylocationcosts (
        payplan              varchar(3),
        payband              smallint,
        categorygroupcode    varchar(4),
        categorysubgroupcode varchar(5),
        subgrouptitle        varchar(150),
        basepay              numeric(15, 2),
        costamount           numeric(15, 2),
        locationname         varchar(100),
        costelementid        integer,
        costelementname      varchar(150),
        costelementcategory  varchar(150),
        appn                 varchar(25),
        amcosversionid       integer,
        locationid           integer,
        inventory            integer
    );

    INSERT INTO paybylocationcosts
        (payplan, payband, categorygroupcode, categorysubgroupcode, basepay,
         costamount, costelementid, costelementname, costelementcategory, appn,
         amcosversionid, locationid, inventory)
    SELECT a.payplan,
           a.payband,
           a.categorygroupcode,
           a.categorysubgroupcode,
           a.avgpay,
           v_largenegativevalue,
           b.costelementid,
           b.costelementname,
           b.costelementcategory,
           b.appn,
           a.amcosversionid,
           a.locationid,
           a.inventory
    FROM temppay AS a
        INNER JOIN lookup.costelement AS b
            ON a.payplan = b.payplan
    WHERE p_amcosversionid BETWEEN b.amcosversionidstart AND b.amcosversionidend;

    ------------------------------------------------------------------------
    -- per cost-element calculations
    ------------------------------------------------------------------------
    -- Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian)
    UPDATE paybylocationcosts
    SET costamount = basepay
    WHERE costelementid IN (4915);

    -- Non-foreign COLA: base pay * COLA % per OPM. The gs_locality table keys on
    -- the nonforeign-area acronym while this table keys on locationid, so we join
    -- through warehouse.location. Source re-aliased the UPDATE target as "a" in
    -- FROM; PG forbids that, so the target is referenced directly and its join
    -- predicates moved to WHERE (inner-join semantics preserved: CE 4925 rows with
    -- no matching Nonforeign-Area COLA keep the sentinel and are filtered out later).
    UPDATE paybylocationcosts AS t
    SET costamount = COALESCE(c.colarate / 100, 0) * t.basepay
    FROM warehouse.location AS b
        INNER JOIN "PaySchedule".nonforeignareacostoflivingallowances AS c
            ON b.sourcesystemcode = c.nonforeignareacode
    WHERE t.locationid = b.locationid
      AND p_amcosversionid = c.amcosversionid
      AND b.locationtype = 'Nonforeign Area' -- just in case any other location codes match our locality areas
      AND t.costelementid IN (4925);

    -- Army CivPay; Compensation - Other; Avg Cost of Other Compensation
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'OtherComp', p_amcosversionid)
    WHERE costelementid IN (4920);

    -- Army CivPay; Benefits; Avg Cost of Benefits
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'BenefitsRet', p_amcosversionid)
    WHERE costelementid IN (4921);

    -- Army CivPay; Benefits; Avg Cost of Former Employee Compensation
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'FormerEmp', p_amcosversionid)
    WHERE costelementid IN (4919);

    -- Army CivPay; Cash Awards; Avg Cost of Cash Awards
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'CashAwards', p_amcosversionid)
    WHERE costelementid IN (4918);

    -- Army CivPay; Holiday Pay; Avg Cost of Holiday Pay
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'Holiday', p_amcosversionid)
    WHERE costelementid IN (4916);

    -- Army CivPay; Overtime Pay; Avg Cost of Overtime Pay
    UPDATE paybylocationcosts
    SET costamount = basepay * crunch.getsinglevalue(v_payplan, 'Ovrt', p_amcosversionid)
    WHERE costelementid IN (4917);

    -- OMA; Training Costs; Training
    UPDATE paybylocationcosts
    SET costamount = v_training
    WHERE costelementid IN (4922);

    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance
    UPDATE paybylocationcosts
    SET costamount = v_postrethealthins
    WHERE costelementid IN (4924);

    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance
    UPDATE paybylocationcosts
    SET costamount = v_postretlifeins
    WHERE costelementid IN (4923);

    ------------------------------------------------------------------------
    -- write results (dry run when p_debug)
    ------------------------------------------------------------------------
    IF NOT p_debug THEN
        -- remove the old costs for this version before inserting the new costs
        DELETE FROM crunch.costs_nf
        WHERE amcosversionid = p_amcosversionid;

        INSERT INTO crunch.costs_nf
            (payplan, occupationalgroupnumber, occupationalseriesnumber,
             costelementid, gradetype, payband, amount, crunchtime,
             amcosversionid, locationid)
        SELECT payplan,
               categorygroupcode,
               categorysubgroupcode,
               costelementid,
               payplan,
               payband,
               costamount,
               v_crunchtime AS crunchtime,
               p_amcosversionid,
               locationid
        FROM paybylocationcosts
        WHERE costamount > 0;
    END IF;

    DROP TABLE IF EXISTS temppay;
    DROP TABLE IF EXISTS paybylocationcosts;
END;
$$;
