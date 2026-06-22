-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[CostElementsByPayPlan]
(
    @PayPlan NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN
(
    SELECT CostElementId,
           APPN,
           CostElementCategory,
           CostElementName
    FROM data.CostElement
    WHERE PayPlan = @PayPlan
);