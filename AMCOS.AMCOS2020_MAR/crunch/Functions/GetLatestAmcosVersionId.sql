-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.GetLatestAmcosVersionId
()
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;
    SELECT @Result = MAX(AmcosVersionId)
    FROM lookup.AMCOSVersion;
    RETURN @Result;

END;