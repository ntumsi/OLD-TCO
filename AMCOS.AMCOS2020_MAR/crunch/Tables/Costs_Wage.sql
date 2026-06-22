CREATE TABLE [crunch].[Costs_Wage] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [WageArea]                 NVARCHAR (3)    NOT NULL,
    [WageSchedule]             NVARCHAR (4)    NOT NULL,
    [LocationId]               INT             NOT NULL,
    [NumberOfDependents]       INT             NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeType]                NVARCHAR (3)    NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Amount]                   NUMERIC (16, 2) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Costs_Wage] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [WageArea] ASC, [WageSchedule] ASC, [LocationId] ASC, [NumberOfDependents] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);


















GO
CREATE NONCLUSTERED INDEX [IX_CostsWage_AddUnit]
    ON [crunch].[Costs_Wage]([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [LocationId] ASC, [NumberOfDependents] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
    INCLUDE([CostElementId]);

