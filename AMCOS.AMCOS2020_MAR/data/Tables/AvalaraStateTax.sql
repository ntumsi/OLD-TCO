CREATE TABLE [data].[AvalaraStateTax](
	[State] [nvarchar](2) NOT NULL,
	[ZipCode] [nvarchar](5) NOT NULL,
	[TaxRegionName] [nvarchar](255) NOT NULL,
	[StateRate] [numeric](8, 6) NOT NULL,
	[EstimatedCombinedRate] [numeric](8, 6) NOT NULL,
	[EstimatedCountyRate] [numeric](8, 6) NOT NULL,
	[EstimatedCityRate] [numeric](8, 6) NOT NULL,
	[EstimatedSpecialRate] [numeric](8, 6) NOT NULL,
	[RiskLevel] [int] NOT NULL,
	[AmcosVersionIdStart] [int] NOT NULL,
	[AmcosVersionIdEnd] [int] NOT NULL,
 CONSTRAINT [PK_AvalaraStateTax] PRIMARY KEY CLUSTERED 
(
	[State] ASC,
	[ZipCode] ASC,
	[AmcosVersionIdEnd] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [data].[AvalaraStateTax] ADD  CONSTRAINT [DF_AvalaraStateTax_AmcosVersionIdStart]  DEFAULT ((1)) FOR [AmcosVersionIdStart]
GO

ALTER TABLE [data].[AvalaraStateTax] ADD  CONSTRAINT [DF_AvalaraStateTax_AmcosVersionIdEnd]  DEFAULT ((999999)) FOR [AmcosVersionIdEnd]
GO