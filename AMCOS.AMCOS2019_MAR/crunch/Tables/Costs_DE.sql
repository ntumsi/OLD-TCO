CREATE TABLE [crunch].[Costs_DE] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [StateCountry]             NVARCHAR (50)   NOT NULL,
    [FunctionalAreaCode]       NVARCHAR (50)   NOT NULL,
    [CostCenterCode]           NVARCHAR (50)   NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [PersonnelNumber]          NVARCHAR (10)   NOT NULL,
    [Amount]                   NUMERIC (18, 4) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    CONSTRAINT [PK_Costs_DE] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [StateCountry] ASC, [FunctionalAreaCode] ASC, [CostCenterCode] ASC, [CostElementId] ASC, [GradeLevel] ASC, [PersonnelNumber] ASC),
    CONSTRAINT [FK_Costs_DE_GFEBS_CostCenter] FOREIGN KEY ([CostCenterCode]) REFERENCES [lookup].[GFEBS_CostCenter] ([CostCenterCode]),
    CONSTRAINT [FK_Costs_DE_GFEBS_FunctionalArea] FOREIGN KEY ([FunctionalAreaCode]) REFERENCES [lookup].[GFEBS_FunctionalArea] ([FunctionalAreaCode])
);





