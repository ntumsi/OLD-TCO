CREATE TABLE [warehouse].[Location] (
    [LocationId]       INT               IDENTITY (1, 1) NOT NULL,
    [SourceSystemCode] NVARCHAR (100)    NULL,
    [LocationType]     NVARCHAR (100)    NULL,
    [DisplayName]      NVARCHAR (250)    NULL,
    [Geometry]         [sys].[geometry]  NULL,
    [Coordinates]      [sys].[geography] NULL,
    [AmcosVersionId] [int] NULL,
    CONSTRAINT [PK_Location] PRIMARY KEY CLUSTERED ([LocationId] ASC)
);









