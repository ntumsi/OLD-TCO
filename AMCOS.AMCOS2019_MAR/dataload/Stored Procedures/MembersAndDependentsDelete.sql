
-- =============================================
-- Author:		
-- Create date: 
-- Description:	Delete rows from table for specific version
-- =============================================
CREATE PROCEDURE [dataload].[MembersAndDependentsDelete] @AmcosVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM DMDC.MembersAndDependents
    WHERE AmcosVersionId = @AmcosVersionId;
END;