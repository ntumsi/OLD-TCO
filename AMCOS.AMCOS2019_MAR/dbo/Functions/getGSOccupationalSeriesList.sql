
-- =============================================
-- Author:		
-- Create date: 3/16/2017
-- Description:	List of GS Occupational Series
-- =============================================
CREATE FUNCTION [dbo].[getGSOccupationalSeriesList] ( )
RETURNS TABLE
AS
RETURN
    ( SELECT    OccupationalSeriesNumber ,
                OccupationalSeriesNumber + ' : ' + SeriesTitle AS SeriesTitle
      FROM      lookup.GS_OccupationalSeries
    );