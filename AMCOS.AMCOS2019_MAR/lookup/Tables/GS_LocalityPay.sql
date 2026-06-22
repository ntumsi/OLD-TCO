CREATE TABLE [lookup].[GS_LocalityPay] (
    [LocalityPayArea] NVARCHAR (100)  NOT NULL,
    [LocalityPayment] NUMERIC (18, 2) NULL,
    CONSTRAINT [PK_GS_LocalityPay] PRIMARY KEY CLUSTERED ([LocalityPayArea] ASC)
);

