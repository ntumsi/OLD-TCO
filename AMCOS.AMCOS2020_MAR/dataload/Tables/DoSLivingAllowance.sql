CREATE TABLE [dataload].[DoSLivingAllowance] (
    [LocationCode]   NVARCHAR (50)   NOT NULL,
    [Amt]            NUMERIC (18, 2) NOT NULL,
    [Family]         INT             NOT NULL,
    [Group]          INT             NOT NULL,
    [AmcosVersionId] INT             DEFAULT ((202101)) NOT NULL,
    CONSTRAINT [DOSLivingAllowancePK] PRIMARY KEY CLUSTERED ([LocationCode] ASC, [AmcosVersionId] ASC, [Family] ASC, [Group] ASC)
);

