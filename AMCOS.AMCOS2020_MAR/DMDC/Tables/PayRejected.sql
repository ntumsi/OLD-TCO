CREATE TABLE [DMDC].[PayRejected] (
    [Id]                           INT            IDENTITY (1, 1) NOT NULL,
    [FileDate]                     NVARCHAR (10)  NULL,
    [ServiceComponent]             NVARCHAR (5)   NULL,
    [GradeType]                    NVARCHAR (2)   NULL,
    [GradeLevel]                   NVARCHAR (3)   NULL,
    [PayType]                      NVARCHAR (300) NULL,
    [PrimaryServiceOccupationCode] NVARCHAR (20)  NULL,
    [Count]                        INT            NULL,
    [TotalPayAmount]               FLOAT (53)     NULL,
    [AmcosVersionId]               INT            NULL,
    CONSTRAINT [PK_PayRejected] PRIMARY KEY CLUSTERED ([Id] ASC)
);





