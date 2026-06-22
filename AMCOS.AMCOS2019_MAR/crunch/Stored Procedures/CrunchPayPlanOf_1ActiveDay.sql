

/*
exec crunch.CrunchPayPlanOf_1ActiveDay 'NE'
exec crunch.CrunchPayPlanOf_1ActiveDay 'NO'
exec crunch.CrunchPayPlanOf_1ActiveDay 'NWO'
exec crunch.CrunchPayPlanOf_1ActiveDay 'RE'
exec crunch.CrunchPayPlanOf_1ActiveDay 'RO'
exec crunch.CrunchPayPlanOf_1ActiveDay 'RWO'
*/
CREATE PROCEDURE [crunch].[CrunchPayPlanOf_1ActiveDay]
    @PayPlan NVARCHAR(3),
    @AmcosVersionId INT = -1
AS
BEGIN
    SET NOCOUNT ON;

    IF (
       (
           SELECT crunch.ValidateAmcosVersion(@AmcosVersionId)
       ) = 0
       )
       OR @AmcosVersionId = -1
    BEGIN
        RETURN 0;
    END;

    IF @PayPlan NOT IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
        RETURN 0;

    DECLARE @CMF NVARCHAR(6);
    DECLARE @MOS NVARCHAR(6);

    TRUNCATE TABLE crunch.Costs_CrunchTemp_1AD;

    IF (@PayPlan = 'NE') TRUNCATE TABLE crunch.Costs_1ActiveDay_NE;
    IF (@PayPlan = 'NO') TRUNCATE TABLE crunch.Costs_1ActiveDay_NO;
    IF (@PayPlan = 'NWO') TRUNCATE TABLE crunch.Costs_1ActiveDay_NWO;
    IF (@PayPlan = 'RE') TRUNCATE TABLE crunch.Costs_1ActiveDay_RE;
    IF (@PayPlan = 'RO') TRUNCATE TABLE crunch.Costs_1ActiveDay_RO;
    IF (@PayPlan = 'RWO') TRUNCATE TABLE crunch.Costs_1ActiveDay_RWO;

    DECLARE cSkills CURSOR FOR
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubGroupCode
    FROM data.CategorySubgroup
    WHERE PayPlan = @PayPlan
    ORDER BY CategoryGroupCode,
             CategorySubGroupCode;

    OPEN cSkills;

    FETCH cSkills
    INTO @PayPlan,
         @CMF,
         @MOS;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT @PayPlan + ' - ' + @CMF + ' - ' + @MOS;

        IF (@PayPlan = 'NE')
        BEGIN
            INSERT crunch.Costs_1ActiveDay_NE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            EXEC crunch.CrunchNE @MOS = @MOS,
                                 @ActiveDutyDays = 1,
                                 @AmcosVersionId = @AmcosVersionId;
        END;

        IF (@PayPlan = 'NO')
        BEGIN
            INSERT crunch.Costs_1ActiveDay_NO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            EXEC crunch.CrunchNO @AOC = @MOS,
                                 @ActiveDutyDays = 1,
                                 @AmcosVersionId = @AmcosVersionId;
        END;

        IF (@PayPlan = 'NWO')
        BEGIN
            INSERT crunch.Costs_1ActiveDay_NWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            EXEC crunch.CrunchNWO @WOMOS = @MOS,
                                  @ActiveDutyDays = 1,
                                  @AmcosVersionId = @AmcosVersionId;
        END;

        IF (@PayPlan = 'RE')
        BEGIN
            INSERT crunch.Costs_1ActiveDay_RE
            (
                PayPlan,
                CMF,
                MOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            EXEC crunch.CrunchRE @MOS = @MOS,
                                 @ActiveDutyDays = 1,
                                 @AmcosVersionId = @AmcosVersionId;
        END;

        IF (@PayPlan = 'RO')
        BEGIN
            INSERT crunch.Costs_1ActiveDay_RO
            (
                PayPlan,
                CMF,
                AOC,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            EXEC crunch.CrunchRO @AOC = @MOS,
                                 @ActiveDutyDays = 1,
                                 @AmcosVersionId = @AmcosVersionId;
        END;

        IF (@PayPlan = 'RWO')
        BEGIN
            INSERT crunch.Costs_1ActiveDay_RWO
            (
                PayPlan,
                Branch,
                WOMOS,
                CostElementId,
                GradeType,
                GradeLevel,
                WeaponSystemId,
                Amount,
                CrunchTime
            )
            EXEC crunch.CrunchRWO @WOMOS = @MOS,
                                  @ActiveDutyDays = 1,
                                  @AmcosVersionId = @AmcosVersionId;
        END;

        FETCH cSkills
        INTO @PayPlan,
             @CMF,
             @MOS;
    END;

    CLOSE cSkills;
    DEALLOCATE cSkills;

END;