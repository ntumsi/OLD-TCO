
CREATE PROCEDURE [crunch].[CrunchAll]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    EXEC crunch.ArmyBudget @AmcosVersionId = 201802, @Debug = 0;

    EXEC crunch.ArmyBudget @AmcosVersionId = @AmcosVersionId, @Debug = 0;

    EXEC crunch.DMDCPay @AmcosVersionId = 201802, @Debug = 0;

    EXEC crunch.DMDCPay @AmcosVersionId = @AmcosVersionId, @Debug = 0;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'AE',
                                @AmcosVersionId = @AmcosVersionId,
                                @Debug = @Debug;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'AO',
                                @AmcosVersionId = @AmcosVersionId,
                                @Debug = @Debug;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'AWO',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'NE',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf_1ActiveDay @PayPlan = N'NE',
                                           @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'NO',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf_1ActiveDay @PayPlan = N'NO',
                                           @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'NWO',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf_1ActiveDay @PayPlan = N'NWO',
                                           @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'RE',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf_1ActiveDay @PayPlan = N'RE',
                                           @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'RO',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf_1ActiveDay @PayPlan = N'RO',
                                           @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'RWO',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf_1ActiveDay @PayPlan = N'RWO',
                                           @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'GG',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'GL',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'GS',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'SES',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'WG',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'WL',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'WS',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'DB',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'DE',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'DJ',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'DK',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'GP',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'NH',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'NJ',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CrunchPayPlanOf @PayPlan = N'NK',
                                @AmcosVersionId = @AmcosVersionId;

    EXEC crunch.CostOfSpecialPays @AmcosVersionId = @AmcosVersionId,
                                  @Debug = 0;

    EXEC crunch.CostOfSelectiveRetentionBonus @AmcosVersionId = @AmcosVersionId,
                                              @Debug = 0;

    EXEC crunch.CostOfRecruiting @AmcosVersionId = @AmcosVersionId,
                                 @Debug = 0;

    EXEC crunch.CostOfOfficerAcquisition @AmcosVersionId = @AmcosVersionId,
                                         @Debug = 0;

    EXEC crunch.CostOfTraining @AmcosVersionId = @AmcosVersionId, @Debug = 0;

    EXEC crunch.CostOfBasicAllowanceforSubsistence @AmcosVersionId = @AmcosVersionId,
                                                   @Debug = 0;

    EXEC crunch.CostOfBasicAllowanceforHousing @AmcosVersionId = @AmcosVersionId,
                                               @Debug = 0;

    DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());

    EXEC crunch.SumOfAveragesFixAE @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixAO @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixAWO @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixNE @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixNO @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixNWO @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixRE @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixRO @CrunchTime = @CrunchTime;
    EXEC crunch.SumOfAveragesFixRWO @CrunchTime = @CrunchTime;

    EXEC crunch.DeleteCostsWithUnknownStepYOSOnly;
END;