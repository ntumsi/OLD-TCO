CREATE FUNCTION [test].[InventoryWithoutPaySchedule]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN SELECT DISTINCT
              KnownInventory.PayPlan,
              KnownInventory.GradeType,
              KnownInventory.GradeLevel,
              KnownInventory.Step,
              KnownInventory.YOS
       FROM data.KnownInventory KnownInventory
       WHERE KnownInventory.PayPlan = @PayPlan
             AND NOT EXISTS
       (
           SELECT DISTINCT
                  PayPlan,
                  GradeType,
                  GradeLevel,
                  Step,
                  YOS
           FROM data.PaySchedules PaySchedules
           WHERE KnownInventory.PayPlan = PaySchedules.PayPlan
                 AND KnownInventory.GradeType = PaySchedules.GradeType
                 AND KnownInventory.GradeLevel = PaySchedules.GradeLevel
                AND KnownInventory.Step = PaySchedules.Step
                 AND KnownInventory.YOS = PaySchedules.YOS
       );