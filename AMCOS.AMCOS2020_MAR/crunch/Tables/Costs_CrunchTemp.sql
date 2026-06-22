CREATE TABLE [crunch].[Costs_CrunchTemp] (
    [PayPlan]              NVARCHAR (3)   NULL,
    [CategoryGroupCode]    NVARCHAR (4)   NULL,
    [CategorySubgroupCode] NVARCHAR (4)   CONSTRAINT [DF__Costs_Cru__sSubG__290D0E62] DEFAULT ('') NULL,
    [WageArea]             NVARCHAR (3)   CONSTRAINT [DF__Costs_Cru__sArea__2A01329B] DEFAULT ('') NULL,
    [sType]                NVARCHAR (3)   CONSTRAINT [DF__Costs_Cru__sType__2AF556D4] DEFAULT ('') NULL,
    [APPN]                 NVARCHAR (25)  NULL,
    [CostElementCategory]  NVARCHAR (50)  NULL,
    [CostElementName]      NVARCHAR (250) NULL,
    [Amortized]            INT            NULL,
    [Model]                INT            NULL,
    [CostElementId]        INT            NULL,
    [GradeType]            NVARCHAR (3)   NULL,
    [GradeLevel]           TINYINT        NULL,
    [Amount]               FLOAT (53)     NULL,
    [AmcosVersionId]       INT            NULL
);



