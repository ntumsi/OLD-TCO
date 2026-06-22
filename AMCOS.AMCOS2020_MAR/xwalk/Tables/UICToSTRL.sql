CREATE TABLE [xwalk].[UICToSTRL] (
    [UIC]                 NVARCHAR (6)   NOT NULL,
    [STRL]                NVARCHAR (20)  NULL,
    [STRLName]            NVARCHAR (200) NULL,
    [AmcosVersionIdStart] INT            NOT NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_UICToSTRL] PRIMARY KEY CLUSTERED ([UIC] ASC, [AmcosVersionIdStart] ASC, [AmcosVersionIdEnd] ASC)
);



