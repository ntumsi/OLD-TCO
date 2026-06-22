-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByCategorySubgroupGradeYos]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN
(
    SELECT CategorySubGroupCode,
           GradeType,
           GradeLevel,
           Step_YOS,
           SUM(Inventory) AS Amount
    FROM data.Inventory
    WHERE PayPlan = @PayPlan
    GROUP BY CategorySubGroupCode,
             GradeType,
             GradeLevel,
             Step_YOS
);