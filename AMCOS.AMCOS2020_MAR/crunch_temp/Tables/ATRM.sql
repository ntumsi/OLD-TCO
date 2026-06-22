CREATE TABLE [crunch_temp].[ATRM] (
    [SchoolCode]        NVARCHAR (25)   NULL,
    [CourseNumber]      NVARCHAR (50)   NULL,
    [CourseTitle]       NVARCHAR (100)  NULL,
    [Activity]          NVARCHAR (100)  NULL,
    [CourseLengthWeeks] NUMERIC (18, 4) NULL,
    [EGRADS]            NUMERIC (18, 4) NULL,
    [Modal Grade]       NVARCHAR (10)   NULL,
    [Frequency]         NUMERIC (18, 4) NULL,
    [Flying Hours]      NUMERIC (18, 4) NULL,
    [TMW/EGRAD]         NUMERIC (18, 4) NULL,
    [MPA]               NUMERIC (18, 4) NULL,
    [OMA CIV]           NUMERIC (18, 4) NULL,
    [OMA Non-Pay]       NUMERIC (18, 4) NULL,
    [Other]             NUMERIC (18, 4) NULL,
    [AmcosVersionId]    INT             NULL
);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250528-131400]
    ON [crunch_temp].[ATRM]([AmcosVersionId] ASC, [SchoolCode] ASC, [CourseNumber] ASC);

