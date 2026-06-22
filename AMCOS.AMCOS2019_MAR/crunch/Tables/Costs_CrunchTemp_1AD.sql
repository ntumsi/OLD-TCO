CREATE TABLE [crunch].[Costs_CrunchTemp_1AD] (
    [PayPlan]              NVARCHAR (3)   NULL,
    [CategoryGroupCode]    NVARCHAR (6)   NULL,
    [CategorySubGroupCode] NVARCHAR (6)   NULL,
    [WageArea]             NVARCHAR (3)   NULL,
    [sType]                NVARCHAR (3)   NULL,
    [APPN]                 NVARCHAR (25)  NULL,
    [CostElementCategory]  NVARCHAR (50)  NULL,
    [CostElementName]      NVARCHAR (300) NULL,
    [Amortized]            INT            NULL,
    [Model]                INT            NULL,
    [CostElementId]        INT            NULL,
    [GradeType]            NVARCHAR (3)   NULL,
    [GradeLevel]           TINYINT        NULL,
    [Amount]               FLOAT (53)     NULL
);

