CREATE TABLE [web].[QlikGroup](
	[GroupName]			[NVARCHAR](25) NOT NULL,
	[QlikApplicationId] [int] NOT NULL,
	[Order]				[INT] NULL,
	CONSTRAINT [PK_QlikGroup] PRIMARY KEY CLUSTERED 
	(
	[GroupName]			ASC,
	[QlikApplicationId] ASC
	)
) 
GO;

ALTER TABLE [web].[QlikGroup] ADD FOREIGN KEY([QlikApplicationId])
REFERENCES [web].[QlikApplication] ([Id])
GO;