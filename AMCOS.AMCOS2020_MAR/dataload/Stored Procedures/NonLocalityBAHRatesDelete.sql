
-- =============================================
-- Author:		
-- Create date: 
-- Description:	Delete rows from table for specific version
-- =============================================
CREATE PROCEDURE [dataload].[NonLocalityBAHRatesDelete] @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dataload.NonLocalityBAHRates
    WHERE AmcosVersionId = @AmcosVersionId;
END;