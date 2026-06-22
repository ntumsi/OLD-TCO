-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetArmyCesTitles
(
    @PayPlan NVARCHAR(3),
    @CostSummaryId INTEGER
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
           ArmyCesTitle
    FROM lookup.CostElement
        INNER JOIN lookup.CostSummaryElement
            ON CostSummaryElement.CostElementId = CostElement.CostElementId
    WHERE PayPlan = @PayPlan
          AND lookup.CostSummaryElement.SummaryId = @CostSummaryId
          AND ArmyCesTitle IS NOT NULL
);