-- Cost-engine web.* functions ported from the AMCOS SQL Server project.
--
-- These read the data.* views (008) and crunch.* tables (005b), so they are all
-- LANGUAGE plpgsql (deferred name resolution) and create cleanly even though the
-- objects they reference are created in later migration files and hold no data until
-- the ETL runs. RUNTIME cost-math correctness requires ETL-loaded data and a separate
-- validation pass; see MIGRATION_PARITY_AUDIT.md (Tier B).

-- crunch.GetSingleValue — single named parameter value (reads dataload.singlevalues).
CREATE OR REPLACE FUNCTION crunch.getsinglevalue(
    p_payplan varchar(10),
    p_parametername varchar(100),
    p_amcosversionid integer DEFAULT -1
)
RETURNS numeric(26,6)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result numeric(26,6);
BEGIN
    SELECT paramvalue INTO v_result
    FROM dataload.singlevalues
    WHERE payplan = p_payplan
      AND paramname = p_parametername
      AND amcosversionid = p_amcosversionid;
    RETURN v_result;
END;
$function$;

-- analysis.GetPayPlans — pay plans for a keyword group (called by web.getamcoslitecosts
-- and the data.CategoryGroup/Subgroup views). Faithful port of the SQL Server TVF.
CREATE OR REPLACE FUNCTION analysis.getpayplans(p_payplantype varchar(50) DEFAULT '-1')
RETURNS TABLE(payplan varchar(3))
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_payplantype IN (SELECT pp.payplan FROM lookup.payplan pp) THEN
        RETURN QUERY SELECT p_payplantype::varchar(3);
    ELSIF p_payplantype = 'All' THEN
        RETURN QUERY SELECT pp.payplan FROM lookup.payplan pp
                     UNION ALL SELECT 'SES'::varchar(3);
    ELSIF p_payplantype = 'Military' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['AO','AWO','AE','RE','RO','RWO','NE','NO','NWO']) v;
    ELSIF p_payplantype = 'Active' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['AO','AWO','AE']) v;
    ELSIF p_payplantype = 'NG_R' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['RE','RO','RWO','NE','NO','NWO']) v;
    ELSIF p_payplantype = 'NG' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['NE','NO','NWO']) v;
    ELSIF p_payplantype = 'Reserve' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['RE','RO','RWO']) v;
    ELSIF p_payplantype = 'Officer' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['AO','RO','NO']) v;
    ELSIF p_payplantype = 'Enlisted' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['AE','RE','NE']) v;
    ELSIF p_payplantype = 'Warrant' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['AWO','RWO','NWO']) v;
    ELSIF p_payplantype = 'GFEBS' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['NH','NJ','NK','DB','DE','DJ','DK','GP']) v;
    ELSIF p_payplantype = 'Acq' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['NH','NJ','NK']) v;
    ELSIF p_payplantype = 'Lab Demo' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['DE','DJ','DK','DB']) v;
    ELSIF p_payplantype = 'G' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['GS','GG','GL','GP']) v;
    ELSIF p_payplantype = 'OPM_G' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['GS','GG','GL']) v;
    ELSIF p_payplantype = 'Wage' THEN
        RETURN QUERY SELECT pp.payplan FROM lookup.payplan pp
                     WHERE pp.payplan LIKE 'W%' OR pp.payplan LIKE 'X%' OR pp.payplan IN ('NA','NL','NS');
    ELSIF p_payplantype = 'Civ' THEN
        RETURN QUERY SELECT v::varchar(3) FROM unnest(ARRAY['NH','NJ','NK','DB','DE','DJ','DK','GP','GS','GG','GL','SES','CCE']) v
                     UNION ALL SELECT pp.payplan FROM lookup.payplan pp WHERE pp.payplan LIKE 'W%' OR pp.payplan LIKE 'X%';
    END IF;
    RETURN;
END;
$function$;

-- ============================ scalar / lookup helpers ============================

CREATE OR REPLACE FUNCTION web.getlocationdisplayname(p_locationid integer)
RETURNS varchar(100)
LANGUAGE plpgsql
AS $function$
DECLARE v_result varchar(100);
BEGIN
    SELECT displayname INTO v_result FROM warehouse.location WHERE locationid = p_locationid;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getprojectyearstart(p_categoryid integer)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE v_result integer;
BEGIN
    SELECT p.yearstart INTO v_result
    FROM webuser.pmcategory c JOIN webuser.pmproject p ON p.projectid = c.projectid
    WHERE c.categoryid = p_categoryid;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getprojectyearduration(p_categoryid integer)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE v_result integer;
BEGIN
    SELECT p.yearduration INTO v_result
    FROM webuser.pmcategory c JOIN webuser.pmproject p ON p.projectid = c.projectid
    WHERE c.categoryid = p_categoryid;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getcostsummaryid(
    p_payplan varchar(3), p_costsummaryname varchar(50), p_amcosversionid integer)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE v_result integer;
BEGIN
    SELECT summaryid INTO v_result FROM lookup.costsummary
    WHERE payplan = p_payplan AND name = p_costsummaryname
      AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getcostsummaryname(
    p_costsummaryid integer, p_amcosversionid integer DEFAULT -1)
RETURNS varchar(50)
LANGUAGE plpgsql
AS $function$
DECLARE v_result varchar(50);
BEGIN
    SELECT name INTO v_result FROM lookup.costsummary
    WHERE summaryid = p_costsummaryid
      AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.payplancontainstag(p_payplan varchar(3), p_tag varchar(50))
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count FROM web.payplantag WHERE payplan = p_payplan AND tag = p_tag;
    RETURN v_count > 0;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getunitauthorizationdocument(p_uic varchar(6))
RETURNS varchar(50)
LANGUAGE plpgsql
AS $function$
DECLARE v_result varchar(50);
BEGIN
    SELECT authorizationdocument INTO v_result FROM warehouse.unitpersonnel
    WHERE uic = p_uic ORDER BY authorizationdocument LIMIT 1;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getlastmtoeunityear(p_uic varchar(6))
RETURNS varchar(4)
LANGUAGE plpgsql
AS $function$
DECLARE v_result varchar(4);
BEGIN
    SELECT MAX(unityear) INTO v_result FROM warehouse.unitpersonnel
    WHERE uic = p_uic AND unityear <> 'OTOE';
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getadjustedavgannualizedcostoffica(
    p_costelementid integer, p_amount numeric(26,6), p_amcosversionid integer DEFAULT 202001)
RETURNS numeric(26,6)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result numeric(26,6);
    v_maxwagess numeric(20,2) := crunch.getsinglevalue('AA', 'Max_Wage_SSW', p_amcosversionid);
BEGIN
    IF p_costelementid IN (290, 360, 414, 454, 524, 578) THEN
        v_result := CASE WHEN p_amount > v_maxwagess THEN v_maxwagess ELSE p_amount END;
    ELSE
        v_result := p_amount;
    END IF;
    RETURN v_result;
END;
$function$;

-- ============================ cost table functions ============================

CREATE OR REPLACE FUNCTION web.getarmycestitles(p_payplan varchar(3), p_costsummaryid integer)
RETURNS TABLE(armycestitle text)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ce.armycestitle::text
    FROM lookup.costelement ce
    JOIN lookup.costsummaryelement cse ON cse.costelementid = ce.costelementid
    JOIN (SELECT costelementid, MAX(amcosversionidend) AS m FROM lookup.costelement GROUP BY costelementid) mi
         ON ce.costelementid = mi.costelementid AND ce.amcosversionidend = mi.m
    JOIN (SELECT summaryid, costelementid, MAX(amcosversionidend) AS m FROM lookup.costsummaryelement GROUP BY summaryid, costelementid) mi2
         ON cse.summaryid = mi2.summaryid AND cse.costelementid = mi2.costelementid AND cse.amcosversionidend = mi2.m
    WHERE ce.payplan = p_payplan AND cse.summaryid = p_costsummaryid AND ce.armycestitle IS NOT NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getminmaxpay(
    p_payplan varchar(3), p_categorygroupcode varchar(4), p_categorysubgroupcode varchar(5),
    p_careerprogramnumber char(2), p_locationid integer, p_strl varchar(50), p_amcosversionid integer)
RETURNS TABLE(grade varchar(5), gradelevel smallint, appropriation varchar(25),
              minimumpay numeric(18,2), maximumpay numeric(18,2))
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT (p.gradetype::varchar(3) || p.gradelevel::varchar(2))::varchar(5),
           p.gradelevel, p.appropriation, p.minrate, p.maxrate
    FROM crunch.payscheduleminmax p
    WHERE p.payplan = p_payplan AND p.categorygroupcode = p_categorygroupcode
      AND p.categorysubgroupcode = p_categorysubgroupcode
      AND p.locationid = p_locationid AND p.strl = p_strl AND p.amcosversionid = p_amcosversionid;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getcosts(
    p_payplan varchar(3),
    p_costsummaryname varchar(50) DEFAULT 'Default',
    p_categorygroupcode varchar(4) DEFAULT '-1',
    p_categorysubgroupcode varchar(5) DEFAULT '-1',
    p_careerprogramnumber char(2) DEFAULT '-1',
    p_locationid integer DEFAULT -1,
    p_strl varchar(20) DEFAULT '-1',
    p_dependentstatus varchar(25) DEFAULT '-1',
    p_numberofdependents integer DEFAULT -1,
    p_amcosversionid integer DEFAULT 202001)
RETURNS TABLE(
    appropriationgroup varchar(50), appn varchar(50), costelementcategory varchar(250),
    costelementname varchar(250), description text, costelementid integer, showorder integer,
    applyinflation boolean, gradelevel smallint, grade varchar(5), weaponsystemid integer,
    weaponsystemname varchar(250), amount numeric(26,6), armycestitle varchar(250),
    osdcapecestitle varchar(250), amcosversionid integer)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT c.appropriationgroup, c.appn, c.costelementcategory, c.costelementname, c.description::text,
           c.costelementid, c.showorder, c.applyinflation, c.gradelevel,
           (CASE c.payplan WHEN 'SES' THEN
                CASE c.gradelevel WHEN 1 THEN 'MIN' WHEN 2 THEN 'AVG' WHEN 3 THEN 'MAX'
                ELSE c.gradelevel::varchar(3) END
            ELSE c.gradetype::varchar(3) || c.gradelevel::varchar(2) END)::varchar(5),
           c.weaponsystemid, NULL::varchar(250), c.amount, c.armycestitle, c.osdcapecestitle, c.amcosversionid
    FROM data.costs c
    JOIN lookup.costelement ce ON ce.costelementid = c.costelementid
         AND p_amcosversionid BETWEEN ce.amcosversionidstart AND ce.amcosversionidend
    JOIN lookup.costsummaryelement cse ON cse.costelementid = ce.costelementid
         AND p_amcosversionid BETWEEN cse.amcosversionidstart AND cse.amcosversionidend
    JOIN lookup.costsummary cs ON cs.summaryid = cse.summaryid
         AND p_amcosversionid BETWEEN cs.amcosversionidstart AND cs.amcosversionidend
    WHERE c.payplan = p_payplan AND c.categorygroupcode = p_categorygroupcode
      AND c.categorysubgroupcode = p_categorysubgroupcode AND c.careerprogramnumber = p_careerprogramnumber
      AND c.locationid = -1 AND c.islocationspecific = false AND c.strl = p_strl
      AND c.dependentstatus = '-1' AND c.numberofdependents = p_numberofdependents
      AND c.amcosversionid = p_amcosversionid AND cs.name = p_costsummaryname
    UNION ALL
    SELECT c.appropriationgroup, c.appn, c.costelementcategory, c.costelementname, c.description::text,
           c.costelementid, c.showorder, c.applyinflation, c.gradelevel,
           (CASE c.payplan WHEN 'SES' THEN
                CASE c.gradelevel WHEN 1 THEN 'MIN' WHEN 2 THEN 'AVG' WHEN 3 THEN 'MAX'
                ELSE c.gradelevel::varchar(3) END
            ELSE c.gradetype::varchar(3) || c.gradelevel::varchar(2) END)::varchar(5),
           c.weaponsystemid, NULL::varchar(250), c.amount, c.armycestitle, c.osdcapecestitle, c.amcosversionid
    FROM data.costs c
    JOIN lookup.costelement ce ON ce.costelementid = c.costelementid
         AND p_amcosversionid BETWEEN ce.amcosversionidstart AND ce.amcosversionidend
    JOIN lookup.costsummaryelement cse ON cse.costelementid = ce.costelementid
         AND p_amcosversionid BETWEEN cse.amcosversionidstart AND cse.amcosversionidend
    JOIN lookup.costsummary cs ON cs.summaryid = cse.summaryid
         AND p_amcosversionid BETWEEN cs.amcosversionidstart AND cs.amcosversionidend
    WHERE c.payplan = p_payplan AND c.categorygroupcode = p_categorygroupcode
      AND c.categorysubgroupcode = p_categorysubgroupcode AND c.careerprogramnumber = p_careerprogramnumber
      AND c.locationid = p_locationid AND c.islocationspecific = true AND c.strl = p_strl
      AND c.dependentstatus = p_dependentstatus AND c.numberofdependents = p_numberofdependents
      AND c.amcosversionid = p_amcosversionid AND cs.name = p_costsummaryname;
END;
$function$;

CREATE OR REPLACE FUNCTION web.costscce(
    p_standardoccupationcode varchar(10), p_area varchar(10),
    p_overheadpercent numeric(19,4), p_amcosversionid integer DEFAULT 202001)
RETURNS TABLE(appngroup varchar(50), costelementname varchar(250), description text,
    a_pct10 numeric(18,0), a_pct25 numeric(18,0), a_median numeric(18,0),
    a_pct75 numeric(18,0), a_pct90 numeric(18,0))
LANGUAGE plpgsql
AS $function$
DECLARE
    v_benefitratio numeric(26,6);
    v_maxpay numeric(19,4) := crunch.getsinglevalue('CCE', 'MaxPayFootnote', p_amcosversionid);
    v_limitben numeric(19,4); v_limitovh numeric(19,4); v_limittot numeric(19,4);
BEGIN
    v_benefitratio := crunch.getsinglevalue('CCE', 'Benefits_All', p_amcosversionid);
    v_limitben := (v_maxpay * v_benefitratio)::numeric(19,4);
    v_limitovh := (v_maxpay * p_overheadpercent / 100)::numeric(19,4);
    v_limittot := (v_maxpay * (1 + v_benefitratio + p_overheadpercent / 100))::numeric(19,4);
    RETURN QUERY
    SELECT 'CCE'::varchar(50), 'zzz1Avg Cost of Salary'::varchar(250), 'Annual salary received in the private sector.'::text,
           (CASE WHEN m.a_pct10=9999999 THEN v_maxpay ELSE m.a_pct10::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct25=9999999 THEN v_maxpay ELSE m.a_pct25::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_median=9999999 THEN v_maxpay ELSE m.a_median::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct75=9999999 THEN v_maxpay ELSE m.a_pct75::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct90=9999999 THEN v_maxpay ELSE m.a_pct90::numeric(19,4) END)::numeric(18,0)
    FROM "BLS_OES".occupationalemploymentstatisticsmetro m
    WHERE m.soc=p_standardoccupationcode AND m.msacode=p_area AND m.amcosversionid=p_amcosversionid
    UNION
    SELECT 'CCE'::varchar(50), 'zzz2Avg Cost of Benefits'::varchar(250), 'Employer Costs for Employee Compensation.'::text,
           (CASE WHEN m.a_pct10=9999999 THEN v_limitben ELSE (m.a_pct10*v_benefitratio)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct25=9999999 THEN v_limitben ELSE (m.a_pct25*v_benefitratio)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_median=9999999 THEN v_limitben ELSE (m.a_median*v_benefitratio)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct75=9999999 THEN v_limitben ELSE (m.a_pct75*v_benefitratio)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct90=9999999 THEN v_limitben ELSE (m.a_pct90*v_benefitratio)::numeric(19,4) END)::numeric(18,0)
    FROM "BLS_OES".occupationalemploymentstatisticsmetro m
    WHERE m.soc=p_standardoccupationcode AND m.msacode=p_area AND m.amcosversionid=p_amcosversionid
    UNION
    SELECT 'CCE'::varchar(50), 'zzz3Overhead'::varchar(250), 'Ongoing business expenses.'::text,
           (CASE WHEN m.a_pct10=9999999 THEN v_limitovh ELSE (m.a_pct10*p_overheadpercent/100)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct25=9999999 THEN v_limitovh ELSE (m.a_pct25*p_overheadpercent/100)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_median=9999999 THEN v_limitovh ELSE (m.a_median*p_overheadpercent/100)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct75=9999999 THEN v_limitovh ELSE (m.a_pct75*p_overheadpercent/100)::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct90=9999999 THEN v_limitovh ELSE (m.a_pct90*p_overheadpercent/100)::numeric(19,4) END)::numeric(18,0)
    FROM "BLS_OES".occupationalemploymentstatisticsmetro m
    WHERE m.soc=p_standardoccupationcode AND m.msacode=p_area AND m.amcosversionid=p_amcosversionid
    UNION
    SELECT 'CCE'::varchar(50), 'zzz3Total'::varchar(250), 'Total cost'::text,
           (CASE WHEN m.a_pct10=9999999 THEN v_limittot ELSE (m.a_pct10*(1+v_benefitratio+p_overheadpercent/100))::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct25=9999999 THEN v_limittot ELSE (m.a_pct25*(1+v_benefitratio+p_overheadpercent/100))::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_median=9999999 THEN v_limittot ELSE (m.a_median*(1+v_benefitratio+p_overheadpercent/100))::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct75=9999999 THEN v_limittot ELSE (m.a_pct75*(1+v_benefitratio+p_overheadpercent/100))::numeric(19,4) END)::numeric(18,0),
           (CASE WHEN m.a_pct90=9999999 THEN v_limittot ELSE (m.a_pct90*(1+v_benefitratio+p_overheadpercent/100))::numeric(19,4) END)::numeric(18,0)
    FROM "BLS_OES".occupationalemploymentstatisticsmetro m
    WHERE m.soc=p_standardoccupationcode AND m.msacode=p_area AND m.amcosversionid=p_amcosversionid
    ORDER BY 2;
END;
$function$;

-- web.CostsCCEInflated — CCE market pay with inflation applied (by location/year).
CREATE OR REPLACE FUNCTION web.costscceinflated(
    p_standardoccupationcode varchar(10), p_locationid integer, p_overheadpercent numeric(19,4),
    p_inflationconversion varchar(25), p_inflationyear varchar(4), p_amcosversionid integer)
RETURNS TABLE(appngroup varchar(50), "Cost Element Name" varchar(250), description text,
    a_pct10 numeric(18,0), a_pct25 numeric(18,0), a_median numeric(18,0),
    a_pct75 numeric(18,0), a_pct90 numeric(18,0))
LANGUAGE plpgsql
AS $function$
DECLARE
    v_benefitratio numeric(18,4);
    v_maxpay numeric(19,4) := crunch.getsinglevalue('CCE','MaxPayFootnote',p_amcosversionid);
    v_limitben numeric(19,4); v_limitovh numeric(19,4); v_limittot numeric(19,4);
    v_msacode varchar(7); v_infl numeric(18,15);
BEGIN
    SELECT l.sourcesystemcode INTO v_msacode FROM warehouse.location l WHERE l.locationid = p_locationid;
    v_benefitratio := crunch.getsinglevalue('CCE','Benefits_All',p_amcosversionid);
    v_limitben := (v_maxpay * v_benefitratio)::numeric(19,4);
    v_limitovh := (v_maxpay * p_overheadpercent / 100)::numeric(19,4);
    v_limittot := (v_maxpay * (1 + v_benefitratio + p_overheadpercent / 100))::numeric(19,4);
    SELECT ir.amount INTO v_infl FROM lookup.jicinflationrates ir
    JOIN (SELECT conversiontype, year, appropriation, MAX(amcosversionid) AS m
          FROM lookup.jicinflationrates GROUP BY conversiontype, year, appropriation) mx
      ON ir.conversiontype=mx.conversiontype AND ir.year=mx.year AND ir.appropriation=mx.appropriation AND ir.amcosversionid=mx.m
    WHERE ir.conversiontype=p_inflationconversion AND ir.year=p_inflationyear::smallint AND ir.appropriation='OMA';
    RETURN QUERY
    WITH base AS (
        SELECT 'CCE'::varchar(50) AS appngroup, 'zzz1Avg Cost of Salary'::varchar(250) AS cen, 'Annual salary received in the private sector.'::text AS descr,
               (CASE WHEN m.a_pct10=9999999 THEN v_maxpay ELSE m.a_pct10::numeric(19,4) END)::numeric(18,0) AS a_pct10,
               (CASE WHEN m.a_pct25=9999999 THEN v_maxpay ELSE m.a_pct25::numeric(19,4) END)::numeric(18,0) AS a_pct25,
               (CASE WHEN m.a_median=9999999 THEN v_maxpay ELSE m.a_median::numeric(19,4) END)::numeric(18,0) AS a_median,
               (CASE WHEN m.a_pct75=9999999 THEN v_maxpay ELSE m.a_pct75::numeric(19,4) END)::numeric(18,0) AS a_pct75,
               (CASE WHEN m.a_pct90=9999999 THEN v_maxpay ELSE m.a_pct90::numeric(19,4) END)::numeric(18,0) AS a_pct90
        FROM "BLS_OES".occupationalemploymentstatisticsmetro m
        WHERE m.soc=p_standardoccupationcode AND m.msacode=v_msacode AND m.amcosversionid=p_amcosversionid)
    SELECT base.appngroup, base.cen, base.descr,
           (base.a_pct10 * COALESCE(v_infl,1))::numeric(18,0), (base.a_pct25 * COALESCE(v_infl,1))::numeric(18,0),
           (base.a_median * COALESCE(v_infl,1))::numeric(18,0), (base.a_pct75 * COALESCE(v_infl,1))::numeric(18,0),
           (base.a_pct90 * COALESCE(v_infl,1))::numeric(18,0)
    FROM base ORDER BY base.cen;
END;
$function$;

-- web.PMInflatedValue — applies the inflation rate to a cost amount.
CREATE OR REPLACE FUNCTION web.pminflatedvalue(
    p_amounttoinflate double precision, p_costelementid integer, p_projectyear smallint,
    p_1activedayamounttoinflate double precision DEFAULT 0, p_activedutydays integer DEFAULT 0,
    p_amcosversionid integer DEFAULT NULL)
RETURNS double precision
LANGUAGE plpgsql
AS $function$
DECLARE
    v_payplan varchar(3); v_appn varchar(25); v_payrate numeric(18,15);
    v_applyinflation boolean; v_amount double precision := p_amounttoinflate;
BEGIN
    SELECT ce.payplan, ce.appn, ce.applyinflation INTO v_payplan, v_appn, v_applyinflation
    FROM lookup.costelement ce WHERE ce.costelementid = p_costelementid;
    IF v_payplan = 'CCE' THEN v_appn := 'OMA'; END IF;
    SELECT j.amount INTO v_payrate FROM lookup.jicinflationrates j
    WHERE j.conversiontype = 'ThenToThen' AND j.appropriation = v_appn
      AND j.year = p_projectyear AND j.amcosversionid = p_amcosversionid;
    IF NOT COALESCE(v_applyinflation, false) THEN v_payrate := 1.00; END IF;
    IF v_payplan IN ('NE','NO','NWO','RE','RO','RWO') THEN
        v_amount := p_1activedayamounttoinflate
                    + (p_amounttoinflate - p_1activedayamounttoinflate) * (p_activedutydays - 1) / 14;
    END IF;
    RETURN v_amount * v_payrate;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getinflationrateheader(
    p_conversiontype varchar(25), p_year varchar(4), p_amcosversionid integer)
RETURNS TABLE(year integer, appropriation varchar(25),
    "Army CivPay" numeric(18,15), "Federal OM" numeric(18,15), mpa numeric(18,15),
    "MPA Non-Pay" numeric(18,15), ngpa numeric(18,15), oma numeric(18,15), oma_1 numeric(18,15),
    omar numeric(18,15), omar_1 numeric(18,15), omdw numeric(18,15), omng numeric(18,15),
    omng_1 numeric(18,15), rpa numeric(18,15))
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT s.year::integer, 'Inflation Rate'::varchar(25),
           SUM(s.amount) FILTER (WHERE s.appropriation='Army CivPay')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='Federal OM')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='MPA')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='MPA Non-Pay')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='NGPA')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMA')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMA_1')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMAR')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMAR_1')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMDW')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMNG')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='OMNG_1')::numeric(18,15),
           SUM(s.amount) FILTER (WHERE s.appropriation='RPA')::numeric(18,15)
    FROM (SELECT j.year, j.appropriation, j.amount FROM lookup.jicinflationrates j
          WHERE j.conversiontype = p_conversiontype AND j.year = p_year::smallint
            AND j.amcosversionid = p_amcosversionid) s
    GROUP BY s.year;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getpmreportinflationrateheader(
    p_projectid integer, p_amcosversionid integer)
RETURNS TABLE(year integer,
    "Army CivPay" numeric(6,4), "Federal OM" numeric(6,4), mpa numeric(6,4),
    "MPA Non-Pay" numeric(6,4), ngpa numeric(6,4), oma numeric(6,4), oma_1 numeric(6,4),
    omar numeric(6,4), omar_1 numeric(6,4), omdw numeric(6,4), omng numeric(6,4),
    omng_1 numeric(6,4), rpa numeric(6,4))
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT inv.year::integer,
           infl."Army CivPay"::numeric(6,4), infl."Federal OM"::numeric(6,4), infl.mpa::numeric(6,4),
           infl."MPA Non-Pay"::numeric(6,4), infl.ngpa::numeric(6,4), infl.oma::numeric(6,4), infl.oma_1::numeric(6,4),
           infl.omar::numeric(6,4), infl.omar_1::numeric(6,4), infl.omdw::numeric(6,4), infl.omng::numeric(6,4),
           infl.omng_1::numeric(6,4), infl.rpa::numeric(6,4)
    FROM webuser.pmreport pr
    JOIN web.pmcategoryskillinventory inv ON inv.categoryid = pr.categoryid AND inv.payplan = pr.payplan
    CROSS JOIN LATERAL web.getinflationrateheader('ThenToThen', inv.year::varchar(4), p_amcosversionid) infl
    WHERE inv.projectid = p_projectid;
END;
$function$;

CREATE OR REPLACE FUNCTION web.pmcostsbypayplan(p_projectid integer, p_amcosversionid integer)
RETURNS TABLE(pmcategoryname varchar(50), uic varchar(6), payplan varchar(3),
    categorygroupcode varchar(10), categorysubgroupcode varchar(10), careerprogramnumber varchar(2),
    locationid integer, locationtext varchar(150), strl varchar(20), gradelevel smallint, grade text,
    dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
    overheadpercent double precision, costsummaryname varchar(50), appn varchar(100),
    costelementcategory varchar(50), costelementname varchar(250), applyinflation boolean,
    showorder integer, costelementid integer, year integer, inventory integer, cost double precision)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT inv.categoryname, inv.uic, inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode,
           inv.careerprogramnumber::varchar(2), (-1)::integer, '-1'::varchar(150), inv.strl, inv.gradelevel,
           web.formatgradelevel(inv.payplan, inv.gradelevel::smallint), inv.dependentstatus,
           inv.numberofdependents, inv.activedutydays, inv.overheadpercent, cs.name, ce.appn,
           ce.costelementcategory, ce.costelementname, ce.applyinflation, ce.showorder, c.costelementid,
           inv.year, inv.amount, (c.amount * inv.amount)::double precision
    FROM data.costs c
    JOIN lookup.costelement ce ON ce.costelementid = c.costelementid
         AND p_amcosversionid BETWEEN ce.amcosversionidstart AND ce.amcosversionidend
    JOIN lookup.costsummaryelement cse ON cse.costelementid = ce.costelementid
         AND p_amcosversionid BETWEEN cse.amcosversionidstart AND cse.amcosversionidend
    JOIN lookup.costsummary cs ON cs.summaryid = cse.summaryid
         AND p_amcosversionid BETWEEN cs.amcosversionidstart AND cs.amcosversionidend
    JOIN web.pmcategoryskillinventory inv ON inv.payplan=c.payplan AND inv.categorygroupcode=c.categorygroupcode
         AND inv.categorysubgroupcode=c.categorysubgroupcode AND inv.careerprogramnumber=c.careerprogramnumber
         AND inv.strl=c.strl AND inv.gradelevel=c.gradelevel AND inv.numberofdependents=c.numberofdependents
    JOIN webuser.pmreport pr ON pr.categoryid=inv.categoryid AND pr.payplan=inv.payplan
    WHERE c.amcosversionid=p_amcosversionid AND inv.projectid=p_projectid
      AND inv.payplan NOT IN ('NE','NO','NWO','RE','RO','RWO')
      AND c.locationid=-1 AND c.dependentstatus='-1' AND c.islocationspecific=false AND cs.name='Default'
    UNION ALL
    SELECT inv.categoryname, inv.uic, inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode,
           inv.careerprogramnumber::varchar(2), inv.locationid, inv.locationtext, inv.strl, inv.gradelevel,
           web.formatgradelevel(inv.payplan, inv.gradelevel::smallint), inv.dependentstatus,
           inv.numberofdependents, inv.activedutydays, inv.overheadpercent, cs.name, ce.appn,
           ce.costelementcategory, ce.costelementname, ce.applyinflation, ce.showorder, c.costelementid,
           inv.year, inv.amount, (c.amount * inv.amount)::double precision
    FROM data.costs c
    JOIN lookup.costelement ce ON ce.costelementid = c.costelementid
         AND p_amcosversionid BETWEEN ce.amcosversionidstart AND ce.amcosversionidend
    JOIN lookup.costsummaryelement cse ON cse.costelementid = ce.costelementid
         AND p_amcosversionid BETWEEN cse.amcosversionidstart AND cse.amcosversionidend
    JOIN lookup.costsummary cs ON cs.summaryid = cse.summaryid
         AND p_amcosversionid BETWEEN cs.amcosversionidstart AND cs.amcosversionidend
    JOIN web.pmcategoryskillinventory inv ON inv.payplan=c.payplan AND inv.categorygroupcode=c.categorygroupcode
         AND inv.categorysubgroupcode=c.categorysubgroupcode AND inv.careerprogramnumber=c.careerprogramnumber
         AND inv.locationid=c.locationid AND inv.strl=c.strl AND inv.gradelevel=c.gradelevel
         AND inv.dependentstatus=c.dependentstatus AND inv.numberofdependents=c.numberofdependents
    JOIN webuser.pmreport pr ON pr.categoryid=inv.categoryid AND pr.payplan=inv.payplan
    WHERE c.amcosversionid=p_amcosversionid AND inv.projectid=p_projectid
      AND inv.payplan NOT IN ('NE','NO','NWO','RE','RO','RWO')
      AND c.islocationspecific=true AND cs.name='Default';
END;
$function$;

CREATE OR REPLACE FUNCTION web.pmcostsbypayplanreservecomponents(p_projectid integer, p_amcosversionid integer)
RETURNS TABLE(pmcategoryname varchar(50), uic varchar(6), payplan varchar(3),
    categorygroupcode varchar(10), categorysubgroupcode varchar(10), careerprogramnumber varchar(2),
    locationid integer, locationtext varchar(150), strl varchar(20), gradelevel smallint, grade text,
    dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
    overheadpercent double precision, costsummaryname varchar(50), appn varchar(100),
    costelementcategory varchar(50), costelementname varchar(250), applyinflation boolean,
    showorder integer, costelementid integer, year integer, inventory integer, cost double precision)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT inv.categoryname, inv.uic, inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode,
           inv.careerprogramnumber::varchar(2), inv.locationid, inv.locationtext, inv.strl, inv.gradelevel,
           web.formatgradelevel(inv.payplan, inv.gradelevel::smallint), inv.dependentstatus,
           inv.numberofdependents, inv.activedutydays, inv.overheadpercent, dsce.costsummaryname,
           dsce.appn, dsce.costelementcategory, dsce.costelementname, dsce.applyinflation, dsce.showorder,
           c.costelementid, inv.year, inv.amount,
           ((c.amount * inv.amount) + web.getadjustedavgannualizedcostoffica(dsce.costelementid,
                ((inv.activedutydays - 15) * COALESCE(cad.amount, 0) * inv.amount)::numeric(26,6),
                p_amcosversionid))::double precision
    FROM data.costs c
    LEFT JOIN crunch.costs_1activeday cad ON cad.payplan=c.payplan
         AND cad.categorysubgroupcode=c.categorysubgroupcode AND cad.costelementid=c.costelementid
         AND cad.gradetype=c.gradetype AND cad.gradelevel=c.gradelevel
         AND cad.weaponsystemid=c.weaponsystemid AND cad.amcosversionid=c.amcosversionid
    JOIN data.currentdefaultsummarycostelements dsce ON c.costelementid = dsce.costelementid
    JOIN web.pmcategoryskillinventory inv ON inv.payplan=c.payplan AND inv.categorygroupcode=c.categorygroupcode
         AND inv.categorysubgroupcode=c.categorysubgroupcode AND inv.careerprogramnumber=c.careerprogramnumber
         AND inv.locationid=c.locationid AND inv.strl=c.strl AND inv.gradelevel=c.gradelevel
         AND inv.dependentstatus=c.dependentstatus
    JOIN webuser.pmreport pr ON pr.categoryid=inv.categoryid AND pr.payplan=inv.payplan
    WHERE c.amcosversionid=p_amcosversionid AND inv.projectid=p_projectid
      AND inv.payplan IN ('NE','NO','NWO','RE','RO','RWO');
END;
$function$;

CREATE OR REPLACE FUNCTION web.pmcostsbypayplancce(p_projectid integer, p_amcosversionid integer)
RETURNS TABLE(pmcategoryname varchar(50), uic varchar(6), payplan varchar(3),
    categorygroupcode varchar(10), categorysubgroupcode varchar(10), careerprogramnumber varchar(2),
    locationid integer, locationtext varchar(150), strl varchar(20), gradelevel smallint, grade varchar(10),
    dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
    overheadpercent double precision, costsummaryname varchar(50), appn varchar(100),
    costelementcategory varchar(50), costelementname varchar(250), costelementid integer,
    applyinflation boolean, showorder integer, year integer, inventory integer, cost double precision,
    exceedssalarylimit boolean)
LANGUAGE plpgsql
AS $function$
#variable_conflict use_column
DECLARE
    v_csn varchar(200) := 'Default';
    v_salid integer; v_salappn varchar(100); v_salcat varchar(50); v_salname varchar(250); v_salinf boolean; v_salord integer;
    v_benid integer; v_benappn varchar(100); v_bencat varchar(50); v_benname varchar(250); v_beninf boolean; v_benord integer;
    v_ovhid integer; v_ovhappn varchar(100); v_ovhcat varchar(50); v_ovhname varchar(250); v_ovhinf boolean; v_ovhord integer;
    v_benefitratio numeric(18,4);
    v_maxpay double precision;
BEGIN
    v_maxpay := crunch.getsinglevalue('CCE','MaxPayFootnote',p_amcosversionid)::double precision;
    v_benefitratio := crunch.getsinglevalue('CCE','Benefits_All',p_amcosversionid)::numeric(18,4);
    SELECT ce.costelementid, ce.appn, ce.costelementcategory, ce.costelementname, ce.applyinflation, ce.showorder
      INTO v_salid, v_salappn, v_salcat, v_salname, v_salinf, v_salord
    FROM lookup.costelement ce WHERE ce.payplan='CCE' AND ce.costelementname='Avg Cost of Salary';
    SELECT ce.costelementid, ce.appn, ce.costelementcategory, ce.costelementname, ce.applyinflation, ce.showorder
      INTO v_benid, v_benappn, v_bencat, v_benname, v_beninf, v_benord
    FROM lookup.costelement ce WHERE ce.payplan='CCE' AND ce.costelementname='Avg Cost of Benefits';
    SELECT ce.costelementid, ce.appn, ce.costelementcategory, ce.costelementname, ce.applyinflation, ce.showorder
      INTO v_ovhid, v_ovhappn, v_ovhcat, v_ovhname, v_ovhinf, v_ovhord
    FROM lookup.costelement ce WHERE ce.payplan='CCE' AND ce.costelementname='Avg Cost of Overhead';

    CREATE TEMP TABLE tmp_cce (
        pmcategoryname varchar(50), uic varchar(6), payplan varchar(3), categorygroupcode varchar(10),
        categorysubgroupcode varchar(10), careerprogramnumber varchar(2), locationid integer,
        locationtext varchar(150), strl varchar(20), gradelevel smallint, grade varchar(10),
        dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
        overheadpercent double precision, costsummaryname varchar(50), appn varchar(100),
        costelementcategory varchar(50), costelementname varchar(250), costelementid integer,
        applyinflation boolean, showorder integer, year integer, inventory integer, cost double precision,
        exceedssalarylimit boolean) ON COMMIT DROP;

    INSERT INTO tmp_cce
    SELECT DISTINCT inv.categoryname, inv.uic, inv.payplan, inv.categorygroupcode, inv.categorysubgroupcode,
           inv.careerprogramnumber::varchar(2), inv.locationid, inv.locationtext, inv.strl, g.gradelevel, g.grade,
           inv.dependentstatus, inv.numberofdependents, inv.activedutydays, inv.overheadpercent, v_csn,
           v_salappn, v_salcat, v_salname, v_salid, v_salinf, v_salord, inv.year, inv.amount,
           CASE WHEN g.pct=9999999 THEN v_maxpay*inv.amount ELSE g.pct*inv.amount END,
           CASE WHEN g.pct=9999999 THEN true ELSE false END
    FROM data.costscce c
    JOIN web.pmcategoryskillinventory inv ON inv.categorysubgroupcode=c.soc AND inv.locationid=c.locationid
    CROSS JOIN LATERAL (VALUES
        (1::smallint,'A_PCT10'::varchar(10),c.a_pct10),(2::smallint,'A_PCT25'::varchar(10),c.a_pct25),
        (3::smallint,'A_MEDIAN'::varchar(10),c.a_median),(4::smallint,'A_PCT75'::varchar(10),c.a_pct75),
        (5::smallint,'A_PCT90'::varchar(10),c.a_pct90)) AS g(gradelevel,grade,pct)
    WHERE inv.projectid=p_projectid AND inv.gradelevel=g.gradelevel AND c.amcosversionid=p_amcosversionid;

    INSERT INTO tmp_cce
    SELECT pmcategoryname, uic, payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
           locationid, locationtext, strl, gradelevel, grade, dependentstatus, numberofdependents,
           activedutydays, overheadpercent, v_csn, v_benappn, v_bencat, v_benname, v_benid, v_beninf, v_benord,
           year, inventory, cost*v_benefitratio, exceedssalarylimit
    FROM tmp_cce WHERE costelementid = v_salid;

    INSERT INTO tmp_cce
    SELECT pmcategoryname, uic, payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
           locationid, locationtext, strl, gradelevel, grade, dependentstatus, numberofdependents,
           activedutydays, overheadpercent, v_csn, v_ovhappn, v_ovhcat, v_ovhname, v_ovhid, v_ovhinf, v_ovhord,
           year, inventory, cost*overheadpercent/100, exceedssalarylimit
    FROM tmp_cce WHERE costelementid = v_salid;

    RETURN QUERY SELECT * FROM tmp_cce;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getalllocationidbyinstallation(p_installationname varchar(500))
RETURNS TABLE(payplan varchar(3), locationid integer)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT lbc.payplan, lbc.locationid
    FROM warehouse.locationbycategory lbc
    WHERE LEFT(RTRIM(lbc.installation), LENGTH(RTRIM(p_installationname)))
        = LEFT(RTRIM(p_installationname), LENGTH(RTRIM(p_installationname)));
END;
$function$;

CREATE OR REPLACE FUNCTION web.getsacsyears(
    p_uic varchar(6), p_unitlocation varchar(150), p_notselectedpayplans varchar(500),
    p_mtoeprojectinventoryyear varchar(25) DEFAULT NULL)
RETURNS TABLE(uic varchar(6), authorizationdocument varchar(50), uictitle varchar(100),
    payplan varchar(3), categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    locationid integer, locationtext varchar(150), strl varchar(20), gradelevel smallint,
    dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
    inventory integer, unityear varchar(4))
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT up.uic::varchar(6), up.authorizationdocument, up.uictitle::varchar(100), up.payplan,
           up.categorygroupcode, up.categorysubgroupcode,
           (CASE p_unitlocation WHEN 'unchanged' THEN up.locationid WHEN 'national' THEN -1 ELSE -1 END)::integer,
           (CASE p_unitlocation WHEN 'unchanged' THEN up.locationtext ELSE up.locationtext END)::varchar(150),
           up.strl, up.gradelevel, up.dependentstatus, up.numberofdependents, up.activedutydays,
           up.inventory, up.unityear
    FROM warehouse.unitpersonnel up
    WHERE up.uic = p_uic AND up.unityear <> 'OTOE'
      AND (p_mtoeprojectinventoryyear IS NULL OR up.unityear = p_mtoeprojectinventoryyear)
      AND up.payplan NOT IN (SELECT TRIM(value) FROM unnest(string_to_array(p_notselectedpayplans, ',')) AS value);
END;
$function$;

CREATE OR REPLACE FUNCTION web.getextendedyears(
    p_uic varchar(6), p_unitlocation varchar(150), p_notselectedpayplans varchar(500),
    p_mtoesyncextendeddurationfillvalue varchar(25) DEFAULT 'OTOE',
    p_projectyearstart integer DEFAULT NULL, p_projectyearduration integer DEFAULT NULL)
RETURNS TABLE(uic varchar(6), authorizationdocument varchar(50), uictitle varchar(100),
    payplan varchar(3), categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    locationid integer, locationtext varchar(150), strl varchar(20), gradelevel smallint,
    dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
    inventory integer, unityear varchar(4))
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fillvalue varchar(4); v_last varchar(4); v_last_int integer; v_tofill integer; v_lastfill integer;
BEGIN
    v_last := web.getlastmtoeunityear(p_uic);
    v_last_int := v_last::integer;
    v_tofill := p_projectyearduration - (v_last_int - p_projectyearstart) - 1;
    v_lastfill := v_last_int + v_tofill;
    IF p_mtoesyncextendeddurationfillvalue = 'OTOE' THEN v_fillvalue := 'OTOE'; ELSE v_fillvalue := v_last; END IF;
    RETURN QUERY
    WITH RECURSIVE cte (uic, authorizationdocument, uictitle, payplan, categorygroupcode,
                        categorysubgroupcode, locationid, locationtext, strl, gradelevel,
                        dependentstatus, numberofdependents, activedutydays, inventory, unityear) AS (
        SELECT up.uic, up.authorizationdocument, up.uictitle, up.payplan, up.categorygroupcode,
               up.categorysubgroupcode,
               CASE p_unitlocation WHEN 'unchanged' THEN up.locationid WHEN 'national' THEN -1 ELSE -1 END,
               CASE p_unitlocation WHEN 'unchanged' THEN up.locationtext ELSE up.locationtext END,
               up.strl, up.gradelevel, up.dependentstatus, up.numberofdependents, up.activedutydays,
               up.inventory, (v_last_int + 1)
        FROM warehouse.unitpersonnel up
        WHERE up.uic = p_uic AND up.unityear = v_fillvalue
          AND up.payplan NOT IN (SELECT TRIM(value) FROM unnest(string_to_array(p_notselectedpayplans, ',')) AS value)
        UNION ALL
        SELECT cte.uic, cte.authorizationdocument, cte.uictitle, cte.payplan, cte.categorygroupcode,
               cte.categorysubgroupcode, cte.locationid, cte.locationtext, cte.strl, cte.gradelevel,
               cte.dependentstatus, cte.numberofdependents, cte.activedutydays, cte.inventory, cte.unityear + 1
        FROM cte WHERE cte.unityear < v_lastfill)
    SELECT cte.uic::varchar(6), cte.authorizationdocument, cte.uictitle::varchar(100), cte.payplan,
           cte.categorygroupcode, cte.categorysubgroupcode, cte.locationid::integer, cte.locationtext::varchar(150),
           cte.strl, cte.gradelevel, cte.dependentstatus, cte.numberofdependents, cte.activedutydays,
           cte.inventory, cte.unityear::varchar(4)
    FROM cte;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getunitpersonnel(
    p_categoryid integer, p_uic varchar(6), p_notselectedpayplans varchar(500), p_unitlocation varchar(150),
    p_mtoeprojectinventoryyear varchar(25) DEFAULT NULL,
    p_mtoesyncextendeddurationfillvalue varchar(25) DEFAULT 'OTOE', p_overheadpercent double precision DEFAULT 150)
RETURNS TABLE(uic varchar(6), authorizationdocument varchar(50), uictitle varchar(100),
    payplan varchar(3), categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    locationid integer, locationtext varchar(150), strl varchar(20), gradelevel smallint,
    dependentstatus varchar(25), numberofdependents integer, activedutydays smallint,
    overheadpercent double precision, inventory integer, unityear varchar(4))
LANGUAGE plpgsql
AS $function$
DECLARE
    v_locname varchar(100) := NULL; v_authdoc varchar(50);
BEGIN
    IF p_unitlocation ~ '^[+-]?\d+$' THEN v_locname := web.getlocationdisplayname(p_unitlocation::integer); END IF;
    v_authdoc := web.getunitauthorizationdocument(p_uic);
    IF POSITION('TDA' IN COALESCE(v_authdoc, '')) > 0 THEN
        RETURN QUERY
        SELECT up.uic::varchar(6), up.authorizationdocument, up.uictitle::varchar(100), up.payplan,
               up.categorygroupcode, up.categorysubgroupcode,
               (CASE p_unitlocation WHEN 'unchanged' THEN up.locationid WHEN 'national' THEN -1 ELSE COALESCE(xw.locationid,-1) END)::integer,
               (CASE p_unitlocation WHEN 'unchanged' THEN up.locationtext WHEN 'national' THEN 'All' ELSE COALESCE(web.getlocationdisplayname(xw.locationid),'All') END)::varchar(150),
               up.strl, up.gradelevel, up.dependentstatus, up.numberofdependents, up.activedutydays,
               (CASE up.payplan WHEN 'CCE' THEN p_overheadpercent ELSE -1 END)::double precision, up.inventory, '0'::varchar(4)
        FROM warehouse.unitpersonnel up
        LEFT JOIN web.getalllocationidbyinstallation(v_locname) xw ON xw.payplan = up.payplan
        WHERE up.uic = p_uic
          AND up.payplan NOT IN (SELECT TRIM(value) FROM unnest(string_to_array(p_notselectedpayplans, ',')) AS value);
    ELSE
        RETURN QUERY
        SELECT sy.uic::varchar(6), sy.authorizationdocument, sy.uictitle::varchar(100), sy.payplan,
               sy.categorygroupcode, sy.categorysubgroupcode,
               (CASE p_unitlocation WHEN 'unchanged' THEN sy.locationid WHEN 'national' THEN -1 ELSE COALESCE(xw.locationid,-1) END)::integer,
               (CASE p_unitlocation WHEN 'unchanged' THEN sy.locationtext WHEN 'national' THEN 'All' ELSE COALESCE(web.getlocationdisplayname(xw.locationid),'All') END)::varchar(150),
               sy.strl, sy.gradelevel, sy.dependentstatus, sy.numberofdependents, sy.activedutydays,
               (CASE sy.payplan WHEN 'CCE' THEN p_overheadpercent ELSE -1 END)::double precision, sy.inventory, sy.unityear
        FROM web.getsacsyears(p_uic, p_unitlocation, p_notselectedpayplans, p_mtoeprojectinventoryyear) sy
        LEFT JOIN web.getalllocationidbyinstallation(v_locname) xw ON xw.payplan = sy.payplan
        UNION ALL
        SELECT ey.uic::varchar(6), ey.authorizationdocument, ey.uictitle::varchar(100), ey.payplan,
               ey.categorygroupcode, ey.categorysubgroupcode,
               (CASE p_unitlocation WHEN 'unchanged' THEN ey.locationid WHEN 'national' THEN -1 ELSE COALESCE(xw.locationid,-1) END)::integer,
               (CASE p_unitlocation WHEN 'unchanged' THEN ey.locationtext WHEN 'national' THEN 'All' ELSE COALESCE(web.getlocationdisplayname(xw.locationid),'All') END)::varchar(150),
               ey.strl, ey.gradelevel, ey.dependentstatus, ey.numberofdependents, ey.activedutydays,
               (CASE ey.payplan WHEN 'CCE' THEN p_overheadpercent ELSE -1 END)::double precision, ey.inventory, ey.unityear
        FROM web.getextendedyears(p_uic, p_unitlocation, p_notselectedpayplans, p_mtoesyncextendeddurationfillvalue,
                 web.getprojectyearstart(p_categoryid), web.getprojectyearduration(p_categoryid)) ey
        JOIN web.getalllocationidbyinstallation(v_locname) xw ON xw.payplan = ey.payplan;
    END IF;
    RETURN;
END;
$function$;

CREATE OR REPLACE FUNCTION web.pminventorybyskillid(p_projectid integer)
RETURNS TABLE(projectid integer, pmcategoryname text, categoryid integer, payplan varchar(3),
    skillid integer, categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    gradelevel smallint, year integer, inventory numeric, activedutydays smallint)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT cat.projectid, cat.categoryname::text, cat.categoryid, sk.payplan, sk.skillid,
           sk.categorygroupcode, sk.categorysubgroupcode, sk.gradelevel, csi.year, csi.amount::numeric, sk.activedutydays
    FROM webuser.pmcategory cat
    JOIN webuser.pmcategoryskill sk ON cat.categoryid = sk.categoryid
    JOIN webuser.pmcategoryskillinventory csi ON sk.skillid = csi.skillid
    WHERE cat.projectid = p_projectid;
END;
$function$;

-- ============================ unit-requirement validators ============================

CREATE OR REPLACE FUNCTION web.pmvalidateunitrequirementcce(
    p_payplan varchar(3), p_categorygroupcode varchar(10), p_categorysubgroupcode varchar(10),
    p_careerprogramnumber char(2), p_locationid integer, p_strl varchar(20), p_gradelevel smallint,
    p_dependentstatus varchar(25), p_numberofdependents integer, p_amcosversionid integer)
RETURNS TABLE(payplan varchar(3), categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    careerprogramnumber char(2), locationid integer, strl varchar(20), gradelevel smallint,
    dependentstatus varchar(25), numberofdependents integer)
LANGUAGE plpgsql
AS $function$
BEGIN
    IF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode=p_categorysubgroupcode AND c.careerprogramnumber=p_careerprogramnumber
        AND c.locationid=p_locationid AND c.strl=p_strl AND c.gradelevel=p_gradelevel
        AND c.dependentstatus=p_dependentstatus AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=p_locationid
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus=p_dependentstatus
        AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,'-1'::varchar(10),p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode='-1'
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=p_locationid
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus=p_dependentstatus
        AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,'-1'::varchar(10),'-1'::varchar(10),p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode=p_categorysubgroupcode AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=-1
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus=p_dependentstatus
        AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,-1,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=-1
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus=p_dependentstatus
        AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,'-1'::varchar(10),p_careerprogramnumber,-1,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode='-1'
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=-1
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus=p_dependentstatus
        AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,'-1'::varchar(10),'-1'::varchar(10),p_careerprogramnumber,-1,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSE
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION web.pmvalidateunitrequirementnoncce(
    p_payplan varchar(3), p_categorygroupcode varchar(10), p_categorysubgroupcode varchar(10),
    p_careerprogramnumber char(2), p_locationid integer, p_strl varchar(20), p_gradelevel smallint,
    p_dependentstatus varchar(25), p_numberofdependents integer, p_amcosversionid integer)
RETURNS TABLE(payplan varchar(3), categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    careerprogramnumber char(2), locationid integer, strl varchar(20), gradelevel smallint,
    dependentstatus varchar(25), numberofdependents integer)
LANGUAGE plpgsql
AS $function$
BEGIN
    IF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode=p_categorysubgroupcode AND c.careerprogramnumber=p_careerprogramnumber
        AND c.locationid=p_locationid AND c.strl=p_strl AND c.gradelevel=p_gradelevel
        AND c.dependentstatus=p_dependentstatus AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode=p_categorysubgroupcode AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=p_locationid
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus='average' AND c.numberofdependents=-1 AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,'average'::varchar(25),-1;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=p_locationid
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus='-1' AND c.numberofdependents=-1 AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,'-1'::varchar(10),p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,'-1'::varchar(25),-1;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode='-1'
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=p_locationid
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus='-1' AND c.numberofdependents=-1 AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,'-1'::varchar(10),'-1'::varchar(10),p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,'-1'::varchar(25),-1;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode=p_categorysubgroupcode AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=-1
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus=p_dependentstatus AND c.numberofdependents=p_numberofdependents AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,-1,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode=p_categorygroupcode
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=-1
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus='-1' AND c.numberofdependents=-1 AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,'-1'::varchar(10),p_careerprogramnumber,-1,p_strl,p_gradelevel,'-1'::varchar(25),-1;
    ELSIF EXISTS (SELECT 1 FROM data.costs c WHERE c.payplan=p_payplan AND c.categorygroupcode='-1'
        AND c.categorysubgroupcode='-1' AND c.careerprogramnumber=p_careerprogramnumber AND c.locationid=-1
        AND c.strl=p_strl AND c.gradelevel=p_gradelevel AND c.dependentstatus='-1' AND c.numberofdependents=-1 AND c.amcosversionid=p_amcosversionid) THEN
        RETURN QUERY SELECT p_payplan,'-1'::varchar(10),'-1'::varchar(10),p_careerprogramnumber,-1,p_strl,p_gradelevel,'-1'::varchar(25),-1;
    ELSE
        RETURN QUERY SELECT p_payplan,p_categorygroupcode,p_categorysubgroupcode,p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents;
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION web.pmvalidateunitrequirement(
    p_payplan varchar(3), p_categorygroupcode varchar(10), p_categorysubgroupcode varchar(10),
    p_careerprogramnumber char(2), p_locationid integer, p_strl varchar(20), p_gradelevel smallint,
    p_dependentstatus varchar(25), p_numberofdependents integer, p_amcosversionid integer)
RETURNS TABLE(payplan varchar(3), categorygroupcode varchar(10), categorysubgroupcode varchar(10),
    careerprogramnumber char(2), locationid integer, strl varchar(20), gradelevel smallint,
    dependentstatus varchar(25), numberofdependents integer)
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_payplan = 'CCE' THEN
        RETURN QUERY SELECT * FROM web.pmvalidateunitrequirementcce(p_payplan,p_categorygroupcode,p_categorysubgroupcode,
            p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents,p_amcosversionid);
    ELSE
        RETURN QUERY SELECT * FROM web.pmvalidateunitrequirementnoncce(p_payplan,p_categorygroupcode,p_categorysubgroupcode,
            p_careerprogramnumber,p_locationid,p_strl,p_gradelevel,p_dependentstatus,p_numberofdependents,p_amcosversionid);
    END IF;
END;
$function$;