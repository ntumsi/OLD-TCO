CREATE TABLE [lookup].[NonforeignArea] (
    [NonforeignAreaCode] NVARCHAR (10)  NOT NULL,
    [NonforeignAreaName] NVARCHAR (100) NOT NULL,
    [LocalityCode]       NVARCHAR (6)   NULL,
    [AmcosVersionId]     INT            NOT NULL,
    CONSTRAINT [PK_NonforeignArea] PRIMARY KEY CLUSTERED ([NonforeignAreaCode] ASC, [AmcosVersionId] ASC)
);





