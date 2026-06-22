CREATE TABLE [webuser].[PMReport] (
    [ReportId]   INT          IDENTITY (1, 1) NOT NULL,
    [CategoryId] INT          NOT NULL,
    [PayPlan]    NVARCHAR (3) NOT NULL,
    CONSTRAINT [PK_PMReport] PRIMARY KEY CLUSTERED ([ReportId] ASC),
    CONSTRAINT [FK_PMReport_PMCategory] FOREIGN KEY ([CategoryId]) REFERENCES [webuser].[PMCategory] ([CategoryId])
);








GO


