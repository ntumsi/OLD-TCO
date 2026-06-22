-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetLocalityRate]
(
    @LocalityId INT
)
RETURNS NUMERIC(18, 4)
AS
BEGIN
    DECLARE @Result NUMERIC(18, 4);
    DECLARE @LocalityPayAreaId INT = web.GetLocalityPayAreaId(@LocalityId);

    SELECT @Result = Amount
    FROM lookup.LocalityRates
    WHERE Id = @LocalityPayAreaId;

    RETURN @Result;

END;