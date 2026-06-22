

-- =============================================
-- Author:		Roxanne Gates
-- Create date: 05/12/2018
-- Description:	Function to check validity of the passed version.
-- =============================================
CREATE FUNCTION [crunch].[ValidateAmcosVersion]
(
    @AmcosVersionId INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result AS BIT;

    IF @AmcosVersionId IS NULL
        SET @Result = 0;

    IF EXISTS
    (
        SELECT AmcosVersionId
        FROM lookup.AMCOSVersion
        WHERE AmcosVersionId = @AmcosVersionId
    )
        SET @Result = 1;
    ELSE
        SET @Result = 0;

    RETURN @Result;
END;