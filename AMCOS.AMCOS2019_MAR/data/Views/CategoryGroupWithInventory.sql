
CREATE VIEW [data].[CategoryGroupWithInventory]
AS
SELECT DISTINCT
       PayPlan,
       CategoryGroupCode,
       CategoryGroupDescription
FROM data.CategorySubgroupWithInventory;