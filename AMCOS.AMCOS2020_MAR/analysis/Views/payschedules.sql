CREATE VIEW analysis.PaySchedules
AS
SELECT a.*,
       b.SourceSystemCode,
       b.LocationType,
       b.DisplayName,
       ISNULL(c.CategorySubgroupDescription, 'All') AS CategorySubgroupDescription,
       ISNULL(c.CategoryGroupDescription, 'All') AS CategoryGroupDescription
FROM data.PaySchedules AS a
    LEFT OUTER JOIN warehouse.Location AS b
        ON a.LocationId = b.LocationId
    LEFT OUTER JOIN data.CategorySubgroup AS c
        ON c.PayPlan = a.PayPlan
           AND c.CategorySubgroupCode = a.CategorySubgroupCode;