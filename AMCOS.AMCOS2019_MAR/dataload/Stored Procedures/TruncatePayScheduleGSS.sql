
-- =============================================
-- Description:	Truncate the PaySchedule_GSS table
-- =============================================
CREATE PROCEDURE [dataload].[TruncatePayScheduleGSS]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_payschedule.PaySchedule_GSS;

END;