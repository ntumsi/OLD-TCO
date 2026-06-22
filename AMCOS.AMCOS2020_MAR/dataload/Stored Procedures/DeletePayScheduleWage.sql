


-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[DeletePayScheduleWage]
	@AmcosVersionId INT
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM PaySchedule.PaySchedule_Wage WHERE AmcosVersionId = @AmcosVersionId;

END;