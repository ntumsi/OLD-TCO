


-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateGSJobSeries]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE lookup.GS_OccupationalGroup;
    TRUNCATE TABLE lookup.GS_OccupationalSeries;

END;