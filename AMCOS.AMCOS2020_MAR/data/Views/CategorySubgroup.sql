



CREATE VIEW [data].[CategorySubgroup]
AS
WITH CTE
AS (
   SELECT b.PayPlan AS PayPlan,
          MOS.MOS AS CategorySubgroupCode,
          MOS.Description AS CategorySubgroupDescription,
          MOS.AmcosVersionIdStart,
          MOS.AmcosVersionIdEnd
   FROM lookup.MOS MOS
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Enlisted') ) AS b
   UNION ALL
   SELECT b.PayPlan,
          AOC.AOC AS CategorySubgroupCode,
          AOC.Description AS CategorySubgroupDescription,
          AOC.AmcosVersionIdStart,
          AOC.AmcosVersionIdEnd
   FROM lookup.AOC AS AOC
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Officer') ) AS b
   UNION ALL
   SELECT b.PayPlan,
          WOMOS.WOMOS AS CategorySubgroupCode,
          WOMOS.Description AS CategorySubgroupDescription,
          WOMOS.AmcosVersionIdStart,
          WOMOS.AmcosVersionIdEnd
   FROM lookup.WOMOS WOMOS
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Warrant') ) AS b
   UNION ALL
   SELECT b.PayPlan,
          GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubgroupCode,
          GS_OccupationalSeries.SeriesTitle AS CategorySubgroupDescription,
          GS_OccupationalSeries.AmcosVersionIdStart,
          GS_OccupationalSeries.AmcosVersionIdEnd
   FROM lookup.GS_OccupationalSeries AS GS_OccupationalSeries
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
		   union
           SELECT 'NF'
       ) AS b
   UNION ALL
   SELECT b.PayPlan,
          a.OccupationalSeriesNumber,
          a.SeriesTitle,
          a.AmcosVersionIdStart,
          a.AmcosVersionIdEnd
   FROM lookup.Wage_OccupationalSeries AS a
       CROSS JOIN
       (SELECT PayPlan FROM analysis.GetPayPlans('Wage') ) AS b
   UNION ALL
   SELECT 'CCE',
          SOCStructure.OccupationCode AS CategorySubgroupCode,
          SOCStructure.OccupationTitle AS CategorySubgroupDescription,
          SOCStructure.AmcosVersionIdStart,
          SOCStructure.AmcosVersionIdEnd
   FROM lookup.SOCStructure SOCStructure
   WHERE SOCStructure.GroupLevel = 'Detailed')
SELECT subgrp.PayPlan,
       subgrp.CategorySubgroupCode,
       subgrp.CategorySubgroupDescription,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription
FROM CTE AS subgrp
    INNER JOIN
    (
        --when displaying the nomenclatures we only care about the latest nomenclature name
        SELECT CategorySubgroupCode,
               MAX(AmcosVersionIdEnd) AS amcosversionidmax
        FROM CTE
        GROUP BY CategorySubgroupCode
    ) AS b
        ON subgrp.AmcosVersionIdEnd = b.amcosversionidmax
           AND subgrp.CategorySubgroupCode = b.CategorySubgroupCode
    LEFT OUTER JOIN data.CategoryGroup AS CategoryGroup
        ON LEFT(subgrp.CategorySubgroupCode, 2) = LEFT(CategoryGroup.CategoryGroupCode, 2)
           AND subgrp.PayPlan = CategoryGroup.PayPlan;