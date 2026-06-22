

/*
EXEC crunch.CrunchPayPlanOf @PayPlan = N'AE', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'AO', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'AWO', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'NE', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'NO', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'NWO', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'RE', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'RO', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'RWO', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'GG', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'GL', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'GS', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'SES', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'WG', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'WL', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'WS', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'DB', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'DE', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'DJ', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'DK', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'GP', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'NH', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'NJ', @AmcosVersionId = 1;
EXEC crunch.CrunchPayPlanOf @PayPlan = N'NK', @AmcosVersionId = 1;
*/
CREATE PROCEDURE [crunch].[CrunchPayPlanOf]
    @PayPlan NVARCHAR(3),
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF NOT EXISTS (SELECT PayPlan FROM lookup.PayPlan WHERE PayPlan = @PayPlan)
        RETURN 0;

    IF (@PayPlan = 'AE')
        IF @Debug = 0
            TRUNCATE TABLE crunch.Costs_AE;
        ELSE
            TRUNCATE TABLE greg.Costs_AE;

    IF (@PayPlan = 'AO')
        IF @Debug = 0
            TRUNCATE TABLE crunch.Costs_AO;
        ELSE
            TRUNCATE TABLE greg.Costs_AO;

    IF (@PayPlan = 'AWO') TRUNCATE TABLE crunch.Costs_AWO;
    IF (@PayPlan = 'NE') TRUNCATE TABLE crunch.Costs_NE;
    IF (@PayPlan = 'NO') TRUNCATE TABLE crunch.Costs_NO;
    IF (@PayPlan = 'NWO') TRUNCATE TABLE crunch.Costs_NWO;
    IF (@PayPlan = 'RE') TRUNCATE TABLE crunch.Costs_RE;
    IF (@PayPlan = 'RO') TRUNCATE TABLE crunch.Costs_RO;
    IF (@PayPlan = 'RWO') TRUNCATE TABLE crunch.Costs_RWO;
    IF (@PayPlan = 'GG') TRUNCATE TABLE crunch.CostsGG;
    IF (@PayPlan = 'GL') TRUNCATE TABLE crunch.CostsGL;
    IF (@PayPlan = 'GS')
    BEGIN
        TRUNCATE TABLE crunch.Costs_GS;
        TRUNCATE TABLE crunch.Costs_GSS;
    END;
    IF (@PayPlan = 'SES') TRUNCATE TABLE crunch.Costs_SES;
    IF (@PayPlan = 'WG') TRUNCATE TABLE crunch.Costs_WG;
    IF (@PayPlan = 'WL') TRUNCATE TABLE crunch.Costs_WL;
    IF (@PayPlan = 'WS') TRUNCATE TABLE crunch.Costs_WS;
    IF (@PayPlan = 'DB') TRUNCATE TABLE crunch.Costs_DB;
    IF (@PayPlan = 'DE') TRUNCATE TABLE crunch.Costs_DE;
    IF (@PayPlan = 'DJ') TRUNCATE TABLE crunch.Costs_DJ;
    IF (@PayPlan = 'DK') TRUNCATE TABLE crunch.Costs_DK;
    IF (@PayPlan = 'GP') TRUNCATE TABLE crunch.Costs_GP;
    IF (@PayPlan = 'NH') TRUNCATE TABLE crunch.Costs_NH;
    IF (@PayPlan = 'NJ') TRUNCATE TABLE crunch.Costs_NJ;
    IF (@PayPlan = 'NK') TRUNCATE TABLE crunch.Costs_NK;

    DECLARE @CategoryGroupCode NVARCHAR(7);
    DECLARE @CategorySubgroupCode NVARCHAR(7);


    IF (
           @PayPlan = 'AE'
           OR @PayPlan = 'AO'
           OR @PayPlan = 'AWO'
           OR @PayPlan = 'NE'
           OR @PayPlan = 'NO'
           OR @PayPlan = 'NWO'
           OR @PayPlan = 'RE'
           OR @PayPlan = 'RO'
           OR @PayPlan = 'RWO'
           OR @PayPlan = 'GG'
           OR @PayPlan = 'GL'
           OR @PayPlan = 'GS'
           OR @PayPlan = 'SES'
           OR @PayPlan = 'WG'
           OR @PayPlan = 'WL'
           OR @PayPlan = 'WS'
       )
    BEGIN

        DECLARE cSkills CURSOR LOCAL FOR
        SELECT DISTINCT
               PayPlan,
               CategoryGroupCode,
               CategorySubGroupCode
        FROM data.CategorySubgroup
        WHERE PayPlan = @PayPlan
        ORDER BY CategoryGroupCode,
                 CategorySubGroupCode;

        OPEN cSkills;

        FETCH cSkills
        INTO @PayPlan,
             @CategoryGroupCode,
             @CategorySubgroupCode;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT @PayPlan + ' - ' + @CategorySubgroupCode;
            IF (@PayPlan = 'AE')
                IF (@Debug = 0)
                    INSERT crunch.Costs_AE
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
                    EXEC crunch.CrunchAE @MOS = @CategorySubgroupCode,
                                         @AmcosVersionId = @AmcosVersionId;
                ELSE
                    INSERT greg.Costs_AE
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
                    EXEC crunch.CrunchAE @MOS = @CategorySubgroupCode,
                                         @AmcosVersionId = @AmcosVersionId;

            IF (@PayPlan = 'AO')
                IF (@Debug = 0)
                    INSERT crunch.Costs_AO
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
                    EXEC crunch.CrunchAO @AOC = @CategorySubgroupCode,
                                         @AmcosVersionId = @AmcosVersionId;
                ELSE
                    INSERT greg.Costs_AO
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
                    EXEC crunch.CrunchAO @AOC = @CategorySubgroupCode,
                                         @AmcosVersionId = @AmcosVersionId;

            IF (@PayPlan = 'AWO')
            BEGIN
                INSERT crunch.Costs_AWO
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
                EXEC crunch.CrunchAWO @WOMOS = @CategorySubgroupCode,
                                      @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'NE')
            BEGIN
                INSERT crunch.Costs_NE
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
                EXEC crunch.CrunchNE @MOS = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'NO')
            BEGIN
                INSERT crunch.Costs_NO
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
                EXEC crunch.CrunchNO @AOC = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'NWO')
            BEGIN
                INSERT crunch.Costs_NWO
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
                EXEC crunch.CrunchNWO @WOMOS = @CategorySubgroupCode,
                                      @AmcosVersionId = @AmcosVersionId;

            END;

            IF (@PayPlan = 'RE')
            BEGIN
                INSERT crunch.Costs_RE
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
                EXEC crunch.CrunchRE @MOS = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'RO')
            BEGIN
                INSERT crunch.Costs_RO
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
                EXEC crunch.CrunchRO @AOC = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'RWO')
            BEGIN
                INSERT crunch.Costs_RWO
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
                EXEC crunch.CrunchRWO @WOMOS = @CategorySubgroupCode,
                                      @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'GG')
            BEGIN
                INSERT crunch.CostsGG
                (
                    PayPlan,
                    OccupationalGroupNumber,
                    OccupationalSeriesNumber,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchGG @OccupationalGroupNumber = @CategoryGroupCode,
                                     @OccupationalSeriesNumber = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'GL')
            BEGIN
                INSERT crunch.CostsGL
                (
                    PayPlan,
                    OccupationalGroupNumber,
                    OccupationalSeriesNumber,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchGL @OccupationalGroupNumber = @CategoryGroupCode,
                                     @OccupationalSeriesNumber = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'GS')
            BEGIN
                INSERT crunch.Costs_GS
                (
                    PayPlan,
                    OccupationalGroupNumber,
                    OccupationalSeriesNumber,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchGS @OccupationalSeriesNumber = @CategorySubgroupCode,
                                     @AmcosVersionId = @AmcosVersionId;

                IF EXISTS
                (
                    SELECT OccupationalSeriesNumber
                    FROM lookup.OPM_SpecialRate
                    WHERE OccupationalSeriesNumber = @CategorySubgroupCode
                )
                BEGIN
                    INSERT crunch.Costs_GSS
                    (
                        PayPlan,
                        OccupationalGroupNumber,
                        OccupationalSeriesNumber,
                        SpecialRateTableNumber,
                        CostElementId,
                        GradeType,
                        GradeLevel,
                        Amount,
                        CrunchTime
                    )
                    EXEC crunch.CrunchGSS @OccupationalSeriesNumber = @CategorySubgroupCode,
                                          @AmcosVersionId = @AmcosVersionId;
                END;


            END;

            IF (@PayPlan = 'SES')
            BEGIN
                INSERT crunch.Costs_SES
                (
                    PayPlan,
                    OccupationalGroupNumber,
                    OccupationalSeriesNumber,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchSES @OccupationalGroupNumber = @CategoryGroupCode,
                                      @OccupationalSeriesNumber = @CategorySubgroupCode,
                                      @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'WG')
            BEGIN
                INSERT crunch.Costs_WG
                (
                    PayPlan,
                    WageArea,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchWG @WageArea = @CategoryGroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'WL')
            BEGIN
                INSERT crunch.Costs_WL
                (
                    PayPlan,
                    WageArea,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchWL @WageArea = @CategoryGroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            IF (@PayPlan = 'WS')
            BEGIN
                INSERT crunch.Costs_WS
                (
                    PayPlan,
                    WageArea,
                    CostElementId,
                    GradeType,
                    GradeLevel,
                    Amount,
                    CrunchTime
                )
                EXEC crunch.CrunchWS @WageArea = @CategoryGroupCode,
                                     @AmcosVersionId = @AmcosVersionId;
            END;

            FETCH cSkills
            INTO @PayPlan,
                 @CategoryGroupCode,
                 @CategorySubgroupCode;
        END;

        CLOSE cSkills;
        DEALLOCATE cSkills;

    END;

    IF (@PayPlan = 'DB')
    BEGIN
        INSERT crunch.Costs_DB
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchDB @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'DE')
    BEGIN
        INSERT crunch.Costs_DE
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchDE @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'DJ')
    BEGIN
        INSERT crunch.Costs_DJ
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchDJ @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'DK')
    BEGIN
        INSERT crunch.Costs_DK
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchDK @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'GP')
    BEGIN
        INSERT crunch.Costs_GP
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            Step,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchGP @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'NH')
    BEGIN
        INSERT crunch.Costs_NH
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchNH @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'NJ')
    BEGIN
        INSERT crunch.Costs_NJ
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchNJ @AmcosVersionId = @AmcosVersionId;
    END;

    IF (@PayPlan = 'NK')
    BEGIN
        INSERT crunch.Costs_NK
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeLevel,
            PersonnelNumber,
            CostElementId,
            Amount,
            CrunchTime
        )
        EXEC crunch.CrunchNK @AmcosVersionId = @AmcosVersionId;
    END;

--IF @PayPlan IN ( 'NO', 'NWO' )
--    BEGIN
--        UPDATE  crunch.Costs_NO
--        SET     APPN = REPLACE(APPN, 'RES', 'NG')
--        WHERE   PayPlan IN ( 'NO', 'NWO' );

--        UPDATE  crunch.Costs_NWO
--        SET     APPN = REPLACE(APPN, 'RES', 'NG')
--        WHERE   PayPlan IN ( 'NO', 'NWO' );
--    END;
END;