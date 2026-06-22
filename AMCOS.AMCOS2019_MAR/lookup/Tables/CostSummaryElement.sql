CREATE TABLE [lookup].[CostSummaryElement] (
    [SummaryId]     INT NOT NULL,
    [CostElementId] INT NOT NULL,
    CONSTRAINT [PK_SummaryElements] PRIMARY KEY CLUSTERED ([SummaryId] ASC, [CostElementId] ASC),
    CONSTRAINT [FK_CostSummaryElement_CostElement] FOREIGN KEY ([CostElementId]) REFERENCES [lookup].[CostElement] ([CostElementId]),
    CONSTRAINT [FK_CostSummaryElement_CostSummary] FOREIGN KEY ([SummaryId]) REFERENCES [lookup].[CostSummary] ([SummaryId])
);

