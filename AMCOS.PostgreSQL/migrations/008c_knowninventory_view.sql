-- data.knowninventory — the "clean inventory" view the crunch cost procedures read.
--
-- Filters data.inventory (008) to exclude rows with unusable YOS/Step sentinels
-- per pay-plan family (Military/DMDC/GFEBS/WASS/CY), classified via lookup.payplantags.
-- Read by the Phase-1 and Phase-3 military cost procs. Source: data/Views/KnownInventory.sql.
-- Runs after 008 (data.inventory) and 001 (lookup.payplantags).

CREATE OR REPLACE VIEW data.knowninventory AS
SELECT payplan,
       categorygroupcode,
       categorysubgroupcode,
       locationid,
       strl,
       gradetype,
       gradelevel,
       step,
       yos,
       inventory,
       amcosversionid
FROM data.inventory
WHERE (
          (   -- military inventory can't have an invalid YOS
              payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'Military')
              AND yos <> 99
              AND yos <> -1
          )
          OR
          (   -- DMDC civilian (blue/white collar) can't have an invalid step
              payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'DMDC')
              -- data.inventory.step is varchar; compare against the sentinel text values
              AND step <> '99'
              AND step <> '-1'
              AND payplan NOT IN (
                  SELECT payplan FROM lookup.payplantags WHERE tag = 'Military'
                  UNION
                  SELECT 'CY'
              )
          )
          OR payplan = 'CY'  -- CY comes in as-is
          OR (payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'GFEBS'))  -- no steps/YOS
          OR (payplan IN (SELECT payplan FROM lookup.payplantags WHERE tag = 'WASS'))   -- wage-based, no pay plan
      )
      AND categorygroupcode <> 'ZZ';
