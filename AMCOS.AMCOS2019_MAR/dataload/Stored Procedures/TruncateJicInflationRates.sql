

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateJicInflationRates]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE lookup.JicInflationRates;

END;