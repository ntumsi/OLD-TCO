CREATE TABLE [crunch_temp].[Training_xwalk_atrrs_crstype_mos] (
    [ATRRS_SchoolCode]     NVARCHAR (255) NULL,
    [ATRRS_CourseNumber]   NVARCHAR (255) NULL,
    [Crs_Type_O]           NVARCHAR (4)   NULL,
    [Crs_Type_E]           NVARCHAR (4)   NULL,
    [WeaponSystemName]     NVARCHAR (50)  NULL,
    [AOC]                  NVARCHAR (8)   NULL,
    [WOMOS]                NVARCHAR (8)   NULL,
    [MOS]                  NVARCHAR (8)   NULL,
    [O_GradeLevel_Floor]   INT            NULL,
    [O_GradeLevel_Ceiling] INT            NULL,
    [W_GradeLevel_Floor]   INT            NULL,
    [W_GradeLevel_Ceiling] INT            NULL,
    [E_GradeLevel_Floor]   INT            NULL,
    [E_GradeLevel_Ceiling] INT            NULL,
    [AmcosVersionId]       INT            NULL
);


GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-194443]
    ON [crunch_temp].[Training_xwalk_atrrs_crstype_mos]([ATRRS_CourseNumber] ASC, [Crs_Type_O] ASC, [Crs_Type_E] ASC, [WeaponSystemName] ASC, [AOC] ASC, [WOMOS] ASC, [MOS] ASC, [AmcosVersionId] ASC);

