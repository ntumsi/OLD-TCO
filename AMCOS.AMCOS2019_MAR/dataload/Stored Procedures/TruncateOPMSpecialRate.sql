
-- =============================================
-- Description:	Truncate the OPM Special Rate table
-- =============================================
CREATE PROCEDURE [dataload].[TruncateOPMSpecialRate]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE lookup.OPM_SpecialRate;

END;