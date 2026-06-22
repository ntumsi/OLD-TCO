CREATE TABLE [lookup].[WOMOS] (
    [WOMOS]               NVARCHAR (4)   NOT NULL,
    [Description]         NVARCHAR (250) NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_WOMOS] PRIMARY KEY CLUSTERED ([WOMOS] ASC, [AmcosVersionIdEnd] ASC)
);



