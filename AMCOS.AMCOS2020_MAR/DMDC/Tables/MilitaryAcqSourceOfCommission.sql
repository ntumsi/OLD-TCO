CREATE TABLE [DMDC].[MilitaryAcqSourceOfCommission] (
    [Id]                  INT           IDENTITY (1, 1) NOT NULL,
    [Component]           NVARCHAR (25) NULL,
    [PayGrade]            NVARCHAR (3)  NULL,
    [TransactionTypeCode] NVARCHAR (3)  NULL,
    [SourceOfCommission]  NVARCHAR (2)  NULL,
    [CMF]                 NVARCHAR (2)  NULL,
    [AOC]                 NVARCHAR (4)  NULL,
    [Total]               INT           NULL,
    [AmcosVersionId]      INT           NULL,
    CONSTRAINT [PK_MilitaryAcqSourceOfCommission] PRIMARY KEY CLUSTERED ([Id] ASC)
);





