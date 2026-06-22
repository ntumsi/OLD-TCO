CREATE TABLE [dataload].[MilitaryEnlistmentBonusCap] (
    [MOS]            NVARCHAR (3) NOT NULL,
    [Cap]            FLOAT (53)   NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_MilitaryEnlistmentBonusCap] PRIMARY KEY CLUSTERED ([MOS] ASC, [AmcosVersionId] ASC)
);

