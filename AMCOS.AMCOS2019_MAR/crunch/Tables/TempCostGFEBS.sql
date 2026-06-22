CREATE TABLE [crunch].[TempCostGFEBS] (
    [PayPlan]                  NVARCHAR (3)    NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [StateCountry]             NVARCHAR (50)   NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50)   NOT NULL,
    [CostCenterCode]           NVARCHAR (50)   NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Step]                     TINYINT         NULL,
    [PersonnelNumber]          NVARCHAR (10)   NOT NULL,
    [ActualHourlyRate]         NUMERIC (18, 4) NULL,
    [CostElementId]            INT             NOT NULL,
    [Amount]                   NUMERIC (18, 4) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL
);

