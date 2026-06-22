-- Stored Procedure

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
CREATE PROCEDURE [crunch].[CrunchPayScheduleIG] @AmcosVersionId INT = -1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);
    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF @AmcosVersionId <
    (
        SELECT CONCAT(YEAR(OpmStartDate), '01')
        FROM lookup.PayPlan
        WHERE PayPlan = 'IG'
    )
    BEGIN
        PRINT (CAST(@AmcosVersionId AS NVARCHAR(6)) + ' is before creation date of pay plan IG, crunch skipped');
        RETURN 0;
    END;

    IF NOT EXISTS
    (
        SELECT *
        FROM PaySchedule.OpmIGRaw
        WHERE AmcosVersionId = @AmcosVersionId
    )
    BEGIN
        SELECT 'Cannot run IG crunch until version ' + CAST(@AmcosVersionId AS NVARCHAR(6)) + '  is added to OpmExRaw';

        RAISERROR('missing version', 18, 1);
        RETURN 0;
    END;

    --################ Create Pay Schedules


    DELETE FROM crunch.OpmIGProcessed
    WHERE AmcosVersionId = @AmcosVersionId;
    INSERT INTO crunch.OpmIGProcessed
    (
        PayPlan,
        GradeLevel,
        RateType,
        Rate,
        AmcosVersionId
    )
    SELECT Top(1) PayPlan,
           0,
           RateType,
           Rate,
           AmcosVersionId
    FROM PaySchedule.OpmIGRaw
    WHERE AmcosVersionId = @AmcosVersionId          
          AND RateType = 'Annual';


END;
GO
