CREATE TABLE [webuser].[AmcosLiteAudit] (
    [UserId]                  VARCHAR (50)  NOT NULL,
    [CreateDate]              DATETIME      NOT NULL,
    [PageAction]              NVARCHAR (50) NOT NULL,
    [PageElement]             NVARCHAR (50) NOT NULL,
    [PayPlan]                 NVARCHAR (3)  NULL,
    [CostSummaryId]           INT           NULL,
    [CategoryGroupCode]       NVARCHAR (7)  NULL,
    [CategorySubgroupCode]    NVARCHAR (7)  NULL,
    [LocalityRateId]          INT           NULL,
    [SpecialRateTableNumber]  NVARCHAR (4)  NULL,
    [WageArea]                NVARCHAR (7)  NULL,
    [MetroAreaCode]           NVARCHAR (9)  NULL,
    [OverheadPercentage]      INT           NULL,
    [StateCountry]            NVARCHAR (50) NULL,
    [FunctionalAreaCode]      NVARCHAR (50) NULL,
    [CostCenterCode]          NVARCHAR (50) NULL,
    [InflationConversionType] NVARCHAR (25) NULL,
    [InflationYear]           NVARCHAR (4)  NULL,
    CONSTRAINT [PK_AmcosLiteAudit] PRIMARY KEY CLUSTERED ([UserId] ASC, [CreateDate] ASC, [PageAction] ASC, [PageElement] ASC)
);

