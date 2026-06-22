


-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateInventoryMilitary]
AS
BEGIN

    SET NOCOUNT ON;
    TRUNCATE TABLE load_inventory.Inventory_Military_Enlisted;
    TRUNCATE TABLE load_inventory.Inventory_Military_Officer;
    TRUNCATE TABLE load_inventory.Inventory_Military_Warrant;
END;