CREATE TABLE [crunch].[Costs_G_Overseas] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (5)    NOT NULL,
    [CareerProgramNumber]      NCHAR (2)       NOT NULL,
    [LocationId]               INT             NOT NULL,
    [NumberOfDependents]       INT             NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeType]                NVARCHAR (3)    NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Amount]                   NUMERIC (16, 2) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Costs_G_Overseas] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [CareerProgramNumber] ASC, [NumberOfDependents] ASC, [CostElementId] ASC, [LocationId] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);

