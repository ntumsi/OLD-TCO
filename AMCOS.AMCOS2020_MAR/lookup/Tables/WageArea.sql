CREATE TABLE [lookup].[WageArea] (
    [WageArea]            NVARCHAR (3)   NOT NULL,
    [ScheduleArea]        NVARCHAR (4)   NOT NULL,
    [AreaName]            NVARCHAR (250) NULL,
    [AmcosVersionIdStart] INT            NOT NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    [FundType]            NVARCHAR (3)   NOT NULL,
    CONSTRAINT [PK_WageArea1] PRIMARY KEY CLUSTERED ([WageArea] ASC, [ScheduleArea] ASC, [FundType] ASC, [AmcosVersionIdStart] ASC, [AmcosVersionIdEnd] ASC)
);









