CREATE TABLE [dataload].[RO_MilCompAllowances] (
    [Code]        NVARCHAR (25)  NOT NULL,
    [GradeType]   NCHAR (1)      NOT NULL,
    [GradeLevel]  INT            NOT NULL,
    [Description] NVARCHAR (255) NULL,
    [Amount]      FLOAT (53)     NOT NULL,
    CONSTRAINT [PK_RO_MilCompAllowances] PRIMARY KEY CLUSTERED ([Code] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

