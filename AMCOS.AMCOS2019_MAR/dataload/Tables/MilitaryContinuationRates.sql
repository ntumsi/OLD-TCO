CREATE TABLE [dataload].[MilitaryContinuationRates] (
    [PayPlan]        NVARCHAR (3) NOT NULL,
    [CMF]            NCHAR (2)    NOT NULL,
    [YOS]            TINYINT      NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    [Amount]         FLOAT (53)   NULL,
    CONSTRAINT [PK_MilitaryContRates] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CMF] ASC, [YOS] ASC, [AmcosVersionId] ASC),
    CONSTRAINT [FK_MilitaryContRates_Version] FOREIGN KEY ([AmcosVersionId]) REFERENCES [lookup].[AMCOSVersion] ([AmcosVersionId])
);

