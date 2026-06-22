-- PostgreSQL conversions for web stored procedures from AMCOS SQL Server project.

-- Result-set returning procedures use (result_set_name text, row_data jsonb) so multi-result and dynamic-shape procedures can be preserved without losing payloads.

-- PostgreSQL PL/pgSQL conversions of SQL Server inventory/pivot procedures.

CREATE OR REPLACE FUNCTION web.spcrosstab(
    p_from text,
    p_select text,
    p_pivotvaluecolumn text,
    p_pivotsortcolumn text,
    p_datacolumn text,
    p_groupby text,
    p_orderby text,
    p_debug boolean DEFAULT false
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $function$
DECLARE
    sql_select text;
    sql_case text := '';
    sql_end text;
    sql_text text;
    pivot_rec record;
BEGIN
    sql_select := 'select ' || p_select;

    FOR pivot_rec IN EXECUTE format(
        'select pivot_value, pivot_sort
         from (
             select distinct cast(%s as text) as pivot_value,
                             cast(%s as integer) as pivot_sort
             from %s
         ) pivot_configuration
         order by pivot_sort',
        p_pivotvaluecolumn,
        p_pivotsortcolumn,
        p_from
    )
    LOOP
        sql_case := sql_case || format(
            ',sum(case cast(%s as text) when %L then %s else 0 end) as %I',
            p_pivotvaluecolumn,
            pivot_rec.pivot_value,
            COALESCE(p_datacolumn, '1'),
            pivot_rec.pivot_value
        );
    END LOOP;

    sql_end := ' from ' || p_from || ' group by ' || p_groupby || ' order by ' || p_orderby;

    IF p_debug THEN
        RAISE NOTICE '%', sql_select || sql_case || sql_end;
    END IF;

    sql_text := format(
        'select %L::text as result_set_name, to_jsonb(src) as row_data from (%s%s%s) as src',
        'spcrosstab',
        sql_select,
        sql_case,
        sql_end
    );

    RETURN QUERY EXECUTE sql_text;
END;
$function$;

CREATE OR REPLACE FUNCTION web.spcrosstabgrades(
    p_from text,
    p_select text,
    p_pivotvaluecolumn text,
    p_pivotsortcolumn text,
    p_datacolumn text,
    p_groupby text,
    p_orderby text,
    p_debug boolean DEFAULT false
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $function$
DECLARE
    sql_select text;
    sql_case text := '';
    sql_end text;
    sql_text text;
    pivot_rec record;
BEGIN
    sql_select := 'select ' || p_select;

    FOR pivot_rec IN EXECUTE format(
        'select pivot_value, pivot_sort
         from (
             select distinct cast(%s as text) as pivot_value,
                             cast(%s as integer) as pivot_sort
             from %s
         ) pivot_configuration
         order by pivot_sort',
        p_pivotvaluecolumn,
        p_pivotsortcolumn,
        p_from
    )
    LOOP
        sql_case := sql_case || format(
            ',sum(case cast(%s as text) when %L then %s else 0 end) as %I',
            p_pivotvaluecolumn,
            pivot_rec.pivot_value,
            COALESCE(p_datacolumn, '1'),
            pivot_rec.pivot_value
        );
    END LOOP;

    sql_end := ' from ' || p_from || ' group by ' || p_groupby || ' order by ' || p_orderby;

    IF p_debug THEN
        RAISE NOTICE '%', sql_select || sql_case || sql_end;
    END IF;

    sql_text := format(
        'select %L::text as result_set_name, to_jsonb(src) as row_data from (%s%s%s) as src',
        'spcrosstabgrades',
        sql_select,
        sql_case,
        sql_end
    );

    RETURN QUERY EXECUTE sql_text;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getinventory(
    p_payplan text,
    p_categorygroupcode text DEFAULT '-1',
    p_categorysubgroupcode text DEFAULT '-1',
    p_amcosversionid integer DEFAULT 202001
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $function$
DECLARE
    column_to_select text := 'step';
    from_clause text;
    select_clause text;
    pivot_value_column text := 'grade';
    pivot_sort_column text := 'gradelevel';
    data_column text := 'inventory';
    group_by_clause text;
    order_by_clause text;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM web.payplantag
        WHERE payplan = p_payplan
          AND tag IN ('Active Military', 'National Guard', 'Reserves')
    ) THEN
        column_to_select := 'yos';
    END IF;

    select_clause := column_to_select;
    group_by_clause := column_to_select;
    order_by_clause := column_to_select;

    IF p_categorygroupcode = '-1' THEN
        from_clause := format(
            '(select gradetype || cast(gradelevel as varchar(2)) as grade,
                     gradelevel,
                     step,
                     yos,
                     inventory
              from data.inventory
              where payplan = %L
                and amcosversionid = %s) tblinv',
            p_payplan,
            p_amcosversionid
        );

        RETURN QUERY
        SELECT 'getinventory'::text, helper.row_data
        FROM web.spcrosstabgrades(
            p_from => from_clause,
            p_select => select_clause,
            p_pivotvaluecolumn => pivot_value_column,
            p_pivotsortcolumn => pivot_sort_column,
            p_datacolumn => data_column,
            p_groupby => group_by_clause,
            p_orderby => order_by_clause,
            p_debug => true
        ) AS helper;
        RETURN;
    END IF;

    IF p_categorysubgroupcode = '-1' THEN
        from_clause := format(
            '(select gradetype || cast(gradelevel as varchar(2)) as grade,
                     gradelevel,
                     step,
                     yos,
                     inventory
              from data.inventory
              where payplan = %L
                and categorygroupcode = %L
                and amcosversionid = %s) tblinv',
            p_payplan,
            p_categorygroupcode,
            p_amcosversionid
        );

        RETURN QUERY
        SELECT 'getinventory'::text, helper.row_data
        FROM web.spcrosstabgrades(
            p_from => from_clause,
            p_select => select_clause,
            p_pivotvaluecolumn => pivot_value_column,
            p_pivotsortcolumn => pivot_sort_column,
            p_datacolumn => data_column,
            p_groupby => group_by_clause,
            p_orderby => order_by_clause,
            p_debug => true
        ) AS helper;
        RETURN;
    END IF;

    from_clause := format(
        '(select gradetype || cast(gradelevel as varchar(2)) as grade,
                 gradelevel,
                 step,
                 yos,
                 inventory
          from data.inventory
          where payplan = %L
            and categorygroupcode = %L
            and categorysubgroupcode = %L
            and amcosversionid = %s) tblinv',
        p_payplan,
        p_categorygroupcode,
        p_categorysubgroupcode,
        p_amcosversionid
    );

    RETURN QUERY
    SELECT 'getinventory'::text, helper.row_data
    FROM web.spcrosstabgrades(
        p_from => from_clause,
        p_select => select_clause,
        p_pivotvaluecolumn => pivot_value_column,
        p_pivotsortcolumn => pivot_sort_column,
        p_datacolumn => data_column,
        p_groupby => group_by_clause,
        p_orderby => order_by_clause,
        p_debug => true
    ) AS helper;
END;
$function$;

CREATE OR REPLACE FUNCTION web.getinventorywage(
    p_payplan text,
    p_locationid integer DEFAULT -1,
    p_amcosversionid integer DEFAULT NULL
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $function$
DECLARE
    from_clause text;
    select_clause text := 'step';
    pivot_value_column text := 'grade';
    pivot_sort_column text := 'gradelevel';
    data_column text := 'inventory';
    group_by_clause text := 'step';
    order_by_clause text := 'step';
BEGIN
    IF p_amcosversionid IS NULL THEN
        RAISE EXCEPTION 'p_amcosversionid is required';
    END IF;

    IF p_locationid = -1 THEN
        from_clause := format(
            '(select gradetype || cast(gradelevel as varchar(2)) as grade,
                     gradelevel,
                     step,
                     yos,
                     inventory
              from data.inventory
              where payplan = %L
                and amcosversionid = %s) tblinv',
            p_payplan,
            p_amcosversionid
        );

        RETURN QUERY
        SELECT 'getinventorywage'::text, helper.row_data
        FROM web.spcrosstabgrades(
            p_from => from_clause,
            p_select => select_clause,
            p_pivotvaluecolumn => pivot_value_column,
            p_pivotsortcolumn => pivot_sort_column,
            p_datacolumn => data_column,
            p_groupby => group_by_clause,
            p_orderby => order_by_clause,
            p_debug => false
        ) AS helper;
        RETURN;
    END IF;

    from_clause := format(
        '(select gradetype || cast(gradelevel as varchar(2)) as grade,
                 gradelevel,
                 step,
                 yos,
                 inventory
          from data.inventory
          where payplan = %L
            and locationid = %s
            and amcosversionid = %s) tblinv',
        p_payplan,
        p_locationid,
        p_amcosversionid
    );

    RETURN QUERY
    SELECT 'getinventorywage'::text, helper.row_data
    FROM web.spcrosstabgrades(
        p_from => from_clause,
        p_select => select_clause,
        p_pivotvaluecolumn => pivot_value_column,
        p_pivotsortcolumn => pivot_sort_column,
        p_datacolumn => data_column,
        p_groupby => group_by_clause,
        p_orderby => order_by_clause,
        p_debug => false
    ) AS helper;
END;
$function$;

-- Source: GetCivPCSLocationById.sql
CREATE OR REPLACE FUNCTION web.getcivpcslocationbyid(
    p_locationid integer,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getcivpcslocationbyid'::text, to_jsonb(src)
    FROM (
SELECT LocationId,
       SourceSystemCode,
       LocationType,
       DisplayName
FROM
(
    SELECT wl.LocationId,
           wl.SourceSystemCode,
           wl.LocationType,
           wl.DisplayName,
           COALESCE(dg.MaximumLodgingRate, dd.MaximumLodgingRate) AS PerDiemAvailable
    FROM warehouse.Location wl
        LEFT JOIN crunch.GSAPerDiem dg
            ON wl.SourceSystemCode = dg.ZipCode
               AND wl.Coordinates IS NOT NULL
               AND dg.AmcosVersionId = p_amcosversionid
               AND wl.LocationType = 'zip'
        LEFT JOIN dataload.DoSPerDiem dd
            ON wl.SourceSystemCode = dd.LocationCode
               AND wl.Coordinates IS NOT NULL
               AND dd.AmcosVersionId = p_amcosversionid
               AND wl.LocationType = 'civilian overseas'
) tbl
WHERE PerDiemAvailable IS NOT NULL
      AND LocationId = p_locationid
    ) src;
END;
$$;

-- Source: GetCivPCSLocations.sql
CREATE OR REPLACE FUNCTION web.getcivpcslocations(
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getcivpcslocations'::text, to_jsonb(src)
    FROM (
SELECT LocationId,
       SourceSystemCode,
       LocationType,
       DisplayName
FROM
(
    SELECT wl.LocationId,
           wl.SourceSystemCode,
           wl.LocationType,
           wl.DisplayName,
           COALESCE(dg.MaximumLodgingRate, dd.MaximumLodgingRate) AS PerDiemAvailable
    FROM warehouse.Location wl
        LEFT JOIN crunch.GSAPerDiem dg
            ON wl.SourceSystemCode = dg.ZipCode
               AND wl.Coordinates IS NOT NULL
               AND dg.AmcosVersionId = p_amcosversionid
               AND wl.LocationType = 'zip'
        LEFT JOIN
        (
            SELECT LocationCode,
                   MAX(MaximumLodgingRate) AS MaximumLodgingRate,
                   MAX(m_ierate) AS m_ierate,
                   AmcosVersionId
            FROM dataload.DoSPerDiem
            GROUP BY LocationCode,
                     AmcosVersionId
        ) dd
            ON wl.SourceSystemCode = dd.LocationCode
               AND wl.Coordinates IS NOT NULL
               AND dd.AmcosVersionId = p_amcosversionid
               AND wl.LocationType = 'civilian overseas'
) tbl
WHERE PerDiemAvailable IS NOT NULL
    ) src;
END;
$$;

-- Source: GetMaxReleaseVersionsPerYear.sql
CREATE OR REPLACE FUNCTION web.getmaxreleaseversionsperyear(
    p_start integer DEFAULT 1900
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getmaxreleaseversionsperyear'::text, to_jsonb(src)
    FROM (
SELECT CY,
           MAX(Release) AS Release
    FROM web.amcosversioncy
    WHERE CY >= p_start
    GROUP BY CY
    ORDER BY CY DESC
    ) src;
END;
$$;

-- Source: GetPayPlanCrosswalkAE.sql
CREATE OR REPLACE FUNCTION web.getpayplancrosswalkae(
    p_categorysubgroupcode varchar(5),
    p_gradelevel smallint,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getpayplancrosswalkae'::text, to_jsonb(src)
    FROM (
SELECT
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 1
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V1,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 2
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V2,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V4,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 10
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V10,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 22
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V22,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 32
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V32,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 83
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V83,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 3966
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V3966,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 45
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V45,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 55
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V55,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 48
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V48,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 53
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V53,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 65
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V65,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 17
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V17,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 75
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V75,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 80
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V80,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 100
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V100,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 119
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V119,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 74
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V74,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 774
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V774,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 775
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V775,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 773
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V773,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 777
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V777,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 778
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V778,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 780
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V780,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4212
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V4212
    ) src;
END;
$$;

-- Source: GetPayPlanCrosswalkAO.sql
CREATE OR REPLACE FUNCTION web.getpayplancrosswalkao(
    p_categorysubgroupcode varchar(5),
    p_gradelevel smallint,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getpayplancrosswalkao'::text, to_jsonb(src)
    FROM (
SELECT
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 128
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V128,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 129
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V129,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 131
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V131,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 136
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V136,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 145
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V145,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 151
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V151,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 180
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V180,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 154
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V154,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 162
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V162,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 157
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V157,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 161
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V161,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 167
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V167,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 150
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V150,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 174
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V174,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 177
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V177,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 188
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V188,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 198
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V198,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 173
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V173,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 790
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V790,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 791
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V791,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 789
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V789,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 793
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V793,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 794
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V794,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 796
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V796,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4213
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V4213
    ) src;
END;
$$;

-- Source: GetPayPlanCrosswalkAWO.sql
CREATE OR REPLACE FUNCTION web.getpayplancrosswalkawo(
    p_categorysubgroupcode varchar(5),
    p_gradelevel smallint,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getpayplancrosswalkawo'::text, to_jsonb(src)
    FROM (
SELECT
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 204
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V204,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 205
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V205,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 207
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V207,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 210
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V210,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 219
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V219,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 225
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V225,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 245
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V245,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 228
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V228,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 236
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V236,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 231
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V231,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 235
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V235,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 241
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V241,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 224
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V224,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 248
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V248,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 678
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V678,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 256
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V256,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 682
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V682,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 269
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V269,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 247
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V247,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 806
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V806,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 807
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V807,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 805
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V805,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 809
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V809,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 810
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V810,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 812
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V812,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4214
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = -1
        ) AS V4214
    ) src;
END;
$$;

-- Source: GetPayPlanCrosswalkGS.sql
CREATE OR REPLACE FUNCTION web.getpayplancrosswalkgs(
    p_categorysubgroupcode varchar(5),
    p_gradelevel smallint,
    p_locationid integer,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getpayplancrosswalkgs'::text, to_jsonb(src)
    FROM (
SELECT
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 275
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V275,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 276
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V276,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 284
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V284,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 286
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V286,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 277
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V277,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 279
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V279,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 282
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V282,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 735
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V735,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 951
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V951,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 952
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V952,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4856
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4856,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4859
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4859,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4864
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4864,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4865
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4865,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4870
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4870,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4871
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4871,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4894
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4894,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = p_categorysubgroupcode
                  AND GradeLevel = p_gradelevel
                  AND CostElementId = 4895
                  AND AmcosVersionId = p_amcosversionid
                  AND LocationId = p_locationid
        ) AS V4895
    ) src;
END;
$$;

-- Source: GetPayPlanCrosswalkWage.sql
CREATE OR REPLACE FUNCTION web.getpayplancrosswalkwage(
    p_payplan varchar(3),
    p_locationid integer,
    p_gradelevel smallint,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getpayplancrosswalkwage'::text, to_jsonb(src)
    FROM (
SELECT
        (
            SELECT COALESCE(Amount, 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Base Pay (Civilian)'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblSalaryW,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Overtime Pay'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_OvertimePay,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Premium Pay'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_PremiumPay,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Federal Employees Gov''t Health Insurance'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_Health,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Federal Employees Gov''t Life Insurance'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_Life,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Miscellaneous Pay'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_MiscPay,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Training'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_wTraining,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Army-Funded Retirement'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_aRetirement,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Cash Awards'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_wCashAward,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Annualized Cost of FICA'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_wFICA,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Former Employee Compensation'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_wFormerEmpComp,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Post Retirement Health Insurance'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_HealthPost,
        (
            SELECT COALESCE(SUM(Amount), 0)
            FROM data.Costs
            WHERE PayPlan = p_payplan
                  AND CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = p_locationid
                  AND GradeLevel = p_gradelevel
                  AND CostElementName = 'Avg Cost of Post Retirement Life Insurance'
                  AND AmcosVersionId = p_amcosversionid
        ) AS lblV_LifePost
    ) src;
END;
$$;

-- Source: DeleteProject.sql
CREATE OR REPLACE FUNCTION web.deleteproject(p_projectid integer)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    CREATE TEMP TABLE tmp_category ON COMMIT DROP AS
    SELECT categoryid
    FROM webuser.pmcategory
    WHERE projectid = p_projectid;

    CREATE TEMP TABLE tmp_skill ON COMMIT DROP AS
    SELECT pcs.skillid
    FROM webuser.pmcategoryskill pcs
    JOIN tmp_category c ON c.categoryid = pcs.categoryid;

    DELETE FROM webuser.pmcategoryskillinventory psi
    USING tmp_skill s
    WHERE s.skillid = psi.skillid;

    DELETE FROM webuser.pmcategoryskill pcs
    USING tmp_category c
    WHERE c.categoryid = pcs.categoryid;

    DELETE FROM webuser.pmreport r
    USING tmp_category c
    WHERE c.categoryid = r.categoryid;

    DELETE FROM webuser.pmcategory WHERE projectid = p_projectid;
    DELETE FROM webuser.pmproject WHERE projectid = p_projectid;
END;
$$;

-- Source: PMAddSkillInventory.sql
CREATE OR REPLACE FUNCTION web.pmaddskillinventory(
    p_skillid integer,
    p_year integer,
    p_amount integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inventoryid integer;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM webuser.pmcategoryskillinventory
        WHERE skillid = p_skillid
          AND year = p_year
    ) THEN
        UPDATE webuser.pmcategoryskillinventory
        SET amount = amount + p_amount
        WHERE skillid = p_skillid
          AND year = p_year;

        SELECT inventoryid INTO v_inventoryid
        FROM webuser.pmcategoryskillinventory
        WHERE skillid = p_skillid
          AND year = p_year;
    ELSE
        INSERT INTO webuser.pmcategoryskillinventory(skillid, year, amount)
        VALUES (p_skillid, p_year, p_amount)
        RETURNING inventoryid INTO v_inventoryid;
    END IF;

    RETURN QUERY
    SELECT 'pmaddskillinventory', jsonb_build_object('inventoryid', v_inventoryid);
END;
$$;

-- Source: PMCategorySkillInventoryInsert.sql
CREATE OR REPLACE FUNCTION web.pmcategoryskillinventoryinsert(
    p_skillid integer,
    p_inventoryyear integer,
    p_inventoryamount integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM webuser.pmcategoryskillinventory
        WHERE skillid = p_skillid AND year = p_inventoryyear
    ) THEN
        UPDATE webuser.pmcategoryskillinventory
        SET amount = amount + p_inventoryamount
        WHERE skillid = p_skillid AND year = p_inventoryyear;
    ELSE
        INSERT INTO webuser.pmcategoryskillinventory(skillid, year, amount)
        VALUES (p_skillid, p_inventoryyear, p_inventoryamount);
    END IF;
END;
$$;

-- Source: PMCategorySkillInsert.sql
CREATE OR REPLACE FUNCTION web.pmcategoryskillinsert(
    p_categoryid integer,
    p_uic varchar(6),
    p_payplan varchar(3),
    p_categorygroupcode varchar(10),
    p_categorysubgroupcode varchar(10),
    p_careerprogramnumber char(2),
    p_locationid integer,
    p_locationtext varchar(150),
    p_strl varchar(20),
    p_gradelevel smallint,
    p_dependentstatus varchar(25),
    p_numberofdependents integer,
    p_activedutydays smallint,
    p_overheadpercent double precision,
    p_inventoryyearindex integer,
    p_inventoryamount integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_skillid integer;
BEGIN
    SELECT skillid INTO v_skillid
    FROM webuser.pmcategoryskill
    WHERE categoryid = p_categoryid
      AND payplan = p_payplan
      AND categorygroupcode = p_categorygroupcode
      AND categorysubgroupcode = p_categorysubgroupcode
      AND careerprogramnumber = p_careerprogramnumber
      AND locationid = p_locationid
      AND locationtext = p_locationtext
      AND strl = p_strl
      AND gradelevel = p_gradelevel
      AND dependentstatus = p_dependentstatus
      AND numberofdependents = p_numberofdependents
      AND activedutydays = p_activedutydays
      AND overheadpercent = p_overheadpercent
    LIMIT 1;

    IF v_skillid IS NULL THEN
        INSERT INTO webuser.pmcategoryskill(
            categoryid, uic, payplan, categorygroupcode, categorysubgroupcode,
            careerprogramnumber, locationid, locationtext, strl, gradelevel,
            dependentstatus, numberofdependents, activedutydays, overheadpercent
        )
        VALUES (
            p_categoryid, p_uic, p_payplan, p_categorygroupcode, p_categorysubgroupcode,
            p_careerprogramnumber, p_locationid, p_locationtext, p_strl, p_gradelevel,
            p_dependentstatus, p_numberofdependents, p_activedutydays, p_overheadpercent
        )
        RETURNING skillid INTO v_skillid;
    END IF;

    PERFORM web.pmcategoryskillinventoryinsert(v_skillid, p_inventoryyearindex, p_inventoryamount);
END;
$$;

-- Source: ProjectRequirementInsertMtoe.sql
CREATE OR REPLACE FUNCTION web.projectrequirementinsertmtoe(
    p_categoryid integer,
    p_uic varchar(6),
    p_payplan varchar(3),
    p_categorygroupcode varchar(10),
    p_categorysubgroupcode varchar(10),
    p_careerprogramnumber char(2),
    p_locationid integer,
    p_locationtext varchar(150),
    p_strl varchar(20),
    p_gradelevel smallint,
    p_dependentstatus varchar(25),
    p_numberofdependents integer,
    p_activedutydays smallint,
    p_overheadpercent double precision,
    p_inventoryyearindex integer,
    p_inventoryamount integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM web.pmcategoryskillinsert(
        p_categoryid, p_uic, p_payplan, p_categorygroupcode, p_categorysubgroupcode,
        p_careerprogramnumber, p_locationid, p_locationtext, p_strl, p_gradelevel,
        p_dependentstatus, p_numberofdependents, p_activedutydays, p_overheadpercent,
        p_inventoryyearindex, p_inventoryamount
    );
END;
$$;

-- Source: ProjectRequirementInsertTda.sql
CREATE OR REPLACE FUNCTION web.projectrequirementinserttda(
    p_categoryid integer,
    p_uic varchar(6),
    p_payplan varchar(3),
    p_categorygroupcode varchar(10),
    p_categorysubgroupcode varchar(10),
    p_careerprogramnumber char(2),
    p_locationid integer,
    p_locationtext varchar(150),
    p_strl varchar(20),
    p_gradelevel smallint,
    p_dependentstatus varchar(25),
    p_numberofdependents integer,
    p_activedutydays smallint,
    p_overheadpercent double precision,
    p_inventoryamount integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_yearindex integer := 0;
    v_projectyearduration integer;
BEGIN
    SELECT web.getprojectyearduration(p_categoryid) INTO v_projectyearduration;
    WHILE v_yearindex < COALESCE(v_projectyearduration, 0) LOOP
        PERFORM web.pmcategoryskillinsert(
            p_categoryid, p_uic, p_payplan, p_categorygroupcode, p_categorysubgroupcode,
            p_careerprogramnumber, p_locationid, p_locationtext, p_strl, p_gradelevel,
            p_dependentstatus, p_numberofdependents, p_activedutydays, p_overheadpercent,
            v_yearindex, p_inventoryamount
        );
        v_yearindex := v_yearindex + 1;
    END LOOP;
END;
$$;

-- Source: PMCopyProject.sql
CREATE OR REPLACE FUNCTION web.pmcopyproject(
    p_projectid integer,
    p_projectname varchar(50),
    p_description text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_category record;
    v_skill record;
    v_newprojectid integer;
    v_newcategoryid integer;
    v_newskillid integer;
    v_oldprojectname varchar(50);
BEGIN
    SELECT projectname INTO v_oldprojectname
    FROM webuser.pmproject
    WHERE projectid = p_projectid;

    INSERT INTO webuser.pmproject(
        userid, projectname, yearstart, yearduration, projectcreator, projecttype,
        reservedaysinactive, reservedaysactive, createdate, lastupdate, description, discountrate
    )
    SELECT userid, p_projectname, yearstart, yearduration, projectcreator, projecttype,
           reservedaysinactive, reservedaysactive, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
           p_description, discountrate
    FROM webuser.pmproject
    WHERE projectid = p_projectid
    RETURNING projectid INTO v_newprojectid;

    FOR v_category IN
        SELECT categoryid, categoryname
        FROM webuser.pmcategory
        WHERE projectid = p_projectid
        ORDER BY categoryid
    LOOP
        INSERT INTO webuser.pmcategory(projectid, categoryname)
        VALUES (
            v_newprojectid,
            CASE WHEN v_category.categoryname = v_oldprojectname THEN p_projectname ELSE v_category.categoryname END
        )
        RETURNING categoryid INTO v_newcategoryid;

        FOR v_skill IN
            SELECT *
            FROM webuser.pmcategoryskill
            WHERE categoryid = v_category.categoryid
            ORDER BY skillid
        LOOP
            INSERT INTO webuser.pmcategoryskill(
                categoryid, payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
                locationid, locationtext, strl, gradelevel, dependentstatus, numberofdependents,
                activedutydays, overheadpercent, uic
            )
            VALUES (
                v_newcategoryid, v_skill.payplan, v_skill.categorygroupcode, v_skill.categorysubgroupcode,
                v_skill.careerprogramnumber, v_skill.locationid, v_skill.locationtext, v_skill.strl,
                v_skill.gradelevel, v_skill.dependentstatus, v_skill.numberofdependents,
                v_skill.activedutydays, v_skill.overheadpercent, v_skill.uic
            )
            RETURNING skillid INTO v_newskillid;

            INSERT INTO webuser.pmcategoryskillinventory(skillid, year, amount)
            SELECT v_newskillid, year, amount
            FROM webuser.pmcategoryskillinventory
            WHERE skillid = v_skill.skillid;
        END LOOP;
    END LOOP;
END;
$$;

-- Source: PMCopyProjectCategory.sql
CREATE OR REPLACE FUNCTION web.pmcopyprojectcategory(
    p_fromcategoryid integer,
    p_tocategoryid integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_skill record;
    v_newskillid integer;
BEGIN
    FOR v_skill IN
        WITH categoryfrom AS (
            SELECT * FROM webuser.pmcategoryskill WHERE categoryid = p_fromcategoryid
        ), categoryto AS (
            SELECT * FROM webuser.pmcategoryskill WHERE categoryid = p_tocategoryid
        )
        SELECT f.*
        FROM categoryfrom f
        LEFT JOIN categoryto t
          ON f.payplan = t.payplan
         AND f.categorygroupcode = t.categorygroupcode
         AND f.categorysubgroupcode = t.categorysubgroupcode
         AND f.careerprogramnumber = t.careerprogramnumber
         AND f.locationid = t.locationid
         AND f.locationtext = t.locationtext
         AND f.strl = t.strl
         AND f.gradelevel = t.gradelevel
         AND f.dependentstatus = t.dependentstatus
         AND f.numberofdependents = t.numberofdependents
         AND COALESCE(f.activedutydays, 0) = COALESCE(t.activedutydays, 0)
         AND COALESCE(f.overheadpercent, 0) = COALESCE(t.overheadpercent, 0)
        WHERE t.skillid IS NULL
    LOOP
        INSERT INTO webuser.pmcategoryskill(
            categoryid, payplan, categorygroupcode, categorysubgroupcode, careerprogramnumber,
            locationid, locationtext, strl, gradelevel, dependentstatus, numberofdependents,
            activedutydays, overheadpercent, uic
        )
        VALUES (
            p_tocategoryid, v_skill.payplan, v_skill.categorygroupcode, v_skill.categorysubgroupcode,
            v_skill.careerprogramnumber, v_skill.locationid, v_skill.locationtext, v_skill.strl,
            v_skill.gradelevel, v_skill.dependentstatus, v_skill.numberofdependents,
            v_skill.activedutydays, v_skill.overheadpercent, v_skill.uic
        )
        RETURNING skillid INTO v_newskillid;

        INSERT INTO webuser.pmcategoryskillinventory(skillid, year, amount)
        SELECT v_newskillid, year, amount
        FROM webuser.pmcategoryskillinventory
        WHERE skillid = v_skill.skillid;
    END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION web.getsubgroupmapping(p_payplan varchar(3), p_categorysubgroupcode varchar(7), p_amcosversionid integer)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    CREATE TEMPORARY TABLE IF NOT EXISTS subgroupmapping_tmp
    (
        payplan varchar(3) NOT NULL,
        categorysubgroupcode varchar(7) NOT NULL,
        topayplan varchar(3) NOT NULL,
        tocategorysubgroupcode varchar(7) NOT NULL,
        amcosversionidstart integer NULL,
        amcosversionidend integer NOT NULL
    ) ON COMMIT DROP;

    TRUNCATE TABLE subgroupmapping_tmp;

    INSERT INTO subgroupmapping_tmp
    (
        payplan,
        categorysubgroupcode,
        topayplan,
        tocategorysubgroupcode,
        amcosversionidstart,
        amcosversionidend
    )
    SELECT payplan,
           categorysubgroupcode,
           topayplan,
           tocategorysubgroupcode,
           amcosversionidstart,
           amcosversionidend
    FROM lookup.subgroupmapping
    WHERE p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend;

    IF p_payplan = 'AE' THEN
        RETURN QUERY
        SELECT 'AE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode = p_categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AE'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'GS'
                            )
                      UNION
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AE'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'CCE'
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AWO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AWO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AE'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'GS'
                            )
                      UNION
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AE'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'CCE'
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'GS'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'GS'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'GS'
                        AND categorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'CCE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'CCE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'CCE'
                        AND categorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'WG_WL_WS_COUNT'::text,
               to_jsonb(t)
        FROM (
            SELECT COUNT(*) AS count
            FROM lookup.subgroupmappingforcivover2299
            WHERE payplan = 'AE'
              AND categorysubgroupcode = p_categorysubgroupcode
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS t;
    ELSIF p_payplan = 'AO' THEN
        RETURN QUERY
        SELECT 'AE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'GS'
                            )
                      UNION
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'CCE'
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode = p_categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AWO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AWO'
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'GS'
                            )
                      UNION
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'CCE'
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'GS'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'GS'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'GS'
                        AND categorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'CCE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'CCE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'CCE'
                        AND categorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'WG_WL_WS_COUNT'::text,
               to_jsonb(t)
        FROM (
            SELECT COUNT(*) AS count
            FROM lookup.subgroupmappingforcivover2299
            WHERE payplan = 'AO'
              AND categorysubgroupcode = p_categorysubgroupcode
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS t;
    ELSIF p_payplan = 'AWO' THEN
        RETURN QUERY
        SELECT 'AE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AWO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'GS'
                            )
                      UNION
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AWO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'CCE'
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AWO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'GS'
                            )
                      UNION
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode IN
                            (
                                SELECT tocategorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AWO'
                                  AND categorysubgroupcode = p_categorysubgroupcode
                                  AND topayplan = 'CCE'
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AWO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AWO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode = p_categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'GS'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'GS'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'GS'
                        AND categorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'CCE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'CCE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'CCE'
                        AND categorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'WG_WL_WS_COUNT'::text,
               to_jsonb(t)
        FROM (
            SELECT COUNT(*) AS count
            FROM lookup.subgroupmappingforcivover2299
            WHERE payplan = 'AWO'
              AND categorysubgroupcode = p_categorysubgroupcode
              AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS t;
    ELSIF p_payplan = 'GS' THEN
        RETURN QUERY
        SELECT 'AE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AWO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AWO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'GS'
                        AND tocategorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'GS'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'GS'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode = p_categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'CCE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'CCE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'CCE'
                        AND categorysubgroupcode IN
                            (
                                SELECT categorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AE'
                                  AND topayplan = 'GS'
                                  AND tocategorysubgroupcode = p_categorysubgroupcode
                            )
                      UNION
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'CCE'
                        AND categorysubgroupcode IN
                            (
                                SELECT categorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AO'
                                  AND topayplan = 'GS'
                                  AND tocategorysubgroupcode = p_categorysubgroupcode
                            )
                      UNION
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'CCE'
                        AND categorysubgroupcode IN
                            (
                                SELECT categorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AWO'
                                  AND topayplan = 'GS'
                                  AND tocategorysubgroupcode = p_categorysubgroupcode
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'WG_WL_WS_COUNT'::text,
               to_jsonb(t)
        FROM (
            SELECT COUNT(*) AS count
            FROM lookup.subgroupmappingforcivover2299
            WHERE (
                      payplan = 'AE'
                      AND categorysubgroupcode IN
                          (
                              SELECT categorysubgroupcode
                              FROM subgroupmapping_tmp
                              WHERE payplan = 'AE'
                                AND topayplan = 'GS'
                                AND tocategorysubgroupcode = p_categorysubgroupcode
                          )
                  )
               OR (
                      payplan = 'AO'
                      AND categorysubgroupcode IN
                          (
                              SELECT categorysubgroupcode
                              FROM subgroupmapping_tmp
                              WHERE payplan = 'AO'
                                AND topayplan = 'GS'
                                AND tocategorysubgroupcode = p_categorysubgroupcode
                          )
                  )
               OR (
                      payplan = 'AWO'
                      AND categorysubgroupcode IN
                          (
                              SELECT categorysubgroupcode
                              FROM subgroupmapping_tmp
                              WHERE payplan = 'AWO'
                                AND topayplan = 'GS'
                                AND tocategorysubgroupcode = p_categorysubgroupcode
                          )
                  )
                  AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS t;
    ELSIF p_payplan = 'CCE' THEN
        RETURN QUERY
        SELECT 'AE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'AWO'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'AWO'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT categorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'CCE'
                        AND tocategorysubgroupcode = p_categorysubgroupcode
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'GS'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'GS'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode IN
                  (
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AE'
                        AND topayplan = 'GS'
                        AND categorysubgroupcode IN
                            (
                                SELECT categorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AE'
                                  AND topayplan = 'CCE'
                                  AND tocategorysubgroupcode = p_categorysubgroupcode
                            )
                      UNION
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AO'
                        AND topayplan = 'GS'
                        AND categorysubgroupcode IN
                            (
                                SELECT categorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AO'
                                  AND topayplan = 'CCE'
                                  AND tocategorysubgroupcode = p_categorysubgroupcode
                            )
                      UNION
                      SELECT tocategorysubgroupcode
                      FROM subgroupmapping_tmp
                      WHERE payplan = 'AWO'
                        AND topayplan = 'GS'
                        AND categorysubgroupcode IN
                            (
                                SELECT categorysubgroupcode
                                FROM subgroupmapping_tmp
                                WHERE payplan = 'AWO'
                                  AND topayplan = 'CCE'
                                  AND tocategorysubgroupcode = p_categorysubgroupcode
                            )
                  )
            ORDER BY categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'CCE'::text,
               to_jsonb(t)
        FROM (
            SELECT categorysubgroupcode,
                   categorysubgroupdisplay
            FROM warehouse.category
            WHERE payplan = 'CCE'
              AND p_amcosversionid = p_amcosversionid
              AND categorysubgroupcode = p_categorysubgroupcode
        ) AS t;

        RETURN QUERY
        SELECT 'WG_WL_WS_COUNT'::text,
               to_jsonb(t)
        FROM (
            SELECT COUNT(*) AS count
            FROM lookup.subgroupmappingforcivover2299
            WHERE (
                      payplan = 'AE'
                      AND categorysubgroupcode IN
                          (
                              SELECT categorysubgroupcode
                              FROM subgroupmapping_tmp
                              WHERE payplan = 'AE'
                                AND topayplan = 'CCE'
                                AND tocategorysubgroupcode = p_categorysubgroupcode
                          )
                  )
               OR (
                      payplan = 'AO'
                      AND categorysubgroupcode IN
                          (
                              SELECT categorysubgroupcode
                              FROM subgroupmapping_tmp
                              WHERE payplan = 'AO'
                                AND topayplan = 'CCE'
                                AND tocategorysubgroupcode = p_categorysubgroupcode
                          )
                  )
               OR (
                      payplan = 'AWO'
                      AND categorysubgroupcode IN
                          (
                              SELECT categorysubgroupcode
                              FROM subgroupmapping_tmp
                              WHERE payplan = 'AWO'
                                AND topayplan = 'CCE'
                                AND tocategorysubgroupcode = p_categorysubgroupcode
                          )
                  )
                  AND p_amcosversionid BETWEEN amcosversionidstart AND amcosversionidend
        ) AS t;
    END IF;

    RETURN;
END;
$$;
-- Source: GetCivPCSLocationsByQuery.sql
CREATE OR REPLACE FUNCTION web.getcivpcslocationsbyquery(
    p_amcosversionid integer,
    p_query varchar(100) DEFAULT 'A',
    p_zipcode varchar(5) DEFAULT NULL
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer := 0;
    v_query text := p_query;
    v_rowcount integer := 0;
BEGIN
    CREATE TEMP TABLE tmp_result(
        locationid integer,
        sourcesystemcode varchar(100),
        locationtype varchar(100),
        displayname varchar(100)
    ) ON COMMIT DROP;

    IF p_zipcode IS NOT NULL AND p_zipcode <> '' THEN
        INSERT INTO tmp_result
        SELECT wl.locationid, wl.sourcesystemcode, wl.locationtype, wl.displayname
        FROM warehouse.location wl
        JOIN crunch.gsaperdiem dg
          ON wl.sourcesystemcode = dg.zipcode
         AND wl.coordinates IS NOT NULL
         AND dg.amcosversionid = p_amcosversionid
         AND wl.locationtype = 'zip'
        WHERE wl.sourcesystemcode = p_zipcode;
        GET DIAGNOSTICS v_rowcount = ROW_COUNT;
        v_count := v_count + v_rowcount;
    END IF;

    IF v_query IS NOT NULL AND v_query <> '' THEN
        INSERT INTO tmp_result
        SELECT locationid, sourcesystemcode, locationtype, displayname
        FROM (
            SELECT wl.locationid, wl.sourcesystemcode, wl.locationtype, wl.displayname,
                   COALESCE(dg.maximumlodgingrate, dd.maximumlodgingrate) AS perdiemavailable
            FROM warehouse.location wl
            LEFT JOIN crunch.gsaperdiem dg
              ON wl.sourcesystemcode = dg.zipcode
             AND wl.coordinates IS NOT NULL
             AND dg.amcosversionid = p_amcosversionid
             AND wl.locationtype = 'zip'
            LEFT JOIN (
                SELECT locationcode,
                       MAX(maximumlodgingrate) AS maximumlodgingrate,
                       MAX(m_ierate) AS m_ierate,
                       amcosversionid
                FROM dataload.dosperdiem
                GROUP BY locationcode, amcosversionid
            ) dd
              ON wl.sourcesystemcode = dd.locationcode
             AND wl.coordinates IS NOT NULL
             AND dd.amcosversionid = p_amcosversionid
             AND wl.locationtype = 'civilian overseas'
        ) tbl
        WHERE perdiemavailable IS NOT NULL
          AND displayname = v_query;
        GET DIAGNOSTICS v_rowcount = ROW_COUNT;
        v_count := v_count + v_rowcount;
    END IF;

    IF v_count < 500 THEN
        INSERT INTO tmp_result
        SELECT locationid, sourcesystemcode, locationtype, displayname
        FROM (
            SELECT wl.locationid, wl.sourcesystemcode, wl.locationtype, wl.displayname,
                   COALESCE(dg.maximumlodgingrate, dd.maximumlodgingrate) AS perdiemavailable
            FROM warehouse.location wl
            LEFT JOIN crunch.gsaperdiem dg
              ON wl.sourcesystemcode = dg.zipcode
             AND wl.coordinates IS NOT NULL
             AND dg.amcosversionid = p_amcosversionid
             AND wl.locationtype = 'zip'
            LEFT JOIN (
                SELECT locationcode,
                       MAX(maximumlodgingrate) AS maximumlodgingrate,
                       MAX(m_ierate) AS m_ierate,
                       amcosversionid
                FROM dataload.dosperdiem
                GROUP BY locationcode, amcosversionid
            ) dd
              ON wl.sourcesystemcode = dd.locationcode
             AND wl.coordinates IS NOT NULL
             AND dd.amcosversionid = p_amcosversionid
             AND wl.locationtype = 'civilian overseas'
        ) tbl
        WHERE perdiemavailable IS NOT NULL
          AND displayname LIKE v_query || '%'
        LIMIT GREATEST(500 - v_count, 0);
        GET DIAGNOSTICS v_rowcount = ROW_COUNT;
        v_count := v_count + v_rowcount;
    END IF;

    IF v_count < 500 THEN
        v_query := replace(v_query, ' ', '%');
        INSERT INTO tmp_result
        SELECT locationid, sourcesystemcode, locationtype, displayname
        FROM (
            SELECT wl.locationid, wl.sourcesystemcode, wl.locationtype, wl.displayname,
                   COALESCE(dg.maximumlodgingrate, dd.maximumlodgingrate) AS perdiemavailable
            FROM warehouse.location wl
            LEFT JOIN crunch.gsaperdiem dg
              ON wl.sourcesystemcode = dg.zipcode
             AND wl.coordinates IS NOT NULL
             AND dg.amcosversionid = p_amcosversionid
             AND wl.locationtype = 'zip'
            LEFT JOIN (
                SELECT locationcode,
                       MAX(maximumlodgingrate) AS maximumlodgingrate,
                       MAX(m_ierate) AS m_ierate,
                       amcosversionid
                FROM dataload.dosperdiem
                GROUP BY locationcode, amcosversionid
            ) dd
              ON wl.sourcesystemcode = dd.locationcode
             AND wl.coordinates IS NOT NULL
             AND dd.amcosversionid = p_amcosversionid
             AND wl.locationtype = 'civilian overseas'
        ) tbl
        WHERE perdiemavailable IS NOT NULL
          AND displayname LIKE '%' || v_query || '%'
        LIMIT GREATEST(500 - v_count, 0);
        GET DIAGNOSTICS v_rowcount = ROW_COUNT;
        v_count := v_count + v_rowcount;
    END IF;

    IF v_count < 500 AND p_zipcode IS NOT NULL THEN
        INSERT INTO tmp_result
        SELECT wl.locationid, wl.sourcesystemcode, wl.locationtype, wl.displayname
        FROM warehouse.location wl
        JOIN crunch.gsaperdiem dg
          ON wl.sourcesystemcode = dg.zipcode
         AND wl.coordinates IS NOT NULL
         AND dg.amcosversionid = p_amcosversionid
         AND wl.locationtype = 'zip'
        WHERE wl.sourcesystemcode LIKE '%' || p_zipcode || '%'
        LIMIT GREATEST(500 - v_count, 0);
    END IF;

    RETURN QUERY
    SELECT 'getcivpcslocationsbyquery', to_jsonb(src)
    FROM (
        SELECT DISTINCT * FROM tmp_result
    ) src;
END;
$$;

-- Source: PMReportSelectedInflationRate.sql
CREATE OR REPLACE FUNCTION web.pmreportselectedinflationrate(
    p_projectid integer,
    p_payplans varchar(800)
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    v_payplans text[];
BEGIN
    v_payplans := string_to_array(replace(replace(p_payplans, '''', ''), ' ', ''), ',');

    RETURN QUERY
    SELECT 'pmreportselectedinflationrate', to_jsonb(src)
    FROM (
        SELECT cc.year,
               cc.civpay,
               cc.oma AS "OMA-CIV",
               cc.dod_oma AS omdw,
               cc.fed_oma AS "FED-OM",
               aa.mpa,
               aa.mpa_nonpay AS "MPA NonPay",
               aa.oma AS "OMA-MIL",
               aa.dod_oma AS "OMDW",
               aa.fed_oma AS "FED-OM2",
               nn.mpa AS ngpa,
               nn.oma AS omng,
               rr.mpa AS rpa,
               rr.oma AS omar,
               aa.oma AS "OMA-CCE"
        FROM (SELECT year, civpay, oma, dod_oma, fed_oma FROM lookup.inflationrates WHERE type = 'CIV') cc
        JOIN (SELECT year, mpa, mpa_nonpay, oma, dod_oma, fed_oma FROM lookup.inflationrates WHERE type = 'MIL_A') aa
          ON cc.year = aa.year
        JOIN (SELECT year, mpa, oma FROM lookup.inflationrates WHERE type = 'MIL_N') nn
          ON cc.year = nn.year
        JOIN (SELECT year, mpa, oma FROM lookup.inflationrates WHERE type = 'MIL_R') rr
          ON cc.year = rr.year
        WHERE cc.year BETWEEN (
                SELECT MIN(i.year + p.yearstart)
                FROM webuser.pmcategory c
                JOIN webuser.pmcategoryskill s ON c.categoryid = s.categoryid
                JOIN webuser.pmproject p ON c.projectid = p.projectid
                JOIN webuser.pmcategoryskillinventory i ON s.skillid = i.skillid
                WHERE i.year < p.yearduration
                  AND c.projectid = p_projectid
                  AND s.payplan = ANY(v_payplans)
            ) AND (
                SELECT MAX(i.year + p.yearstart)
                FROM webuser.pmcategory c
                JOIN webuser.pmcategoryskill s ON c.categoryid = s.categoryid
                JOIN webuser.pmproject p ON c.projectid = p.projectid
                JOIN webuser.pmcategoryskillinventory i ON s.skillid = i.skillid
                WHERE i.year < p.yearduration
                  AND c.projectid = p_projectid
                  AND s.payplan = ANY(v_payplans)
            )
        ORDER BY cc.year
    ) src;
END;
$$;

-- Source: PMProjectInventory.sql
CREATE OR REPLACE FUNCTION web.pmprojectinventory(
    p_projectid integer,
    p_silentrunning boolean DEFAULT NULL
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    v_imax integer;
    v_sql text;
    v_groupby text;
BEGIN
    CREATE TEMP TABLE tmp_projectinventory ON COMMIT DROP AS
    SELECT tbldata.projectid,
           tbldata.skillid,
           tbldata.pmcategoryname,
           tbldata.uic,
           tbldata.payplan,
           tbldata.categorygroupcode,
           tbldata.categorysubgroupcode,
           tbldata.activedutydays,
           tbldata.overheadpercent,
           tbldata.grade,
           tbldata.year,
           tbldata.amount
    FROM (
        SELECT pmcategoryskillreport.projectid,
               pmcategoryskillinventory.skillid,
               pmcategoryskillreport.pmcategoryname,
               pmcategoryskillreport.uic,
               pmcategoryskillreport.payplan,
               pmcategoryskillreport.categorygroupcode,
               pmcategoryskillreport.categorysubgroupcode,
               pmcategoryskillreport.activedutydays,
               pmcategoryskillreport.overheadpercent,
               web.formatgradelevel(pmcategoryskillreport.payplan, pmcategoryskillreport.gradelevel) AS grade,
               pmcategoryskillinventory.year,
               pmcategoryskillinventory.amount
        FROM (
            SELECT pmcategory.projectid,
                   pmcategory.categoryname AS pmcategoryname,
                   pmcategoryskill.uic,
                   pmcategoryskill.payplan,
                   pmcategoryskill.categorygroupcode,
                   pmcategoryskill.categorysubgroupcode,
                   pmcategoryskill.gradelevel,
                   pmcategoryskill.skillid,
                   pmcategoryskill.activedutydays,
                   pmcategoryskill.overheadpercent
            FROM webuser.pmcategoryskill pmcategoryskill
            INNER JOIN webuser.pmcategory pmcategory ON pmcategoryskill.categoryid = pmcategory.categoryid
            INNER JOIN webuser.pmreport pmreport
               ON pmcategoryskill.categoryid = pmreport.categoryid
              AND pmcategoryskill.payplan = pmreport.payplan
            WHERE pmcategory.projectid = p_projectid
        ) pmcategoryskillreport
        JOIN webuser.pmcategoryskillinventory pmcategoryskillinventory
          ON pmcategoryskillreport.skillid = pmcategoryskillinventory.skillid
        JOIN webuser.pmproject pmproject
          ON pmcategoryskillreport.projectid = pmproject.projectid
         AND pmcategoryskillinventory.year < pmproject.yearduration
    ) tbldata;

    SELECT COALESCE(yearduration, 0) INTO v_imax
    FROM webuser.pmproject WHERE projectid = p_projectid;

    IF v_imax > (SELECT COALESCE(MAX(year), 0) FROM tmp_projectinventory) THEN
        v_imax := (SELECT COALESCE(MAX(year), 0) FROM tmp_projectinventory);
    END IF;

    CREATE TEMP TABLE tmp_placeholderprojectinventory ON COMMIT DROP AS
    SELECT a.projectid, a.skillid, a.pmcategoryname, a.uic, a.payplan,
           a.categorygroupcode, a.categorysubgroupcode, a.activedutydays,
           a.overheadpercent, a.grade, gs.i AS year, 0 AS amount
    FROM (
        SELECT DISTINCT projectid, skillid, pmcategoryname, uic, payplan,
               categorygroupcode, categorysubgroupcode, activedutydays,
               overheadpercent, grade
        FROM tmp_projectinventory
    ) a
    CROSS JOIN generate_series(0, GREATEST(v_imax - 1, -1)) AS gs(i);

    INSERT INTO tmp_projectinventory(
        projectid, skillid, pmcategoryname, uic, payplan,
        categorygroupcode, categorysubgroupcode, activedutydays,
        overheadpercent, grade, year, amount
    )
    SELECT b.projectid, b.skillid, b.pmcategoryname, b.uic, b.payplan,
           b.categorygroupcode, b.categorysubgroupcode, b.activedutydays,
           b.overheadpercent, b.grade, b.year, b.amount
    FROM tmp_placeholderprojectinventory b
    LEFT JOIN tmp_projectinventory a
      ON a.projectid = b.projectid
     AND a.skillid = b.skillid
     AND a.pmcategoryname = b.pmcategoryname
     AND a.uic = b.uic
     AND a.payplan = b.payplan
     AND a.categorygroupcode = b.categorygroupcode
     AND a.categorysubgroupcode = b.categorysubgroupcode
     AND a.grade = b.grade
     AND a.year = b.year
     AND a.activedutydays = b.activedutydays
     AND a.overheadpercent = b.overheadpercent
    WHERE a.projectid IS NULL;

    UPDATE tmp_projectinventory SET categorygroupcode = 'ALL' WHERE categorygroupcode = '-1';
    UPDATE tmp_projectinventory SET categorysubgroupcode = 'ALL' WHERE categorysubgroupcode = '-1';

    IF COALESCE(p_silentrunning, false) THEN
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM tmp_projectinventory) THEN
        v_sql := 'pmcategoryname, uic as "UIC", payplan, categorygroupcode, categorysubgroupcode';
        v_groupby := 'pmcategoryname, uic, payplan, categorygroupcode, categorysubgroupcode';
        IF EXISTS (SELECT 1 FROM tmp_projectinventory WHERE payplan IN (''NE'',''NO'',''NWO'',''RE'',''RO'',''RWO'')) THEN
            v_sql := v_sql || ', activedutydays';
            v_groupby := v_groupby || ', activedutydays';
        END IF;
        IF EXISTS (SELECT 1 FROM tmp_projectinventory WHERE payplan = 'CCE') THEN
            v_sql := v_sql || ', overheadpercent';
            v_groupby := v_groupby || ', overheadpercent';
        END IF;
        v_sql := v_sql || ', grade';
        v_groupby := v_groupby || ', grade';

        RETURN QUERY
        SELECT 'pmprojectinventory', helper.row_data
        FROM web.spcrosstab(
            p_from => 'tmp_projectinventory',
            p_select => v_sql,
            p_pivotvaluecolumn => 'year',
            p_pivotsortcolumn => 'year',
            p_datacolumn => 'amount',
            p_groupby => v_groupby,
            p_orderby => v_groupby,
            p_debug => false
        ) helper;
    ELSE
        RETURN QUERY
        SELECT 'pmprojectinventory', to_jsonb(src)
        FROM (
            SELECT skillid, pmcategoryname, uic AS "UIC", payplan,
                   categorygroupcode, categorysubgroupcode, activedutydays,
                   overheadpercent, grade, year, amount
            FROM tmp_projectinventory
        ) src;
    END IF;
END;
$$;
-- Source: ProjectManagerReport.sql
CREATE OR REPLACE FUNCTION web.projectmanagerreport(
    p_projectid integer,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'projectmanagerreport', to_jsonb(src)
    FROM (
        SELECT *
        FROM web.pmcostsbypayplan(p_projectid, p_amcosversionid)
        UNION ALL
        SELECT *
        FROM web.pmcostsbypayplancce(p_projectid, p_amcosversionid)
    ) src;
END;
$$;

-- Source: PMReport.sql
CREATE OR REPLACE FUNCTION web.pmreport(
    p_projectid integer,
    p_amcosversionid integer
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    v_def_from text := 'tmp_costdefault';
    v_osd_from text := 'tmp_costosdcapedodi';
BEGIN
    CREATE TEMP TABLE tmp_costs ON COMMIT DROP AS
    SELECT * FROM web.pmcostsbypayplan(p_projectid, p_amcosversionid)
    UNION ALL
    SELECT * FROM web.pmcostsbypayplanreservecomponents(p_projectid, p_amcosversionid)
    UNION ALL
    SELECT * FROM web.pmcostsbypayplancce(p_projectid, p_amcosversionid);

    UPDATE tmp_costs c
    SET cost = c.cost * jir.amount
    FROM lookup.jicinflationrates jir
    WHERE c.appn = jir.appropriation
      AND c.year = jir.year
      AND jir.conversiontype = 'ThenToThen'
      AND c.applyinflation = true
      AND jir.amcosversionid = p_amcosversionid;

    CREATE TEMP TABLE tmp_costdefault ON COMMIT DROP AS SELECT * FROM tmp_costs WHERE costsummaryname = 'Default';
    CREATE TEMP TABLE tmp_costosdcapedodi ON COMMIT DROP AS SELECT * FROM tmp_costs WHERE costsummaryname <> 'Default';

    RETURN QUERY
    SELECT 'pmreport_payload', jsonb_build_object(
        'default_summary', COALESCE((SELECT jsonb_agg(row_data) FROM web.spcrosstab(v_def_from,
            'PMCategoryName as "Sub-Project Name", UIC, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationText as "Location", GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory as "Category", CostElementName as "Cost Element", ShowOrder',
            'Year','Year','ROUND(COALESCE(Cost,0),2)',
            'PMCategoryName, UIC, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationText, GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory, CostElementName, ShowOrder',
            'PMCategoryName, UIC, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationText, GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory, CostElementName, ShowOrder', false)), '[]'::jsonb),
        'osd_cape_dodi_summary', COALESCE((SELECT jsonb_agg(row_data) FROM web.spcrosstab(v_osd_from,
            'PMCategoryName as "Sub-Project Name", UIC, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationText as "Location", GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory as "Category", CostElementName as "Cost Element", ShowOrder',
            'Year','Year','ROUND(COALESCE(Cost,0),2)',
            'PMCategoryName, UIC, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationText, GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory, CostElementName, ShowOrder',
            'PMCategoryName, UIC, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationText, GradeLevel, Grade, ActiveDutyDays, ExceedsSalaryLimit, APPN, CostElementCategory, CostElementName, ShowOrder', false)), '[]'::jsonb)
    );
END;
$$;

-- Source: GetAmcosLiteCosts.sql
CREATE OR REPLACE FUNCTION web.getamcoslitecosts(
    p_payplan varchar(3),
    p_costsummaryname varchar(50) DEFAULT 'Default',
    p_categorygroupcode varchar(4) DEFAULT '-1',
    p_categorysubgroupcode varchar(5) DEFAULT '-1',
    p_careerprogramnumber char(2) DEFAULT '-1',
    p_locationid integer DEFAULT -1,
    p_strl varchar(20) DEFAULT '-1',
    p_dependentstatus varchar(25) DEFAULT '-1',
    p_numberofdependents integer DEFAULT -1,
    p_inflationconversion varchar(25) DEFAULT NULL,
    p_inflationyear varchar(4) DEFAULT NULL,
    p_amcosversionid integer DEFAULT 202001,
    p_includevisualizationdata boolean DEFAULT true,
    p_debug boolean DEFAULT false
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from text;
    v_select text := 'appngroup, appn, costelementcategory as "Cost Element Category", costelementname as "Cost Element Name", description, showorder';
    v_groupby text := 'appngroup, appn, costelementcategory, costelementname, description, showorder';
    v_orderby text := 'appngroup, appn, costelementcategory, costelementname, description, showorder';
BEGIN
    IF p_payplan IN (SELECT payplan FROM analysis.getpayplans('Military'))
       AND p_categorysubgroupcode = '-1'
       AND p_locationid <> -1 THEN
        RAISE EXCEPTION 'No military cost data exists for group or payplan level aggregation';
    END IF;

    CREATE TEMP TABLE tmp_amcoslite ON COMMIT DROP AS
    SELECT appropriationgroup AS appngroup, appn, costelementcategory, costelementname, description,
           costelementid, showorder, applyinflation, gradelevel, grade, weaponsystemid,
           weaponsystemname, amount, armycestitle, osdcapecestitle, amcosversionid
    FROM web.getcosts(
        p_payplan, p_costsummaryname, p_categorygroupcode, p_categorysubgroupcode,
        p_careerprogramnumber, p_locationid, p_strl, p_dependentstatus,
        p_numberofdependents, p_amcosversionid
    );

    UPDATE tmp_amcoslite a
    SET amount = jir.amount * a.amount
    FROM lookup.jicinflationrates jir
    WHERE p_inflationconversion = jir.conversiontype
      AND p_inflationyear = jir.year
      AND a.appn = jir.appropriation
      AND a.amcosversionid = jir.amcosversionid
      AND a.applyinflation = true;

    IF p_costsummaryname = 'Weapon System Manpower' THEN
        v_select := 'appngroup, appn, costelementcategory as "Cost Element Category", armycestitle as "Army CES Title", osdcapecestitle as "OSD CAPE CES Title", weaponsystemname as "Weapon System Name", costelementname as "Cost Element Name", description, showorder';
        v_groupby := 'appngroup, appn, costelementcategory, armycestitle, osdcapecestitle, weaponsystemname, costelementname, description, showorder';
        v_orderby := v_groupby;
    END IF;

    v_from := '(select appngroup, appn, costelementcategory, costelementname, description, showorder, gradelevel, grade, armycestitle, osdcapecestitle, weaponsystemname, avg(amount) as amount from tmp_amcoslite group by appngroup, appn, costelementcategory, costelementname, description, showorder, gradelevel, grade, armycestitle, osdcapecestitle, weaponsystemname) costs';

    RETURN QUERY
    SELECT 'getamcoslitecosts_payload', jsonb_build_object(
        'costs', COALESCE((SELECT jsonb_agg(row_data) FROM web.spcrosstabgrades(v_from, v_select, 'grade', 'gradelevel', 'amount', v_groupby, v_orderby, p_debug)), '[]'::jsonb)
    );
END;
$$;

-- Source: GetAmcosLiteCostsForForces.sql
CREATE OR REPLACE FUNCTION web.getamcoslitecostsforforces(
    p_inflationconversion varchar(25),
    p_inflationyear varchar(4),
    p_amcosversionid integer DEFAULT 202001
)
RETURNS TABLE(result_set_name text, row_data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'getamcoslitecostsforforces_payload', jsonb_build_object('label', s.label, 'payload', r.row_data)
    FROM (
        VALUES
        ('WG Default', 'WG', 'Default', '-1', '-1', -1),
        ('WL Default', 'WL', 'Default', '-1', '-1', -1),
        ('WS Default', 'WS', 'Default', '-1', '-1', -1),
        ('CCE 11-9199 Default', 'CCE', 'Default', '-1', '11-9199', -1),
        ('GS RUS Default', 'GS', 'Default', '-1', '-1', 1007),
        ('AE Detailed', 'AE', 'Detailed', '-1', '-1', -1),
        ('AO Detailed', 'AO', 'Detailed', '-1', '-1', -1),
        ('AWO Detailed', 'AWO', 'Detailed', '-1', '-1', -1),
        ('NE Detailed', 'NE', 'Detailed', '-1', '-1', -1),
        ('NO Detailed', 'NO', 'Detailed', '-1', '-1', -1),
        ('NWO Detailed', 'NWO', 'Detailed', '-1', '-1', -1),
        ('RE Detailed', 'RE', 'Detailed', '-1', '-1', -1),
        ('RO Detailed', 'RO', 'Detailed', '-1', '-1', -1),
        ('RWO Detailed', 'RWO', 'Detailed', '-1', '-1', -1),
        ('AO 15B Detailed', 'AO', 'Detailed', '15', '15B', -1),
        ('AWO 152H Detailed', 'AWO', 'Detailed', '15', '152H', -1),
        ('AO 60 Detailed', 'AO', 'Detailed', '60', '-1', -1),
        ('AO 61 Detailed', 'AO', 'Detailed', '61', '-1', -1),
        ('AO 62 Detailed', 'AO', 'Detailed', '62', '-1', -1),
        ('AO 63 Detailed', 'AO', 'Detailed', '63', '-1', -1),
        ('AO 64 Detailed', 'AO', 'Detailed', '64', '-1', -1),
        ('AO 65D Detailed', 'AO', 'Detailed', '65', '65D', -1),
        ('AO 66 Detailed', 'AO', 'Detailed', '66', '-1', -1),
        ('AO 67E Detailed', 'AO', 'Detailed', '67', '67E', -1),
        ('AO 67F Detailed', 'AO', 'Detailed', '67', '67F', -1),
        ('AO 73B Detailed', 'AO', 'Detailed', '73', '73B', -1)
    ) AS s(label, payplan, costsummaryname, categorygroupcode, categorysubgroupcode, locationid)
    CROSS JOIN LATERAL web.getamcoslitecosts(
        s.payplan, s.costsummaryname, s.categorygroupcode, s.categorysubgroupcode,
        '-1', s.locationid, '-1', '-1', -1,
        p_inflationconversion, p_inflationyear, p_amcosversionid, false, false
    ) r
    WHERE r.result_set_name = 'getamcoslitecosts_payload';
END;
$$;

-- Source: ProjectAddUnit.sql
CREATE OR REPLACE FUNCTION web.projectaddunit(
    p_categoryid integer,
    p_uic varchar(6),
    p_notselectedpayplans varchar(500),
    p_unitlocation varchar(150),
    p_mtoeprojectinventoryyear varchar(25) DEFAULT NULL,
    p_mtoesyncextendeddurationfillvalue varchar(25) DEFAULT 'OTOE',
    p_useroverheadpercent double precision DEFAULT 150,
    p_amcosversionid integer DEFAULT NULL,
    p_debug boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_projectdurationyears integer;
    r record;
BEGIN
    SELECT web.getprojectyearduration(p_categoryid) INTO v_projectdurationyears;

    CREATE TEMP TABLE tmp_validatedunitpersonnel ON COMMIT DROP AS
    SELECT * FROM web.getunitpersonnel(
        p_categoryid, p_uic, p_notselectedpayplans, p_unitlocation,
        p_mtoeprojectinventoryyear, p_mtoesyncextendeddurationfillvalue,
        p_useroverheadpercent
    ) WHERE false;

    FOR r IN
        SELECT * FROM web.getunitpersonnel(
            p_categoryid, p_uic, p_notselectedpayplans, p_unitlocation,
            p_mtoeprojectinventoryyear, p_mtoesyncextendeddurationfillvalue,
            p_useroverheadpercent
        )
    LOOP
        IF NOT p_debug THEN
            PERFORM web.projectrequirementinserttda(
                p_categoryid, r.uic, r.payplan, r.categorygroupcode, r.categorysubgroupcode,
                '-1', r.locationid, r.locationtext, r.strl, r.gradelevel, r.dependentstatus,
                r.numberofdependents, r.activedutydays, r.overheadpercent, r.inventory
            );
        END IF;
    END LOOP;
END;
$$;
