-- 009_version_compare_demo.sql
-- Demo data for the local dashboards' two-version comparison. Derives a prior AMCOS
-- version (202401) from the seeded current version (202501) for every crunch.costs_*
-- fact table, scaling amount to 95% so Cost Compare shows a visible A-vs-B delta.
--
-- Idempotent: existing 202401 rows are removed first, then re-derived. Purely demo
-- data; real prior-version data comes from the ETL. lookup.amcosversion already
-- carries 202401 (seed 001), so the version selector and joins resolve.

DO $$
DECLARE
    r        record;
    v_prior  integer := 202401;
    v_curr   integer := 202501;
    n        bigint;
    cols     text;
    sel      text;
    inserted bigint;
BEGIN
    FOR r IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'crunch'
          AND table_name LIKE 'costs\_%'
          AND table_type = 'BASE TABLE'
    LOOP
        -- Skip tables with no current-version rows.
        EXECUTE format('SELECT count(*) FROM crunch.%I WHERE amcosversionid = %L', r.table_name, v_curr)
            INTO n;
        CONTINUE WHEN n = 0;

        -- Refresh any prior demo rows so the script can be re-run safely.
        EXECUTE format('DELETE FROM crunch.%I WHERE amcosversionid = %L', r.table_name, v_prior);

        -- Build an explicit column list + a matching SELECT that overrides amcosversionid
        -- (-> prior) and amount (-> 95%), passing every other column through unchanged.
        SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position),
               string_agg(
                   CASE
                       WHEN column_name = 'amcosversionid' THEN format('%L::integer', v_prior)
                       WHEN column_name = 'amount'          THEN 'round(amount * 0.95, 2)'
                       ELSE quote_ident(column_name)
                   END,
                   ', ' ORDER BY ordinal_position)
        INTO cols, sel
        FROM information_schema.columns
        WHERE table_schema = 'crunch' AND table_name = r.table_name;

        EXECUTE format(
            'INSERT INTO crunch.%I (%s) SELECT %s FROM crunch.%I WHERE amcosversionid = %L',
            r.table_name, cols, sel, r.table_name, v_curr);
        GET DIAGNOSTICS inserted = ROW_COUNT;

        RAISE NOTICE 'crunch.%: derived % prior-version (v%) rows', r.table_name, inserted, v_prior;
    END LOOP;
END $$;
