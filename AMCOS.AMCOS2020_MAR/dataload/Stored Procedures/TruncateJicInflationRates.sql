

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateJicInflationRates]
	@AmcosVersionId INT
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM lookup.JicInflationRates WHERE AmcosVersionId = @AmcosVersionId;

END;