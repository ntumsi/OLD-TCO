-- 010_inventory_demo.sql
-- Demo inventory head-count for the local Inventory dashboard. Seeds crunch.inventory_gfebs
-- (the one data.inventory branch with no pay-plan-tag filter, so it always surfaces even
-- though lookup.payplantags is unseeded here) for a few lab-demo / acq pay plans that also
-- appear in Cost Compare (DB, NH, GG), across two occupational groups, pay bands 1-5, and
-- two AMCOS versions (202501 current + 202401 prior at ~93%) so the two-version comparison
-- shows a visible delta.
--
-- Idempotent: clears these demo rows first. Purely demo data; real inventory comes from ETL.

DELETE FROM crunch.inventory_gfebs
WHERE payplan IN ('DB', 'NH', 'GG')
  AND amcosversionid IN (202501, 202401);

INSERT INTO crunch.inventory_gfebs
    (payplan, occupationalgroupnumber, occupationalseriesnumber, locationid, strl,
     gradetype, gradelevel, step, yos, inventory, amcosversionid)
SELECT pp.payplan,
       og.grp,
       og.series,
       1              AS locationid,
       '-1'           AS strl,
       'CE'           AS gradetype,
       g.grade        AS gradelevel,
       0              AS step,
       0              AS yos,
       -- Head-count rises with grade then is scaled by the per-version factor and a small
       -- per-group offset, so bars differ by group, grade, and version.
       GREATEST(1, round((40 + g.grade * 12 + og.grp_offset) * ver.factor))::int AS inventory,
       ver.v          AS amcosversionid
FROM (VALUES ('DB'), ('NH'), ('GG')) AS pp(payplan)
CROSS JOIN (VALUES ('0800', '0801', 0), ('1500', '1550', 10)) AS og(grp, series, grp_offset)
CROSS JOIN generate_series(1, 5) AS g(grade)
CROSS JOIN (VALUES (202501, 1.00), (202401, 0.93)) AS ver(v, factor);
