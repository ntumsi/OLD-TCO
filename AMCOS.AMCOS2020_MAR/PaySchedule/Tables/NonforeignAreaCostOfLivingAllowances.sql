CREATE TABLE [PaySchedule].[NonforeignAreaCostOfLivingAllowances] (
    [NonforeignAreaCode] NVARCHAR (10)  NOT NULL,
    [ColaRate]           NUMERIC (5, 2) NOT NULL,
    [AmcosVersionId]     INT            NOT NULL,
    CONSTRAINT [PK_NonforeignAreaCostOfLivingAllowances] PRIMARY KEY CLUSTERED ([NonforeignAreaCode] ASC, [AmcosVersionId] ASC)
);











