-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.GetTotalInventoryForPayPlan
(
    @PayPlan NVARCHAR(3)
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SELECT @Result = SUM(Amount)
    FROM crunch.InventoryByGradeForPayPlan(@PayPlan);

    RETURN @Result;

END;