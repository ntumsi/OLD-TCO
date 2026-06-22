CREATE TABLE [load_training].[ATRRS] (
    [Id]               INT            IDENTITY (1, 1) NOT NULL,
    [CPBRANCH]         NCHAR (1)      NOT NULL,
    [SchoolCode]       NVARCHAR (5)   NOT NULL,
    [SchoolName]       NVARCHAR (50)  NOT NULL,
    [CourseNumber]     NVARCHAR (30)  NOT NULL,
    [CourseTitle]      NVARCHAR (100) NOT NULL,
    [PGRAD]            NVARCHAR (2)   NOT NULL,
    [PMOSEN4]          NVARCHAR (10)  NOT NULL,
    [CRMGOF]           NCHAR (2)      NOT NULL,
    [CRSTYPE]          NCHAR (2)      NOT NULL,
    [NumberOfStudents] INT            NULL,
    [AmcosVersionId]   INT            NOT NULL,
    CONSTRAINT [PK_ATRRS] PRIMARY KEY NONCLUSTERED ([Id] ASC)
);












GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-195601]
    ON [load_training].[ATRRS]([CPBRANCH] ASC, [SchoolCode] ASC, [CourseNumber] ASC, [CourseTitle] ASC, [PMOSEN4] ASC, [CRSTYPE] ASC, [AmcosVersionId] ASC);



