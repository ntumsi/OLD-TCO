





CREATE VIEW [data].[CategoryGroup]
AS
WITH CTE
AS (
   SELECT b.PayPlan AS PayPlan,
          a.Code AS CategoryGroupCode,
          a.Description AS CategoryGroupDescription,
          a.AmcosVersionIdStart,
          a.AmcosVersionIdEnd
   FROM lookup.CMF_Branch_FA AS a
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Enlisted') ) AS b
   WHERE a.GradeType = 'E'
   UNION ALL
   SELECT b.PayPlan AS PayPlan,
          a.Code AS CategoryGroupCode,
          a.Description AS CategoryGroupDescription,
          a.AmcosVersionIdStart,
          a.AmcosVersionIdEnd
   FROM lookup.CMF_Branch_FA AS a
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Officer') ) AS b
   WHERE a.GradeType = 'O'
   UNION ALL
   SELECT b.PayPlan AS PayPlan,
          a.Code AS CategoryGroupCode,
          a.Description AS CategoryGroupDescription,
          a.AmcosVersionIdStart,
          a.AmcosVersionIdEnd
   FROM lookup.CMF_Branch_FA AS a
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Warrant') ) AS b
   WHERE a.GradeType = 'W'
   UNION ALL
   SELECT b.PayPlan AS PayPlan,
          OccupationalGroup.OccupationalGroupNumber AS CategoryGroupCode,
          OccupationalGroup.GroupTitle AS CategoryGroupDescription,
          OccupationalGroup.AmcosVersionIdStart,
          OccupationalGroup.AmcosVersionIdEnd
   FROM lookup.GS_OccupationalGroup OccupationalGroup
       CROSS JOIN
       (
           SELECT PayPlan
           FROM analysis.GetPayPlans('Acq')
           UNION
           SELECT PayPlan
           FROM analysis.GetPayPlans('Lab Demo')
           UNION
           SELECT PayPlan
           FROM analysis.GetPayPlans('G')
           UNION
           SELECT PayPlan
           FROM analysis.GetPayPlans('SES')
		   UNION
           SELECT 'CY'
		   UNION
           SELECT 'AD'
		   UNION
		   SELECT 'CA'
		   UNION
		   SELECT 'EE'
		   UNION
		   SELECT 'EF'
		   UNION
		   SELECT 'EX'
		   UNION
		   SELECT 'IE'
		   UNION
		   SELECT 'IP'
		   UNION
		   SELECT 'IG'
		   UNION
		   SELECT 'SL'
		   UNION
		   SELECT 'ST'
		   UNION
		   SELECT 'ZZ'
		   UNION

           SELECT 'NF'
       ) AS b
   UNION ALL
   SELECT b.PayPlan AS PayPlan,
          a.OccupationalGroupNumber AS CategoryGroupCode,
          a.GroupTitle AS CategoryGroupDescription,
          a.AmcosVersionIdStart,
          a.AmcosVersionIdEnd
   FROM lookup.Wage_OccupationalGroup AS a
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Wage') ) AS b
   UNION ALL
   SELECT 'CCE' AS PayPlan,
          OccupationCode AS CategoryGroupCode,
          OccupationTitle AS CategoryGroupDescription,
          AmcosVersionIdStart,
          AmcosVersionIdEnd
   FROM lookup.SOCStructure
   WHERE GroupLevel = 'Major')
SELECT a.PayPlan,
       a.CategoryGroupCode,
       a.CategoryGroupDescription
FROM CTE AS a
    INNER JOIN
    (
        --when displaying the nomenclatures we only care about the latest nomenclature name
        SELECT CategoryGroupCode,
               MAX(AmcosVersionIdEnd) AS amcosversionidmax
        FROM CTE
        GROUP BY CategoryGroupCode
    ) AS b
        ON a.AmcosVersionIdEnd = b.amcosversionidmax
           AND a.CategoryGroupCode = b.CategoryGroupCode;