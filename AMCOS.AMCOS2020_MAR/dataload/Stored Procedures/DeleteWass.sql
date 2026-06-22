



-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[DeleteWass]
	@AmcosVersionId INT	
AS
BEGIN

    SET NOCOUNT ON;

	DELETE FROM load_inventory.WASS_Raw WHERE AmcosVersionId = @AmcosVersionId;


END;