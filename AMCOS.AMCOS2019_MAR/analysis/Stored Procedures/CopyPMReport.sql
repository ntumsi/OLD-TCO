

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [analysis].[CopyPMReport]
    @UserId NVARCHAR(50),
    @ProjectIdToCopy INT,
    @ProjectId INT,
    @CategoryIdToCopy INT,
    @CategoryId INT
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO webuser.PMReport
    (
        UserId,
        ProjectId,
        CategoryId,
        PayPlan,
        SummaryName
    )
    SELECT @UserId,
           @ProjectId,
           @CategoryId,
           PayPlan,
           SummaryName
    FROM webuser.PMReport
    WHERE ProjectId = @ProjectIdToCopy
          AND CategoryId = @CategoryIdToCopy;

    PRINT 'Copied PMReport (' + CAST(@ProjectId AS NVARCHAR(25)) + ')';

    RETURN;

END;