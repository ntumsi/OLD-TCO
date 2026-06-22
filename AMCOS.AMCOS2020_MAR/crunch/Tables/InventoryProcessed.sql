CREATE TABLE [crunch].[InventoryProcessed] (
    [CivType]          VARCHAR (3)  NOT NULL,
    [PayPlan]          VARCHAR (3)  NOT NULL,
    [CategoryGroup]    VARCHAR (20) NOT NULL,
    [CategorySubgroup] NVARCHAR (5) NOT NULL,
    [GradeType]        VARCHAR (2)  NOT NULL,
    [GradeLevel]       VARCHAR (2)  NOT NULL,
    [Step]             VARCHAR (2)  NOT NULL,
    [LocationId]       INT          NOT NULL,
    [YOS]              SMALLINT     NOT NULL,
    [Inventory]        INT          NOT NULL,
    [AmcosVersionId]   INT          NOT NULL,
    CONSTRAINT [PK_DMDC_Inv] PRIMARY KEY CLUSTERED ([CivType] ASC, [PayPlan] ASC, [CategoryGroup] ASC, [CategorySubgroup] ASC, [Step] ASC, [LocationId] ASC, [YOS] ASC, [GradeType] ASC, [GradeLevel] ASC, [AmcosVersionId] ASC)
);



