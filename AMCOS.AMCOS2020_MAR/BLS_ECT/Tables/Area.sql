CREATE TABLE [BLS_ECT].[Area] (
    [MSACode]       NCHAR (7)    NOT NULL,
    [area_text]     VARCHAR (50) NULL,
    [display_level] VARCHAR (50) NULL,
    [selectable]    VARCHAR (50) NULL,
    [sort_sequence] VARCHAR (50) NULL,
    CONSTRAINT [PK_Area] PRIMARY KEY CLUSTERED ([MSACode] ASC)
);



