CREATE TABLE [analysis].[CrunchTime] (
    [ObjectName]     NVARCHAR (75) NOT NULL,
    [AmcosVersionId] INT           NOT NULL,
    [StartTime]      DATETIME      NOT NULL,
    [EndTime]        DATETIME      NOT NULL,
    [Debug]          BIT           DEFAULT ((0)) NOT NULL
);

