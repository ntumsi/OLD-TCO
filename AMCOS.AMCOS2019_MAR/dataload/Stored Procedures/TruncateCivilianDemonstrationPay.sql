
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateCivilianDemonstrationPay]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_payschedule.PaySchedule_CivilianDemonstration;

END;