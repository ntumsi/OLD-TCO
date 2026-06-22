
-- =============================================
-- Author:		
-- Create date: 
-- Description:	Delete rows from table for specific version
-- =============================================
CREATE PROCEDURE [dataload].[MilitaryAcqSourceOfCommissionDelete] @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM DMDC.MilitaryAcqSourceOfCommission
    WHERE AmcosVersionId = @AmcosVersionId;
END;