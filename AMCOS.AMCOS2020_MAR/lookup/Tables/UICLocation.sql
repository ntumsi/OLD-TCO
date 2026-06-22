CREATE TABLE [lookup].[UICLocation] (
    [Id]                  INT            IDENTITY (1, 1) NOT NULL,
    [LOCNM]               NVARCHAR (100) NULL,
    [GELOC]               NVARCHAR (4)   NULL,
    [ARLOC]               NVARCHAR (5)   NULL,
    [SRCASGMT]            NVARCHAR (50)  NULL,
    [UIC]                 NVARCHAR (6)   NOT NULL,
    [SOURCE]              NVARCHAR (50)  NULL,
    [CITY]                NVARCHAR (50)  NULL,
    [STATE]               NVARCHAR (2)   NULL,
    [ZIP]                 NVARCHAR (10)  NULL,
    [COUNTRY]             NVARCHAR (50)  NULL,
    [DRRSNAME]            NVARCHAR (50)  NULL,
    [DRRSZIPCDCITY]       NVARCHAR (50)  NULL,
    [DRRSZIPCDSTATE]      NVARCHAR (2)   NULL,
    [DRRSZIPCD]           NVARCHAR (5)   NULL,
    [DRRSZIPCDCOUNTRY]    NVARCHAR (50)  NULL,
    [STACO]               NVARCHAR (5)   NULL,
    [STACONAME]           NVARCHAR (100) NULL,
    [STACOCITY]           NVARCHAR (50)  NULL,
    [STACOSTATE]          NVARCHAR (2)   NULL,
    [STACOZIP]            NVARCHAR (10)  NULL,
    [STACOCOUNTRY]        NVARCHAR (50)  NULL,
    [EFY]                 NVARCHAR (4)   NULL,
    [TFY]                 NVARCHAR (4)   NULL,
    [SAMASSTACOCITY]      NVARCHAR (50)  NULL,
    [EffectiveDate] INT            NOT NULL,    
    CONSTRAINT [PK_UICLocation] PRIMARY KEY CLUSTERED ([Id] ASC)
);









