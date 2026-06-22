-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetLastMtoeUnitYear]
(
    @UIC NVARCHAR(6)
)
RETURNS NVARCHAR(4)
AS
BEGIN
    DECLARE @Result NVARCHAR(4);

    SELECT @Result = MAX(UnitYear)
    FROM warehouse.UnitPersonnel
    WHERE UIC = @UIC
          AND UnitYear <> 'OTOE';

    RETURN @Result;

END;