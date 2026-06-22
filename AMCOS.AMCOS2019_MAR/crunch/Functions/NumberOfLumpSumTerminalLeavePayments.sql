

-- =============================================
-- Author:		
-- Create date: 
-- Description:	Number of Lump Sum Terminal Leave Payments
-- =============================================
CREATE FUNCTION [crunch].[NumberOfLumpSumTerminalLeavePayments]
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
        WHERE PayPlan = 'AE'
              AND Code = N'NUM_LSTLP';
    END;

    RETURN;
END;