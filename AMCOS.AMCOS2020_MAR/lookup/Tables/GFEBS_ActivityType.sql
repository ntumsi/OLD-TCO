CREATE TABLE [lookup].[GFEBS_ActivityType] (
    [ActivityTypeCode]    NVARCHAR (50)  NOT NULL,
    [ActivityTypeText]    NVARCHAR (250) NULL,
    [AmcosVersionIdStart] INT            NULL,
    [AmcosVersionIdEnd]   INT            NOT NULL,
    CONSTRAINT [PK_GFEBS_ActivityType] PRIMARY KEY CLUSTERED ([ActivityTypeCode] ASC, [AmcosVersionIdEnd] ASC)
);



