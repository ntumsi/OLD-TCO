CREATE TABLE [crunch].[Costs_SES] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [LocationId]               INT             NOT NULL,
    [NumberOfDependents]       INT             NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeType]                NVARCHAR (3)    NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Amount]                   NUMERIC (16, 2) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Costs_SES] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [LocationId] ASC, [NumberOfDependents] ASC, [AmcosVersionId] ASC)
);









