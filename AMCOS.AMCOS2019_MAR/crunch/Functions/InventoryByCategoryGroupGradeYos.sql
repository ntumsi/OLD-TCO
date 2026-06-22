
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByCategoryGroupGradeYos]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN
(
    SELECT CategoryGroupCode,
           GradeType,
           GradeLevel,
           Step_YOS,
           SUM(Inventory) AS Amount
    FROM data.Inventory
    WHERE PayPlan = @PayPlan
    GROUP BY CategoryGroupCode,
             GradeType,
             GradeLevel,
             Step_YOS
);