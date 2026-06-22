CREATE TABLE [lookup].[GFEBS_CostCenter] (
    [CostCenterCode] NVARCHAR (50)  NOT NULL,
    [CostCenterText] NVARCHAR (250) NULL,
    CONSTRAINT [PK_GFEBS_CostCenter] PRIMARY KEY CLUSTERED ([CostCenterCode] ASC)
);

