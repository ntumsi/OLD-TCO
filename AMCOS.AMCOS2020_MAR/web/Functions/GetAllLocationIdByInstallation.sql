-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION web.GetAllLocationIdByInstallation
(
    @InstallationName NVARCHAR(500)
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
           PayPlan,
           LocationId
    FROM warehouse.LocationByCategory
    WHERE LEFT(RTRIM(Installation), LEN(RTRIM(@InstallationName))) = LEFT(RTRIM(@InstallationName), LEN(RTRIM(@InstallationName)))
);