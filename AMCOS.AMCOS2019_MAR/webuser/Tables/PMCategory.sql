CREATE TABLE [webuser].[PMCategory] (
    [UserId]       NVARCHAR (50) NOT NULL,
    [ProjectId]    INT           NOT NULL,
    [CategoryId]   INT           IDENTITY (1, 1) NOT NULL,
    [CategoryName] NVARCHAR (50) NULL,
    CONSTRAINT [PK_Category] PRIMARY KEY CLUSTERED ([UserId] ASC, [ProjectId] ASC, [CategoryId] ASC)
);

