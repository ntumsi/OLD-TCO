CREATE TABLE [lookup].[ATRRSCourseTypeMOS] (
    [ATRRS_Sch_Code]       NVARCHAR (4)  NOT NULL,
    [ATRRS_Crs_Number]     NVARCHAR (50) NOT NULL,
    [Crs_Type_O]           NVARCHAR (4)  NULL,
    [Crs_Type_E]           NVARCHAR (4)  NULL,
    [WeaponSystemName]     NVARCHAR (50) NULL,
    [AOC]                  NVARCHAR (8)  NULL,
    [WOMOS]                NVARCHAR (8)  NULL,
    [MOS]                  NVARCHAR (8)  NULL,
    [O_GradeLevel_Floor]   INT           NULL,
    [O_GradeLevel_Ceiling] INT           NULL,
    [W_GradeLevel_Floor]   INT           NULL,
    [W_GradeLevel_Ceiling] INT           NULL,
    [E_GradeLevel_Floor]   INT           NULL,
    [E_GradeLevel_Ceiling] INT           NULL,
    [AmcosVersionId]       INT           NOT NULL,
    CONSTRAINT [PK_ATRRSCourseTypeMOS] PRIMARY KEY CLUSTERED ([ATRRS_Sch_Code] ASC, [ATRRS_Crs_Number] ASC, [AmcosVersionId] ASC)
);





