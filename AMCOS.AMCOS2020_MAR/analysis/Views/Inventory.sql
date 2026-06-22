

CREATE VIEW [analysis].[Inventory]
AS
SELECT Inventory.PayPlan,
       Inventory.CategoryGroupCode,
       Inventory.CategorySubgroupCode,
       Inventory.Strl,
       Inventory.LocationId,
       Inventory.GradeType,
       Inventory.GradeLevel,
       Inventory.Step,
       Inventory.YOS,
       Inventory.Inventory,
       Inventory.AmcosVersionId,
       b.SourceSystemCode,
       b.LocationType,
       b.DisplayName,
       c.CategorySubgroupDescription,
       c.CategoryGroupDescription
FROM data.Inventory Inventory
    LEFT OUTER JOIN warehouse.Location AS b
        ON Inventory.LocationId = b.LocationId
    LEFT OUTER JOIN data.CategorySubgroup AS c
        ON c.PayPlan = Inventory.PayPlan
           AND c.CategorySubgroupCode = Inventory.CategorySubgroupCode
WHERE Inventory.PayPlan IN
      (
          SELECT PayPlan FROM lookup.PayPlan WHERE DisplayTitle IS NOT NULL
      );