-- View: web.pmcategoryskill
-- Joins project/category/skill tables for the project manager skill grid.
CREATE OR REPLACE VIEW web.pmcategoryskill AS
SELECT
    p.userid,
    p.projectid,
    p.projectname,
    c.categoryname,
    c.categoryid,
    s.payplan,
    s.categorygroupcode,
    s.categorysubgroupcode,
    s.careerprogramnumber,
    s.locationid,
    s.locationtext,
    s.strl,
    s.gradelevel,
    s.dependentstatus,
    s.numberofdependents,
    s.activedutydays,
    s.overheadpercent
FROM webuser.pmproject p
JOIN webuser.pmcategory c ON c.projectid = p.projectid
JOIN webuser.pmcategoryskill s ON s.categoryid = c.categoryid;

-- View: web.amcosversioncy
-- Latest release per calendar year from the AMCOS version list (2020+).
CREATE OR REPLACE VIEW web.amcosversioncy AS
SELECT LEFT(amcosversionid::text, 4)       AS cy,
       MAX(RIGHT(amcosversionid::text, 2)) AS release
FROM lookup.amcosversion
WHERE LENGTH(amcosversionid::text) = 6
  AND amcosversionid >= 202001
GROUP BY LEFT(amcosversionid::text, 4);

-- View: web.pmcategoryskillinventory
-- Project skill inventory by absolute year (raw stored year + project YearStart),
-- limited to the project's duration. Used by the project report.
CREATE OR REPLACE VIEW web.pmcategoryskillinventory AS
SELECT p.userid,
       p.projectid,
       c.categoryname,
       c.categoryid,
       sk.uic,
       sk.payplan,
       sk.categorygroupcode,
       sk.categorysubgroupcode,
       sk.careerprogramnumber,
       sk.locationid,
       sk.locationtext,
       sk.strl,
       sk.gradelevel,
       sk.dependentstatus,
       sk.numberofdependents,
       sk.activedutydays,
       sk.overheadpercent,
       inv.year + p.yearstart AS year,
       inv.amount
FROM webuser.pmcategory c
JOIN webuser.pmcategoryskill sk           ON c.categoryid = sk.categoryid
JOIN webuser.pmcategoryskillinventory inv ON sk.skillid = inv.skillid
JOIN webuser.pmproject p                  ON p.projectid = c.projectid
JOIN webuser.pmreport r                   ON r.categoryid = c.categoryid
                                         AND r.payplan = sk.payplan
WHERE inv.year <= p.yearduration - 1;

-- View: web.pendingusers
-- Users awaiting approval, with their sponsor's details for CONTRACTOR/OTHER types.
-- (Replaces the empty placeholder table previously created in 004_web_tables.sql.)
CREATE OR REPLACE VIEW web.pendingusers AS
SELECT u.userid || ',' || u.firstname || ' ' || COALESCE(u.middlename, '') || u.lastname || ',' || u.email AS userinfo,
       u.firstname || ' ' || COALESCE(u.middlename, '') || u.lastname AS username,
       u.email           AS useremail,
       u.comphone        AS userphone,
       u.officename      AS userofficename,
       u.macom           AS usermacom,
       u.selfaccounttype AS useraccounttype,
       u.armyrank        AS userarmyrank,
       u.companyname     AS usercompanyname,
       u.lastlogin       AS userlastlogin,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL
            ELSE s.firstname || ' ' || COALESCE(s.middlename, '') || s.lastname END AS sponsorname,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL ELSE s.email           END AS sponsoremail,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL ELSE s.comphone        END AS sponsorphone,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL ELSE s.officename      END AS sponsorofficename,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL ELSE s.macom           END AS sponsormacom,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL ELSE s.selfaccounttype END AS sponsoraccounttype,
       CASE WHEN u.selfaccounttype IN ('MILITARY', 'CIVILIAN') THEN NULL ELSE s.armyrank        END AS sponsorarmyrank,
       u.userstatus      AS userstatus
FROM webuser.amcosuser u
LEFT JOIN webuser.amcosuser s ON u.sponsoruserid = s.userid
WHERE u.userstatus LIKE 'Pending%';

------------------------------------------------------------------------------
-- data.* cost-engine views (over the crunch.* tables in 005b + lookup.*).
-- These are empty until the ETL populates crunch.*; see MIGRATION_PARITY_AUDIT.md.
-- Integer literals (-1) are used where SQL Server relied on implicit text->int
-- conversion in UNIONs (PostgreSQL requires the literal types to unify).
------------------------------------------------------------------------------

-- data.CostElement — active cost elements (passthrough of lookup.costelement).
CREATE OR REPLACE VIEW data.costelement AS
SELECT costelementid, payplan, appropriationgroup, appn, costelementcategory,
       costelementname, amort, model, locality, description, businesslogic,
       basisofcomputation, source, showorder, armycestitle, osdcapecestitle, active
FROM lookup.costelement
WHERE active = true;

-- data.CostsCCE — CCE market pay (BLS OES metro joined to MSA locations).
CREATE OR REPLACE VIEW data.costscce AS
SELECT m.soc, m.msacode, m.a_pct10, m.a_pct25, m.a_median, m.a_pct75, m.a_pct90,
       m.amcosversionid, l.locationid
FROM "BLS_OES".occupationalemploymentstatisticsmetro m
JOIN warehouse.location l ON l.sourcesystemcode = m.msacode
WHERE l.locationtype = 'MSA';

-- data.CurrentDefaultSummaryCostElements — cost elements in the latest 'Default' summary.
CREATE OR REPLACE VIEW data.currentdefaultsummarycostelements AS
WITH cse AS (
    SELECT summaryid, costelementid, MAX(amcosversionidend) AS amcosversionidend
    FROM lookup.costsummaryelement
    GROUP BY summaryid, costelementid),
cs AS (
    SELECT summaryid, name, MAX(amcosversionidend) AS amcosversionidend
    FROM lookup.costsummary
    WHERE name = 'Default'
    GROUP BY summaryid, name),
ce AS (
    SELECT costelementid, payplan, appn, costelementcategory, costelementname,
           applyinflation, showorder, MAX(amcosversionidend) AS amcosversionidend
    FROM lookup.costelement
    GROUP BY costelementid, payplan, appn, costelementcategory, costelementname,
             applyinflation, showorder)
SELECT cse.costelementid, ce.payplan, ce.appn, ce.costelementcategory,
       ce.costelementname, ce.applyinflation, ce.showorder, cs.name AS costsummaryname
FROM cs
JOIN cse ON cse.summaryid = cs.summaryid
JOIN ce  ON ce.costelementid = cse.costelementid;

-- data.Inventory — unified inventory across DMDC, WASS and GFEBS sources.
CREATE OR REPLACE VIEW data.inventory AS
SELECT payplan, categorygroup AS categorygroupcode, categorysubgroup AS categorysubgroupcode,
       '-1' AS strl, locationid, gradetype, gradelevel, step, yos, inventory, amcosversionid
FROM crunch.inventoryprocessed
WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'DMDC')
UNION ALL
SELECT payplan, "group" AS categorygroupcode, subgroup AS categorysubgroupcode,
       '-1' AS strl, locationid, gradetype, gradelevel, step, NULL::smallint AS yos, inventory, amcosversionid
FROM crunch.wass_processed
WHERE payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'WASS')
UNION ALL
SELECT payplan, occupationalgroupnumber AS categorygroupcode, occupationalseriesnumber AS categorysubgroupcode,
       strl, locationid, gradetype, gradelevel::text, step::text, yos::smallint, inventory, amcosversionid
FROM crunch.inventory_gfebs;

-- data.Costs — unified per-element costs across all 15 crunch.Costs_* pay-plan tables,
-- joined to the most recent revision of each cost element.
CREATE OR REPLACE VIEW data.costs AS
SELECT (ROW_NUMBER() OVER ())::integer AS rowid,
       allcosts.payplan, allcosts.categorygroupcode, allcosts.categorysubgroupcode,
       allcosts.careerprogramnumber, allcosts.locationid, allcosts.strl, allcosts.costelementid,
       allcosts.weaponsystemid, allcosts.gradetype, allcosts.gradelevel, allcosts.dependentstatus,
       allcosts.numberofdependents, allcosts.amount, allcosts.crunchtime, allcosts.amcosversionid,
       costelement.appropriationgroup, costelement.appn, costelement.costelementcategory,
       costelement.costelementname, costelement.description, costelement.armycestitle,
       costelement.osdcapecestitle, costelement.amort, costelement.model, costelement.locality,
       costelement.applyinflation, costelement.islocationspecific, costelement.showorder
FROM (
    SELECT payplan, cmf AS categorygroupcode, mos AS categorysubgroupcode, '-1' AS careerprogramnumber,
           locationid, '-1' AS strl, costelementid, weaponsystemid, gradetype, gradelevel,
           dependentstatus, -1 AS numberofdependents, amount, crunchtime, amcosversionid
    FROM crunch.costs_ae
    UNION ALL
    SELECT payplan, cmf, aoc, '-1', locationid, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           dependentstatus, -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_ao
    UNION ALL
    SELECT payplan, branch, womos, '-1', locationid, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           dependentstatus, -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_awo
    UNION ALL
    SELECT payplan, cmf, mos, '-1', -1, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_ne
    UNION ALL
    SELECT payplan, cmf, aoc, '-1', -1, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_no
    UNION ALL
    SELECT payplan, branch, womos, '-1', -1, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_nwo
    UNION ALL
    SELECT payplan, cmf, mos, '-1', -1, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_re
    UNION ALL
    SELECT payplan, cmf, aoc, '-1', -1, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_ro
    UNION ALL
    SELECT payplan, branch, womos, '-1', -1, '-1', costelementid, weaponsystemid, gradetype, gradelevel,
           '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_rwo
    UNION ALL
    SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, locationid, '-1',
           costelementid, -1, gradetype, gradelevel, '-1', numberofdependents, amount, crunchtime, amcosversionid
    FROM crunch.costs_g
    UNION ALL
    SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, '-1', locationid, '-1',
           costelementid, -1, gradetype, payband, '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_cy
    UNION ALL
    SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, '-1', locationid, '-1',
           costelementid, -1, gradetype, payband, '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_nf
    UNION ALL
    SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, '-1', locationid, '-1',
           costelementid, -1, gradetype, gradelevel, '-1', numberofdependents, amount, crunchtime, amcosversionid
    FROM crunch.costs_ses
    UNION ALL
    SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, '-1', locationid, '-1',
           costelementid, -1, gradetype, gradelevel, '-1', numberofdependents, amount, crunchtime, amcosversionid
    FROM crunch.costs_wage
    UNION ALL
    SELECT payplan, occupationalgroupnumber, occupationalseriesnumber, careerprogramnumber, locationid, strl,
           costelementid, -1, payplan, gradelevel, '-1', -1, amount, crunchtime, amcosversionid
    FROM crunch.costs_gfebs
) AS allcosts
JOIN (
    -- most recent revision of each cost element (nomenclature/flags)
    SELECT a.*
    FROM lookup.costelement a
    JOIN (
        SELECT costelementid, MAX(amcosversionidend) AS amcosversionidmax
        FROM lookup.costelement
        GROUP BY costelementid
    ) b ON a.costelementid = b.costelementid AND a.amcosversionidend = b.amcosversionidmax
) AS costelement ON costelement.costelementid = allcosts.costelementid;
