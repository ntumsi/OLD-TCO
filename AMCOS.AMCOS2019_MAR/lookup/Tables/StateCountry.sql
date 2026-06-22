CREATE TABLE [lookup].[StateCountry] (
    [ZIPCode]              NCHAR (5)     NOT NULL,
    [State]                NCHAR (2)     NOT NULL,
    [StateName]            NVARCHAR (50) NULL,
    [StateNameCapitalized] NVARCHAR (50) NULL,
    CONSTRAINT [PK_StateCountry] PRIMARY KEY CLUSTERED ([ZIPCode] ASC, [State] ASC)
);

