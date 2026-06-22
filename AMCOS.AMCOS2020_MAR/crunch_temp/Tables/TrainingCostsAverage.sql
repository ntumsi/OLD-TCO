CREATE TABLE [crunch_temp].[TrainingCostsAverage] (
    [WeaponSystemName]     NVARCHAR (50)   NULL,
    [CourseTypeFinal]      NVARCHAR (10)   NULL,
    [MOSFinal]             NVARCHAR (10)   NULL,
    [GradeTypeFinal]       NVARCHAR (10)   NULL,
    [GradeLevelFinal]      NVARCHAR (10)   NULL,
    [PayPlan]              NVARCHAR (10)   NULL,
    [Inventory]            INT             NULL,
    [mpa_total_avg_cost]   NUMERIC (18, 4) NULL,
    [oma_total_avg_cost]   NUMERIC (18, 4) NULL,
    [other_total_avg_cost] NUMERIC (18, 4) NULL,
    [MPA_adj]              NUMERIC (18, 4) NULL,
    [OMA_adj]              NUMERIC (18, 4) NULL,
    [Other_adj]            NUMERIC (18, 4) NULL
);


GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-194306]
    ON [crunch_temp].[TrainingCostsAverage]([WeaponSystemName] ASC, [CourseTypeFinal] ASC, [MOSFinal] ASC, [GradeTypeFinal] ASC, [GradeLevelFinal] ASC, [PayPlan] ASC);

