CREATE TABLE [webuser].[User_Summaries] (
    [SummaryId]   INT           IDENTITY (1, 1) NOT NULL,
    [UserId]      NVARCHAR (50) NOT NULL,
    [ProjectId]   INT           NOT NULL,
    [PayPlan]     NVARCHAR (3)  NOT NULL,
    [Type]        NVARCHAR (50) NULL,
    [SummaryName] NVARCHAR (50) NOT NULL,
    [InReport]    INT           NOT NULL,
    CONSTRAINT [PK_User_Summaries] PRIMARY KEY CLUSTERED ([SummaryId] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_User_Summaries]
    ON [webuser].[User_Summaries]([UserId] ASC, [ProjectId] ASC, [PayPlan] ASC, [SummaryName] ASC);

