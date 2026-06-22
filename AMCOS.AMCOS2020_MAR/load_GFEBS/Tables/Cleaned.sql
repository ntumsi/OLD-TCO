CREATE TABLE [load_GFEBS].[Cleaned] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [StateCountry]             NVARCHAR (50)   NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50)   NOT NULL,
    [CostCenterCode]           NVARCHAR (50)   NOT NULL,
    [Country]                  NVARCHAR (50)   CONSTRAINT [DF_Cleaned_Country] DEFAULT ((-1)) NOT NULL,
    [LocalityCode]             NVARCHAR (6)    CONSTRAINT [DF_Cleaned_LocalityCode] DEFAULT ((-1)) NOT NULL,
    [ActivityTypeCode]         NVARCHAR (50)   NULL,
    [FundsCenterCode]          NVARCHAR (50)   NULL,
    [Fund]                     NVARCHAR (50)   NULL,
    [UICUCForManpower]         NVARCHAR (50)   NULL,
    [PostalCode1]              NVARCHAR (10)   NULL,
    [PostalCode2]              NVARCHAR (10)   NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Step]                     TINYINT         NULL,
    [CivilianTypeCode]         NCHAR (3)       NOT NULL,
    [PayPeriodEndDate]         DATE            NOT NULL,
    [PersonnelNumber]          NVARCHAR (10)   NOT NULL,
    [CostElementCode]          NVARCHAR (50)   NOT NULL,
    [GRC_TypeHourCode]         NCHAR (2)       NOT NULL,
    [AmountPaid]               NUMERIC (18, 4) NULL,
    [PaidHours]                NUMERIC (18, 4) NULL,
    [ActualHourlyRate]         NUMERIC (10, 2) NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Cleaned] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [StateCountry] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [Country] ASC, [LocalityCode] ASC, [GradeLevel] ASC, [PayPeriodEndDate] ASC, [CivilianTypeCode] ASC, [PersonnelNumber] ASC, [CostElementCode] ASC, [GRC_TypeHourCode] ASC, [AmcosVersionId] ASC)
);















