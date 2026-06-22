CREATE TABLE [lookup].[DutyStation] (
    [DutyStationCode]          NVARCHAR (9)  NOT NULL,
    [LocalityPayAreaCode]      NCHAR (2)     NULL,
    [CoreBasedStatisticalArea] NVARCHAR (5)  NULL,
    [CombinedStatisticalArea]  NVARCHAR (3)  NULL,
    [DutyStationName]          NVARCHAR (40) NULL,
    CONSTRAINT [PK_DutyStation] PRIMARY KEY CLUSTERED ([DutyStationCode] ASC)
);



