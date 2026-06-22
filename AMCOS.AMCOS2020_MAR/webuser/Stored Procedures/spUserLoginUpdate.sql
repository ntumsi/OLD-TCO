
CREATE PROCEDURE [webuser].[spUserLoginUpdate]
    @UserId VARCHAR(50),
    @DodId VARCHAR(100),
    @Browser VARCHAR(50),
    @BrowserVersion VARCHAR(50),
    @CACEmail VARCHAR(500) = NULL
AS
BEGIN
    UPDATE webuser.AMCOSUser
    SET LastLogin = GETDATE(),
        DodId = @DodId,
        CACEmail = @CACEmail
    WHERE UserId = @UserId;

    INSERT INTO webuser.User_Login_History
    (
        UserId,
        LoginDateTime,
        Browser,
        BrowserVersion
    )
    VALUES
    (@UserId, SYSDATETIME(), @Browser, @BrowserVersion);
END;