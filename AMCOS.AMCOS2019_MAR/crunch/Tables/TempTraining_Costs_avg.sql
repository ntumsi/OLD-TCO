CREATE TABLE [crunch].[TempTraining_Costs_avg] (
    [WeaponSystemName]     NVARCHAR (50) NULL,
    [final_crs_type]       NVARCHAR (10) NULL,
    [final_MOS]            NVARCHAR (10) NULL,
    [final_GradeType]      NVARCHAR (10) NULL,
    [final_GradeLevel]     NVARCHAR (10) NULL,
    [payplan]              NVARCHAR (10) NULL,
    [inv]                  INT           NULL,
    [mpa_total_avg_cost]   FLOAT (53)    NULL,
    [oma_total_avg_cost]   FLOAT (53)    NULL,
    [other_total_avg_cost] FLOAT (53)    NULL,
    [MPA_adj]              FLOAT (53)    NULL,
    [OMA_adj]              FLOAT (53)    NULL,
    [Other_adj]            FLOAT (53)    NULL
);

