
-- =============================================
-- Author:		
-- Create date: 3/16/2017
-- Description:	List of Wage Areas
-- =============================================
CREATE FUNCTION [dbo].[getWageAreaList] ( )
RETURNS TABLE
AS
RETURN
    (
	-- Add the SELECT statement with parameter references here
      SELECT    WageArea ,
                WageArea + ' : ' + Description AS 'Description'
      FROM      lookup.WageArea
    );