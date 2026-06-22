CREATE TABLE [webuser].[PMReport] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [UserId]      NVARCHAR (50)  NOT NULL,
    [ProjectId]   INT            NOT NULL,
    [CategoryId]  INT            NOT NULL,
    [PayPlan]     NVARCHAR (3)   NOT NULL,
    [SummaryName] NVARCHAR (100) NOT NULL,
    CONSTRAINT [PK_PMReport] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_PMReport]
    ON [webuser].[PMReport]([UserId] ASC, [ProjectId] ASC, [CategoryId] ASC, [PayPlan] ASC)
    INCLUDE([SummaryName]);

