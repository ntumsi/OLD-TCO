CREATE TABLE [lookup].[CostElement] (
    [CostElementId]       INT             IDENTITY (1, 1) NOT NULL,
    [PayPlan]             NVARCHAR (3)    NOT NULL,
    [AppropriationGroup]  NVARCHAR (50)   NULL,
    [APPN]                NVARCHAR (25)   NOT NULL,
    [CostElementCategory] NVARCHAR (50)   NOT NULL,
    [CostElementName]     NVARCHAR (250)  NOT NULL,
    [Amort]               INT             NULL,
    [Model]               INT             NULL,
    [Locality]            BIT             NULL,
    [Description]         NVARCHAR (3000) NULL,
    [BusinessLogic]       NVARCHAR (3000) NULL,
    [BasisOfComputation]  NVARCHAR (3000) NULL,
    [Source]              NVARCHAR (3000) NULL,
    [ShowOrder]           INT             NULL,
    [ArmyCesTitle]        NVARCHAR (250)  NULL,
    [OsdCapeCesTitle]     NVARCHAR (250)  NULL,
    [Active]              BIT             NULL,
    [AmcosVersionIdStart] INT             NULL,
    [AmcosVersionIdEnd]   INT             NOT NULL,
    [ApplyInflation]      BIT             NULL,
    [IsLocationSpecific]  BIT             DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_CostElement] PRIMARY KEY CLUSTERED ([CostElementId] ASC, [AmcosVersionIdEnd] ASC)
);












GO



GO


