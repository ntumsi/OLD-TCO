CREATE TABLE [load_GFEBS].[Raw] (
    [Id]                 INT            IDENTITY (1, 1) NOT NULL,
    [SourceSystem]       NVARCHAR (50)  NULL,
    [PayPlan]            NVARCHAR (50)  NULL,
    [JobSeries]          NVARCHAR (50)  NULL,
    [StateCountry]       NVARCHAR (50)  NULL,
    [FunctionalAreaCode] NVARCHAR (50)  NULL,
    [FunctionalAreaText] NVARCHAR (250) NULL,
    [CostCenterCode]     NVARCHAR (50)  NULL,
    [CostCenterText]     NVARCHAR (250) NULL,
    [ActivityTypeCode]   NVARCHAR (50)  NULL,
    [ActivityTypeText]   NVARCHAR (250) NULL,
    [FundsCenterCode]    NVARCHAR (50)  NULL,
    [FundsCenterText]    NVARCHAR (250) NULL,
    [Fund]               NVARCHAR (50)  NULL,
    [UICUCForManpower]   NVARCHAR (50)  NULL,
    [Grade]              NVARCHAR (50)  NULL,
    [CivilianTypeCode]   NVARCHAR (50)  NULL,
    [CivilianTypeText]   NVARCHAR (50)  NULL,
    [TempPositionCode]   NVARCHAR (50)  NULL,
    [WorkScheduleCode]   NVARCHAR (50)  NULL,
    [WorkScheduleText]   NVARCHAR (50)  NULL,
    [PersonnelNumber]    NVARCHAR (50)  NULL,
    [TDA_TOEParagraph]   NVARCHAR (50)  NULL,
    [PostalCode1]        NVARCHAR (50)  NULL,
    [PostalCode2]        NVARCHAR (50)  NULL,
    [CostElementCode]    NVARCHAR (50)  NULL,
    [CostElementText]    NVARCHAR (50)  NULL,
    [PayPeriodEndDate]   NVARCHAR (50)  NULL,
    [FiscalYear_Period]  NVARCHAR (50)  NULL,
    [GRC_TypeHourCode]   NVARCHAR (50)  NULL,
    [AmountPaid]         NVARCHAR (150) NULL,
    [PaidHours]          NVARCHAR (150) NULL,
    [ActualHourlyRate]   NVARCHAR (150) NULL,
    [AmcosVersionId]     INT            NULL,
    CONSTRAINT [PK_Raw] PRIMARY KEY CLUSTERED ([Id] ASC)
);






GO
ADD SENSITIVITY CLASSIFICATION TO
    [load_GFEBS].[Raw].[PersonnelNumber]
    WITH (LABEL = 'Confidential', LABEL_ID = '331f0b13-76b5-2f1b-a77b-def5a73c73c2', INFORMATION_TYPE = 'Name', INFORMATION_TYPE_ID = '57845286-7598-22f5-9659-15b24aeb125e', RANK = MEDIUM);




















GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20180311-173713]
    ON [load_GFEBS].[Raw]([PayPeriodEndDate] ASC, [StateCountry] ASC, [PayPlan] ASC, [Grade] ASC, [JobSeries] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [PersonnelNumber] ASC);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20191104-124904]
    ON [load_GFEBS].[Raw]([PersonnelNumber] ASC);

