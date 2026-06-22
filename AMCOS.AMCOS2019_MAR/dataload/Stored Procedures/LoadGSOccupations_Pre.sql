



-- =============================================
-- Description:	Truncate the GS Occupation tables
-- =============================================
CREATE PROCEDURE [dataload].[LoadGSOccupations_Pre]
AS
BEGIN

    SET NOCOUNT ON;

    /* Remove Foreign Keys */
    IF (OBJECT_ID('load_inventory.FK_Inventory_CivilianGS_GS_OccupationalSeries', 'F') IS NOT NULL)
    BEGIN
        ALTER TABLE [load_inventory].[Inventory_CivilianGS]
        DROP CONSTRAINT [FK_Inventory_CivilianGS_GS_OccupationalSeries];
    END;

	/* Truncate Tables */
    TRUNCATE TABLE lookup.GS_OccupationalGroup;
    TRUNCATE TABLE lookup.GS_OccupationalSeries;

END;