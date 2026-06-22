CREATE TABLE [web].[ApplicationErrorLog] (
    [ErrorId]     INT             IDENTITY (1, 1) NOT NULL,
    [ErrorTime]   DATETIME        NULL,
    [UserId]      NVARCHAR (50)   NULL,
    [ErrorPage]   NVARCHAR (200)  NULL,
    [ErrorDetail] NVARCHAR (3000) NULL
);

