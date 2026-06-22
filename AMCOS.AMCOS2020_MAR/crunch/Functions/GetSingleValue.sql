-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetSingleValue]
(
    @PayPlan NVARCHAR(10),
    @ParameterName NVARCHAR(100),
	@AmcosVersionId INT = -1
)
RETURNS NUMERIC(26, 6)
AS
BEGIN
    DECLARE @Result NUMERIC(26, 6);

    SELECT @Result = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = @PayPlan
          AND paramName = @ParameterName
		  AND AmcosVersionId = @AmcosVersionId;

    RETURN @Result;

END;