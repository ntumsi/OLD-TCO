
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [web].[PMAddUserSummary]
    @UserID NVARCHAR(50),
    @ProjectID INT,
    @PayPlan NVARCHAR(3),
    @Type NVARCHAR(50),
    @SummaryName NVARCHAR(50),
    @InReport INT,
	@SummaryId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO webuser.User_Summaries
    (
        UserId,
        ProjectId,
        PayPlan,
        Type,
        SummaryName,
        InReport
    )
    VALUES
    (@UserID, @ProjectID, @PayPlan, @Type, @SummaryName, @InReport);
    
	SELECT @SummaryId = @@IDENTITY;
END;