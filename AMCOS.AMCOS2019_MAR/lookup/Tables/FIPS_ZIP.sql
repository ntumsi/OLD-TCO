CREATE TABLE [lookup].[FIPS_ZIP] (
    [FIPSCode]             NVARCHAR (5)  NOT NULL,
    [ZIPCode]              NCHAR (5)     NOT NULL,
    [City]                 NVARCHAR (50) NULL,
    [County]               NVARCHAR (50) NULL,
    [State]                NCHAR (2)     NULL,
    [StateName]            NVARCHAR (50) NULL,
    [StateNameCapitalized] NVARCHAR (50) NULL,
    [Latitude]             NVARCHAR (50) NULL,
    [Longitude]            NVARCHAR (50) NULL,
    CONSTRAINT [PK_FIPS_ZIP] PRIMARY KEY CLUSTERED ([FIPSCode] ASC, [ZIPCode] ASC)
);



