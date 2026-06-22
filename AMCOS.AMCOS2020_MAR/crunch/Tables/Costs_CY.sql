CREATE TABLE [crunch].[Costs_CY] (
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (5)    NOT NULL,
    [LocationId]               INT             NOT NULL,
    [CostElementId]            INT             NOT NULL,
    [GradeType]                NVARCHAR (3)    NOT NULL,
    [PayBand]                  TINYINT         NOT NULL,
    [Amount]                   NUMERIC (16, 2) NOT NULL,
    [CrunchTime]               SMALLDATETIME   NULL,
    [AmcosVersionId]           INT             NOT NULL,
    CONSTRAINT [PK_Costs_CY] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [CostElementId] ASC, [LocationId] ASC, [GradeType] ASC, [PayBand] ASC, [AmcosVersionId] ASC)
);

