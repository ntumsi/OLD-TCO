CREATE TABLE [crunch].[InventoryWASS]
(
[PayPlan] [nvarchar] (3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OccupationalGroupNumber] [nvarchar] (4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OccupationalSeriesNumber] [nvarchar] (4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GradeType] [nvarchar] (3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GradeLevel] [tinyint] NOT NULL,
[Step] [int] NOT NULL,
[LocationId] [int] NOT NULL,
[Inventory] [int] NOT NULL,
[AveragePay] [numeric] (18, 2) NULL,
[AmcosVersionId] [int] NOT NULL
)
