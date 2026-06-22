CREATE TABLE [dataload].[DoSPostAllowance] (
    [LocationCode]   NVARCHAR (50)  NOT NULL,
    [PostAllowance]  NUMERIC (5, 4) NULL,
    [Hardship]       NUMERIC (5, 4) NULL,
    [DangerPay]      NUMERIC (5, 4) NULL,
    [AmcosVersionId] INT            DEFAULT ((202101)) NOT NULL,
    CONSTRAINT [DOSDoSPostAllowancePK] PRIMARY KEY CLUSTERED ([LocationCode] ASC, [AmcosVersionId] ASC)
);

