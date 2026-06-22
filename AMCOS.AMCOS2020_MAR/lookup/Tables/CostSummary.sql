CREATE TABLE [lookup].[CostSummary] (
    [SummaryId]           INT           IDENTITY (1, 1) NOT NULL,
    [PayPlan]             NVARCHAR (3)  NOT NULL,
    [Name]                NVARCHAR (50) NOT NULL,
    [AmcosVersionIdStart] INT           NULL,
    [AmcosVersionIdEnd]   INT           NOT NULL,
    CONSTRAINT [PK_CostSummary] PRIMARY KEY CLUSTERED ([SummaryId] ASC, [AmcosVersionIdEnd] ASC)
);



