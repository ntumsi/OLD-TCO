-- ==========================================================================
-- AMCOS seed: demo users + a worked sample project
-- Idempotent. Identity ids are resolved via subqueries on natural keys.
--
-- Demo accounts (development / staging only — remove before production):
--   admin.demo  -> Admin role   (userrole = 'Admin')
--   analyst.demo-> standard user (userrole = 'User')
-- ==========================================================================

-- --------------------------------------------------------------------------
-- Users
-- --------------------------------------------------------------------------
INSERT INTO webuser.amcosuser
    (userid, firstname, lastname, email, prefix, armyrank, armyaccounttype,
     officename, companyname, macom, accessstatus, userstatus, userrole,
     selfaccounttype, datecreated, lastupdate, lastapproveddate, lastlogin)
VALUES
    ('admin.demo',   'Avery',  'Admin',   'admin.demo@army.mil',   'Mr.', NULL, 'Government',
     'DASA-CE', 'Department of the Army', 'FC', 1, 'Active', 'Admin',
     'CAC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('analyst.demo', 'Jordan', 'Analyst', 'jordan.analyst@army.mil','Ms.', NULL, 'Government',
     'Cost Analysis Division', 'Department of the Army', 'TR', 1, 'Active', 'User',
     'CAC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (userid) DO NOTHING;

-- --------------------------------------------------------------------------
-- Login history
-- --------------------------------------------------------------------------
INSERT INTO webuser.user_login_history (userid, logindatetime, browser, browserversion) VALUES
    ('admin.demo',   CURRENT_TIMESTAMP - INTERVAL '1 day', 'Edge',   '126'),
    ('admin.demo',   CURRENT_TIMESTAMP,                    'Edge',   '126'),
    ('analyst.demo', CURRENT_TIMESTAMP - INTERVAL '2 hour','Chrome', '127')
ON CONFLICT (userid, logindatetime) DO NOTHING;

-- --------------------------------------------------------------------------
-- Project Manager: sample project owned by analyst.demo
-- --------------------------------------------------------------------------
INSERT INTO webuser.pmproject
    (userid, projectname, yearstart, yearduration, projectcreator, projecttype, description, discountrate)
SELECT 'analyst.demo', 'Sample Weapons System Project', 2025, 5, 'analyst.demo',
       'Weapons System', 'Demo project illustrating a 5-year manpower cost estimate.', 0.0275
WHERE NOT EXISTS (
    SELECT 1 FROM webuser.pmproject p
    WHERE p.userid = 'analyst.demo' AND p.projectname = 'Sample Weapons System Project'
);

-- Categories under the sample project
INSERT INTO webuser.pmcategory (projectid, categoryname)
SELECT p.projectid, v.categoryname
FROM webuser.pmproject p
-- The project-named category is the default "main" bucket every project carries
-- (matches Project.AddProject + GetMainCategoryId); 'Operators'/'Maintainers' are sub-projects.
CROSS JOIN (VALUES ('Sample Weapons System Project'), ('Operators'), ('Maintainers')) AS v(categoryname)
WHERE p.userid = 'analyst.demo'
  AND p.projectname = 'Sample Weapons System Project'
  AND NOT EXISTS (
      SELECT 1 FROM webuser.pmcategory c
      WHERE c.projectid = p.projectid AND c.categoryname = v.categoryname
  );

-- Skills under the "Operators" category
INSERT INTO webuser.pmcategoryskill
    (categoryid, uic, payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
     locationid, locationtext, strl, gradelevel, dependentstatus, numberofdependents,
     activedutydays, overheadpercent)
SELECT c.categoryid, 'WABCAA', v.payplan, v.cgc, v.csc, '00',
       l.locationid, 'Fort Liberty, NC', 'TOE', v.gradelevel, 'With Dependents', 2,
       365, 0.0
FROM webuser.pmcategory c
JOIN webuser.pmproject p ON p.projectid = c.projectid
CROSS JOIN LATERAL (
    SELECT locationid FROM warehouse.location WHERE displayname = 'Fort Liberty, NC' LIMIT 1
) l
CROSS JOIN (VALUES
    ('AE', '11', '11B', 4::smallint),
    ('AE', '11', '11B', 5::smallint),
    ('AO', '11', '11A', 3::smallint)
) AS v(payplan, cgc, csc, gradelevel)
WHERE p.userid = 'analyst.demo'
  AND p.projectname = 'Sample Weapons System Project'
  AND c.categoryname = 'Operators'
  AND NOT EXISTS (
      SELECT 1 FROM webuser.pmcategoryskill s
      WHERE s.categoryid = c.categoryid AND s.payplan = v.payplan
        AND s.categorysubgroupcode = v.csc AND s.gradelevel = v.gradelevel
  );

-- Inventory amounts per skill, spread across the project years
INSERT INTO webuser.pmcategoryskillinventory (skillid, year, amount)
SELECT s.skillid, y.year, (10 + s.gradelevel)::integer
FROM webuser.pmcategoryskill s
JOIN webuser.pmcategory c ON c.categoryid = s.categoryid
JOIN webuser.pmproject p ON p.projectid = c.projectid
CROSS JOIN generate_series(2025, 2029) AS y(year)
WHERE p.userid = 'analyst.demo'
  AND p.projectname = 'Sample Weapons System Project'
  AND NOT EXISTS (
      SELECT 1 FROM webuser.pmcategoryskillinventory i
      WHERE i.skillid = s.skillid AND i.year = y.year
  );

-- A report definition tied to the Operators category
INSERT INTO webuser.pmreport (categoryid, payplan)
SELECT c.categoryid, 'AE'
FROM webuser.pmcategory c
JOIN webuser.pmproject p ON p.projectid = c.projectid
WHERE p.userid = 'analyst.demo'
  AND p.projectname = 'Sample Weapons System Project'
  AND c.categoryname = 'Operators'
  AND NOT EXISTS (
      SELECT 1 FROM webuser.pmreport r WHERE r.categoryid = c.categoryid AND r.payplan = 'AE'
  );

-- --------------------------------------------------------------------------
-- Civilian PCS: sample PCS estimate (Fort Liberty -> Fort Belvoir)
-- --------------------------------------------------------------------------
INSERT INTO webuser.pcsproject
    (userid, projectname, projectsavedate, conversiontype, year, appropriation,
     amcosversionid, originationid, destinationid, calculateddistance, grandtotal, deleted)
SELECT 'analyst.demo', 'Sample PCS Move', CURRENT_TIMESTAMP, 'Raw', 2025, 'O&M',
       202501, o.locationid, d.locationid, 290, 18250.00, FALSE
FROM (SELECT locationid FROM warehouse.location WHERE displayname = 'Fort Liberty, NC' LIMIT 1) o
CROSS JOIN (SELECT locationid FROM warehouse.location WHERE displayname = 'Fort Belvoir, VA' LIMIT 1) d
WHERE NOT EXISTS (
    SELECT 1 FROM webuser.pcsproject pc
    WHERE pc.userid = 'analyst.demo' AND pc.projectname = 'Sample PCS Move'
);
