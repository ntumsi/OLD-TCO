CREATE TABLE [dataload].[AE_MilCompAllowances] (
    [Code]        NVARCHAR (25)  NOT NULL,
    [GradeType]   NVARCHAR (3)   NOT NULL,
    [GradeLevel]  TINYINT        NOT NULL,
    [Description] NVARCHAR (255) NULL,
    [Amount]      FLOAT (53)     NULL,
    CONSTRAINT [PK_AE_Mil_Comp_Allowances] PRIMARY KEY CLUSTERED ([Code] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

