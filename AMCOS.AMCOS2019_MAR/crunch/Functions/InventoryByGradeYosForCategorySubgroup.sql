-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByGradeYosForCategorySubgroup]
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(4)
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
    WHERE CategorySubGroupCode = @CategorySubgroupCode
          AND PayPlan = @PayPlan
    GROUP BY GradeType,
             GradeLevel,
             Step_YOS
);