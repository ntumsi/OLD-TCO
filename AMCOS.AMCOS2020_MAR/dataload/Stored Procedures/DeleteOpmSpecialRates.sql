




-- =============================================
-- Description:	Delete rows in the OpmSpecialRates_raw table for the @AmcosVersionId
-- =============================================
CREATE PROCEDURE [dataload].[DeleteOpmSpecialRates] @AmcosVersionId INT
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM PaySchedule.OpmSpecialRates
    WHERE AmcosVersionId = @AmcosVersionId;

    DELETE FROM xwalk.SpecialRateTablesByAgency
    WHERE AmcosVersionId = @AmcosVersionId;

    DELETE FROM xwalk.SpecialRateTablesByLocation
    WHERE AmcosVersionId = @AmcosVersionId;

    DELETE FROM xwalk.SpecialRateTablesByOccupation
    WHERE AmcosVersionId = @AmcosVersionId;

END;