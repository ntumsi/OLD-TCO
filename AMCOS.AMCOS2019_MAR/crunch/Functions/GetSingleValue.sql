-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.GetSingleValue
(
    @PayPlan NVARCHAR(3),
    @ParameterName NVARCHAR(100)
)
RETURNS NUMERIC(26, 6)
AS
BEGIN
    DECLARE @Result NUMERIC(26, 6);

    SELECT @Result = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = @PayPlan
          AND paramName = @ParameterName;

    RETURN @Result;

END;