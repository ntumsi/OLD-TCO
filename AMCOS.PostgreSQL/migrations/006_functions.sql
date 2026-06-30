-- PostgreSQL conversions of web.* functions from the AMCOS SQL Server project.
--
-- SCOPE: This file currently ports the self-contained project-management / admin
-- functions that depend only on the webuser/web/lookup tables already created in
-- migrations 001-005. The cost-engine functions (web.GetCosts, web.CostsCCE,
-- web.CostsCCEInflated, web.PMCostsByPayPlan*, web.GetInflationRateHeader, etc.)
-- are NOT ported here because they read the data.* views, which in turn read the
-- crunch.* tables produced by the cost-crunch engine / ETL. Those crunch tables do
-- not yet exist in the migrations. See MIGRATION_PARITY_AUDIT.md (Tier B).
--
-- C# callers invoke table-returning functions as `SELECT * FROM web.fn(...)`, so they
-- return real typed columns (not the jsonb pattern used by some procedures in 007).

-- web.GetPendingUserCount() -> int. Rendered in the page header for admins.
CREATE OR REPLACE FUNCTION web.getpendingusercount()
RETURNS integer
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(*)::integer
    FROM webuser.amcosuser
    WHERE userstatus LIKE 'Pending%';
$$;

-- web.FormatGradeLevel(payplan, gradelevel) -> text. Display helper, e.g. 'AE',5 -> 'E5'.
CREATE OR REPLACE FUNCTION web.formatgradelevel(p_payplan text, p_gradelevel smallint)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT (CASE p_payplan
                WHEN 'AE'  THEN 'E'
                WHEN 'AO'  THEN 'O'
                WHEN 'AWO' THEN 'W'
                WHEN 'NE'  THEN 'E'
                WHEN 'NO'  THEN 'O'
                WHEN 'NWO' THEN 'W'
                WHEN 'RE'  THEN 'E'
                WHEN 'RO'  THEN 'O'
                WHEN 'RWO' THEN 'W'
                ELSE p_payplan
            END) || COALESCE(p_gradelevel::text, '');
$$;

-- web.ProjectCategoryCount(projectId, fromCategoryId, toCategoryId) -> int.
-- Counts skills in the "from" category that are NOT already present in the "to"
-- category; used to detect duplicates before copying a project category.
CREATE OR REPLACE FUNCTION web.projectcategorycount(
    p_projectid integer,
    p_fromcategoryid integer,
    p_tocategoryid integer
)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(*)::integer
    FROM (
        SELECT cat.projectid, sk.payplan, sk.categorysubgroupcode,
               sk.gradelevel, sk.overheadpercent
        FROM webuser.pmcategoryskill sk
        JOIN webuser.pmcategory cat ON cat.categoryid = sk.categoryid
        WHERE cat.projectid = p_projectid
          AND sk.categoryid = p_fromcategoryid
    ) a
    LEFT JOIN (
        SELECT cat.projectid, sk.payplan, sk.categorysubgroupcode,
               sk.gradelevel, sk.overheadpercent
        FROM webuser.pmcategoryskill sk
        JOIN webuser.pmcategory cat ON cat.categoryid = sk.categoryid
        WHERE cat.projectid = p_projectid
          AND sk.categoryid = p_tocategoryid
    ) b
      ON a.projectid = b.projectid
         AND a.payplan = b.payplan
         AND a.categorysubgroupcode = b.categorysubgroupcode
         AND a.gradelevel = b.gradelevel
         AND COALESCE(a.overheadpercent, 0) = COALESCE(b.overheadpercent, 0)
    WHERE b.projectid IS NULL;
$$;

-- web.PMGetCategories(projectId) -> table. Project categories excluding the
-- auto-created category that mirrors the project name.
CREATE OR REPLACE FUNCTION web.pmgetcategories(p_projectid integer)
RETURNS TABLE(projectid integer, categoryid integer, categoryname text)
LANGUAGE sql
STABLE
AS $$
    SELECT c.projectid, c.categoryid, c.categoryname
    FROM webuser.pmcategory c
    JOIN webuser.pmproject p
      ON c.projectid = p.projectid
     AND c.categoryname <> p.projectname
    WHERE p.projectid = p_projectid;
$$;

-- web.PMGetCategoriesAll(projectId) -> table. All project categories.
CREATE OR REPLACE FUNCTION web.pmgetcategoriesall(p_projectid integer)
RETURNS TABLE(projectid integer, categoryid integer, categoryname text)
LANGUAGE sql
STABLE
AS $$
    SELECT c.projectid, c.categoryid, c.categoryname
    FROM webuser.pmcategory c
    JOIN webuser.pmproject p ON c.projectid = p.projectid
    WHERE p.projectid = p_projectid;
$$;

-- web.PMGetProjectOutputs(projectId) -> table. Distinct category/payplan outputs.
-- Queries the base tables directly (equivalent to the web.pmcategoryskill view,
-- which is defined later in 008) so this function is self-contained at 006.
CREATE OR REPLACE FUNCTION web.pmgetprojectoutputs(p_projectid integer)
RETURNS TABLE(categoryid integer, category text, payplan text)
LANGUAGE sql
STABLE
AS $$
    SELECT c.categoryid, c.categoryname AS category, sk.payplan
    FROM webuser.pmcategory c
    JOIN webuser.pmproject p  ON p.projectid = c.projectid
    JOIN webuser.pmcategoryskill sk ON sk.categoryid = c.categoryid
    WHERE c.projectid = p_projectid
    GROUP BY c.categoryname, c.categoryid, sk.payplan;
$$;
