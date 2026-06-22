-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetUnitAuthorizationDocument
(
    @UIC NVARCHAR(6)
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @Result NVARCHAR(50);
    SELECT TOP (1)
           @Result = AuthorizationDocument
    FROM warehouse.UnitPersonnel
    WHERE UIC = @UIC
    ORDER BY AuthorizationDocument;
    RETURN @Result;

END;