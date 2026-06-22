

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncatePayScheduleWage]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_payschedule.PaySchedule_Wage;

END;