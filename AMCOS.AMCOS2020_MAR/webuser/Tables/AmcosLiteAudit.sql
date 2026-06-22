CREATE TABLE [webuser].[AmcosLiteAudit]
(
    [UserId] VARCHAR(50) NOT NULL,
    [CreateDate] DATETIME NOT NULL,
    [PageAction] NVARCHAR(50) NOT NULL,
    [PageElement] NVARCHAR(50) NOT NULL,
    [PayPlan] NVARCHAR(3) NULL,
    [CostSummaryName] NVARCHAR(50) NULL,
    [CategoryGroupCode] NVARCHAR(7) NULL,
    [CategorySubgroupCode] NVARCHAR(7) NULL,
    [CareerProgramNumber] NCHAR(2) NULL,
    [LocationId] INT NULL,
    [LocationText] NVARCHAR(150) NULL,
    [STRL] NVARCHAR(20) NULL,
    [DependentStatus] NVARCHAR(25) NULL,
    [NumberOfDependents] INT NULL,
    [OverheadPercent] INT NULL,
    [InflationConversionType] NVARCHAR(25) NULL,
    [InflationYear] NVARCHAR(4) NULL,
    CONSTRAINT [PK_AmcosLiteAudit]
        PRIMARY KEY CLUSTERED (
                                  [UserId] ASC,
                                  [CreateDate] ASC,
                                  [PageAction] ASC,
                                  [PageElement] ASC
                              )
);





