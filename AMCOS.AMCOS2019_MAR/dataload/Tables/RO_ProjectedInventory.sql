CREATE TABLE [dataload].[RO_ProjectedInventory] (
    [Code]       NVARCHAR (25) NOT NULL,
    [GradeType]  NVARCHAR (3)  NOT NULL,
    [GradeLevel] TINYINT       NOT NULL,
    [Amount]     FLOAT (53)    NOT NULL,
    CONSTRAINT [PK_RO_ProjectedInventory] PRIMARY KEY CLUSTERED ([Code] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

