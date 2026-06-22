CREATE TABLE [dataload].[MilitarySRBCaps] (
    [MOS]            NVARCHAR (3) NOT NULL,
    [GradeLevel]     NVARCHAR (2) NOT NULL,
    [Tier]           INT          NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    [BonusCap]       FLOAT (53)   NULL,
    CONSTRAINT [PK_MilitarySRBCaps] PRIMARY KEY CLUSTERED ([MOS] ASC, [GradeLevel] ASC, [Tier] ASC, [AmcosVersionId] ASC)
);



