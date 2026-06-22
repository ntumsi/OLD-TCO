CREATE TABLE [warehouse].[UnitPersonnel] (
    [UIC]                   NVARCHAR (6)   NOT NULL,
    [UICTitle]              NVARCHAR (150) NOT NULL,
    [PayPlan]               NVARCHAR (3)   NOT NULL,
    [CategoryGroupCode]     NVARCHAR (10)  NOT NULL,
    [CategorySubgroupCode]  NVARCHAR (10)  NOT NULL,
    [LocationId]            INT            NOT NULL,
    [LocationText]          NVARCHAR (150) NOT NULL,
    [STRL]                  NVARCHAR (20)  NOT NULL,
    [GradeLevel]            TINYINT        NOT NULL,
    [DependentStatus]       NVARCHAR (25)  NOT NULL,
    [NumberOfDependents]    INT            NOT NULL,
    [ActiveDutyDays]        SMALLINT       NOT NULL,
    [Inventory]             INT            NOT NULL,
    [UnitYear]              NVARCHAR (4)   NOT NULL,
    [AsOf]                  NVARCHAR (8)   NOT NULL,
    [AuthorizationDocument] NVARCHAR (50)  NULL,
    CONSTRAINT [PK_WarehouseUnitPersonnel] PRIMARY KEY CLUSTERED ([UIC] ASC, [PayPlan] ASC, [CategoryGroupCode] ASC, [CategorySubgroupCode] ASC, [LocationId] ASC, [STRL] ASC, [GradeLevel] ASC, [DependentStatus] ASC, [NumberOfDependents] ASC, [UnitYear] ASC, [AsOf] ASC)
);



