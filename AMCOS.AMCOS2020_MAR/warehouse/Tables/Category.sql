CREATE TABLE [warehouse].[Category] (
    [PayPlan]                     NVARCHAR (3)   NOT NULL,
    [CategoryGroupCode]           NVARCHAR (7)   NOT NULL,
    [CategoryGroupDescription]    NVARCHAR (150) NULL,
    [CategoryGroupDisplay]        NVARCHAR (175) NULL,
    [CategorySubgroupCode]        NVARCHAR (7)   NOT NULL,
    [CategorySubgroupDescription] NVARCHAR (150) NULL,
    [CategorySubgroupDisplay]     NVARCHAR (175) NULL,
    [CareerProgramNumber]         NCHAR (2)      NOT NULL,
    [CareerProgramDescription]    NVARCHAR (75)  NULL,
    [CareerProgramDisplay]        NVARCHAR (100) NULL
    CONSTRAINT [PK_Category] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [CareerProgramNumber] ASC)
);





