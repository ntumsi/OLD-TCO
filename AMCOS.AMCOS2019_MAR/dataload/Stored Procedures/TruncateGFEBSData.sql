

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateGFEBSData]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_GFEBS.Cleaned;
    TRUNCATE TABLE load_GFEBS.Processed;
    TRUNCATE TABLE load_GFEBS.Raw;

END;