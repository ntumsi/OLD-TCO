CREATE TABLE [load_GFEBS].[Rejected] (
    [Id]                       INT            IDENTITY (1, 1) NOT NULL,
    [SourceSystem]             NVARCHAR (50)  NULL,
    [PayPlan]                  NVARCHAR (50)  NULL,
    [JobSeries]                NVARCHAR (50)  NULL,
    [StateCountry]             NVARCHAR (50)  NULL,
    [FunctionalAreaCode]       NVARCHAR (50)  NULL,
    [FunctionalAreaText]       NVARCHAR (250) NULL,
    [CostCenterCode]           NVARCHAR (50)  NULL,
    [CostCenterText]           NVARCHAR (250) NULL,
    [ActivityTypeCode]         NVARCHAR (50)  NULL,
    [ActivityTypeText]         NVARCHAR (250) NULL,
    [FundsCenterCode]          NVARCHAR (50)  NULL,
    [FundsCenterText]          NVARCHAR (250) NULL,
    [Fund]                     NVARCHAR (50)  NULL,
    [UICUCForManpower]         NVARCHAR (50)  NULL,
    [Grade]                    NVARCHAR (50)  NULL,
    [CivilianTypeCode]         NVARCHAR (50)  NULL,
    [CivilianTypeText]         NVARCHAR (50)  NULL,
    [TempPositionCode]         NVARCHAR (50)  NULL,
    [WorkScheduleCode]         NVARCHAR (50)  NULL,
    [WorkScheduleText]         NVARCHAR (50)  NULL,
    [PersonnelNumber]          NVARCHAR (50)  NULL,
    [TDA_TOEParagraph]         NVARCHAR (50)  NULL,
    [PostalCode1]              NVARCHAR (50)  NULL,
    [PostalCode2]              NVARCHAR (50)  NULL,
    [CostElementCode]          NVARCHAR (50)  NULL,
    [CostElementText]          NVARCHAR (50)  NULL,
    [PayPeriodEndDate]         NVARCHAR (50)  NULL,
    [FiscalYear_Period]        NVARCHAR (50)  NULL,
    [GRC_TypeHourCode]         NVARCHAR (50)  NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)   NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)   NULL,
    [PayBand]                  NVARCHAR (2)   NULL,
    [TypeHourCode]             NVARCHAR (2)   NULL,
    [UicLocationZipCode5]      NVARCHAR (5)   NULL,
    [UicLocationZip]           NVARCHAR (10)  NULL,
    [UicLocationCountry]       NVARCHAR (50)  NULL,
    [AmountPaid]               NVARCHAR (150) NULL,
    [PaidHours]                NVARCHAR (150) NULL,
    [ActualHourlyRate]         NVARCHAR (150) NULL,
    [AmcosVersionId]           INT            NULL,
    [RejectionReason]          NVARCHAR (250) NULL,
    CONSTRAINT [PK_Rejected] PRIMARY KEY CLUSTERED ([Id] ASC)
);









