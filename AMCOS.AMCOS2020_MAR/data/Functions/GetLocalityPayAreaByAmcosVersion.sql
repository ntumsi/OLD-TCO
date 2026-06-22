-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION data.GetLocalityPayAreaByAmcosVersion
(
    @AmcosVersionId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM xwalk.LocalityPayArea
    WHERE @AmcosVersionId
    BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
);