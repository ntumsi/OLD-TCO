CREATE TABLE [webuser].[PMProject] (
    [UserId]              NVARCHAR (50)   NOT NULL,
    [ProjectId]           INT             IDENTITY (1, 1) NOT NULL,
    [ProjectName]         NVARCHAR (50)   NOT NULL,
    [YearStart]           INT             NOT NULL,
    [YearDuration]        INT             CONSTRAINT [DF_User_Projects_YearDuration] DEFAULT ((5)) NOT NULL,
    [ProjectCreator]      NVARCHAR (50)   NULL,
    [ProjectType]         NVARCHAR (50)   CONSTRAINT [DF_User_Projects_ProjectType] DEFAULT ('Weapons System') NOT NULL,
    [ReserveDaysInActive] INT             CONSTRAINT [DF_User_Projects_ReserveDaysInActive] DEFAULT ((24)) NOT NULL,
    [ReserveDaysActive]   INT             CONSTRAINT [DF_User_Projects_ReserveDaysActive] DEFAULT ((14)) NOT NULL,
    [CreateDate]          DATETIME        CONSTRAINT [DF_User_Projects_CreateDate] DEFAULT (getdate()) NOT NULL,
    [LastUpdate]          DATETIME        CONSTRAINT [DF_User_Projects_LastUpdate] DEFAULT (getdate()) NOT NULL,
    [Description]         NVARCHAR (4000) NULL,
    [DiscountRate]        FLOAT (53)      NULL,
    CONSTRAINT [PK_User_Projects] PRIMARY KEY CLUSTERED ([UserId] ASC, [ProjectId] ASC)
);

