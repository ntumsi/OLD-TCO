CREATE TABLE [crunch_temp].[ATRRS] (
    [CPBRANCH]         NCHAR (1)      NULL,
    [SchoolCode]       NVARCHAR (5)   NULL,
    [SchoolName]       NVARCHAR (50)  NULL,
    [CRSPH]            NVARCHAR (30)  NULL,
    [CourseTitle]      NVARCHAR (100) NULL,
    [PGRAD]            NVARCHAR (2)   NULL,
    [PMOSEN4]          NVARCHAR (10)  NULL,
    [CRMGOF]           NCHAR (2)      NULL,
    [CRSTYPE]          NCHAR (2)      NULL,
    [NumberOfStudents] INT            NULL,
    [AmcosVersionId]   INT            NULL
);


GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-194103]
    ON [crunch_temp].[ATRRS]([CPBRANCH] ASC, [SchoolCode] ASC, [CRSPH] ASC, [PMOSEN4] ASC, [AmcosVersionId] ASC);

