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
CREATE PROCEDURE [crunch].[CrunchPayScheduleCA] @AmcosVersionId INT = -1
AS
BEGIN

    SET NOCOUNT ON;

    IF @AmcosVersionId <
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01')
        FROM lookup.PayPlan
        WHERE PayPlan = 'CA'
    )
    BEGIN
        PRINT (CAST(@AmcosVersionId AS NVARCHAR(6)) + ' is before creation date of pay plan CA, crunch skipped');
        RETURN 0;
    END;

    --CA is limited to the rate for level III of the executive schedule per 5 U.S.C 5304(g)(2)
    DECLARE @SalaryLimit NUMERIC(17, 2) =
            (
                SELECT Rate
                FROM PaySchedule.OpmExRaw
                WHERE @AmcosVersionId = AmcosVersionId
                      AND RateType = 'Annual'
                      AND Level = 'Level III'
            );

    --################ Create Pay Schedules

    DELETE FROM crunch.OpmCaProcessed
    WHERE AmcosVersionId = @AmcosVersionId;

    INSERT INTO crunch.OpmCaProcessed
    (
        a.PayPlan,
        a.Gradelevel,
        a.GradeLevelDescription,
        LocationId,
        a.RateType,
        a.Rate,
        a.AmcosVersionId
    )
    SELECT a.PayPlan,
           --unlike all other pay plans, the gradelevel goes in reverse so 1 is the higest paid and 3 is the lowest
           CASE
               WHEN a.Level = 'Chairman' THEN
                   1
               WHEN a.Level = 'Vice Chairman' THEN
                   2
               WHEN a.Level = 'Other Members' THEN
                   3
               ELSE
                   NULL
           END,
           a.Level,
           c.LocationId,
           a.RateType,
           CASE
               WHEN a.Rate * ((b.LocalityRate / 100) + 1) > @SalaryLimit THEN
                   @SalaryLimit
               ELSE
                   a.Rate * ((b.LocalityRate / 100) + 1)
           END,
           b.AmcosVersionId
    FROM PaySchedule.OpmCaRaw AS a
        CROSS JOIN PaySchedule.LocalityPay AS b
        LEFT OUTER JOIN warehouse.Location AS c
            ON c.SourceSystemCode = b.LocalityCode
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND b.AmcosVersionId = @AmcosVersionId
          AND c.LocationType = 'Locality Pay Area';

END;