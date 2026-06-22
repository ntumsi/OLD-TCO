CREATE TABLE [webuser].[AMCOSUser] (
    [UserId]           NVARCHAR (50)  NOT NULL,
    [FirstName]        NVARCHAR (50)  NOT NULL,
    [MiddleName]       NVARCHAR (50)  NULL,
    [LastName]         NVARCHAR (50)  NOT NULL,
    [Email]            NVARCHAR (50)  NOT NULL,
    [Prefix]           NVARCHAR (5)   NULL,
    [AkoId]            NVARCHAR (50)  NULL,
    [DodId]            NVARCHAR (50)  NULL,
    [ComPhone]         NVARCHAR (50)  NULL,
    [Dsn]              NVARCHAR (50)  NULL,
    [InternationalNo]  NVARCHAR (30)  NULL,
    [ArmyAccountType]  NVARCHAR (50)  NULL,
    [ArmyRank]         NVARCHAR (50)  NULL,
    [OfficeName]       NVARCHAR (100) NULL,
    [CompanyName]      NVARCHAR (100) NULL,
    [Macom]            NVARCHAR (50)  NULL,
    [AccessStatus]     SMALLINT       NULL,
    [UserStatus]       NVARCHAR (14)  NULL,
    [UserRole]         NVARCHAR (50)  NULL,
    [SelfAccountType]  NVARCHAR (10)  NULL,
    [SponsorUserId]    NVARCHAR (50)  NULL,
    [LastLogin]        DATETIME       NULL,
    [DateCreated]      DATETIME       NOT NULL,
    [LastUpdate]       DATETIME       NOT NULL,
    [LastApprovedDate] DATETIME       NULL,
    [LastDeniedDate]   DATETIME       NULL,
    [CACEmail]         NVARCHAR (500) NULL,
    [Cn]               NVARCHAR (50)  NULL,
    CONSTRAINT [PK_AMCOSUser] PRIMARY KEY CLUSTERED ([UserId] ASC)
);


GO
ADD SENSITIVITY CLASSIFICATION TO
    [webuser].[AMCOSUser].[DodId]
    WITH (LABEL = 'Confidential', LABEL_ID = '331f0b13-76b5-2f1b-a77b-def5a73c73c2', INFORMATION_TYPE = 'Other', INFORMATION_TYPE_ID = '9c5b4809-0ccc-0637-6547-91a6f8bb609d', RANK = MEDIUM);
