
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetCostSummaryId]
(
    @PayPlan NVARCHAR(3),
    @CostSummaryName NVARCHAR(50),
    @AmcosVersionId INT
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SELECT @Result = SummaryId
    FROM lookup.CostSummary
    WHERE PayPlan = @PayPlan
          AND Name = @CostSummaryName
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    RETURN @Result;

END;