CREATE TABLE [crunch].[Inventory_GFEBS] (
    [PayPlan]                  NVARCHAR (3)  NOT NULL,
    [OccupationalGroupNumber]  NVARCHAR (4)  NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (4)  NOT NULL,
    [LocationId]               INT           NOT NULL,
    [STRL]                     NVARCHAR (20) NOT NULL,
    [GradeType]                NVARCHAR (3)  NOT NULL,
    [GradeLevel]               TINYINT       NOT NULL,
    [Step]                     INT           NOT NULL,
    [YOS]                      INT           NULL,
    [Inventory]                INT           NOT NULL,
    [AmcosVersionId]           INT           NOT NULL,
    CONSTRAINT [PK_Inventory_GFEBS] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [OccupationalGroupNumber] ASC, [OccupationalSeriesNumber] ASC, [LocationId] ASC, [STRL] ASC, [GradeType] ASC, [GradeLevel] ASC, [Step] ASC, [AmcosVersionId] ASC)
);

