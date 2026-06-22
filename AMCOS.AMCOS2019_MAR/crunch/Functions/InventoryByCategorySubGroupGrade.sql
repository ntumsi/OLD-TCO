
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[InventoryByCategorySubgroupGrade]
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
           SUM(Inventory) AS Inventory
    FROM data.Inventory
    WHERE PayPlan = @PayPlan
    GROUP BY CategorySubGroupCode,
             GradeType,
             GradeLevel
);