
CREATE VIEW [data].[CategorySubgroupWithInventory]
AS
SELECT DISTINCT
       CategorySubgroup.PayPlan,
       CategorySubgroup.CategoryGroupCode,
       CategorySubgroup.CategorySubGroupCode,
       CategorySubgroup.CategorySubGroupDescription,
       CategorySubgroup.CategoryGroupDescription
FROM data.CategorySubgroup CategorySubgroup
    INNER JOIN data.Inventory Inventory
        ON CategorySubgroup.PayPlan = Inventory.PayPlan
           AND CategorySubgroup.CategoryGroupCode = Inventory.CategoryGroupCode
           AND CategorySubgroup.CategorySubGroupCode = Inventory.CategorySubGroupCode
UNION ALL
SELECT DISTINCT
       CategorySubgroup.PayPlan,
       CategorySubgroup.CategoryGroupCode,
       CategorySubgroup.CategorySubGroupCode,
       CategorySubgroup.CategorySubGroupDescription,
       CategorySubgroup.CategoryGroupDescription
FROM data.CategorySubgroup CategorySubgroup
    INNER JOIN dataload.OccupationalEmploymentStatisticsMetro Inventory
        ON CategorySubgroup.CategorySubGroupCode = Inventory.SOC
WHERE CategorySubgroup.PayPlan = 'CCE';