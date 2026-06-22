-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetLocalityPayAreaId
(
    @LocalityId INT
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SELECT @Result = LocalityId
    FROM lookup.LocalityRates
    WHERE Id = @LocalityId;

    RETURN @Result;

END;