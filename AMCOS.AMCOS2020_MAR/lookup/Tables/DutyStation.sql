CREATE TABLE [lookup].[DutyStation] (
    [DutyStationCode]     NVARCHAR (9)   NOT NULL,
    [LPA]                 NVARCHAR (200) NULL,
    [CBSA]                NVARCHAR (5)   NULL,
    [Csa]                 NVARCHAR (3)   NULL,
    [City]                NVARCHAR (200) NULL,
    [County]              NVARCHAR (200) NULL,
    [State]               NVARCHAR (200) NULL,
    [Country]             NVARCHAR (200) NOT NULL,
    [AmcosVersionIdStart] INT            NOT NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_ArmyBudget] PRIMARY KEY CLUSTERED ([DutyStationCode] ASC, [AmcosVersionIdEnd] ASC)
);









