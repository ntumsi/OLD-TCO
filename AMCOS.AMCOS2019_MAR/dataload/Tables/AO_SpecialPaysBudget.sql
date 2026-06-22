CREATE TABLE [dataload].[AO_SpecialPaysBudget] (
    [Code]        NVARCHAR (25)  NOT NULL,
    [GradeType]   NVARCHAR (3)   NOT NULL,
    [GradeLevel]  TINYINT        NOT NULL,
    [Description] NVARCHAR (255) NULL,
    [Amount]      FLOAT (53)     NOT NULL,
    CONSTRAINT [PK_AO_SpecPays_Budget] PRIMARY KEY CLUSTERED ([Code] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

