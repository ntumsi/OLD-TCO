
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[DeletePayScheduleGSeriesRaw] @AmcosVersionId INT
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM PaySchedule.PaySchedule_G_Series_raw
    WHERE AmcosVersionId = @AmcosVersionId;

END;