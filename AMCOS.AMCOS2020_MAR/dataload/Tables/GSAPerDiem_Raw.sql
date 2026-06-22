CREATE TABLE [dataload].[GSAPerDiem_Raw] (
    [ID]              INT            IDENTITY (1, 1) NOT NULL,
    [DestinationID]   FLOAT (53)     NOT NULL,
    [Name]            NVARCHAR (50)  NULL,
    [County]          NVARCHAR (50)  NULL,
    [LocationDefined] NVARCHAR (500) NULL,
    [State]           NVARCHAR (50)  NULL,
    [Zip]             NVARCHAR (5)   NOT NULL,
    [FiscalYear]      FLOAT (53)     NULL,
    [Oct]             FLOAT (53)     NULL,
    [Nov]             FLOAT (53)     NULL,
    [Dec]             FLOAT (53)     NULL,
    [Jan]             FLOAT (53)     NULL,
    [Feb]             FLOAT (53)     NULL,
    [Mar]             FLOAT (53)     NULL,
    [Apr]             FLOAT (53)     NULL,
    [May]             FLOAT (53)     NULL,
    [Jun]             FLOAT (53)     NULL,
    [Jul]             FLOAT (53)     NULL,
    [Aug]             FLOAT (53)     NULL,
    [Sep]             FLOAT (53)     NULL,
    [Meals]           FLOAT (53)     NULL,
    [AmcosVersionId]  INT            CONSTRAINT [DF__GSAPerDie__Amcos__0B335E0F] DEFAULT (CONVERT([int],CONVERT([varchar](4),datepart(year,getdate()))+'01')) NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);



