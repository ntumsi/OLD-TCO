-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMGetCategoriesAll]
(
    @UserID NVARCHAR(50),
    @ProjectID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT PMCategory.UserId,
           PMCategory.ProjectId,
           PMCategory.CategoryId,
           PMCategory.CategoryName
    FROM webuser.PMCategory PMCategory
        JOIN webuser.PMProject p
            ON PMCategory.UserId = p.UserId
               AND PMCategory.ProjectId = p.ProjectId
    WHERE PMCategory.UserId = @UserID
          AND PMCategory.ProjectId = @ProjectID
);