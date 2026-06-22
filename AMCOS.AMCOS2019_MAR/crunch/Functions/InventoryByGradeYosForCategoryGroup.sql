
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByGradeYosForCategoryGroup]
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
           Step_YOS,
           SUM(Inventory) AS Amount
    FROM data.Inventory
    WHERE CategoryGroupCode = @CategoryGroupCode
          AND PayPlan = @PayPlan
    GROUP BY GradeType,
             GradeLevel,
             Step_YOS
);