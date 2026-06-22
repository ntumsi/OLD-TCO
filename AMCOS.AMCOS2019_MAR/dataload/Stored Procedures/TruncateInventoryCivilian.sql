


-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateInventoryCivilian]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_inventory.Inventory_CivilianAcquisition;
    TRUNCATE TABLE load_inventory.Inventory_CivilianDemonstration;
    TRUNCATE TABLE load_inventory.Inventory_CivilianGS;
    TRUNCATE TABLE load_inventory.Inventory_CivilianOther;
    TRUNCATE TABLE load_inventory.Inventory_CivilianSES;
    TRUNCATE TABLE load_inventory.Inventory_CivilianWage;

END;