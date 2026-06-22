CREATE TABLE [warehouse].[LocationByCategory] (
    [Id]                   INT            IDENTITY (1, 1) NOT NULL,
    [PayPlan]              NVARCHAR (3)   NOT NULL,
    [CategoryGroupCode]    NVARCHAR (7)   NOT NULL,
    [CategorySubgroupCode] NVARCHAR (7)   NOT NULL,
    [CareerProgramNumber]  NCHAR (2)      NOT NULL,
    [LocationId]           INT            NOT NULL,
    [OconusMHA]            NVARCHAR (500) NULL,
    [ConusMHA]             NVARCHAR (500) NULL,
    [Installation]         NVARCHAR (500) NULL,
    [LocalityPayArea]      NVARCHAR (500) NULL,
    [SpecialPayArea]       NVARCHAR (500) NULL,
    [Country]              NVARCHAR (500) NULL,
    [WageSchedule]         NVARCHAR (500) NULL,
    [CityCounty]           NVARCHAR (500) NULL,
    [MSA]                  NVARCHAR (150) NULL,
    [STRL]                 NVARCHAR (200) NULL,
    [CivOverseas]          NVARCHAR (500) NULL,
    CONSTRAINT [PK_LocationByCategory] PRIMARY KEY CLUSTERED ([Id] ASC)
);
















GO


