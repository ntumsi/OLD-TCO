CREATE TABLE [lookup].[DCWFWorkRole] (
    [WorkRoleCode]        NVARCHAR (3)  NOT NULL,
    [WorkRoleName]        NVARCHAR (50) NOT NULL,
    [TLMSPayTableGroup]   NVARCHAR (50) NULL,
    [EffectiveDate]       DATE          NULL,
    [AmcosVersionIdStart] INT           NULL,
    [AmcosVersionIdEnd]   INT           NOT NULL,
    CONSTRAINT [PK_CyberWorkCodes] PRIMARY KEY CLUSTERED ([WorkRoleCode] ASC, [AmcosVersionIdEnd] ASC)
);

