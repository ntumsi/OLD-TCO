CREATE TABLE [webuser].[User_Login_History] (
    [UserId]         VARCHAR (50) NOT NULL,
    [loginDateTime]  DATETIME     NOT NULL,
    [Browser]        VARCHAR (50) NULL,
    [BrowserVersion] VARCHAR (50) NULL,
    CONSTRAINT [PK_User_Login_History] PRIMARY KEY CLUSTERED ([UserId] ASC, [loginDateTime] ASC)
);

