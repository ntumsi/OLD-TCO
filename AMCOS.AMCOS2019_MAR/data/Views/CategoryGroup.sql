

/****** Script for SelectTopNRows command from SSMS  ******/

CREATE VIEW [data].[CategoryGroup]
AS
SELECT PayPlan,
       CategoryGroupCode,
       CategoryGroupDescription
FROM
(
    SELECT 'AE' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'E'
    UNION ALL
    SELECT 'AO' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'O'
    UNION ALL
    SELECT 'AWO' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'W'
    UNION ALL
    SELECT 'NE' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'E'
    UNION ALL
    SELECT 'NO' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'O'
    UNION ALL
    SELECT 'NWO' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'W'
    UNION ALL
    SELECT 'RE' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'E'
    UNION ALL
    SELECT 'RO' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'O'
    UNION ALL
    SELECT 'RWO' AS PayPlan,
           Code AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.CMF_Branch_FA
    WHERE GradeType = 'W'
    UNION ALL
    SELECT 'DB' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'DE' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'DJ' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'DK' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'NH' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'NJ' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'NK' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'GG' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'GL' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'GS' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'GP' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    WHERE OccupationalGroupNumber = '0600'
    UNION ALL
    SELECT 'SES' AS PayPlan,
           OccupationalGroupNumber AS CategoryGroupCode,
           GroupTitle AS CategoryGroupDescription
    FROM lookup.GS_OccupationalGroup
    UNION ALL
    SELECT 'WG' AS PayPlan,
           WageArea AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.WageArea
    UNION ALL
    SELECT 'WL' AS PayPlan,
           WageArea AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.WageArea
    UNION ALL
    SELECT 'WS' AS PayPlan,
           WageArea AS CategoryGroupCode,
           Description AS CategoryGroupDescription
    FROM lookup.WageArea
    UNION ALL
    SELECT 'CCE' AS PayPlan,
           OccupationCode AS CategoryGroupCode,
           OccupationTitle AS CategoryGroupDescription
    FROM lookup.SOCStructure
    WHERE GroupLevel = 'Major'
) a;