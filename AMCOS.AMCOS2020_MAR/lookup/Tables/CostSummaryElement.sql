CREATE TABLE [lookup].[CostSummaryElement] (
    [SummaryId]           INT NOT NULL,
    [CostElementId]       INT NOT NULL,
    [AmcosVersionIdStart] INT NULL,
    [AmcosVersionIdEnd]   INT NOT NULL,
    CONSTRAINT [PK_SummaryElements] PRIMARY KEY CLUSTERED ([SummaryId] ASC, [CostElementId] ASC, [AmcosVersionIdEnd] ASC)
);



