CREATE TABLE [load_GFEBS].[Cleaned] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [StateCountry]             NVARCHAR (50)   NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50)   NOT NULL,
    [CostCenterCode]           NVARCHAR (50)   NOT NULL,
    [ActivityTypeCode]         NVARCHAR (50)   NOT NULL,
    [FundsCenterCode]          NVARCHAR (50)   NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Step]                     TINYINT         NULL,
    [PayPeriodEndDate]         DATE            NOT NULL,
    [PersonnelNumber]          NVARCHAR (10)   NOT NULL,
    [CostElementCode]          NVARCHAR (50)   NOT NULL,
    [PostalCode1]              NVARCHAR (10)   NULL,
    [PostalCode2]              NVARCHAR (10)   NULL,
    [GRC_TypeHourCode]         NVARCHAR (50)   NULL,
    [AmountPaid]               NUMERIC (18, 4) NULL,
    [PaidHours]                NUMERIC (18, 4) NULL,
    [ActualHourlyRate]         NUMERIC (10, 2) NULL
);



