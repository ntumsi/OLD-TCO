CREATE TABLE [crunch_temp].[ATRRS_ATRM_Raw] (
    [Exception]              NVARCHAR (50)   NULL,
    [ATRM_Other]             NUMERIC (18, 4) NULL,
    [ATRM_OMA]               NUMERIC (18, 4) NULL,
    [ATRM_MPA]               NUMERIC (18, 4) NULL,
    [ATRM_TMW_EGRD]          NUMERIC (18, 4) NULL,
    [ATRM_Flying_Hrs]        NUMERIC (18, 4) NULL,
    [ATRM_Frequency]         NUMERIC (18, 4) NULL,
    [ATRM_Modal_Grade]       NVARCHAR (10)   NULL,
    [ATRM_EGRADS]            NUMERIC (18, 4) NULL,
    [ATRM_CourseLengthWeeks] NUMERIC (18, 4) NULL,
    [ATRM_Activity]          NVARCHAR (100)  NULL,
    [ATRM_CourseTitle]       NVARCHAR (100)  NULL,
    [ATRM_CourseNumber]      NVARCHAR (50)   NULL,
    [ATRM_SchoolCode]        NVARCHAR (25)   NULL,
    [ATRM_VersionId]         INT             NULL,
    [ATRM_Key]               NVARCHAR (50)   NULL,
    [ATRRS_Key]              NVARCHAR (50)   NULL,
    [AmcosVersionId]         INT             NULL,
    [ATRRS_VersionId]        INT             NULL,
    [ATRRS_SchoolCode]       NVARCHAR (255)  NULL,
    [ATRRS_CourseNumber]     NVARCHAR (255)  NULL,
    [ATRRS_Component]        NVARCHAR (255)  NULL,
    [ATRRS_School]           NVARCHAR (255)  NULL,
    [ATRRS_CourseTitle]      NVARCHAR (255)  NULL,
    [ATRRS_GradeLevel]       NVARCHAR (255)  NULL,
    [ATRRS_MOS]              NVARCHAR (255)  NULL,
    [ATRRS_Branch]           NVARCHAR (255)  NULL,
    [ATRRS_CrsType]          NVARCHAR (2)    NULL,
    [ATRRS_NumberOfStudents] NUMERIC (18, 4) NULL
);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250528-132418]
    ON [crunch_temp].[ATRRS_ATRM_Raw]([ATRRS_Key] ASC, [AmcosVersionId] ASC);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250528-132350]
    ON [crunch_temp].[ATRRS_ATRM_Raw]([ATRM_Key] ASC, [AmcosVersionId] ASC);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250528-131453]
    ON [crunch_temp].[ATRRS_ATRM_Raw]([ATRRS_CourseNumber] ASC);

