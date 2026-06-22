CREATE TABLE [load_GFEBS].[Raw] (
    [SourceSystem]       NVARCHAR (50)   NULL,
    [PayPlan]            NVARCHAR (50)   NULL,
    [JobSeries]          NVARCHAR (50)   NULL,
    [StateCountry]       NVARCHAR (50)   NULL,
    [FunctionalAreaCode] NVARCHAR (50)   NULL,
    [FunctionalAreaText] NVARCHAR (250)  NULL,
    [CostCenterCode]     NVARCHAR (50)   NULL,
    [CostCenterText]     NVARCHAR (250)  NULL,
    [ActivityTypeCode]   NVARCHAR (50)   NULL,
    [ActivityTypeText]   NVARCHAR (250)  NULL,
    [FundsCenterCode]    NVARCHAR (50)   NULL,
    [FundsCenterText]    NVARCHAR (250)  NULL,
    [Fund]               NVARCHAR (50)   NULL,
    [UICUCForManpower]   NVARCHAR (50)   NULL,
    [Grade]              NVARCHAR (50)   NULL,
    [CivilianTypeCode]   NVARCHAR (50)   NULL,
    [CivilianTypeText]   NVARCHAR (50)   NULL,
    [TempPositionCode]   NVARCHAR (50)   NULL,
    [WorkScheduleCode]   NVARCHAR (50)   NULL,
    [WorkScheduleText]   NVARCHAR (50)   NULL,
    [PersonnelNumber]    NVARCHAR (50)   NULL,
    [TDA_TOEParagraph]   NVARCHAR (50)   NULL,
    [PostalCode1]        NVARCHAR (50)   NULL,
    [PostalCode2]        NVARCHAR (50)   NULL,
    [CostElementCode]    NVARCHAR (50)   NULL,
    [CostElementText]    NVARCHAR (50)   NULL,
    [PayPeriodEndDate]   BIGINT          NULL,
    [FiscalYear_Period]  NVARCHAR (50)   NULL,
    [GRC_TypeHourCode]   NVARCHAR (50)   NULL,
    [AmountPaid]         NUMERIC (18, 4) NULL,
    [PaidHours]          NUMERIC (18, 4) NULL,
    [ActualHourlyRate]   NUMERIC (10, 2) NULL
);




GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20180311-173713]
    ON [load_GFEBS].[Raw]([PayPeriodEndDate] ASC, [StateCountry] ASC, [PayPlan] ASC, [Grade] ASC, [JobSeries] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [PersonnelNumber] ASC);

