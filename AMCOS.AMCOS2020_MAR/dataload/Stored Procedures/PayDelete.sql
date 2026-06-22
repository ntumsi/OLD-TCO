
-- =============================================
-- Author:		
-- Create date: 
-- Description:	Delete rows from table for specific version
-- =============================================
CREATE PROCEDURE [dataload].[PayDelete] @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM DMDC.PayRejected
    WHERE AmcosVersionId = @AmcosVersionId;

    DELETE FROM DMDC.Pay
    WHERE AmcosVersionId = @AmcosVersionId;
END;