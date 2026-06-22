

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [data].[GetLocalityPayByAmcosVersion]
(
    @AmcosVersionId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT LocalityCode,
           LocalityRate,
           AmcosVersionId
    FROM PaySchedule.LocalityPay
    WHERE AmcosVersionId = @AmcosVersionId
);