-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMGetCategories]
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
        JOIN webuser.PMProject PMProject
            ON PMCategory.UserId = PMProject.UserId
               AND PMCategory.ProjectId = PMProject.ProjectId
               AND PMCategory.CategoryName <> PMProject.ProjectName
    WHERE PMCategory.UserId = @UserID
          AND PMCategory.ProjectId = @ProjectID
);