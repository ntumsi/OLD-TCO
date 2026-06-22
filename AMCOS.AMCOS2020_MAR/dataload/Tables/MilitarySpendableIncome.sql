CREATE TABLE [dataload].[MilitarySpendableIncome] (
    [LowerLimit]         INT NOT NULL,
    [UpperLimit]         INT NOT NULL,
    [NumberOfDependents] INT NOT NULL,
    [SpendableIncome]    INT NOT NULL,
    [AmcosVersionId]     INT NOT NULL,
    CONSTRAINT [PK_MilitarySpendableIncome] PRIMARY KEY CLUSTERED ([LowerLimit] ASC, [UpperLimit] ASC, [NumberOfDependents] ASC, [AmcosVersionId] ASC)
);





