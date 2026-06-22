

CREATE FUNCTION [crunch].[GetAmortGrade]
(
    @PayPlan NVARCHAR(3),
    @CMF NVARCHAR(3),
    @GradeLevel TINYINT,
    @AmcosVersionId INT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @Amort FLOAT = 0.0;
    DECLARE @Value FLOAT = 0.0;
    DECLARE @YOS INT = 1;

    IF @PayPlan = 'NE'
       OR @PayPlan = 'RE'
    BEGIN
        WHILE (@YOS < 41)
        BEGIN
            SET @Value = @Value +
            (
                SELECT ISNULL(SUM(Inventory), 0)
                FROM data.Inventory
                WHERE PayPlan = @PayPlan
                      AND Step_YOS = @YOS
                      AND GradeType = 'E'
                      AND GradeLevel = @GradeLevel
            )            * crunch.GetManYears(@PayPlan, @CMF, @YOS, @AmcosVersionId);
            SET @YOS = @YOS + 1;
        END;
    END;

    SET @Amort = @Value /
                 (
                     SELECT SUM(Inventory)
                     FROM data.Inventory
                     WHERE PayPlan = @PayPlan
                           AND GradeType = 'E'
                           AND GradeLevel = @GradeLevel
                 );
    RETURN @Amort;
END;