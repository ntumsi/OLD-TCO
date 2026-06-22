
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetMinMaxPay]
(
    @PayPlan NVARCHAR(3),
    @CategoryGroupCode NVARCHAR(4),
    @CategorySubgroupCode NVARCHAR(5),
    @CareerProgramNumber NCHAR(2),
    @LocationId INT,
    @STRL NVARCHAR(50),
    @AmcosVersionId INT
)
RETURNS @Table_Var TABLE
(
    Grade NVARCHAR(5) NOT NULL,
    GradeLevel TINYINT NOT NULL,
    Appropriation NVARCHAR(25) NOT NULL,
    MinimumPay NUMERIC(18, 2) NOT NULL,
    MaximumPay NUMERIC(18, 2) NOT NULL
)
AS
BEGIN
    INSERT INTO @Table_Var
    (
        Grade,
        GradeLevel,
        Appropriation,
        MinimumPay,
        MaximumPay
    )
    SELECT CAST(GradeType AS NVARCHAR(3)) + CAST(GradeLevel AS NVARCHAR(2)) Grade,
           GradeLevel,
           Appropriation,
           MinRate MinimumPay,
           MaxRate MaximumPay
    FROM crunch.PayScheduleMinMax
    WHERE PayPlan = @PayPlan
          AND CategoryGroupCode = @CategoryGroupCode
          AND CategorySubgroupCode = @CategorySubgroupCode
          AND CareerProgramNumber = @CareerProgramNumber
          AND LocationId = @LocationId
          AND STRL = @STRL
          AND AmcosVersionId = @AmcosVersionId;
    RETURN;
END;