CREATE TABLE [dataload].[DoSPerDiem] (
    [LocationCode]        NVARCHAR (50) NOT NULL,
    [SeasonBegin]         NVARCHAR (50) NOT NULL,
    [SeasonEnd]           NVARCHAR (50) NOT NULL,
    [MaximumLodgingRate]  INT           NOT NULL,
    [m_ierate]            INT           NOT NULL,
    [_maximumperdiemrate] INT           NOT NULL,
    [EffectiveDate]       NVARCHAR (50) NOT NULL,
    [AmcosVersionId]      INT           DEFAULT ((202101)) NOT NULL,
    CONSTRAINT [PK_DoSPerDiem] PRIMARY KEY CLUSTERED ([LocationCode] ASC, [SeasonBegin] ASC, [SeasonEnd] ASC, [AmcosVersionId] ASC)
);



