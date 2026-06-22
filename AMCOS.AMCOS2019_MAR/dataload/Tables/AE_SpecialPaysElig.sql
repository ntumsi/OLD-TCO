CREATE TABLE [dataload].[AE_SpecialPaysElig] (
    [MOS]       NVARCHAR (3)   NOT NULL,
    [OCONUS]    NUMERIC (9, 4) NULL,
    [Diving]    FLOAT (53)     NULL,
    [iLanguage] FLOAT (53)     NULL,
    [Special]   FLOAT (53)     NULL,
    CONSTRAINT [PK_AE_SpecPaysElig] PRIMARY KEY CLUSTERED ([MOS] ASC)
);

