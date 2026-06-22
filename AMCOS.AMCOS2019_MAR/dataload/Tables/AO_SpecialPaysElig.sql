CREATE TABLE [dataload].[AO_SpecialPaysElig] (
    [CMF]      NCHAR (2)      NOT NULL,
    [OCONUS]   NUMERIC (9, 4) NULL,
    [Medical]  FLOAT (53)     NULL,
    [Dental]   FLOAT (53)     NULL,
    [Vet]      FLOAT (53)     NULL,
    [Aviation] FLOAT (53)     NULL,
    [Dive]     FLOAT (53)     NULL,
    CONSTRAINT [PK_AO_SpecPays_Elig] PRIMARY KEY CLUSTERED ([CMF] ASC)
);

