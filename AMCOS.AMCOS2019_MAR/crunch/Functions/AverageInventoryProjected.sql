
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	Average Inventory Projected (Budget)
-- =============================================
CREATE FUNCTION [crunch].[AverageInventoryProjected]
(
    @PayPlan NVARCHAR(3)
)
RETURNS @Table_Var TABLE
(
    GradeType NCHAR(1) NOT NULL,
    GradeLevel INT NOT NULL,
    Amount FLOAT NULL,
    PRIMARY KEY (
                    GradeType,
                    GradeLevel
                )
)
AS
BEGIN
    IF @PayPlan = 'AE'
    BEGIN
        INSERT INTO @Table_Var
        (
            GradeType,
            GradeLevel,
            Amount
        )
        SELECT GradeType,
               GradeLevel,
               Amount
        FROM dataload.SepParms
        WHERE (
                  PayPlan = 'AE'
                  AND Code = N'AI_PRJ'
              );
    END;

    RETURN;
END;