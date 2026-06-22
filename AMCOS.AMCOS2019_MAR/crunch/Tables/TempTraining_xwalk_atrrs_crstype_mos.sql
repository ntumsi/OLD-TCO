CREATE TABLE [crunch].[TempTraining_xwalk_atrrs_crstype_mos] (
    [ATRRS_Sch_Code]       NVARCHAR (255) NULL,
    [ATRRS_Crs_Number]     NVARCHAR (255) NULL,
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

