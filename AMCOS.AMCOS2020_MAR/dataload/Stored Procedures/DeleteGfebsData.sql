


-- =============================================
-- Author:		
-- Create date: 
-- Description:	Clear all data for specific AmcosVersionId from GFEBS related tables. Typically called 
--              before importing new data.
-- =============================================
CREATE PROCEDURE [dataload].[DeleteGfebsData] @AmcosVersionId INT
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM load_GFEBS.Raw
    WHERE AmcosVersionId = @AmcosVersionId;
    DELETE FROM load_GFEBS.Cleaned
    WHERE AmcosVersionId = @AmcosVersionId;
    DELETE FROM load_GFEBS.Rejected
    WHERE AmcosVersionId = @AmcosVersionId;

END;