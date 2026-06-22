-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [dbo].[GetCostElementId]
(
    @PayPlan NVARCHAR(3),
    @APPN NVARCHAR(25),
    @CostElementName NVARCHAR(250),
    @AmcosVersionId INT = -1
)
RETURNS INT
AS
BEGIN
    -- Declare the return variable here
    DECLARE @Result INT;

    -- Add the T-SQL statements to compute the return value here
    SELECT @Result = CostElementId
    FROM lookup.CostElement
    WHERE PayPlan = @PayPlan
          AND APPN = @APPN
          AND CostElementName = @CostElementName
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    -- Return the result of the function
    RETURN @Result;

END;