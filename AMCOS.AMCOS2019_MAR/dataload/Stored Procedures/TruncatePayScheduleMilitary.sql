

-- =============================================
-- Description:	Truncate the PaySchedule_Military table
-- =============================================
CREATE PROCEDURE [dataload].[TruncatePayScheduleMilitary]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_payschedule.PaySchedule_Military;

END;