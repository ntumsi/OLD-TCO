CREATE TABLE [crunch_temp].[TrainingCostsByVersion] (
    [AmcosVersionId]           INT             NULL,
    [ATRM_Key]                 NVARCHAR (50)   NULL,
    [ATRRS_Key]                NVARCHAR (50)   NULL,
    [ATRM_CourseTitle]         NVARCHAR (100)  NULL,
    [ATRM_MPA]                 NUMERIC (18, 4) NULL,
    [ATRM_OMA]                 NUMERIC (18, 4) NULL,
    [ATRM_Other]               NUMERIC (18, 4) NULL,
    [Inventory]                INT             NULL,
    [PayPlan]                  NVARCHAR (10)   NULL,
    [MOSFinal]                 NVARCHAR (10)   NULL,
    [CourseTypeFinal]          NVARCHAR (10)   NULL,
    [WeaponSystemName]         NVARCHAR (50)   NULL,
    [GradeTypeFinal]           NVARCHAR (10)   NULL,
    [GradeLevelFinal]          NVARCHAR (10)   NULL,
    [NumberOfStudentsAdjusted] NUMERIC (18, 4) NULL,
    [MPA_Total_Cost]           NUMERIC (18, 4) NULL,
    [OMA_Total_Cost]           NUMERIC (18, 4) NULL,
    [Other_Total_cost]         NUMERIC (18, 4) NULL
);


GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-194332]
    ON [crunch_temp].[TrainingCostsByVersion]([AmcosVersionId] ASC, [ATRM_Key] ASC, [ATRRS_Key] ASC, [PayPlan] ASC, [MOSFinal] ASC, [CourseTypeFinal] ASC, [WeaponSystemName] ASC, [GradeTypeFinal] ASC, [GradeLevelFinal] ASC);

