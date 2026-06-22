-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [test].[InventoryWithoutPaySchedule]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN SELECT DISTINCT
              Inventory.PayPlan,
              Inventory.GradeType,
              Inventory.GradeLevel,
              Inventory.Step_YOS
       FROM data.Inventory Inventory
       WHERE Inventory.PayPlan = @PayPlan
             AND Inventory.Step_YOS <> 99
             AND NOT EXISTS
       (
           SELECT DISTINCT
                  PayPlan,
                  GradeType,
                  GradeLevel,
                  Step_YOS
           FROM data.PaySchedules AS PaySchedules
           WHERE Inventory.PayPlan = PaySchedules.PayPlan
                 AND Inventory.GradeType = PaySchedules.GradeType
                 AND Inventory.GradeLevel = PaySchedules.GradeLevel
                 AND Inventory.Step_YOS = PaySchedules.Step_YOS
       );