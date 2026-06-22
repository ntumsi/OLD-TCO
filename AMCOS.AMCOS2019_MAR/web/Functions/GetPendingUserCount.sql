-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetPendingUserCount
()
RETURNS INT
AS
BEGIN
    DECLARE @Result INT;

    SELECT @Result = COUNT(*)
    FROM webuser.AMCOSUser
    WHERE UserStatus LIKE 'Pending%';

    RETURN @Result;

END;