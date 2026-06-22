CREATE TABLE [dataload].[RE_SpecialPays] (
    [GroupCode]  NVARCHAR (50)  NOT NULL,
    [Type]       NVARCHAR (150) NOT NULL,
    [SubType]    NVARCHAR (150) NOT NULL,
    [GradeType]  NVARCHAR (3)   NOT NULL,
    [GradeLevel] TINYINT        NOT NULL,
    [Amount]     FLOAT (53)     NOT NULL,
    CONSTRAINT [PK_RE_SpecialPays] PRIMARY KEY CLUSTERED ([GroupCode] ASC, [Type] ASC, [SubType] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

