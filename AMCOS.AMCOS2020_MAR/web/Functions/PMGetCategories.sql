-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMGetCategories]
(
    @ProjectId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT PMCategory.ProjectId,
           PMCategory.CategoryId,
           PMCategory.CategoryName
    FROM webuser.PMCategory PMCategory
        JOIN webuser.PMProject PMProject
            ON PMCategory.ProjectId = PMProject.ProjectId
               AND PMCategory.CategoryName <> PMProject.ProjectName
    WHERE PMProject.ProjectId = @ProjectId
);