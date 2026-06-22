

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByCategorySubgroupGradeForPayPlan]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN
(
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubGroupCode,
           GradeType,
           GradeLevel,
           SUM(Inventory) AS Amount
    FROM data.Inventory
    WHERE PayPlan = @PayPlan
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubGroupCode,
             GradeType,
             GradeLevel
);