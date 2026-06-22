CREATE TABLE [crunch].[TempTraining_Costs_by_version] (
    [AmcosVersionId]   INT            NULL,
    [ATRM_Key]         NVARCHAR (255) NULL,
    [ATRRS_Key]        NVARCHAR (255) NULL,
    [ATRM_Crs_Title]   NVARCHAR (255) NULL,
    [ATRM_Location]    NVARCHAR (255) NULL,
    [atrm_mpa]         FLOAT (53)     NULL,
    [atrm_oma]         FLOAT (53)     NULL,
    [atrm_other]       FLOAT (53)     NULL,
    [inventory]        INT            NULL,
    [payplan]          NVARCHAR (10)  NULL,
    [final_MOS]        NVARCHAR (10)  NULL,
    [final_crs_type]   NVARCHAR (10)  NULL,
    [WeaponSystemName] NVARCHAR (50)  NULL,
    [final_GradeType]  NVARCHAR (10)  NULL,
    [final_GradeLevel] NVARCHAR (10)  NULL,
    [adj_students]     FLOAT (53)     NULL,
    [MPA_Total_Cost]   FLOAT (53)     NULL,
    [OMA_Total_Cost]   FLOAT (53)     NULL,
    [Other_Total_cost] FLOAT (53)     NULL
);

