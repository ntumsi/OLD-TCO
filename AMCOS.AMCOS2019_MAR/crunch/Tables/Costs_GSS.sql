CREATE TABLE [crunch].[Costs_GSS] (
    [PayPlan]                  NVARCHAR (3)  NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)  NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)  NOT NULL,
    [SpecialRateTableNumber]   NVARCHAR (4)  NOT NULL,
    [CostElementId]            INT           NOT NULL,
    [GradeType]                NVARCHAR (3)  NOT NULL,
    [GradeLevel]               TINYINT       NOT NULL,
    [Amount]                   FLOAT (53)    NOT NULL,
    [CrunchTime]               SMALLDATETIME NULL,
    CONSTRAINT [PK_Costs_GSS] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [SpecialRateTableNumber] ASC, [CostElementId] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

