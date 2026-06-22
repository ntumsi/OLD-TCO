CREATE TABLE [webuser].[User_SummaryElements] (
    [ID]            INT           IDENTITY (1, 1) NOT NULL,
    [UserId]        NVARCHAR (50) NOT NULL,
    [ProjectId]     INT           NOT NULL,
    [SummaryId]     INT           NOT NULL,
    [CostElementId] INT           NOT NULL,
    CONSTRAINT [PK_User_SummaryElements] PRIMARY KEY CLUSTERED ([UserId] ASC, [ProjectId] ASC, [SummaryId] ASC, [CostElementId] ASC)
);

