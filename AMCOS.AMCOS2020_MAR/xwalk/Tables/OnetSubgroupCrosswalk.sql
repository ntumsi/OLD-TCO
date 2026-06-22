CREATE TABLE [xwalk].[OnetSubgroupCrosswalk] (
    [ONET_code]           NVARCHAR (20)  NOT NULL,
    [ONetCodeTrimmed]     NVARCHAR (20)  NULL,
    [SubgroupCode]        NVARCHAR (5)   NOT NULL,
    [SortIndex]           INT            NOT NULL,
    [PayPlanType]         NVARCHAR (3)   NOT NULL,
    [MinGradeLevel]       INT            NOT NULL,
    [Source]              NVARCHAR (300) NOT NULL,
    [AmcosVersionIdStart] INT            NOT NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_OnetSubgroupCrosswalk] PRIMARY KEY CLUSTERED ([ONET_code] ASC, [SubgroupCode] ASC, [PayPlanType] ASC, [AmcosVersionIdEnd] ASC)
);



