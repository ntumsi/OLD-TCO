CREATE TABLE [DMDC].[Pay] (
    [FileDate]                     NVARCHAR (10)   NOT NULL,
    [PayPlan]                      NVARCHAR (3)    NOT NULL,
    [GradeType]                    NVARCHAR (3)    NOT NULL,
    [GradeLevel]                   TINYINT         NOT NULL,
    [PayType]                      NVARCHAR (300)  NOT NULL,
    [PrimaryServiceOccupationCode] NVARCHAR (20)   NOT NULL,
    [Count]                        INT             NULL,
    [TotalPayAmount]               NUMERIC (18, 2) NULL,
    [AmcosVersionId]               INT             NOT NULL,
    CONSTRAINT [PK_Pay] PRIMARY KEY CLUSTERED ([FileDate] ASC, [PayPlan] ASC, [GradeType] ASC, [GradeLevel] ASC, [PayType] ASC, [PrimaryServiceOccupationCode] ASC, [AmcosVersionId] ASC)
);




GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-20190116-152447]
    ON [DMDC].[Pay]([AmcosVersionId] ASC);

