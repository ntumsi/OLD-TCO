CREATE TABLE [lookup].[SubgroupMappingForCivOver2299] (
    [PayPlan]                         NVARCHAR (3) NOT NULL,
    [CategorySubgroupCode]            NVARCHAR (7) NOT NULL,
    [CivCategorySubgroupCodeOver2299] NVARCHAR (7) NOT NULL,
    [AmcosVersionIdStart]             INT          NULL,
    [AmcosVersionIdEnd]               INT          NOT NULL,
    CONSTRAINT [PK_SubGroup_Mapping_ForCivOver2299] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategorySubgroupCode] ASC, [CivCategorySubgroupCodeOver2299] ASC, [AmcosVersionIdEnd] ASC)
);



