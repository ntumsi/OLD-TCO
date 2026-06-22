



-- =============================================
-- Description:	Truncate the GS Occupation tables
-- =============================================
CREATE PROCEDURE [dataload].[LoadGSOccupations_Post]
AS
BEGIN

    SET NOCOUNT ON;

    /* Add Foreign Keys */
    ALTER TABLE [load_inventory].[Inventory_CivilianGS] WITH CHECK
    ADD CONSTRAINT [FK_Inventory_CivilianGS_OccupationalSeries]
        FOREIGN KEY ([OccupationalSeriesNumber])
        REFERENCES [lookup].[GS_OccupationalSeries] ([OccupationalSeriesNumber]);

    ALTER TABLE [load_inventory].[Inventory_CivilianGS] CHECK CONSTRAINT [FK_Inventory_CivilianGS_OccupationalSeries];

END;