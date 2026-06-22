
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByGradeForCategoryGroup]
(
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(4)
)
RETURNS TABLE
AS
RETURN
(
    SELECT GradeType,
           GradeLevel,
           SUM(Inventory) AS Amount
    FROM data.Inventory
    WHERE CategoryGroupCode = @CategoryGroupCode
          AND PayPlan = @PayPlan
    GROUP BY GradeType,
             GradeLevel
);