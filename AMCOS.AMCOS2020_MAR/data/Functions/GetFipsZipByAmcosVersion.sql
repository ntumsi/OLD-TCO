-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION data.GetFipsZipByAmcosVersion
(
    @AmcosVersionId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM lookup.FIPS_ZIP
    WHERE @AmcosVersionId
    BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
);