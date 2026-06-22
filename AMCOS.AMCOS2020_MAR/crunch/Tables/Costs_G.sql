CREATE TABLE [crunch].[Costs_G] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (5)    NOT NULL,
    [CareerProgramNumber]      NCHAR (2)       NOT NULL,
    [LocationId]               INT             NOT NULL,
    [NumberOfDependents]       INT             CONSTRAINT [DF_Costs_G_NumberOfDependents] DEFAULT ((-1)) NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeType]                NVARCHAR (3)    NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Amount]                   NUMERIC (16, 2) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Costs_G] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [CareerProgramNumber] ASC, [LocationId] ASC, [NumberOfDependents] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);






















GO


