-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetProjectYearStart] 
(
	@CategoryId int
)
RETURNS int
AS
BEGIN
	DECLARE @Result int

	SELECT @Result = PMProject.YearStart
    FROM webuser.PMCategory PMCategory
        INNER JOIN webuser.PMProject PMProject
            ON PMProject.ProjectId = PMCategory.ProjectId
    WHERE PMCategory.CategoryId = @CategoryId;

	RETURN @Result
END