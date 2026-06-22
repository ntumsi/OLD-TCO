
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[AnnualBasicPayActiveDuty]
(
    @PayPlan NVARCHAR(3)
)
RETURNS @Table_Var TABLE
(
    GradeType NVARCHAR(3) NOT NULL,
    GradeLevel TINYINT NOT NULL,
    YOS TINYINT NOT NULL,
    Amount NUMERIC(18, 2) NULL
)
AS
BEGIN
    INSERT INTO @Table_Var
    (
        GradeType,
        GradeLevel,
        YOS,
        Amount
    )
    SELECT GradeType,
           GradeLevel,
           Step_YOS AS YOS,
           (Rate * 12) AS Amount
    FROM data.PaySchedules
    WHERE (PayPlan = @PayPlan);

    RETURN;
END;