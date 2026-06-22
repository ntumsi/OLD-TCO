
-- =============================================
-- Author:		
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetArmyBudgetSingleValue]
(
    @ParameterName NVARCHAR(100),
    @Appropriation NVARCHAR(10),
    @FY NVARCHAR(4),
    @AmcosVersionId INT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @Result FLOAT;

    SELECT @Result = Amount
    FROM crunch.ArmyBudgetSingleValues
    WHERE ParameterName = @ParameterName
          AND Appropriation = @Appropriation
          AND FY = @FY
          AND AmcosVersionId = @AmcosVersionId;

    RETURN @Result;

END;