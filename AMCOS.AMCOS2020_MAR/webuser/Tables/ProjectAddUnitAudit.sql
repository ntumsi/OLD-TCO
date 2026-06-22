CREATE TABLE [webuser].[ProjectAddUnitAudit] (
    [UserId]                    VARCHAR (50)  NOT NULL,
    [CreateDate]                DATETIME      NOT NULL,
    [CategoryId]                INT           NULL,
    [UIC]                       NVARCHAR (6)  NULL,
    [ExcludedPayPlans]          NVARCHAR (50) NULL,
    [DataAction]                NVARCHAR (7)  NULL,
    [NewSubprojectName]         NVARCHAR (50) NULL,
    [UnitLocation]              NCHAR (2)     NULL,
    [MtoeProjectInventoryYear]  INT           NULL,
    [ProjectExtendsSacsYears]   NVARCHAR (25) NULL,
    [ContractorOverheadPercent] FLOAT (53)    NULL,
    CONSTRAINT [PK_ProjectAddUnitAudit] PRIMARY KEY CLUSTERED ([UserId] ASC, [CreateDate] ASC)
);

