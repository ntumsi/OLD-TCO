/*
-- Author:Dan Hogan
-- Create date: 5/23/2022
-- modified on 1/15/2020 to consolidate special pays into one single g series crunch following the use of warehouse location
-- modified on 4/1/2020 to add in calculation of base pay
-- modified on 7/3/2020 to add in non-foreign COLA calculation
-- Description:	Crunch GS
*/

/*
This is a complicated crunch when it comes to incorporating special pay, so the outline for it is as follows:
 1) generate pay schedules, do this by creating a master list of all pay for all locations to include location and occupation specific pay, SP fails if an occupation or location is not in the respective table
*/
CREATE PROCEDURE [crunch].[CrunchPayScheduleEX] @AmcosVersionId INT = -1
AS
BEGIN

    SET NOCOUNT ON;

    IF @AmcosVersionId <
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01')
        FROM lookup.PayPlan
        WHERE PayPlan = 'EX'
    )
    BEGIN
        PRINT (CAST(@AmcosVersionId AS NVARCHAR(6)) + ' is before creation date of pay plan EX, crunch skipped');
        RETURN 0;
    END;

    --################ Create Pay Schedules

    DELETE FROM crunch.OpmExProcessed
    WHERE AmcosVersionId = @AmcosVersionId;
    INSERT INTO crunch.OpmExProcessed
    (
        PayPlan,
        GradeLevel,
        GradeLevelDescription,
        RateType,
        Rate,
        AmcosVersionId
    )
    SELECT PayPlan,
           --unlike all other pay plans, the gradelevel goes in reverse so 1 is the higest paid and 4 is the lowest
           CASE
               WHEN Level = 'Level I' THEN
                   5
               WHEN Level = 'Level II' THEN
                   4
               WHEN Level = 'Level III' THEN
                   3
               WHEN Level = 'Level IV' THEN
                   2
               WHEN Level = 'Level V' THEN
                   1
               ELSE
                   NULL
           END,
           Level,
           RateType,
           Rate,
           AmcosVersionId
    FROM PaySchedule.OpmExRaw
    WHERE AmcosVersionId = @AmcosVersionId;

END;