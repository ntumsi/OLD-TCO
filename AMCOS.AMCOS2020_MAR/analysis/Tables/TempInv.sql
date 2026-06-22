CREATE TABLE [analysis].[TempInv] (
    [PayPlan]              NVARCHAR (3)  NOT NULL,
    [CategoryGroupCode]    NVARCHAR (20) NOT NULL,
    [CategorySubgroupCode] NVARCHAR (4)  NOT NULL,
    [Strl]                 NVARCHAR (20) NOT NULL,
    [LocationId]           INT           NOT NULL,
    [GradeType]            NVARCHAR (3)  NOT NULL,
    [GradeLevel]           TINYINT       NOT NULL,
    [Step]                 INT           NOT NULL,
    [YOS]                  INT           NULL,
    [Inventory]            INT           NOT NULL,
    [AmcosVersionId]       INT           NOT NULL
);

