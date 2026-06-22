CREATE TABLE [dataload].[AO_ProjEndstrength] (
    [GradeType]  NVARCHAR (3) NOT NULL,
    [GradeLevel] TINYINT      NOT NULL,
    [Amount]     FLOAT (53)   NOT NULL,
    CONSTRAINT [PK_AO_ProjEndstrength] PRIMARY KEY CLUSTERED ([GradeType] ASC, [GradeLevel] ASC)
);

