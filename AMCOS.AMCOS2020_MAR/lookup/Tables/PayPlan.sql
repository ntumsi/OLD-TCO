CREATE TABLE [lookup].[PayPlan] (
    [PayPlan]                   NVARCHAR (3)   NOT NULL,
    [AmcosVersionIdStart]       INT            NULL,
    [AmcosVersionIdEnd]         INT            NOT NULL,
    [DisplayTitle]              NVARCHAR (75)  NULL,
    [GroupTitle]                NVARCHAR (50)  NULL,
    [Description]               NVARCHAR (50)  NULL,
    [CategoryGroupLabel]        NVARCHAR (50)  NULL,
    [CategorySubgroupLabel]     NVARCHAR (50)  NULL,
    [IncludeArmyCareerPrograms] BIT            NULL,
    [Explanation]               NVARCHAR (500) NULL,
    [DisplaySequence]           NUMERIC (3, 2) NULL,
    [VersionIntroduced]         INT            NULL,
    [OpmStartDate]              DATE           NULL,
    CONSTRAINT [PK_PayPlan] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [AmcosVersionIdEnd] ASC)
);















