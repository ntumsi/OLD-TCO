-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetLocationDisplayName
(
    @LocationId INT
)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @Result NVARCHAR(100);
    SELECT @Result = DisplayName
    FROM warehouse.Location
    WHERE LocationId = @LocationId;
    RETURN @Result;

END;