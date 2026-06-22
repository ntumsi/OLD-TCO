CREATE TABLE [webuser].[PMCategorySkillInventory] (
    [InventoryId] INT IDENTITY (1, 1) NOT NULL,
    [SkillId]     INT NOT NULL,
    [Year]        INT NOT NULL,
    [Amount]      INT NOT NULL,
    CONSTRAINT [PK_PMCategorySkillInventory] PRIMARY KEY CLUSTERED ([InventoryId] ASC),
    CONSTRAINT [FK_PMCategorySkillInventory_PMCategorySkill] FOREIGN KEY ([SkillId]) REFERENCES [webuser].[PMCategorySkill] ([SkillId])
);








GO
CREATE NONCLUSTERED INDEX [IX_PMCategorySkillInventory_AddUnit]
    ON [webuser].[PMCategorySkillInventory]([SkillId] ASC, [Year] ASC);

