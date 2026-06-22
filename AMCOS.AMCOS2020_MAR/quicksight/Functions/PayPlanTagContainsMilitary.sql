
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================

CREATE FUNCTION [quicksight].[PayPlanTagContainsMilitary](@PayPlan NVARCHAR(3))
RETURNS BIT
AS BEGIN
    DECLARE @Result BIT;
    DECLARE @NumberOfRows INT;
    SELECT @NumberOfRows=COUNT(PayPlan)
    FROM lookup.PayPlan
    WHERE EXISTS (SELECT PayPlan
                  FROM lookup.PayPlanTags
                  WHERE PayPlan.PayPlan=PayPlanTags.PayPlan AND Tag='military')AND PayPlan=@PayPlan;
    IF @NumberOfRows>0 SET @Result=1;
    ELSE SET @Result=0;
    RETURN @Result;
END;