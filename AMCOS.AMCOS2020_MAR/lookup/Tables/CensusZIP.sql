CREATE TABLE [lookup].[CensusZIP] (
    [ZCTA5CE10]           NVARCHAR (50)    NOT NULL,
    [GEOID10]             NVARCHAR (50)    NULL,
    [CLASSFP10]           NVARCHAR (50)    NULL,
    [MTFCC10]             NVARCHAR (50)    NULL,
    [FUNCSTAT10]          NVARCHAR (50)    NULL,
    [ALAND10]             NVARCHAR (50)    NULL,
    [AWATER10]            NVARCHAR (50)    NULL,
    [INTPTLAT10]          NVARCHAR (50)    NULL,
    [INTPTLON10]          NVARCHAR (50)    NULL,
    [Boundary]            [sys].[geometry] NULL,
    [AmcosVersionIdStart] INT              NULL,
    [AmcosVersionIdEnd]   INT              NOT NULL,
    CONSTRAINT [PK_CensusZIP] PRIMARY KEY CLUSTERED ([ZCTA5CE10] ASC, [AmcosVersionIdEnd] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census longitude of the internal point', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'INTPTLON10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census latitude of the internal point', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'INTPTLAT10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census water area', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'AWATER10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census land area', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'ALAND10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census functional status', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'FUNCSTAT10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'MAF/TIGER feature class code (G2200)', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'MTFCC10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census FIPS class code', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'CLASSFP10';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'2010 Census 5-digit ZIP Code Tabulation Area code', @level0type = N'SCHEMA', @level0name = N'lookup', @level1type = N'TABLE', @level1name = N'CensusZIP', @level2type = N'COLUMN', @level2name = N'ZCTA5CE10';

