CREATE TABLE [crunch].[ArmyBudgetSingleValues] (
    [ParameterName]  NVARCHAR (50) NOT NULL,
    [Appropriation]  NVARCHAR (10) NOT NULL,
    [FY]             NVARCHAR (4)  NOT NULL,
    [AmcosVersionId] INT           NOT NULL,
    [Amount]         FLOAT (53)    NULL,
    CONSTRAINT [PK_ArmyBudgetSingleValues] PRIMARY KEY CLUSTERED ([ParameterName] ASC, [Appropriation] ASC, [FY] ASC, [AmcosVersionId] ASC)
);

