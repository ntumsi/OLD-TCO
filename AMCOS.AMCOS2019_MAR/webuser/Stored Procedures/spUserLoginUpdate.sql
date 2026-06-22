
CREATE PROCEDURE [webuser].[spUserLoginUpdate]
    @UserId VARCHAR(50),
    @DodId VARCHAR(100),
    @Browser VARCHAR(50),
    @BrowserVersion VARCHAR(50)
AS
BEGIN
    UPDATE webuser.AMCOSUser
    SET LastLogin = GETDATE(),
        DodId = @DodId
    WHERE UserId = @UserId;

    INSERT INTO webuser.User_Login_History
    (
        UserId,
        loginDateTime,
        Browser,
        BrowserVersion
    )
    VALUES
    (@UserId, GETDATE(), @Browser, @BrowserVersion);
END;