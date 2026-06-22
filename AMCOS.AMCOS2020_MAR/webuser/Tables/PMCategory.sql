CREATE TABLE [webuser].[PMCategory] (
    [CategoryId]   INT           IDENTITY (1, 1) NOT NULL,
    [ProjectId]    INT           NOT NULL,
    [CategoryName] NVARCHAR (50) NULL,
    CONSTRAINT [PK_PMCategory] PRIMARY KEY CLUSTERED ([CategoryId] ASC),
    CONSTRAINT [FK_PMCategory_PMProject] FOREIGN KEY ([ProjectId]) REFERENCES [webuser].[PMProject] ([ProjectId])
);





