-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [data].[GetLocalityPayAreaByAmcosVersion]
(
    @AmcosVersionId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM xwalk.LocalityPayAreaToFips
    WHERE @AmcosVersionId = AmcosVersionId
);