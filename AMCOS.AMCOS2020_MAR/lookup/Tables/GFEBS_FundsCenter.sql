CREATE TABLE [lookup].[GFEBS_FundsCenter] (
    [FundsCenterCode]     NVARCHAR (50)  NOT NULL,
    [FundsCenterText]     NVARCHAR (250) NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_GFEBS_FundsCenter] PRIMARY KEY CLUSTERED ([FundsCenterCode] ASC, [AmcosVersionIdEnd] ASC)
);



