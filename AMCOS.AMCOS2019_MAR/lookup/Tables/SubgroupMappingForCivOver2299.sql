CREATE TABLE [lookup].[SubgroupMappingForCivOver2299] (
    [PayPlan]                         NVARCHAR (3) NOT NULL,
    [CategorySubGroupCode]            NVARCHAR (7) NOT NULL,
    [CivCategorySubGroupCodeOver2299] NVARCHAR (7) NOT NULL,
    CONSTRAINT [PK_SubGroup_Mapping_ForCivOver2299] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategorySubGroupCode] ASC, [CivCategorySubGroupCodeOver2299] ASC)
);

