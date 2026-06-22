CREATE TABLE [dataload].[DoDOCONUSPerDiem_Raw](
	[StateCounty] [nvarchar](100) NOT NULL,
	[Location] [nvarchar](200) NOT NULL,
	[SeasonBegin] [nvarchar](50) NOT NULL,
	[SeasonEnd] [nvarchar](5) NOT NULL,
	[Lodging] [int] NULL,
	[LocalMealRate] [int] NULL,
	[ProportionalMealRate] [int] NULL,
	[LocalIncidental] [int] NULL,
	[MaximumPerDiem] [int] NULL,
	[EffectiveDate] [date] NOT NULL,
	[AmcosVersionId] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[StateCounty] ASC,
	[Location] ASC,
	[SeasonBegin] ASC,
	[SeasonEnd] ASC,
	[EffectiveDate] ASC,
	[AmcosVersionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
