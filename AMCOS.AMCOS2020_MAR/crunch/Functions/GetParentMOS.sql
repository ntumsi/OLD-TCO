-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.GetParentMOS
(
    @CategorySubgroupCode NVARCHAR(3),
    @AmcosVersionId INT = -1
)
RETURNS NVARCHAR(3)
AS
BEGIN
    DECLARE @Result NVARCHAR(3);

    SET @Result =
    (
        SELECT TOP (1)
               Parent_MOS
        FROM lookup.MOS
        WHERE MOS = @CategorySubgroupCode
              AND (@AmcosVersionId
              BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                  )
        ORDER BY MOS
    );

    RETURN @Result;

END;