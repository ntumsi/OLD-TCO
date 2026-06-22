
CREATE   PROCEDURE crunch.CrunchPayScheduleCY
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN

    SET NOCOUNT ON;

    IF @Debug = 0
    BEGIN
        DELETE FROM PaySchedule.PaySchedule_CY
        WHERE AmcosVersionId = @AmcosVersionId;

        /* Pay schedule is based on the G series plan and the corresponding xwalk table which equates the the appropriate GS grade level for each pay band */
        INSERT INTO PaySchedule.PaySchedule_CY
        (
            PayPlan,
            GradeType,
            PayBand,
            MinPay,
            MaxPay,
            LocationId,
            AmcosVersionId
        )
        SELECT 'CY',
               'CY',
               a.PayBand,
               b.Rate AS MinPay,
               c.Rate AS MaxPay,
               b.LocationId,
               @AmcosVersionId
        FROM PaySchedule.PaySchedule_CY_Xwalk AS a
            INNER JOIN PaySchedule.PaySchedule_G_Series AS b
                ON a.Min_GS_GL = b.GradeLevel
            INNER JOIN PaySchedule.PaySchedule_G_Series AS c
                ON a.Max_GS_GL = c.GradeLevel
                   AND b.LocationId = c.LocationId
        WHERE @AmcosVersionId
              BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
              AND b.AmcosVersionId = @AmcosVersionId
              AND c.AmcosVersionId = @AmcosVersionId
              AND b.CategorySubgroupCode = '-1'
              AND c.CategorySubgroupCode = '-1'
              AND b.PayPlan = 'GS'
              AND c.PayPlan = 'GS'
              AND b.Step = 1
              AND c.Step = 10
              AND b.LocationId <> -1
              AND c.LocationId <> -1;
    END;

    IF @Debug = 1
    BEGIN
        SELECT 'CY',
               'CY',
               a.PayBand,
               b.Rate AS MinPay,
               c.Rate AS MaxPay,
               b.LocationId,
               @AmcosVersionId
        FROM PaySchedule.PaySchedule_CY_Xwalk AS a
            INNER JOIN PaySchedule.PaySchedule_G_Series AS b
                ON a.Min_GS_GL = b.GradeLevel
            INNER JOIN PaySchedule.PaySchedule_G_Series AS c
                ON a.Max_GS_GL = c.GradeLevel
                   AND b.LocationId = c.LocationId
        WHERE @AmcosVersionId
              BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
              AND b.AmcosVersionId = @AmcosVersionId
              AND c.AmcosVersionId = @AmcosVersionId
              AND b.CategorySubgroupCode = '-1'
              AND c.CategorySubgroupCode = '-1'
              AND b.PayPlan = 'GS'
              AND c.PayPlan = 'GS'
              AND b.Step = 1
              AND c.Step = 10
              AND b.LocationId <> -1
              AND c.LocationId <> -1;
    END;

END;