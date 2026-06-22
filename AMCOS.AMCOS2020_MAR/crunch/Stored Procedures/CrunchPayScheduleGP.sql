
CREATE PROCEDURE [crunch].[CrunchPayScheduleGP]
    @AmcosVersionId INT = -1,
    @Debug BIT = -1
AS
BEGIN

    IF @Debug = 0
    BEGIN
        DELETE FROM PaySchedule.PaySchedule_G_Series
        WHERE AmcosVersionId = @AmcosVersionId
              AND PayPlan = 'GP';
        INSERT INTO PaySchedule.PaySchedule_G_Series
        (
            PayPlan,
            GradeType,
            GradeLevel,
            Step,
            Rate,
            AmcosVersionId,
            LocationId,
            CategoryGroupCode,
            CategorySubgroupCode
        )
        SELECT 'GP',
               'GP',
               GradeLevel,
               Step,
               Rate,
               AmcosVersionId,
               -1 AS LocationId,
               '-1' AS CategoryGroupCode,
               '-1' AS CategorySubgroupcode
        FROM PaySchedule.PaySchedule_G_Series_raw
        WHERE PayPlan = 'GS'
              AND RateType = 'Annual'
              AND GradeLevel >= 12
              AND AmcosVersionId = @AmcosVersionId;
    END;
END;