CREATE TABLE [crunch_temp].[TrainingCosts] (
    [WeaponSystemName]     NVARCHAR (50)   NULL,
    [CourseType]           NVARCHAR (10)   NULL,
    [PayPlan]              NVARCHAR (3)    NOT NULL,
    [CategoryGroupCode]    NVARCHAR (4)    NOT NULL,
    [CategorySubgroupCode] NVARCHAR (4)    NOT NULL,
    [GradeType]            NVARCHAR (3)    NOT NULL,
    [GradeLevel]           TINYINT         NOT NULL,
    [Inventory]            INT             NULL,
    [MPA_MOS]              NUMERIC (18, 4) NULL,
    [OMA_MOS]              NUMERIC (18, 4) NULL,
    [Other_MOS]            NUMERIC (18, 4) NULL,
    [MPA_CMF]              NUMERIC (18, 4) NULL,
    [OMA_CMF]              NUMERIC (18, 4) NULL,
    [Other_CMF]            NUMERIC (18, 4) NULL,
    [MPA_PP]               NUMERIC (18, 4) NULL,
    [OMA_PP]               NUMERIC (18, 4) NULL,
    [other_PP]             NUMERIC (18, 4) NULL,
    [CGLA_MOS_inv]         NUMERIC (18, 4) NULL,
    [CGLA_CMF_Inv]         NUMERIC (18, 4) NULL,
    [CGLA_PP_inv]          NUMERIC (18, 4) NULL,
    [CGLA_MPA]             NUMERIC (18, 4) NULL,
    [CGLA_OMA]             NUMERIC (18, 4) NULL,
    [CGLA_Other]           NUMERIC (18, 4) NULL,
    [RPA_NGPA]             NUMERIC (18, 4) NULL,
    [OMAR_OMNG]            NUMERIC (18, 4) NULL,
    [WeaponSystemId]       INT             NULL
);


GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-194226]
    ON [crunch_temp].[TrainingCosts]([WeaponSystemName] ASC, [CourseType] ASC, [PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [GradeType] ASC, [GradeLevel] ASC);

