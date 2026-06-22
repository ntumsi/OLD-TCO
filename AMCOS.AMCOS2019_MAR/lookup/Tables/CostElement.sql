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
    [showOrder]           INT             NULL,
    [ArmyCesTitle]        NVARCHAR (250)  NULL,
    [OsdCapeCesTitle]     NVARCHAR (250)  NULL,
    [Active]              BIT             NULL,
    [ApplyInflation]      BIT             DEFAULT ((1)) NULL,
    CONSTRAINT [PK_CostElement] PRIMARY KEY CLUSTERED ([CostElementId] ASC)
);






GO
CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20180904-112229]
    ON [lookup].[CostElement]([PayPlan] ASC, [APPN] ASC, [CostElementCategory] ASC, [CostElementName] ASC);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_CostElement_CostElementId]
    ON [lookup].[CostElement]([CostElementId] ASC);

