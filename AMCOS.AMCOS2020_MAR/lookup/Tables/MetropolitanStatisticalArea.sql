CREATE TABLE [lookup].[MetropolitanStatisticalArea]
(
[MSACode] [nvarchar] (7) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MSAName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AmcosVersionIdStart] [int] NULL,
[AmcosVersionIdEnd] [int] NULL,
[AmcosVersionId] [int] NOT NULL,
CONSTRAINT [PK_MetropolitanStatisticalArea] PRIMARY KEY CLUSTERED ([MSACode], [AmcosVersionId])

);









