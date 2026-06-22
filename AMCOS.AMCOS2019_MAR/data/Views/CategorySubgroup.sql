






/****** Object:  View [data].[CategorySubgroupNew]    Script Date: 7/14/2018 9:22:26 PM ******/

/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [data].[CategorySubgroup]
AS
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       MOS.MOS AS CategorySubGroupCode,
       MOS.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.MOS MOS
        ON CategoryGroup.CategoryGroupCode = LEFT(MOS.MOS, 2)
WHERE CategoryGroup.PayPlan = 'AE'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       AOC.AOC AS CategorySubGroupCode,
       AOC.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.AOC AOC
        ON CategoryGroup.CategoryGroupCode = LEFT(AOC.AOC, 2)
WHERE CategoryGroup.PayPlan = 'AO'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       WOMOS.WOMOS AS CategorySubGroupCode,
       WOMOS.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.WOMOS WOMOS
        ON CategoryGroup.CategoryGroupCode = LEFT(WOMOS.WOMOS, 2)
WHERE CategoryGroup.PayPlan = 'AWO'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       MOS.MOS AS CategorySubGroupCode,
       MOS.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.MOS MOS
        ON CategoryGroup.CategoryGroupCode = LEFT(MOS.MOS, 2)
WHERE CategoryGroup.PayPlan = 'NE'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       AOC.AOC AS CategorySubGroupCode,
       AOC.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.AOC AOC
        ON CategoryGroup.CategoryGroupCode = LEFT(AOC.AOC, 2)
WHERE CategoryGroup.PayPlan = 'NO'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       WOMOS.WOMOS AS CategorySubGroupCode,
       WOMOS.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.WOMOS WOMOS
        ON CategoryGroup.CategoryGroupCode = LEFT(WOMOS.WOMOS, 2)
WHERE CategoryGroup.PayPlan = 'NWO'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       MOS.MOS AS CategorySubGroupCode,
       MOS.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.MOS MOS
        ON CategoryGroup.CategoryGroupCode = LEFT(MOS.MOS, 2)
WHERE CategoryGroup.PayPlan = 'RE'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       AOC.AOC AS CategorySubGroupCode,
       AOC.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.AOC AOC
        ON CategoryGroup.CategoryGroupCode = LEFT(AOC.AOC, 2)
WHERE CategoryGroup.PayPlan = 'RO'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       WOMOS.WOMOS AS CategorySubGroupCode,
       WOMOS.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.WOMOS WOMOS
        ON CategoryGroup.CategoryGroupCode = LEFT(WOMOS.WOMOS, 2)
WHERE CategoryGroup.PayPlan = 'RWO'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'DB'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'DE'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'DJ'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'DK'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'GG'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'GL'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'GP'
      AND GS_OccupationalSeries.OccupationalSeriesNumber IN ( '0602', '0680' )
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'GS'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'NH'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'NJ'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'NK'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       GS_OccupationalSeries.OccupationalSeriesNumber AS CategorySubGroupCode,
       GS_OccupationalSeries.SeriesTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.GS_OccupationalSeries GS_OccupationalSeries
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(GS_OccupationalSeries.OccupationalSeriesNumber, 2)
WHERE CategoryGroup.PayPlan = 'SES'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       WageArea.WageArea AS CategorySubGroupCode,
       WageArea.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.WageArea WageArea
        ON CategoryGroup.CategoryGroupCode = WageArea.WageArea
WHERE CategoryGroup.PayPlan = 'WG'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       WageArea.WageArea AS CategorySubGroupCode,
       WageArea.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.WageArea WageArea
        ON CategoryGroup.CategoryGroupCode = WageArea.WageArea
WHERE CategoryGroup.PayPlan = 'WL'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       WageArea.WageArea AS CategorySubGroupCode,
       WageArea.Description AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.WageArea WageArea
        ON CategoryGroup.CategoryGroupCode = WageArea.WageArea
WHERE CategoryGroup.PayPlan = 'WS'
UNION ALL
SELECT CategoryGroup.PayPlan,
       CategoryGroup.CategoryGroupCode,
       CategoryGroup.CategoryGroupDescription,
       SOCStructure.OccupationCode AS CategorySubGroupCode,
       SOCStructure.OccupationTitle AS CategorySubGroupDescription
FROM data.CategoryGroup CategoryGroup
    INNER JOIN lookup.SOCStructure SOCStructure
        ON LEFT(CategoryGroup.CategoryGroupCode, 2) = LEFT(SOCStructure.OccupationCode, 2)
WHERE CategoryGroup.PayPlan = 'CCE'
      AND SOCStructure.GroupLevel = 'Detailed';