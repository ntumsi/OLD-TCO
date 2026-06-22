CREATE TABLE [webuser].[User_Login_History_DeletedUsers] (
    [UserId]         VARCHAR (50) NOT NULL,
    [loginDateTime]  DATETIME     NOT NULL,
    [browser]        VARCHAR (50) NULL,
    [browserVersion] VARCHAR (50) NULL
);

