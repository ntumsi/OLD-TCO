CREATE TABLE [PaySchedule].[PaySchedule_Wage](
	[PayPlan] [NVARCHAR](3) NOT NULL,
	[FundType] [NVARCHAR](3) NOT NULL,
	[AreaCode] [NVARCHAR](4) NOT NULL,
	[GradeType] [NVARCHAR](3) NOT NULL,
	[GradeLevel] [TINYINT] NOT NULL,
	[Step] [TINYINT] NOT NULL,
	[RateType] [NVARCHAR](25) NOT NULL,
	[DateEffective] [DATE] NOT NULL,
	[Rate] [NUMERIC](18, 2) NOT NULL,
	[LocationId] [INT] NOT NULL,
	[AmcosVersionId] [INT] NOT NULL,
	[WageArea] [NVARCHAR](3) NULL,
 CONSTRAINT [PK_PaySchedule_Wage] PRIMARY KEY CLUSTERED 
(
	[PayPlan] ASC,
	[FundType] ASC,
	[AreaCode] ASC,
	[GradeType] ASC,
	[GradeLevel] ASC,
	[Step] ASC,
	[RateType] ASC,
	[DateEffective] ASC,
	[LocationId] ASC,
	[AmcosVersionId] ASC
));