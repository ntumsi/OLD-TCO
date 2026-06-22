CREATE TABLE [lookup].[MOS] (
    [MOS]             NVARCHAR (3)    NOT NULL,
    [Description]     NVARCHAR (250)  NULL,
    [CONUSTourLength] NUMERIC (18, 2) NULL,
    [Parent_MOS]      NVARCHAR (3)    NULL,
    CONSTRAINT [PK_MOS] PRIMARY KEY CLUSTERED ([MOS] ASC)
);







