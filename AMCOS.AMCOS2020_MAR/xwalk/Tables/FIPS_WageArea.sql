CREATE TABLE [xwalk].[FIPS_WageArea] (
    [FundType]       NVARCHAR (3) NOT NULL,
    [Wage_area]      NVARCHAR (3) NOT NULL,
    [Wage_schedule]  NVARCHAR (4) NOT NULL,
    [FIPS]           NVARCHAR (5) NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_FIPS_WageArea] PRIMARY KEY CLUSTERED ([FundType] ASC, [Wage_area] ASC, [Wage_schedule] ASC, [FIPS] ASC, [AmcosVersionId] ASC)
);







