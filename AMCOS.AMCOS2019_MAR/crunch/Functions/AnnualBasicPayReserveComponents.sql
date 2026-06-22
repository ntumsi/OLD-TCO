

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.AnnualBasicPayReserveComponents
(
    @PayPlan NVARCHAR(3),
    @ActiveDutyDays INT
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
    DECLARE @ActiveDutyPayPlan NVARCHAR(3);
    SET @ActiveDutyPayPlan = REPLACE(@PayPlan, 'N', 'A');
    SET @ActiveDutyPayPlan = REPLACE(@PayPlan, 'R', 'A');

    INSERT INTO @Table_Var
    (
        GradeType,
        GradeLevel,
        YOS,
        Amount
    )
    SELECT ReserveComponentPay.GradeType,
           ReserveComponentPay.GradeLevel,
           ReserveComponentPay.Step_YOS AS YOS,
           (ReserveComponentPay.Rate * 12) + (ISNULL(ActiveDutyPay.Rate, 0) * @ActiveDutyDays / 30)
    FROM data.PaySchedules ReserveComponentPay
        LEFT JOIN data.PaySchedules ActiveDutyPay
            ON ActiveDutyPay.GradeLevel = ReserveComponentPay.GradeLevel
               AND ActiveDutyPay.Step_YOS = ReserveComponentPay.Step_YOS
    WHERE ReserveComponentPay.PayPlan = @PayPlan
          AND ActiveDutyPay.PayPlan = @ActiveDutyPayPlan;

    RETURN;
END;