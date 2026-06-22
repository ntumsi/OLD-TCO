CREATE TABLE [load_GFEBS].[Processed] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [StateCountry]             NVARCHAR (50)   NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50)   NOT NULL,
    [CostCenterCode]           NVARCHAR (50)   NOT NULL,
    [ActivityTypeCode]         NVARCHAR (50)   NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Step]                     TINYINT         NULL,
    [PayPeriodEndDate]         DATE            NOT NULL,
    [PersonnelNumber]          NVARCHAR (10)   NOT NULL,
    [CostElementCode]          NVARCHAR (50)   NOT NULL,
    [PostalCode1]              NVARCHAR (10)   NULL,
    [AmountPaid]               NUMERIC (18, 4) NULL,
    [PaidHours]                NUMERIC (18, 4) NULL,
    [ActualHourlyRate]         NUMERIC (10, 2) NULL,
    [LocalityPaymentAmount]    NUMERIC (18, 4) NULL,
    CONSTRAINT [PK_Processed] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [StateCountry] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [ActivityTypeCode] ASC, [GradeLevel] ASC, [PayPeriodEndDate] ASC, [PersonnelNumber] ASC, [CostElementCode] ASC)
);



