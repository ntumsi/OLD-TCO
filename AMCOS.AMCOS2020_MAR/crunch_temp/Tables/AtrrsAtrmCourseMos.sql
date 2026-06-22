CREATE TABLE [crunch_temp].[AtrrsAtrmCourseMos] (
    [ATRRS_NumberOfStudents]   INT             NULL,
    [ATRRS_CrsType]            NVARCHAR (255)  NULL,
    [ATRRS_Branch]             NVARCHAR (255)  NULL,
    [ATRRS_MOS]                NVARCHAR (255)  NULL,
    [ATRRS_GradeLevel]         NVARCHAR (255)  NULL,
    [ATRRS_CourseTitle]        NVARCHAR (255)  NULL,
    [ATRRS_School]             NVARCHAR (255)  NULL,
    [ATRRS_Component]          NVARCHAR (255)  NULL,
    [ATRRS_CourseNumber]       NVARCHAR (255)  NULL,
    [ATRRS_SchoolCode]         NVARCHAR (255)  NULL,
    [ATRRS_VersionId]          INT             NULL,
    [AmcosVersionId]           INT             NULL,
    [ATRRS_Key]                NVARCHAR (50)   NULL,
    [ATRM_Key]                 NVARCHAR (50)   NULL,
    [ATRM_VersionId]           INT             NULL,
    [ATRM_SchoolCode]          NVARCHAR (25)   NULL,
    [ATRM_CourseNumber]        NVARCHAR (50)   NULL,
    [ATRM_CourseTitle]         NVARCHAR (100)  NULL,
    [ATRM_Activity]            NVARCHAR (100)  NULL,
    [ATRM_CourseLengthWeeks]   NUMERIC (18, 4) NULL,
    [ATRM_EGRADS]              NUMERIC (18, 4) NULL,
    [ATRM_Modal_Grade]         NVARCHAR (10)   NULL,
    [ATRM_Frequency]           NUMERIC (18, 4) NULL,
    [ATRM_Flying_Hrs]          NUMERIC (18, 4) NULL,
    [ATRM_TMW_EGRD]            NUMERIC (18, 4) NULL,
    [ATRM_MPA]                 NUMERIC (18, 4) NULL,
    [ATRM_OMA]                 NUMERIC (18, 4) NULL,
    [ATRM_Other]               NUMERIC (18, 4) NULL,
    [Exception]                NVARCHAR (50)   NULL,
    [Crs_Type_O]               NVARCHAR (4)    NULL,
    [Crs_Type_E]               NVARCHAR (4)    NULL,
    [WeaponSystemName]         NVARCHAR (50)   NULL,
    [AOC]                      NVARCHAR (8)    NULL,
    [WOMOS]                    NVARCHAR (8)    NULL,
    [MOS]                      NVARCHAR (8)    NULL,
    [O_GradeLevel_Floor]       INT             NULL,
    [O_GradeLevel_Ceiling]     INT             NULL,
    [W_GradeLevel_Floor]       INT             NULL,
    [W_GradeLevel_Ceiling]     INT             NULL,
    [E_GradeLevel_Floor]       INT             NULL,
    [E_GradeLevel_Ceiling]     INT             NULL,
    [CourseTypeFinal]          NVARCHAR (10)   NULL,
    [MOSFinal]                 NVARCHAR (10)   NULL,
    [BranchFinal]              NVARCHAR (10)   NULL,
    [GradeFinal]               NVARCHAR (10)   NULL,
    [GradeTypeFinal]           NVARCHAR (10)   NULL,
    [GradeLevelFinal]          NVARCHAR (10)   NULL,
    [PayPlan]                  NVARCHAR (10)   NULL,
    [atrrs_tot_students]       INT             NULL,
    [NumberOfStudentsAdjusted] NUMERIC (18, 4) NULL,
    [running_adj_students]     NUMERIC (18, 4) NULL,
    [Inventory]                INT             NULL,
    [InventoryAdjustment]      NUMERIC (18, 4) NULL,
    [total_inv_add]            NUMERIC (18, 4) NULL,
    [final_adj_inv]            NUMERIC (18, 4) NULL,
    [final_adj_students]       NUMERIC (18, 4) NULL
);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250528-170707]
    ON [crunch_temp].[AtrrsAtrmCourseMos]([CourseTypeFinal] ASC);


GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20250528-170637]
    ON [crunch_temp].[AtrrsAtrmCourseMos]([ATRRS_CourseTitle] ASC);

