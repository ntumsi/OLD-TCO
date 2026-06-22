CREATE TABLE [dataload].[MilitaryAnnualComp] (
    [Grade]              NVARCHAR (3)    NOT NULL,
    [GradeLevel]         TINYINT         NOT NULL,
    [YoS]                INT             NOT NULL,
    [HasDependents]      BIT             NOT NULL,
    [AnnualCompensation] NUMERIC (16, 2) NOT NULL,
    [AmcosVersionId]     INT             NOT NULL,
    CONSTRAINT [PK_MilitaryAnnualComp] PRIMARY KEY CLUSTERED ([Grade] ASC, [GradeLevel] ASC, [YoS] ASC, [HasDependents] ASC, [AmcosVersionId] ASC)
);











