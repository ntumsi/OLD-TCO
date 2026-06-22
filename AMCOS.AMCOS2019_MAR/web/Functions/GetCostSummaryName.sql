-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetCostSummaryName
(
    @CostSummaryId INT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @Result NVARCHAR(50);

    SELECT @Result = Name
    FROM lookup.CostSummary
    WHERE SummaryId = @CostSummaryId;

    RETURN @Result;

END;