


-- =============================================
-- Description:	Delete rows in the PaySchedule_Military table for the @AmcosVersionId
-- =============================================
CREATE PROCEDURE [dataload].[DeletePayScheduleMilitary]
	@AmcosVersionId INT
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM PaySchedule.PaySchedule_Military WHERE AmcosVersionId = @AmcosVersionId;

END;