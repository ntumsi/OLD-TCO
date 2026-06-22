CREATE TABLE [dataload].[RE_NPSAccessions] (
    [MOS]                 NVARCHAR (3) NOT NULL,
    [NPS_Accessions_E1_3] INT          NULL,
    [NPS_HQ]              FLOAT (53)   NULL,
    CONSTRAINT [PK_RE_NPS_Accessions] PRIMARY KEY CLUSTERED ([MOS] ASC),
    CONSTRAINT [FK_RE_NPSAccessions_MOS] FOREIGN KEY ([MOS]) REFERENCES [lookup].[MOS] ([MOS])
);

