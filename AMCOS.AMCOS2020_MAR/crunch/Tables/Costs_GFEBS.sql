CREATE TABLE [crunch].[Costs_GFEBS] (
    [PayPlan]                  NVARCHAR (2)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)    NOT NULL,
    [CareerProgramNumber]      NCHAR (2)       NOT NULL,
    [LocalityCode]             NVARCHAR (6)    NOT NULL,
    [Country]                  NVARCHAR (50)   NOT NULL,
    [LocationId]               INT             NOT NULL,
    [STRL]                     NVARCHAR (20)   NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeLevel]               TINYINT         NOT NULL,
    [Amount]                   NUMERIC (16, 2) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Costs_GFEBS] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [CareerProgramNumber] ASC, [CostElementId] ASC, [GradeLevel] ASC, [Country] ASC, [LocalityCode] ASC, [LocationId] ASC, [STRL] ASC, [AmcosVersionId] ASC)
);




















GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Costs_GFEBS_Unique]
    ON [crunch].[Costs_GFEBS]([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [CareerProgramNumber] ASC, [LocalityCode] ASC, [Country] ASC, [LocationId] ASC, [STRL] ASC, [GradeLevel] ASC, [CostElementId] ASC, [AmcosVersionId] ASC)
    INCLUDE([Amount], [CrunchTime]);



