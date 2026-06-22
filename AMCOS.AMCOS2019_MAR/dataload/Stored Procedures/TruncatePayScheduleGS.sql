


-- =============================================
-- Description:	Truncate the PaySchedule_GS table
-- =============================================
CREATE PROCEDURE [dataload].[TruncatePayScheduleGS]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_payschedule.PaySchedule_GS;

END;