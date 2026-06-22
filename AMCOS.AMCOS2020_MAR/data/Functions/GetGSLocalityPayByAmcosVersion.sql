-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION data.GetGSLocalityPayByAmcosVersion
(
    @AmcosVersionId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM lookup.GS_LocalityPay
    WHERE @AmcosVersionId
    BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
);