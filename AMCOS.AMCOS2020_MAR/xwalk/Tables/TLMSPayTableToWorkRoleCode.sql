CREATE TABLE [xwalk].[TLMSPayTableToWorkRoleCode] (
    [TLMSPayTable]   NVARCHAR (2) NOT NULL,
    [WorkRoleCode]   NVARCHAR (3) NOT NULL,
    [AmcosVersionId] INT          NOT NULL,
    CONSTRAINT [PK_TLMSPayTableToWorkRoleCode] PRIMARY KEY CLUSTERED ([TLMSPayTable] ASC, [WorkRoleCode] ASC, [AmcosVersionId] ASC)
);

