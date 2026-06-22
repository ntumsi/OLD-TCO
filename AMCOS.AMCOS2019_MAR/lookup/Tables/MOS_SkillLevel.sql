CREATE TABLE [lookup].[MOS_SkillLevel] (
    [GradeType]  NVARCHAR (3) NOT NULL,
    [GradeLevel] TINYINT      NOT NULL,
    [SkillLevel] NCHAR (1)    NULL,
    CONSTRAINT [PK_MOS_SkillLevel] PRIMARY KEY CLUSTERED ([GradeType] ASC, [GradeLevel] ASC)
);

