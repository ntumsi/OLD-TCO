CREATE TABLE [dataload].[ArmyBudgetManualValues] (
    [PayType]        NVARCHAR (50)   NOT NULL,
    [GradeType]      NVARCHAR (1)    NOT NULL,
    [GradeLevel]     INT             NOT NULL,
    [Amount]         NUMERIC (18, 2) NOT NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_ArmyBudgetManualValues] PRIMARY KEY CLUSTERED ([GradeLevel] ASC, [PayType] ASC, [GradeType] ASC, [AmcosVersionId] ASC)
);

