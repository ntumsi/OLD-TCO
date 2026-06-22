CREATE TABLE [xwalk].[Costs](
	[PayPlan] [nvarchar](3) NOT NULL,
	[CategoryGroupCode] [nvarchar](7) NOT NULL,
	[CategoryGroupDescription] [nvarchar](max) NULL,
	[CategorySubgroupCode] [nvarchar](7) NOT NULL,
	[CategorySubgroupDescription] [nvarchar](max) NULL,
	[DisplaySubGroup] [nvarchar](max) NULL,
	[LocationId] [int] NOT NULL,
	[LocationName] [nvarchar](max) NULL,
	[DependentStatus] [nvarchar](25) NOT NULL,
	[NumberOfDependents] [int] NOT NULL,
	[GradeLevel] [nvarchar](5) NULL,
	[STRL] [nvarchar](20) NOT NULL,
	[PayType] [nvarchar](16) NOT NULL,
	[Amount] [decimal](16, 2) NULL
);

