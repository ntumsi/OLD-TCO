CREATE TABLE [webuser].[PMCategorySkillInventory] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [UserId]     NVARCHAR (50) NOT NULL,
    [ProjectId]  INT           NOT NULL,
    [CategoryId] INT           NOT NULL,
    [SkillId]    INT           NOT NULL,
    [Year]       INT           NOT NULL,
    [Amount]     INT           NOT NULL,
    CONSTRAINT [PK_PMCategorySkillInventory] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_PMCategorySkillInventory]
    ON [webuser].[PMCategorySkillInventory]([UserId] ASC, [ProjectId] ASC, [CategoryId] ASC, [SkillId] ASC, [Year] ASC)
    INCLUDE([Amount]);

