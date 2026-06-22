
CREATE PROCEDURE [crunch].[CrunchAll]
    @AmcosVersionId INT = -1,
    @Debug_mode AS BIT = 0,
    @WhichtoRun AS NVARCHAR(25) = '-1' --'All','All_no_mil_training','GFEBS','Mil','Mil_no_training','No Mil','OPM_G','SES','Wage'
AS
BEGIN
    DECLARE @CrunchAllStart AS SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());;
    DECLARE @TimestampStart AS DATETIME;
    DECLARE @TimestampEnd AS DATETIME;

    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    RAISERROR('Populate JIC', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.JointInflationCalculator;

    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.JointInflationCalculator', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    --insert/update the warehouse table
    RAISERROR('UpdateLocationId', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC warehouse.UpdateLocationId @AmcosVersionId = @AmcosVersionId,
                                    @Debug = 0;
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('warehouse.UpdateLocationId', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    RAISERROR('LoadGSAPerDiem', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.LoadGSAPerDiem @AmcosVersionId = @AmcosVersionId;
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.LoadGSAPerDiem', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    -- because many pay plans use the army budget data this must be run every time
    RAISERROR('ArmyBudget', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.ArmyBudget @AmcosVersionId = @AmcosVersionId,
                           @Debug = @Debug_mode;
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.ArmyBudget', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    /* Anytime we crunch the costs we need to regenerate inventory in case anything changes */

    RAISERROR('CrunchWASSInventory', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.CrunchWASSInventory @AmcosVersionId = @AmcosVersionId,
                                    @debug = @Debug_mode;
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.CrunchWASSInventory', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    RAISERROR('CrunchDMDCInventory', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.CrunchDMDCInventory @AmcosVersionId = @AmcosVersionId,
                                    @Debug = @Debug_mode;
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.CrunchDMDCInventory', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    IF @WhichtoRun IN ( 'OPM_G', 'All', 'No Mil' )
       OR LEFT(@WhichtoRun, 3) = 'All'
    BEGIN
        RAISERROR('CrunchPayScheduleGSeries', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleGSeries @AmcosVersionId = @AmcosVersionId, -- int
                                             @Debug = @Debug_mode;              -- bit
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleGSeries', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchGSeries', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchGSeries @AmcosVersionId = @AmcosVersionId,
                                  @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchGSeries', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchPayScheduleCY', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleCY @AmcosVersionId = @AmcosVersionId, -- int
                                        @Debug = @Debug_mode;              -- bit
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleCY', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchCY', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchCY @AmcosVersionId = @AmcosVersionId,
                             @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchCY', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchPayScheduleNF', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleNF @AmcosVersionId = @AmcosVersionId, -- int
                                        @Debug = @Debug_mode;              -- bit
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleNF', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchNF', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchNF @AmcosVersionId = @AmcosVersionId,
                             @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchNF', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);
    END; --end OPM G series section

    IF @WhichtoRun IN ( 'SES', 'All' )
       OR LEFT(@WhichtoRun, 3) = 'All'
    BEGIN
        RAISERROR('CrunchSES', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchSES @debug = @Debug_mode,              -- bit
                              @AmcosVersionId = @AmcosVersionId; -- int
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchSES', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchPayScheduleCA', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleCA @AmcosVersionId = @AmcosVersionId; -- int
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleCA', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchPayScheduleEX', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleEX @AmcosVersionId = @AmcosVersionId; -- int
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleEX', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchPayScheduleIG', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleIG @AmcosVersionId = @AmcosVersionId; -- int
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleIG', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);
    END;

    IF @WhichtoRun IN ( 'Wage', 'All', 'No Mil' )
       OR LEFT(@WhichtoRun, 3) = 'All'
    BEGIN
        RAISERROR('CrunchPayScheduleWage', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleWage @AmcosVersionId = @AmcosVersionId, -- int
                                          @Debug = @Debug_mode;              -- bit
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleWage', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchWage', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchWage @AmcosVersionId = @AmcosVersionId, -- int
                               @debug = @Debug_mode;              -- bit

        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchWage', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);
    END;

    IF @WhichtoRun IN ( 'All', 'GFEBS', 'No Mil' )
       OR LEFT(@WhichtoRun, 3) = 'All'
    BEGIN
        -- NOTE: GFEBS inventory is populated inside the crunch.GFEBS object
        RAISERROR('GFEBS Crunch', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchGFEBS @AmcosVersionId = @AmcosVersionId, -- int
                                @CrunchTime = @CrunchAllStart,
                                @debug = @Debug_mode;              -- bit

        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchGFEBS', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CrunchPayScheduleGP', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CrunchPayScheduleGP @AmcosVersionId = @AmcosVersionId, -- int
                                        @Debug = @Debug_mode;              -- bit
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CrunchPayScheduleGP', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);
    END;

    IF (
           @WhichtoRun IN ( 'All', 'Mil', 'Mil_no_training' )
           OR LEFT(@WhichtoRun, 3) = 'All'
       )
       AND @WhichtoRun <> 'No Mil'
    BEGIN
        --all military pay plans use the DMDC crunch so that must be run
        RAISERROR('DMDC Pay Crunch', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.DMDCPay @AmcosVersionId = @AmcosVersionId,
                            @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.DMDCPay', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('Military Crunches', 0, 1) WITH NOWAIT;
        RAISERROR('CostOfBasePay', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfBasePay @AmcosVersionId = @AmcosVersionId,
                                  @CrunchTime = @CrunchAllStart,
                                  @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfBasePay', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);


        RAISERROR('CostOfSimpleCEs', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfSimpleCEs @AmcosVersionId = @AmcosVersionId,
                                    @CrunchTime = @CrunchAllStart,
                                    @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfSimpleCEs', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        -- !! Other benefit/Misc crunches
        RAISERROR('CostOfFICAandRetiredPay', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfFICAandRetiredPay @AmcosVersionId = @AmcosVersionId,
                                            @CrunchTime = @CrunchAllStart,
                                            @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfFICAandRetiredPay', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfClothing', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfClothing @AmcosVersionId = @AmcosVersionId,
                                   @CrunchTime = @CrunchAllStart,
                                   @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfClothing', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        -- this must be run after all other benefit/misc crunches
        RAISERROR('CostOfMisc', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfMisc @AmcosVersionId = @AmcosVersionId,
                               @CrunchTime = @CrunchAllStart,
                               @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfMisc', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfPCS', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfPCS @AmcosVersionId = @AmcosVersionId,
                              @CrunchTime = @CrunchAllStart,
                              @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfPCS', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);
        -- !! end other benefit/misc crunches

        RAISERROR('CostOfFamilySeparation', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfFamilySeparation @AmcosVersionId = @AmcosVersionId,
                                           @CrunchTime = @CrunchAllStart,
                                           @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfFamilySeparation', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfSeparationPay', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfSeparationPay @AmcosVersionId = @AmcosVersionId,
                                        @CrunchTime = @CrunchAllStart,
                                        @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfSeparationPay', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfSpecialPays', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfSpecialPays @AmcosVersionId = @AmcosVersionId,
                                      @CrunchTime = @CrunchAllStart,
                                      @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfSpecialPays', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfSelectiveRetentionBonus', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfSelectiveRetentionBonus @AmcosVersionId = @AmcosVersionId,
                                                  @CrunchTime = @CrunchAllStart,
                                                  @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfSelectiveRetentionBonus', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfRecruiting', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfRecruiting @AmcosVersionId = @AmcosVersionId,
                                     @CrunchTime = @CrunchAllStart,
                                     @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfRecruiting', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfOfficerAcquisition', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfOfficerAcquisition @AmcosVersionId = @AmcosVersionId,
                                             @CrunchTime = @CrunchAllStart,
                                             @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfOfficerAcquisition', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfBasicAllowanceforSubsistence', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfBasicAllowanceForSubsistence @AmcosVersionId = @AmcosVersionId,
                                                       @CrunchTime = @CrunchAllStart,
                                                       @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfBasicAllowanceforSubsistence', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);


        RAISERROR('CostOfBasicAllowanceforHousingandCOLA', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfBasicAllowanceForHousingAndCola @AmcosVersionId = @AmcosVersionId,
                                                          @CrunchTime = @CrunchAllStart,
                                                          @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfBasicAllowanceforHousingandCOLA', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        RAISERROR('CostOfOverseas', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfOverseas @AmcosVersionId = @AmcosVersionId,
                                   @CrunchTime = @CrunchAllStart,
                                   @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfOverseas', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

        -- because the training crunch takes a really long time to run we may sometimes not want to run it with the other military crunches											
        IF @WhichtoRun NOT IN ( 'Mil_no_training', 'All_no_mil_training' )
        BEGIN
            RAISERROR('CostOfTraining', 0, 1) WITH NOWAIT;
            SET @TimestampStart = GETDATE();
            EXEC crunch.CostOfTraining @AmcosVersionId = @AmcosVersionId,
                                       @CrunchTime = @CrunchAllStart,
                                       @Debug = @Debug_mode;
            SET @TimestampEnd = GETDATE();
            INSERT INTO analysis.CrunchTime
            (
                ObjectName,
                AmcosVersionId,
                StartTime,
                EndTime,
                Debug
            )
            VALUES
            ('crunch.CostOfTraining', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);
        END;

        --compute all the military average costs
        RAISERROR('CostOfMilAverages', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.CostOfMilAverages @AmcosVersionId = @AmcosVersionId, -- int
                                      @Debug = @Debug_mode;              -- bit
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.CostOfMilAverages', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);


        -- once all the military crunches are run we run the 1 active day crunch for Project Manager NG/R
        RAISERROR('1 active day crunch', 0, 1) WITH NOWAIT;
        SET @TimestampStart = GETDATE();
        EXEC crunch.Crunch1ActiveDay @AmcosVersionId = @AmcosVersionId,
                                     @Debug = @Debug_mode;
        SET @TimestampEnd = GETDATE();
        INSERT INTO analysis.CrunchTime
        (
            ObjectName,
            AmcosVersionId,
            StartTime,
            EndTime,
            Debug
        )
        VALUES
        ('crunch.Crunch1ActiveDay', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    END;

    /* Compute D and N series payschedules which rely on SES and GS payschedule data */
    RAISERROR('CrunchPayScheduleDSeriesNSeries', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.CrunchPayScheduleDSeriesNSeries @AmcosVersionId = @AmcosVersionId, -- int
                                                @Debug = @Debug_mode;              -- bit
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.CrunchPayScheduleDSeriesNSeries', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    -- Whenever the crunches are run we need to re-populate the tables that run the drop downs
    RAISERROR('Populate Categories', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC warehouse.PopulateCategory @AmcosVersionId = @AmcosVersionId; -- int

    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('warehouse.PopulateCategory', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    RAISERROR('Populate Category Locations', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC warehouse.PopulateLocationByCategory @AmcosVersionId = @AmcosVersionId; -- int

    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('warehouse.PopulateLocationByCategory', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    RAISERROR('CalculatePayPlanMinMax', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC crunch.CalculatePayPlanMinMax @AmcosVersionId = @AmcosVersionId;
    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('crunch.CalculatePayPlanMinMax', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);


    RAISERROR('PopulateUnitPersonnel', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC warehouse.PopulateUnitPersonnel @CrunchTime = @CrunchAllStart; -- smalldatetime

    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('warehouse.PopulateUnitPersonnel', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);

    RAISERROR('PopulatePPXwalk', 0, 1) WITH NOWAIT;
    SET @TimestampStart = GETDATE();
    EXEC warehouse.PopulatePPXwalk @CategorySubgroupCode = N'',   -- nvarchar(10)
                                   @CrunchTime = @CrunchAllStart, -- smalldatetime
                                   @Debug = NULL;                 -- bit


    SET @TimestampEnd = GETDATE();
    INSERT INTO analysis.CrunchTime
    (
        ObjectName,
        AmcosVersionId,
        StartTime,
        EndTime,
        Debug
    )
    VALUES
    ('warehouse.PopulatePPXwalk', @AmcosVersionId, @TimestampStart, @TimestampEnd, @Debug_mode);


    --Display Crunch results
    SELECT ObjectName,
           CONVERT(CHAR(8), DATEADD(s, DATEDIFF(s, StartTime, EndTime), '1900-1-1'), 8) AS runtime
    FROM analysis.CrunchTime
    WHERE DATEADD(DAY, -1, GETDATE()) < CONVERT(DATE, StartTime)
    ORDER BY StartTime;
END;