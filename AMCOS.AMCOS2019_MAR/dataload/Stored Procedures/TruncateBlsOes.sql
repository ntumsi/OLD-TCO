

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateBlsOes]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE dataload.OccupationalEmploymentStatisticsMetro;
    TRUNCATE TABLE dataload.OccupationalEmploymentStatisticsNational;
    TRUNCATE TABLE lookup.MetroArea;
    TRUNCATE TABLE lookup.SOCStructure;

END;