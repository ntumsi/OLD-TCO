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
