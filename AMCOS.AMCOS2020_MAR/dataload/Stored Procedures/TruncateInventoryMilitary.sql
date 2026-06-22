


-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateInventoryMilitary]
	@AmcosVersionId INT	
AS
BEGIN

    SET NOCOUNT ON;
    DELETE FROM load_inventory.Inventory_Military_Enlisted WHERE AmcosVersionId = @AmcosVersionId;
    DELETE FROM load_inventory.Inventory_Military_Officer WHERE AmcosVersionId = @AmcosVersionId;
    DELETE FROM load_inventory.Inventory_Military_Warrant WHERE AmcosVersionId = @AmcosVersionId;
END;