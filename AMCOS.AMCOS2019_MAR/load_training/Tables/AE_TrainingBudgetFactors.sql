CREATE TABLE [load_training].[AE_TrainingBudgetFactors] (
    [GradeType]  NCHAR (1)  NOT NULL,
    [GradeLevel] INT        NOT NULL,
    [Amount]     FLOAT (53) NOT NULL,
    CONSTRAINT [PK_AE_Training_BudgetFactors] PRIMARY KEY CLUSTERED ([GradeType] ASC, [GradeLevel] ASC)
);

