CREATE TABLE [crunch].[InventoryDMDC]
(
[CivType] [varchar] (3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PayPlan] [varchar] (3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CategoryGroup] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CategorySubgroup] [nvarchar] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GradeType] [varchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GradeLevel] [tinyint] NOT NULL,
[Step] [varchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LocationId] [int] NOT NULL,
[YOS] [smallint] NOT NULL,
[Inventory] [int] NOT NULL,
[AmcosVersionId] [int] NOT NULL, 
    [ZIP] VARCHAR(5) NULL, 
    [DutyStationZIP] VARCHAR(5) NULL
)

