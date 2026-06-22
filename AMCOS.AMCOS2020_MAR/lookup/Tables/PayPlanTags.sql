CREATE TABLE [lookup].[PayPlanTags](
	[PayPlan] [NVARCHAR](3) NOT NULL,
	[Tag] [NVARCHAR](100) NOT NULL,
	[AmcosVersionId] [INT] NOT NULL,
 CONSTRAINT [PK_PayPlanTags] PRIMARY KEY CLUSTERED 
(
	[PayPlan] ASC,
	[Tag] ASC,
	[AmcosVersionId] ASC
));

