CREATE TABLE [PaySchedule].[LocalityPay] (
    [LocalityCode]   NVARCHAR (6)   NOT NULL,
    [LocalityRate]   NUMERIC (5, 2) NOT NULL,
    [AmcosVersionId] INT            NOT NULL,
    CONSTRAINT [PK_LocalityPay] PRIMARY KEY CLUSTERED ([LocalityCode] ASC, [AmcosVersionId] ASC)
);



