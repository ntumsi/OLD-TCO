
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByGradeForPayPlan]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN
(
    SELECT GradeType,
           GradeLevel,
           SUM(Inventory) AS Amount
    FROM data.Inventory
    WHERE PayPlan = @PayPlan
    GROUP BY GradeType,
             GradeLevel
);