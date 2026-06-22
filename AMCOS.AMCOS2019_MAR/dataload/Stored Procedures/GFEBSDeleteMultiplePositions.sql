
-- =============================================
-- Author:		
-- Create date: 04/18/2018
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[GFEBSDeleteMultiplePositions]
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM load_GFEBS.Raw
    WHERE EXISTS
    (
        SELECT PersonnelNumber
        FROM load_GFEBS.PersonnelNumberWithMultiplePositions
        WHERE PersonnelNumber = Raw.PersonnelNumber
    );
END;