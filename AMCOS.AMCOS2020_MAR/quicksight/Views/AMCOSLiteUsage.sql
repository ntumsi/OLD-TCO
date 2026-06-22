CREATE VIEW [quicksight].[AMCOSLiteUsage]
AS(
SELECT ala.UserId,
       CONVERT(DATE, ala.CreateDate) AS CreateDate,
       CONVERT(DATE, ala.CreateDate) AS CreateDateConvert,
       ala.PageAction,
       ala.PageElement,
       ala.PayPlan,
       ala.CostSummaryName,
       ala.CategoryGroupCode,
       cat.CategoryGroupDisplay,
       ala.CategorySubgroupCode,
       cat.CategorySubgroupDisplay,
       ala.CareerProgramNumber,
       cat.CareerProgramDisplay,
       loc.DisplayName AS LocationName,
       ala.STRL,
       ala.DependentStatus,
       ala.NumberOfDependents,
       ala.OverheadPercent,
       ala.InflationConversionType,
       ala.InflationYear
FROM webuser.AmcosLiteAudit ala
    LEFT OUTER JOIN warehouse.Location loc
        ON ala.LocationId = loc.LocationId
    LEFT OUTER JOIN warehouse.Category cat
        ON ala.PayPlan = cat.PayPlan
           AND ala.CategoryGroupCode = cat.CategoryGroupCode
           AND ala.CategorySubgroupCode = cat.CategorySubgroupCode
           AND ala.CareerProgramNumber = cat.CareerProgramNumber);