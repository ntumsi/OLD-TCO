CREATE TABLE [load_inventory].[Rejected](
	[Id] [INT] IDENTITY(1,1) NOT NULL,
	[PayPlan] [NVARCHAR](3) NULL,
	[CategoryGroup] [NVARCHAR](50) NULL,
	[CategorySubgroup] [NVARCHAR](50) NULL,
	[Quality] [TINYINT] NULL,
	[GradeType] [NVARCHAR](4) NULL,
	[Grade] [NVARCHAR](2) NULL,
	[Step] [NVARCHAR](2) NULL,
	[YOS] [TINYINT] NULL,
	[Count] [INT] NULL,
	[AmcosVersionId] [INT] NULL,
	[CivType] [NVARCHAR](4) NULL,
	[UIC] [NCHAR](8) NULL,
	[DutyLocationCode] [NCHAR](9) NULL,
	[RCC] [NCHAR](1) NULL,
	[RejectReason] [NVARCHAR](MAX) NULL,
 CONSTRAINT [PK_Rejected_1] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
));







