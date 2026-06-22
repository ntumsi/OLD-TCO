CREATE TABLE [load_training].[AO_TrainingBudgetFactors] (
    [GradeType]  NCHAR (1)  NOT NULL,
    [GradeLevel] INT        NOT NULL,
    [Amount]     FLOAT (53) NOT NULL,
    CONSTRAINT [PK_AO_TrainingBudgetFactors] PRIMARY KEY CLUSTERED ([GradeType] ASC, [GradeLevel] ASC)
);

