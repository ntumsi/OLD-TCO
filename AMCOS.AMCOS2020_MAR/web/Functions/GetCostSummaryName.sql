-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetCostSummaryName]
(
    @CostSummaryId INT,
    @AmcosVersionId INT = -1
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @Result NVARCHAR(50);

    SELECT @Result = Name
    FROM lookup.CostSummary
    WHERE SummaryId = @CostSummaryId
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    RETURN @Result;

END;