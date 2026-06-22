CREATE TABLE [dataload].[SepParms] (
    [PayPlan]     NVARCHAR (3)   NOT NULL,
    [Code]        NVARCHAR (25)  NOT NULL,
    [GradeType]   NCHAR (1)      NOT NULL,
    [GradeLevel]  TINYINT        NOT NULL,
    [Description] NVARCHAR (255) NULL,
    [Amount]      FLOAT (53)     NOT NULL,
    CONSTRAINT [PK_SepParms] PRIMARY KEY CLUSTERED ([PayPlan] ASC, [Code] ASC, [GradeType] ASC, [GradeLevel] ASC)
);

